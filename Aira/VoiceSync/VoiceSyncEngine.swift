import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
class VoiceSyncEngine: ObservableObject {
  static let inputTapBufferSize: AVAudioFrameCount = 128

  @Published var state: EngineState = .idle
  @Published var isPausedByUser: Bool = false
  @Published var scrollOffset: CGFloat = 0
  @Published var manualLineNudgeID: Int = 0
  @Published var manualLineNudgeDirection: CGFloat = 0
  @Published var currentWordIndex: Int?
  @Published var highlightedWordRange: Range<Int>?
  @Published var visualCurrentWordIndex: Int?
  @Published var visualHighlightedWordRange: Range<Int>?
  @Published var isHumanSpeechActive: Bool = false

  private var audioEngine: AVAudioEngine?
  private var recognitionTask: SFSpeechRecognitionTask?
  // Thread-safe box so the AVAudioEngine tap (audio thread) can append buffers
  // without racing against @MainActor restarts that swap the request out.
  private let recognitionBox = RecognitionRequestBox()
  private let recognizer = SFSpeechRecognizer(locale: .current)
  weak var audioLevelMonitor: AudioLevelMonitor?
  private var silenceDeadlineTask: Task<Void, Never>?
  private let speechAuthorizationStatus: () -> SFSpeechRecognizerAuthorizationStatus
  private let microphonePermissionGranted: () -> Bool

  private var scriptWords: [String] = []
  private var cursorIndex: Int = 0
  private var visualCursorIndex: Int = 0
  private var visibleWordRange: Range<Int> = 0..<0
  private let strictMatchLookAhead: Int = 3
  private let visualMatchLookAhead: Int = 3
  private let silenceThresholdNanoseconds: UInt64 = 500_000_000
  private var recognitionEnabled: Bool = false
  private var recognitionDrivesScroll: Bool = true
  private var previousPartialTokens: [String] = []
  private var recognitionGeneration: UInt64 = 0

  init(
    speechAuthorizationStatus: @escaping () -> SFSpeechRecognizerAuthorizationStatus = {
      SFSpeechRecognizer.authorizationStatus()
    },
    microphonePermissionGranted: @escaping () -> Bool = {
      AVAudioApplication.shared.recordPermission == .granted
    }
  ) {
    self.speechAuthorizationStatus = speechAuthorizationStatus
    self.microphonePermissionGranted = microphonePermissionGranted
  }

  // MARK: - Public API

  func loadScript(text: String, startingAt offset: CGFloat = 0) {
    scriptWords = VoiceSyncMatching.tokenize(text)
    cursorIndex = Int(CGFloat(max(scriptWords.count, 1)) * offset)
    visibleWordRange = 0..<scriptWords.count
    scrollOffset = offset
    isPausedByUser = false
    currentWordIndex = nil
    highlightedWordRange = nil
    visualCurrentWordIndex = nil
    visualHighlightedWordRange = nil
    isHumanSpeechActive = false
    visualCursorIndex = cursorIndex
    previousPartialTokens = []
  }

  func start() {
    guard state == .idle else { return }
    AiraLogger.shared.info("voiceSync.start requested", category: "voice")
    recognitionEnabled = true
    startWithRecognitionIfAuthorized()
  }

  func startAudioMonitoring() {
    guard state == .idle else { return }
    recognitionEnabled = false
    startMonitoringIfAuthorized()
  }

  func stop() {
    recognitionGeneration &+= 1
    state = .idle
    silenceDeadlineTask?.cancel()
    silenceDeadlineTask = nil
    recognitionTask?.cancel()
    recognitionTask = nil
    recognitionBox.set(nil)
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine = nil
    cursorIndex = 0
    scrollOffset = 0
    isPausedByUser = false
    manualLineNudgeID = 0
    manualLineNudgeDirection = 0
    currentWordIndex = nil
    highlightedWordRange = nil
    visualCurrentWordIndex = nil
    visualHighlightedWordRange = nil
    isHumanSpeechActive = false
    audioLevelMonitor?.reset()
    recognitionEnabled = false
    recognitionDrivesScroll = true
    scriptWords = []
    visibleWordRange = 0..<0
    visualCursorIndex = 0
    previousPartialTokens = []
  }

  func togglePause() {
    isPausedByUser.toggle()
  }

  func enableRecognitionIfNeeded() {
    guard !recognitionEnabled else { return }
    recognitionEnabled = true
    restartRecognitionIfNeeded()
  }

