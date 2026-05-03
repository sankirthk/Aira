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
  private let silenceThresholdNanoseconds: UInt64 = 500_000_000
  private let firstTapTimeoutNanoseconds: UInt64 = 2_000_000_000
  private let firstRecognitionTimeoutNanoseconds: UInt64 = 4_000_000_000
  private let diagnosticAudioFloor: Float = 0.003
  private var recognitionEnabled: Bool = false
  private var recognitionDrivesScroll: Bool = true
  private var previousPartialTokens: [String] = []
  private var recognitionGeneration: UInt64 = 0
  private var audioEngineConfigurationObserver: NSObjectProtocol?
  private var firstTapTimeoutTask: Task<Void, Never>?
  private var firstRecognitionTimeoutTask: Task<Void, Never>?
  private var diagnostics = DiagnosticsState()
  private let recognitionBackend: SpeechRecognitionBackend?
  private let tokenLookAhead = 50

  enum MatcherMode: Equatable {
    case startup
    case steady
    case catchUp(lagWords: Int)
  }

  init(
    recognitionBackend: SpeechRecognitionBackend? = nil,
    speechAuthorizationStatus: @escaping () -> SFSpeechRecognizerAuthorizationStatus = {
      SFSpeechRecognizer.authorizationStatus()
    },
    microphonePermissionGranted: @escaping () -> Bool = {
      AVAudioApplication.shared.recordPermission == .granted
    }
  ) {
    self.recognitionBackend = recognitionBackend
    self.speechAuthorizationStatus = speechAuthorizationStatus
    self.microphonePermissionGranted = microphonePermissionGranted
    self.recognitionBackend?.onRecognizedWord = { [weak self] token in
      self?.handleRecognizedWordToken(token)
    }
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
    removeDiagnosticsObservers()
    firstTapTimeoutTask?.cancel()
    firstTapTimeoutTask = nil
    firstRecognitionTimeoutTask?.cancel()
    firstRecognitionTimeoutTask = nil
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
    diagnostics = DiagnosticsState()
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
    let microphoneGranted = microphonePermissionGranted()
    AiraLogger.shared.info(
      "voiceSync.authorization speech=\(speechStatus.debugName) microphoneGranted=\(microphoneGranted)",
      category: "voice"
    )

    if speechStatus == .authorized && microphoneGranted {
      startEngine()
    }
  }

  private func startMonitoringIfAuthorized() {
    let microphoneGranted = microphonePermissionGranted()
    AiraLogger.shared.info(
      "voiceSync.audioMonitor authorization microphoneGranted=\(microphoneGranted)",
      category: "voice"
    )
    if microphoneGranted {
      startEngine()
    }
  }

  // MARK: - Engine

  private func startEngine() {
    AiraLogger.shared.info("voiceSync.startEngine begin", category: "voice")
    diagnostics = DiagnosticsState()
    diagnostics.sessionStart = Date()
    removeDiagnosticsObservers()
    let engine = AVAudioEngine()
    audioEngine = engine
    observeAudioEngineConfigurationChanges(engine)

    let inputNode = engine.inputNode
    let inputFormat = inputNode.inputFormat(forBus: 0)
    let format = inputNode.outputFormat(forBus: 0)
    let recognizerLocale = recognizer?.locale.identifier ?? "nil"
    AiraLogger.shared.info(
      "voiceSync.input format input=\(inputFormat.voiceSyncDebugDescription) output=\(format.voiceSyncDebugDescription) recognizerAvailable=\(recognizer != nil) recognizerLocale=\(recognizerLocale)",
      category: "voice"
    )

    inputNode.installTap(onBus: 0, bufferSize: Self.inputTapBufferSize, format: format) {
      [weak self, recognitionBox] buffer, _ in
      // recognitionBox is captured by reference and is lock-protected,
      // so this audio-thread access is safe across recognition restarts.
      if self?.recognitionEnabled == true {
        recognitionBox.append(buffer)
      }
      Task { @MainActor [weak self] in
        self?.recordTapDiagnostics(for: buffer)
        self?.audioLevelMonitor?.processBuffer(buffer)
      }
    }

    if recognitionEnabled {
      recognizer?.supportsOnDeviceRecognition = true
      AiraLogger.shared.info(
        "voiceSync.recognition config supportsOnDevice=\(recognizer?.supportsOnDeviceRecognition == true)",
        category: "voice"
      )

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
            self.recordRecognitionDiagnostics(for: result)
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
          self.logRecognitionError(nsError)
          // Code 301 = audio session interrupted; Code 216 = task cancelled
          // Code 1110 = no speech detected — ignore these
          let ignoredCodes = [216, 301, 1110]
          guard !ignoredCodes.contains(nsError.code) else { return }
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
      scheduleDiagnosticTimeouts()
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
    logSearchWindowStateIfNeeded(recognizedWords: recognizedWords, searchRange: searchRange)
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
    let hasEstablishedSpokenMatch = currentWordIndex != nil || highlightedWordRange != nil
    let strictMatcherMode = matcherMode(
      hasEstablishedMatch: hasEstablishedSpokenMatch,
      lagWords: max(visibleWordRange.lowerBound - cursorIndex, 0)
    )

    if !hasEstablishedSpokenMatch,
      let startupSeedMatch = Self.startupSeedMatch(
        scriptWords: scriptWords,
        recognizedWords: recognizedWords,
        searchRange: searchRange
      )
    {
      logStartupSeedMatch(
        startupSeedMatch, recognizedWords: recognizedWords, searchRange: searchRange)
      match = startupSeedMatch
    } else if !hasEstablishedSpokenMatch {
      logStartupSeedMissIfNeeded(recognizedWords: recognizedWords, searchRange: searchRange)
    }

    for configuration in VoiceSyncMatching.matchConfigurations(
      hasEstablishedMatch: hasEstablishedSpokenMatch
    ) {
      if match != nil { break }
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
        lookAhead: Self.recommendedStrictMatchLookAhead(
          visibleWordCount: searchRange.count,
          minimumOverlap: configuration.windowLength,
          mode: strictMatcherMode
        ),
        minimumOverlap: configuration.windowLength
      )

      if let match,
        !Self.isLowOverlapMatchPlausible(
          matchStartIndex: match.startIndex,
          searchStart: searchRange.lowerBound,
          minimumOverlap: configuration.windowLength,
          mode: strictMatcherMode
        )
      {
        continue
      }

      if match != nil {
        logStrictMatch(match, configuration: configuration, mode: strictMatcherMode)
        break
      }
    }

    guard let match else { return }

    currentWordIndex = match.currentWordIndex
    highlightedWordRange = match.startIndex..<match.matchedWindowEnd
    logScrollHighlightPublish(match)

    // Directly use the matched index. Visual smoothing is handled by UI.
    guard match.currentWordIndex > cursorIndex else { return }

    cursorIndex = match.currentWordIndex
    let offset = VoiceSyncMatching.scrollOffset(
      cursorIndex: cursorIndex,
      totalWords: scriptWords.count
    )

    scrollOffset = offset

  }

  private func handleRecognizedWordToken(_ token: SpokenWordToken) {
    guard state != .idle || recognitionBackend != nil else { return }
    guard !isPausedByUser else { return }
    guard let match = matchRecognizedWordToken(token) else { return }

    currentWordIndex = match.currentWordIndex
    highlightedWordRange = 0..<match.currentWordIndex
    visualCurrentWordIndex = match.currentWordIndex
    visualHighlightedWordRange = 0..<match.currentWordIndex
    cursorIndex = max(cursorIndex, match.currentWordIndex)
    visualCursorIndex = max(visualCursorIndex, match.currentWordIndex + 1)
  }

  private func matchRecognizedWordToken(_ token: SpokenWordToken) -> VoiceSyncMatching.Match? {
    guard let normalized = VoiceSyncMatching.normalizeToken(token.word) else { return nil }
    let searchStart = min(max(cursorIndex, 0), scriptWords.count)
    let lookAhead = min(tokenLookAhead, max(scriptWords.count - searchStart, 0))
    guard lookAhead > 0 else { return nil }
    return VoiceSyncMatching.findDetailedMatch(
      scriptWords: scriptWords,
      spokenWindow: [normalized],
      cursorIndex: searchStart,
      lookAhead: lookAhead,
      minimumOverlap: 1
    )
  }

  private func normalizedSearchRange() -> Range<Int> {
    guard !scriptWords.isEmpty else { return 0..<0 }
    let lower = min(
      max(
        Self.startupSearchLowerBound(
          cursorIndex: cursorIndex,
          visibleWordLowerBound: visibleWordRange.lowerBound,
          hasEstablishedMatch: currentWordIndex != nil || highlightedWordRange != nil
        ),
        0
      ),
      scriptWords.count
    )
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

    let hasEstablishedVisualMatch = visualCurrentWordIndex != nil || !previousPartialTokens.isEmpty
    let visualSearchLowerBound = min(
      max(
        Self.startupSearchLowerBound(
          cursorIndex: visualCursorIndex,
          visibleWordLowerBound: searchRange.lowerBound,
          hasEstablishedMatch: hasEstablishedVisualMatch
        ),
        0
      ),
      scriptWords.count
    )
    let visualSearchUpperBound = min(
      max(searchRange.upperBound, visualSearchLowerBound), scriptWords.count)
    let visualSearchRange = visualSearchLowerBound..<visualSearchUpperBound

    guard !visualSearchRange.isEmpty else {
      previousPartialTokens = partialTokens
      return
    }

    let visualMatcherMode = matcherMode(
      hasEstablishedMatch: hasEstablishedVisualMatch,
      lagWords: max(visibleWordRange.lowerBound - visualCursorIndex, 0)
    )
    let visibleLowerBound = searchRange.lowerBound

    if visualMatcherMode == .startup,
      let startupSeedMatch = Self.startupSeedMatch(
        scriptWords: scriptWords,
        recognizedWords: recognizedWords,
        searchRange: visualSearchRange
      )
    {
      visualCursorIndex = startupSeedMatch.currentWordIndex + 1
      visualCurrentWordIndex = startupSeedMatch.currentWordIndex
      visualHighlightedWordRange = 0..<startupSeedMatch.currentWordIndex
      logVisualHighlightPublish(index: startupSeedMatch.currentWordIndex, source: "startupSeed")
      previousPartialTokens = partialTokens
      return
    }

    var nextVisualCursor = visualCursorIndex
    var lastMatchedVisualIndex: Int?

    for token in partialTokens.dropFirst(stablePrefixCount) {
      let searchStart = min(
        max(
          Self.startupSearchLowerBound(
            cursorIndex: nextVisualCursor,
            visibleWordLowerBound: visibleLowerBound,
            hasEstablishedMatch: hasEstablishedVisualMatch
          ),
          visualSearchRange.lowerBound
        ),
        visualSearchRange.upperBound
      )
      let remainingLookAhead = min(
        max(visualSearchRange.upperBound - searchStart, 0),
        Self.recommendedVisualMatchLookAhead(
          visibleWordCount: visualSearchRange.count,
          mode: visualMatcherMode
        )
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

      guard
        Self.isLowOverlapMatchPlausible(
          matchStartIndex: match.startIndex,
          searchStart: searchStart,
          minimumOverlap: 1,
          mode: visualMatcherMode
        )
      else { continue }

      logVisualCandidateIfNeeded(
        token: token,
        searchStart: searchStart,
        lookAhead: remainingLookAhead,
        match: match,
        mode: visualMatcherMode
      )

      nextVisualCursor = match.currentWordIndex + 1
      lastMatchedVisualIndex = match.currentWordIndex

      // In voice-driven mode, keep immediate per-word updates so follow feels
      // live. In classical highlight-only mode, publish once per partial below
      // to avoid redraw bursts that can make scrolling look jerky.
      if recognitionDrivesScroll {
        visualCurrentWordIndex = match.currentWordIndex
        visualHighlightedWordRange = 0..<match.currentWordIndex
        logVisualHighlightPublish(index: match.currentWordIndex, source: "partialDelta")
      }
    }

    visualCursorIndex = nextVisualCursor
    if !recognitionDrivesScroll, let lastMatchedVisualIndex {
      visualCurrentWordIndex = lastMatchedVisualIndex
      visualHighlightedWordRange = 0..<lastMatchedVisualIndex
      logVisualHighlightPublish(index: lastMatchedVisualIndex, source: "highlightOnly")
    }
    previousPartialTokens = partialTokens
  }

  private func restartRecognitionIfNeeded() {
    guard state != .idle, audioEngine != nil else { return }
    diagnostics.didLogFirstRecognitionPartial = false
    diagnostics.didLogFirstRecognitionFinal = false
    firstRecognitionTimeoutTask?.cancel()
    firstRecognitionTimeoutTask = nil
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
          self.recordRecognitionDiagnostics(for: result)
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
        self.logRecognitionError(nsError)
        let ignoredCodes = [216, 301, 1110]
        guard !ignoredCodes.contains(nsError.code) else { return }
        Task { @MainActor [weak self] in
          guard let self, generation == self.recognitionGeneration else { return }
          self.restartRecognitionIfNeeded()
        }
      }
    }
    scheduleFirstRecognitionTimeout()
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

  private func observeAudioEngineConfigurationChanges(_ engine: AVAudioEngine) {
    audioEngineConfigurationObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange,
      object: engine,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.logAudioEngineConfigurationChange()
      }
    }
  }

  private func removeDiagnosticsObservers() {
    if let audioEngineConfigurationObserver {
      NotificationCenter.default.removeObserver(audioEngineConfigurationObserver)
      self.audioEngineConfigurationObserver = nil
    }
  }

  private func logAudioEngineConfigurationChange() {
    guard let audioEngine else { return }
    let format = audioEngine.inputNode.outputFormat(forBus: 0)
    AiraLogger.shared.info(
      "voiceSync.configurationChanged state=\(state.debugName) format=\(format.voiceSyncDebugDescription)",
      category: "voice"
    )
  }

  private func scheduleDiagnosticTimeouts() {
    scheduleFirstTapTimeout()
    scheduleFirstRecognitionTimeout()
  }

  private func scheduleFirstTapTimeout() {
    firstTapTimeoutTask?.cancel()
    let generation = recognitionGeneration
    firstTapTimeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: self?.firstTapTimeoutNanoseconds ?? 2_000_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        guard let self else { return }
        guard generation == self.recognitionGeneration else { return }
        guard !self.diagnostics.didLogFirstTap else { return }
        AiraLogger.shared.info(
          "voiceSync.diagnostic noTapBufferWithin2s recognitionEnabled=\(self.recognitionEnabled) state=\(self.state.debugName)",
          category: "voice"
        )
      }
    }
  }

  private func scheduleFirstRecognitionTimeout() {
    guard recognitionEnabled else { return }
    firstRecognitionTimeoutTask?.cancel()
    let generation = recognitionGeneration
    firstRecognitionTimeoutTask = Task { [weak self] in
      try? await Task.sleep(
        nanoseconds: self?.firstRecognitionTimeoutNanoseconds ?? 4_000_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        guard let self else { return }
        guard generation == self.recognitionGeneration else { return }
        guard !self.diagnostics.didLogFirstRecognitionPartial else { return }
        AiraLogger.shared.info(
          "voiceSync.diagnostic noRecognitionPartialWithin4s tapReceived=\(self.diagnostics.didLogFirstTap) nontrivialAudio=\(self.diagnostics.didLogFirstNontrivialAudio)",
          category: "voice"
        )
      }
    }
  }

  private func recordTapDiagnostics(for buffer: AVAudioPCMBuffer) {
    if !diagnostics.didLogFirstTap {
      diagnostics.didLogFirstTap = true
      firstTapTimeoutTask?.cancel()
      firstTapTimeoutTask = nil
      AiraLogger.shared.info(
        "voiceSync.tap firstBuffer frames=\(buffer.frameLength) format=\(buffer.format.voiceSyncDebugDescription)",
        category: "voice"
      )
    }

    guard !diagnostics.didLogFirstNontrivialAudio else { return }
    let amplitude = buffer.voiceSyncPeakAmplitude
    guard amplitude >= diagnosticAudioFloor else { return }
    diagnostics.didLogFirstNontrivialAudio = true
    let peakText = String(format: "%.4f", amplitude)
    AiraLogger.shared.info(
      "voiceSync.tap firstNontrivialAudio peak=\(peakText) frames=\(buffer.frameLength)",
      category: "voice"
    )
  }

  private func recordRecognitionDiagnostics(for result: SFSpeechRecognitionResult) {
    let transcript = result.bestTranscription.formattedString
    diagnostics.recognitionPartialCount += 1
    let partialWordCount = VoiceSyncMatching.recognizedWords(
      from: result.bestTranscription.segments
    ).count
    if diagnostics.recognitionPartialCount <= 3 {
      AiraLogger.shared.info(
        "voiceSync.recognition partial seq=\(diagnostics.recognitionPartialCount) isFinal=\(result.isFinal) words=\(partialWordCount) chars=\(transcript.count) t=\(diagnosticElapsedText()) text=\"\(transcript.prefix(80))\"",
        category: "voice"
      )
    }
    if !diagnostics.didLogFirstRecognitionPartial {
      diagnostics.didLogFirstRecognitionPartial = true
      firstRecognitionTimeoutTask?.cancel()
      firstRecognitionTimeoutTask = nil
      AiraLogger.shared.info(
        "voiceSync.recognition firstPartial isFinal=\(result.isFinal) words=\(partialWordCount) chars=\(transcript.count) t=\(diagnosticElapsedText()) text=\"\(transcript.prefix(80))\"",
        category: "voice"
      )
    }

    if result.isFinal && !diagnostics.didLogFirstRecognitionFinal {
      diagnostics.didLogFirstRecognitionFinal = true
      AiraLogger.shared.info(
        "voiceSync.recognition firstFinal chars=\(transcript.count) text=\"\(transcript.prefix(80))\"",
        category: "voice"
      )
    }
  }

  private func logRecognitionError(_ error: NSError) {
    AiraLogger.shared.error(
      "Recognition error domain=\(error.domain) code=\(error.code) message=\(error.localizedDescription)",
      category: "voice"
    )
  }

  private struct DiagnosticsState {
    var sessionStart: Date?
    var didLogFirstTap = false
    var didLogFirstNontrivialAudio = false
    var didLogFirstRecognitionPartial = false
    var didLogFirstRecognitionFinal = false
    var didLogFirstStartupSeed = false
    var didLogFirstStrictMatch = false
    var didLogFirstVisualPublish = false
    var didLogFirstScrollPublish = false
    var didLogFirstSearchWindow = false
    var didLogFirstStartupSeedMiss = false
    var didLogFirstVisualCandidate = false
    var recognitionPartialCount = 0
  }

  private func diagnosticElapsedText() -> String {
    guard let sessionStart = diagnostics.sessionStart else { return "n/a" }
    let elapsedMs = Date().timeIntervalSince(sessionStart) * 1000
    return String(format: "%.2fms", elapsedMs)
  }

  private func logStartupSeedMatch(
    _ match: VoiceSyncMatching.Match,
    recognizedWords: [VoiceSyncMatching.RecognizedWord],
    searchRange: Range<Int>
  ) {
    guard !diagnostics.didLogFirstStartupSeed else { return }
    diagnostics.didLogFirstStartupSeed = true
    let tokenPreview = recognizedWords.prefix(6).map(\.token).joined(separator: " ")
    AiraLogger.shared.info(
      "voiceSync.startupSeed startIndex=\(match.startIndex) currentWordIndex=\(match.currentWordIndex) search=\(searchRange.lowerBound)..<\(searchRange.upperBound) t=\(diagnosticElapsedText()) tokens=\"\(tokenPreview)\"",
      category: "voice"
    )
  }

  private func logStartupSeedMissIfNeeded(
    recognizedWords: [VoiceSyncMatching.RecognizedWord],
    searchRange: Range<Int>
  ) {
    guard !diagnostics.didLogFirstStartupSeedMiss else { return }
    diagnostics.didLogFirstStartupSeedMiss = true
    let tokenPreview = recognizedWords.prefix(6).map(\.token).joined(separator: " ")
    AiraLogger.shared.info(
      "voiceSync.startupSeed miss search=\(searchRange.lowerBound)..<\(searchRange.upperBound) cursor=\(cursorIndex) visualCursor=\(visualCursorIndex) visible=\(visibleWordRange.lowerBound)..<\(visibleWordRange.upperBound) t=\(diagnosticElapsedText()) tokens=\"\(tokenPreview)\"",
      category: "voice"
    )
  }

  private func logStrictMatch(
    _ match: VoiceSyncMatching.Match?,
    configuration: VoiceSyncMatching.MatchConfiguration,
    mode: MatcherMode
  ) {
    guard !diagnostics.didLogFirstStrictMatch else { return }
    guard let match else { return }
    diagnostics.didLogFirstStrictMatch = true
    AiraLogger.shared.info(
      "voiceSync.strictMatch mode=\(mode.debugName) window=\(configuration.windowLength) startIndex=\(match.startIndex) overlap=\(match.overlap) currentWordIndex=\(match.currentWordIndex) t=\(diagnosticElapsedText())",
      category: "voice"
    )
  }

  private func logSearchWindowStateIfNeeded(
    recognizedWords: [VoiceSyncMatching.RecognizedWord],
    searchRange: Range<Int>
  ) {
    guard diagnostics.recognitionPartialCount <= 3 else { return }
    let tokenPreview = recognizedWords.prefix(6).map(\.token).joined(separator: " ")
    AiraLogger.shared.info(
      "voiceSync.searchWindow seq=\(diagnostics.recognitionPartialCount) cursor=\(cursorIndex) visualCursor=\(visualCursorIndex) visible=\(visibleWordRange.lowerBound)..<\(visibleWordRange.upperBound) search=\(searchRange.lowerBound)..<\(searchRange.upperBound) t=\(diagnosticElapsedText()) tokens=\"\(tokenPreview)\"",
      category: "voice"
    )
  }

  private func logVisualCandidateIfNeeded(
    token: String,
    searchStart: Int,
    lookAhead: Int,
    match: VoiceSyncMatching.Match,
    mode: MatcherMode
  ) {
    guard !diagnostics.didLogFirstVisualCandidate else { return }
    diagnostics.didLogFirstVisualCandidate = true
    AiraLogger.shared.info(
      "voiceSync.visualCandidate token=\"\(token)\" mode=\(mode.debugName) searchStart=\(searchStart) lookAhead=\(lookAhead) matchStart=\(match.startIndex) currentWordIndex=\(match.currentWordIndex) t=\(diagnosticElapsedText())",
      category: "voice"
    )
  }

  private func logVisualHighlightPublish(index: Int, source: String) {
    guard !diagnostics.didLogFirstVisualPublish else { return }
    diagnostics.didLogFirstVisualPublish = true
    AiraLogger.shared.info(
      "voiceSync.publish visual index=\(index) source=\(source) t=\(diagnosticElapsedText())",
      category: "voice"
    )
  }

  private func logScrollHighlightPublish(_ match: VoiceSyncMatching.Match) {
    guard !diagnostics.didLogFirstScrollPublish else { return }
    diagnostics.didLogFirstScrollPublish = true
    AiraLogger.shared.info(
      "voiceSync.publish scroll startIndex=\(match.startIndex) currentWordIndex=\(match.currentWordIndex) t=\(diagnosticElapsedText())",
      category: "voice"
    )
  }

  private func matcherMode(hasEstablishedMatch: Bool, lagWords: Int) -> MatcherMode {
    guard hasEstablishedMatch else { return .startup }
    return lagWords >= 4 ? .catchUp(lagWords: lagWords) : .steady
  }

  static func startupSeedMatch(
    scriptWords: [String],
    recognizedWords: [VoiceSyncMatching.RecognizedWord],
    searchRange: Range<Int>
  ) -> VoiceSyncMatching.Match? {
    guard !recognizedWords.isEmpty else { return nil }

    let startupLookAhead = Self.recommendedStrictMatchLookAhead(
      visibleWordCount: searchRange.count,
      minimumOverlap: 1,
      mode: .startup
    )

    for recognizedWord in recognizedWords {
      guard
        let match = VoiceSyncMatching.findDetailedMatch(
          scriptWords: scriptWords,
          spokenWindow: [recognizedWord.token],
          cursorIndex: searchRange.lowerBound,
          lookAhead: startupLookAhead,
          minimumOverlap: 1
        )
      else { continue }

      return match
    }

    return nil
  }

  static func startupSearchLowerBound(
    cursorIndex: Int,
    visibleWordLowerBound: Int,
    hasEstablishedMatch: Bool
  ) -> Int {
    let visibleLowerBound = max(visibleWordLowerBound, 0)
    guard hasEstablishedMatch else { return visibleLowerBound }
    return max(cursorIndex, 0)
  }

  static func recommendedStrictMatchLookAhead(
    visibleWordCount: Int,
    minimumOverlap: Int,
    mode: MatcherMode
  ) -> Int {
    let normalizedVisibleCount = max(visibleWordCount, 0)
    switch mode {
    case .startup:
      switch minimumOverlap {
      case 3...:
        return min(max(normalizedVisibleCount / 3, 12), 18)
      case 2:
        return min(max(normalizedVisibleCount / 4, 10), 14)
      default:
        return min(max(normalizedVisibleCount / 4, 10), 12)
      }
    case .steady:
      switch minimumOverlap {
      case 3...:
        return min(max(normalizedVisibleCount / 3, 10), 18)
      case 2:
        return min(max(normalizedVisibleCount / 5, 7), 12)
      default:
        return min(max(normalizedVisibleCount / 8, 4), 7)
      }
    case .catchUp(let lagWords):
      let lagBonus = min(max(lagWords / 2, 0), 8)
      switch minimumOverlap {
      case 3...:
        return min(max(normalizedVisibleCount / 2, 12) + lagBonus, 28)
      case 2:
        return min(max(normalizedVisibleCount / 4, 9) + (lagBonus / 2), 16)
      default:
        return min(max(normalizedVisibleCount / 6, 6) + (lagBonus / 2), 10)
      }
    }
  }

  static func recommendedVisualMatchLookAhead(
    visibleWordCount: Int,
    mode: MatcherMode
  ) -> Int {
    let normalizedVisibleCount = max(visibleWordCount, 0)
    switch mode {
    case .startup:
      return min(max(normalizedVisibleCount / 4, 8), 10)
    case .steady:
      return min(max(normalizedVisibleCount / 8, 4), 7)
    case .catchUp(let lagWords):
      let lagBonus = min(max(lagWords / 2, 0), 8)
      return min(max(normalizedVisibleCount / 5, 6) + (lagBonus / 2), 12)
    }
  }

  static func isLowOverlapMatchPlausible(
    matchStartIndex: Int,
    searchStart: Int,
    minimumOverlap: Int,
    mode: MatcherMode
  ) -> Bool {
    guard minimumOverlap <= 1 else { return true }
    let forwardDistance = max(matchStartIndex - searchStart, 0)
    switch mode {
    case .startup:
      return true
    case .steady:
      return true
    case .catchUp(let lagWords):
      return forwardDistance <= min(max(lagWords + 4, 8), 12)
    }
  }
}