  func setRecognitionDrivesScroll(_ drivesScroll: Bool) {
    recognitionDrivesScroll = drivesScroll
  }

  func nudgeScroll(by delta: CGFloat, resetSpokenTracking: Bool = true) {
    let updatedOffset = min(max(scrollOffset + delta, 0), 1)
    scrollOffset = updatedOffset
    cursorIndex = Int(CGFloat(max(scriptWords.count, 1)) * updatedOffset)
    if resetSpokenTracking {
      currentWordIndex = nil
      highlightedWordRange = nil
      visualCurrentWordIndex = nil
      visualHighlightedWordRange = nil
      visualCursorIndex = cursorIndex
      previousPartialTokens = []
    }
  }

  func nudgeScroll(to offset: CGFloat, resetSpokenTracking: Bool = true) {
    let clamped = min(max(offset, 0), 1)
    scrollOffset = clamped
    cursorIndex = Int(CGFloat(max(scriptWords.count, 1)) * clamped)
    if resetSpokenTracking {
      currentWordIndex = nil
      highlightedWordRange = nil
      visualCurrentWordIndex = nil
      visualHighlightedWordRange = nil
      visualCursorIndex = cursorIndex
      previousPartialTokens = []
    }
  }

  func updateVisibleWordRange(_ range: Range<Int>) {
    let lower = min(max(range.lowerBound, 0), scriptWords.count)
    let upper = min(max(range.upperBound, lower), scriptWords.count)
    visibleWordRange = lower..<upper
  }

  func reseedHighlight(to wordIndex: Int) {
    guard !scriptWords.isEmpty else { return }

    let clampedIndex = min(max(wordIndex, 0), scriptWords.count - 1)
    cursorIndex = clampedIndex
    visualCursorIndex = clampedIndex
    currentWordIndex = nil
    highlightedWordRange = nil
    visualCurrentWordIndex = clampedIndex
    visualHighlightedWordRange = 0..<clampedIndex
    previousPartialTokens = []
  }

  func requestManualLineNudge(direction: CGFloat) {
    guard direction != 0 else { return }
    manualLineNudgeDirection = direction
    manualLineNudgeID += 1
  }

  // MARK: - Permissions

  private func startWithRecognitionIfAuthorized() {
    let speechStatus = speechAuthorizationStatus()

    if speechStatus == .authorized && microphonePermissionGranted() {
      startEngine()
    }
  }

  private func startMonitoringIfAuthorized() {
    if microphonePermissionGranted() {
      startEngine()
    }
  }

  // MARK: - Engine

  private func startEngine() {
    AiraLogger.shared.info("voiceSync.startEngine begin", category: "voice")
    let engine = AVAudioEngine()
    audioEngine = engine

    let inputNode = engine.inputNode
    let format = inputNode.outputFormat(forBus: 0)

    inputNode.installTap(onBus: 0, bufferSize: Self.inputTapBufferSize, format: format) {
      [weak self, recognitionBox] buffer, _ in
      // recognitionBox is captured by reference and is lock-protected,
      // so this audio-thread access is safe across recognition restarts.
      if self?.recognitionEnabled == true {
        recognitionBox.append(buffer)
      }
      Task { @MainActor [weak self] in
        self?.audioLevelMonitor?.processBuffer(buffer)
      }
    }

    if recognitionEnabled {
      recognizer?.supportsOnDeviceRecognition = true

      let request = SFSpeechAudioBufferRecognitionRequest()
      request.requiresOnDeviceRecognition = true
      request.shouldReportPartialResults = true
      request.addsPunctuation = false
      recognitionBox.set(request)
      let generation = recognitionGeneration

      recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
        guard let self else { return }
        guard generation == self.recognitionGeneration else { return }
        if let result {
          Task { @MainActor [weak self] in
            guard let self, generation == self.recognitionGeneration else { return }
            self.handleRecognitionResult(result)
          }
          // On-device recognition tasks have a ~1 minute limit.
          // When isFinal is true the task is done — restart immediately
          // so voice sync continues uninterrupted.
          if result.isFinal {
            Task { @MainActor [weak self] in
              guard let self, generation == self.recognitionGeneration else { return }
              self.restartRecognitionIfNeeded()
            }
          }
        }
        if let error {
          let nsError = error as NSError
          // Code 301 = audio session interrupted; Code 216 = task cancelled
          // Code 1110 = no speech detected — ignore these
          let ignoredCodes = [216, 301, 1110]
          guard !ignoredCodes.contains(nsError.code) else { return }
          AiraLogger.shared.error(
            "Recognition error code=\(nsError.code) message=\(error.localizedDescription)",
            category: "voice"
          )
          Task { @MainActor [weak self] in
            guard let self, generation == self.recognitionGeneration else { return }
            self.restartRecognitionIfNeeded()
          }
        }
      }
    }