extension VoiceSyncEngine.EngineState {
  fileprivate var debugName: String {
    switch self {
    case .idle:
      "idle"
    case .running:
      "running"
    case .paused:
      "paused"
    }
  }
}

extension VoiceSyncEngine.MatcherMode {
  fileprivate var debugName: String {
    switch self {
    case .startup:
      "startup"
    case .steady:
      "steady"
    case .catchUp(let lagWords):
      "catchUp(\(lagWords))"
    }
  }
}

extension SFSpeechRecognizerAuthorizationStatus {
  fileprivate var debugName: String {
    switch self {
    case .notDetermined:
      "notDetermined"
    case .denied:
      "denied"
    case .restricted:
      "restricted"
    case .authorized:
      "authorized"
    @unknown default:
      "unknown"
    }
  }
}

extension AVAudioFormat {
  fileprivate var voiceSyncDebugDescription: String {
    "sampleRate=\(sampleRate) channels=\(channelCount) interleaved=\(isInterleaved) commonFormat=\(commonFormat.debugName)"
  }
}

extension AVAudioCommonFormat {
  fileprivate var debugName: String {
    switch self {
    case .otherFormat:
      "other"
    case .pcmFormatFloat32:
      "float32"
    case .pcmFormatFloat64:
      "float64"
    case .pcmFormatInt16:
      "int16"
    case .pcmFormatInt32:
      "int32"
    @unknown default:
      "unknown"
    }
  }
}