    do {
      try engine.start()
      AiraLogger.shared.info("voiceSync.engineStarted", category: "voice")
      state = .running
      if recognitionEnabled {
        scheduleSilenceDeadline()
      }
    } catch {
      AiraLogger.shared.error(error, category: "voice", context: "Failed to start audio engine")
    }
  }

  // MARK: - Word Matching

  private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
    defer {
      if result.isFinal {
        previousPartialTokens = []
      }
    }

    guard state != .idle else { return }
    guard !isPausedByUser else { return }

    scheduleSilenceDeadline()
    if state == .paused {
      state = .running
    }

    let recognizedWords = VoiceSyncMatching.recognizedWords(from: result.bestTranscription.segments)
    guard !recognizedWords.isEmpty else { return }

    isHumanSpeechActive = true
    let searchRange = normalizedSearchRange()
    guard !searchRange.isEmpty else { return }
    processVisualPartialDelta(recognizedWords, searchRange: searchRange)

    guard recognitionDrivesScroll else { return }

    // Tiered Matching Strategy
    // Apple's partial results update the trailing words constantly. We use the
    // last few words to overlap against the script.
    // To prevent false jumps (jitter), we restrict the look-ahead distance
    // based on how much contextual overlap we have. This ensures we don't jump
    // 40 words ahead just because the user said "the".
    var match: VoiceSyncMatching.Match?

    for configuration in VoiceSyncMatching.matchConfigurations {
      guard
        let window = VoiceSyncMatching.trailingRecognizedWindow(
          from: recognizedWords,
          length: configuration.windowLength,
          minimumWordConfidence: configuration.minimumWordConfidence,
          minimumAverageConfidence: configuration.minimumAverageConfidence
        )
      else { continue }

      match = VoiceSyncMatching.findDetailedMatch(
        scriptWords: scriptWords,
        spokenWindow: window.map(\.token),
        cursorIndex: searchRange.lowerBound,
        lookAhead: min(searchRange.count, strictMatchLookAhead),
        minimumOverlap: configuration.windowLength
      )

      if match != nil {
        break
      }
    }

    guard let match else { return }

    currentWordIndex = match.currentWordIndex
    highlightedWordRange = match.startIndex..<match.matchedWindowEnd

    // Directly use the matched index. Visual smoothing is handled by UI.
    guard match.currentWordIndex > cursorIndex else { return }

    cursorIndex = match.currentWordIndex
    let offset = VoiceSyncMatching.scrollOffset(
      cursorIndex: cursorIndex,
      totalWords: scriptWords.count
    )

    scrollOffset = offset

  }

  private func normalizedSearchRange() -> Range<Int> {
    guard !scriptWords.isEmpty else { return 0..<0 }
    let lower = min(max(max(cursorIndex, visibleWordRange.lowerBound), 0), scriptWords.count)
    let upper = min(max(visibleWordRange.upperBound, lower), scriptWords.count)
    return lower..<upper
  }

  private func processVisualPartialDelta(
    _ recognizedWords: [VoiceSyncMatching.RecognizedWord],
    searchRange: Range<Int>
  ) {
    let partialTokens = recognizedWords.map(\.token)
    let stablePrefixCount = VoiceSyncMatching.commonPrefixLength(
      lhs: previousPartialTokens,
      rhs: partialTokens
    )

    let visualSearchLowerBound = min(
      max(max(visualCursorIndex, searchRange.lowerBound), 0),
      scriptWords.count
    )
    let visualSearchUpperBound = min(
      max(searchRange.upperBound, visualSearchLowerBound), scriptWords.count)
    let visualSearchRange = visualSearchLowerBound..<visualSearchUpperBound

    guard !visualSearchRange.isEmpty else {
      previousPartialTokens = partialTokens
      return
    }

    var nextVisualCursor = visualCursorIndex
    var lastMatchedVisualIndex: Int?

    for token in partialTokens.dropFirst(stablePrefixCount) {
      let searchStart = min(
        max(nextVisualCursor, visualSearchRange.lowerBound), visualSearchRange.upperBound)
      let remainingLookAhead = min(
        max(visualSearchRange.upperBound - searchStart, 0),
        visualMatchLookAhead
      )
      guard remainingLookAhead > 0 else { continue }
      guard
        let match = VoiceSyncMatching.findDetailedMatch(
          scriptWords: scriptWords,
          spokenWindow: [token],
          cursorIndex: searchStart,
          lookAhead: remainingLookAhead,
          minimumOverlap: 1
        )
      else { continue }

      nextVisualCursor = match.currentWordIndex + 1
      lastMatchedVisualIndex = match.currentWordIndex

      // In voice-driven mode, keep immediate per-word updates so follow feels
      // live. In classical highlight-only mode, publish once per partial below
      // to avoid redraw bursts that can make scrolling look jerky.
      if recognitionDrivesScroll {
        visualCurrentWordIndex = match.currentWordIndex
        visualHighlightedWordRange = 0..<match.currentWordIndex
      }
    }

    visualCursorIndex = nextVisualCursor
    if !recognitionDrivesScroll, let lastMatchedVisualIndex {
      visualCurrentWordIndex = lastMatchedVisualIndex
      visualHighlightedWordRange = 0..<lastMatchedVisualIndex
    }
    previousPartialTokens = partialTokens
  }

  private func restartRecognitionIfNeeded() {
    guard state != .idle, audioEngine != nil else { return }
    recognitionTask?.cancel()
    recognitionTask = nil

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.requiresOnDeviceRecognition = true
    request.shouldReportPartialResults = true
    request.addsPunctuation = false
    recognitionBox.set(request)
    let generation = recognitionGeneration

    recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
      guard let self else { return }
      guard generation == self.recognitionGeneration else { return }
      if let result {
        Task { @MainActor [weak self] in
          guard let self, generation == self.recognitionGeneration else { return }
          self.handleRecognitionResult(result)
        }
        if result.isFinal {
          Task { @MainActor [weak self] in
            guard let self, generation == self.recognitionGeneration else { return }
            self.restartRecognitionIfNeeded()
          }
        }
      }
      if let error {
        let nsError = error as NSError
        let ignoredCodes = [216, 301, 1110]
        guard !ignoredCodes.contains(nsError.code) else { return }
        AiraLogger.shared.error(
          "Recognition error code=\(nsError.code) message=\(error.localizedDescription)",
          category: "voice"
        )
        Task { @MainActor [weak self] in
          guard let self, generation == self.recognitionGeneration else { return }
          self.restartRecognitionIfNeeded()
        }
      }
    }
  }

  private func scheduleSilenceDeadline() {
    silenceDeadlineTask?.cancel()
    let generation = recognitionGeneration
    silenceDeadlineTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: self?.silenceThresholdNanoseconds ?? 500_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        guard let self else { return }
        guard generation == self.recognitionGeneration else { return }
        if self.state == .running {
          self.state = .paused
          self.isHumanSpeechActive = false
          self.highlightedWordRange = nil
        }
      }
    }
  }

  // MARK: - State

  enum EngineState {
    case idle, running, paused
  }
}

/// Thread-safe container for the active SFSpeechAudioBufferRecognitionRequest.
/// The AVAudioEngine tap runs on an audio thread and must not access @MainActor
/// state directly. This box uses NSLock to allow safe concurrent reads from the
/// audio thread while @MainActor code swaps requests during recognition restarts.
final class RecognitionRequestBox {
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private let lock = NSLock()

  func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
    lock.withLock { self.request = request }
  }

  func append(_ buffer: AVAudioPCMBuffer) {
    let r = lock.withLock { request }
    r?.append(buffer)
  }
}

struct VoiceSyncMatching {
  struct RecognizedWord: Equatable {
    let token: String
    let confidence: Float
  }

  struct MatchConfiguration {
    let windowLength: Int
    let minimumWordConfidence: Float
    let minimumAverageConfidence: Float
  }

  struct TokenSpan: Equatable {
    let normalized: String
    let range: NSRange
  }

  struct Match: Equatable {
    let startIndex: Int
    let overlap: Int

    var currentWordIndex: Int {
      startIndex + max(overlap - 1, 0)
    }

    var matchedWindowEnd: Int {
      startIndex + overlap
    }
  }

  static func tokenize(_ text: String) -> [String] {
    tokenSpans(in: text).map(\.normalized)
  }

  static let matchConfigurations: [MatchConfiguration] = [
    MatchConfiguration(
      windowLength: 3, minimumWordConfidence: 0.35, minimumAverageConfidence: 0.55),
    MatchConfiguration(
      windowLength: 2, minimumWordConfidence: 0.45, minimumAverageConfidence: 0.62),
    MatchConfiguration(
      windowLength: 1, minimumWordConfidence: 0.72, minimumAverageConfidence: 0.72),
  ]