extension AVAudioPCMBuffer {
  fileprivate var voiceSyncPeakAmplitude: Float {
    guard let channelData = floatChannelData, frameLength > 0 else { return 0 }
    let frameCount = Int(frameLength)
    let samples = UnsafeBufferPointer(start: channelData[0], count: frameCount)
    var peak: Float = 0
    for sample in samples {
      peak = max(peak, abs(sample))
    }
    return peak
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
    guard let r else { return }
    if let recognitionBuffer = VoiceSyncRecognitionInput.makeRecognitionBuffer(from: buffer) {
      r.append(recognitionBuffer)
    } else {
      r.append(buffer)
    }
  }
}

struct VoiceSyncRecognitionInput {
  static let targetPeak: Float = 0.18
  static let maxGain: Float = 12

  static func dominantChannelIndex(for buffer: AVAudioPCMBuffer) -> Int? {
    guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else { return nil }

    let frameCount = Int(buffer.frameLength)
    var strongestIndex: Int?
    var strongestPeak: Float = 0

    for channelIndex in 0..<Int(buffer.format.channelCount) {
      let samples = UnsafeBufferPointer(start: channelData[channelIndex], count: frameCount)
      var peak: Float = 0
      for sample in samples {
        peak = max(peak, abs(sample))
      }
      guard peak > strongestPeak else { continue }
      strongestPeak = peak
      strongestIndex = channelIndex
    }

    return strongestIndex
  }