  static func recognizedWords(from segments: [SFTranscriptionSegment]) -> [RecognizedWord] {
    segments.compactMap { segment in
      guard let token = normalizeToken(segment.substring) else { return nil }
      return RecognizedWord(token: token, confidence: segment.confidence)
    }
  }

  static func trailingRecognizedWindow(
    from recognizedWords: [RecognizedWord],
    length: Int,
    minimumWordConfidence: Float,
    minimumAverageConfidence: Float
  ) -> [RecognizedWord]? {
    guard recognizedWords.count >= length else { return nil }
    let window = Array(recognizedWords.suffix(length))
    guard window.allSatisfy({ $0.confidence >= minimumWordConfidence }) else { return nil }
    let averageConfidence =
      window.reduce(Float.zero) { partial, word in
        partial + word.confidence
      } / Float(length)
    guard averageConfidence >= minimumAverageConfidence else { return nil }
    return window
  }

  static func commonPrefixLength(lhs: [String], rhs: [String]) -> Int {
    let maxCount = min(lhs.count, rhs.count)
    var prefixLength = 0

    while prefixLength < maxCount, lhs[prefixLength] == rhs[prefixLength] {
      prefixLength += 1
    }

    return prefixLength
  }

  static func tokenSpans(in text: String) -> [TokenSpan] {
    let nsText = text as NSString
    let fullRange = NSRange(location: 0, length: nsText.length)
    let regex = try? NSRegularExpression(pattern: #"[^\s]+"#)
    let matches = regex?.matches(in: text, range: fullRange) ?? []

    return matches.compactMap { match in
      let rawToken = nsText.substring(with: match.range)
      guard let normalized = normalizeToken(rawToken) else { return nil }
      return TokenSpan(normalized: normalized, range: match.range)
    }
  }

  static func normalizeToken(_ token: String) -> String? {
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed.hasPrefix("[") == false else { return nil }

    let normalized =
      trimmed
      .lowercased()
      .trimmingCharacters(in: .punctuationCharacters)

    return normalized.isEmpty ? nil : normalized
  }

  static func findDetailedMatch(
    scriptWords: [String],
    spokenWindow: [String],
    cursorIndex: Int,
    lookAhead: Int = 18,
    minimumOverlap: Int = 2
  ) -> Match? {
    guard !scriptWords.isEmpty, !spokenWindow.isEmpty else {
      return nil
    }

    let requiredOverlap = min(max(minimumOverlap, 1), spokenWindow.count)
    let startIndex = min(cursorIndex, scriptWords.count)
    let endIndex = min(startIndex + lookAhead, scriptWords.count)
    var bestMatch: Match?

    for index in startIndex..<endIndex {
      let overlap = overlapCount(
        scriptWords: scriptWords,
        spokenWindow: spokenWindow,
        startIndex: index
      )

      guard overlap >= requiredOverlap else { continue }

      let candidate = Match(startIndex: index, overlap: overlap)
      if let currentBest = bestMatch {
        if overlap > currentBest.overlap
          || (overlap == currentBest.overlap && index < currentBest.startIndex)
        {
          bestMatch = candidate
        }
      } else {
        bestMatch = candidate
      }
    }

    return bestMatch
  }

  static func findMatch(
    scriptWords: [String],
    spokenWindow: [String],
    cursorIndex: Int,
    lookAhead: Int = 100,
    minimumOverlap: Int = 2
  ) -> Int? {
    findDetailedMatch(
      scriptWords: scriptWords,
      spokenWindow: spokenWindow,
      cursorIndex: cursorIndex,
      lookAhead: lookAhead,
      minimumOverlap: minimumOverlap
    ).map { $0.startIndex + spokenWindow.count }
  }

  static func scrollOffset(cursorIndex: Int, totalWords: Int) -> CGFloat {
    CGFloat(cursorIndex) / CGFloat(max(totalWords, 1))
  }

  private static func overlapCount(
    scriptWords: [String],
    spokenWindow: [String],
    startIndex: Int
  ) -> Int {
    var overlap = 0
    for wordIndex in 0..<spokenWindow.count {
      let scriptIndex = startIndex + wordIndex
      guard scriptIndex < scriptWords.count else { break }
      if scriptWords[scriptIndex] == spokenWindow[wordIndex] {
        overlap += 1
      }
    }
    return overlap
  }

}