  static func makeRecognitionBuffer(from buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard
      let channelData = buffer.floatChannelData,
      buffer.frameLength > 0,
      let dominantChannelIndex = dominantChannelIndex(for: buffer)
    else {
      return nil
    }

    let frameCount = Int(buffer.frameLength)
    let sourceSamples = UnsafeBufferPointer(
      start: channelData[dominantChannelIndex],
      count: frameCount
    )
    let sourcePeak = sourceSamples.reduce(into: Float(0)) { peak, sample in
      peak = max(peak, abs(sample))
    }

    let monoFormat = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: buffer.format.sampleRate,
      channels: 1,
      interleaved: false
    )
    guard let monoFormat,
      let recognitionBuffer = AVAudioPCMBuffer(
        pcmFormat: monoFormat,
        frameCapacity: buffer.frameLength
      ),
      let destinationChannel = recognitionBuffer.floatChannelData?[0]
    else {
      return nil
    }

    recognitionBuffer.frameLength = buffer.frameLength
    let destinationSamples = UnsafeMutableBufferPointer(
      start: destinationChannel, count: frameCount)
    let gain = recognitionGain(forPeak: sourcePeak)
    for frameIndex in 0..<frameCount {
      destinationSamples[frameIndex] = max(-1, min(1, sourceSamples[frameIndex] * gain))
    }

    return recognitionBuffer
  }

  private static func recognitionGain(forPeak peak: Float) -> Float {
    guard peak > 0 else { return 1 }
    return max(1, min(maxGain, targetPeak / peak))
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

  static let startupMatchConfigurations: [MatchConfiguration] = [
    MatchConfiguration(
      windowLength: 3, minimumWordConfidence: 0.35, minimumAverageConfidence: 0.55),
    MatchConfiguration(
      windowLength: 2, minimumWordConfidence: 0.45, minimumAverageConfidence: 0.62),
    MatchConfiguration(
      windowLength: 1, minimumWordConfidence: 0.55, minimumAverageConfidence: 0.55),
  ]

  static let steadyStateMatchConfigurations: [MatchConfiguration] = [
    MatchConfiguration(
      windowLength: 3, minimumWordConfidence: 0.35, minimumAverageConfidence: 0.55),
    MatchConfiguration(
      windowLength: 2, minimumWordConfidence: 0.45, minimumAverageConfidence: 0.62),
    MatchConfiguration(
      windowLength: 1, minimumWordConfidence: 0.72, minimumAverageConfidence: 0.72),
  ]

  static func matchConfigurations(hasEstablishedMatch: Bool) -> [MatchConfiguration] {
    hasEstablishedMatch ? steadyStateMatchConfigurations : startupMatchConfigurations
  }

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
