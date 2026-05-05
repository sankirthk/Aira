import AVFoundation
import Combine
import Foundation

@MainActor
class VoiceSyncEngine: ObservableObject {
  static let inputTapBufferSize: AVAudioFrameCount = 128
  static let enablesPlatformVoiceProcessingDSP = false

  @Published var state: EngineState = .idle
  @Published var isPausedByUser: Bool = false
  @Published var scrollOffset: CGFloat = 0
  @Published var manualLineNudgeID: Int = 0
  @Published var manualLineNudgeDirection: CGFloat = 0
  @Published var currentWordIndex: Int?
  @Published var highlightedWordRange: Range<Int>?
  @Published var isHumanSpeechActive: Bool = false
  @Published var voiceScrollMode: VoiceScrollMode = .wordTracking

  private var audioEngine: AVAudioEngine?
  weak var audioLevelMonitor: AudioLevelMonitor?
  private var silenceDeadlineTask: Task<Void, Never>?
  private let microphonePermissionGranted: () -> Bool

  private var scriptWords: [String] = []
  private var cursorIndex: Int = 0
  private var visibleWordRange: Range<Int> = 0..<0
  private let silenceThresholdNanoseconds: UInt64 = 500_000_000
  private let firstTapTimeoutNanoseconds: UInt64 = 2_000_000_000
  private let firstRecognitionTimeoutNanoseconds: UInt64 = 4_000_000_000
  private let diagnosticAudioFloor: Float = 0.003
  private var recognitionEnabled: Bool = false
  private var recognitionDrivesScroll: Bool = true
  private var recognitionGeneration: UInt64 = 0
  private var audioEngineConfigurationObserver: NSObjectProtocol?
  private var firstTapTimeoutTask: Task<Void, Never>?
  private var firstRecognitionTimeoutTask: Task<Void, Never>?
  private var diagnostics = DiagnosticsState()
  private let wordTrackingRecognitionBackend: SpeechRecognitionBackend?
  private let highlightRecognitionBackend: SpeechRecognitionBackend?
  private var previousPartialTokens: [String] = []
  private let tokenLookAhead = 50
  private let minimumRecognizedWordConfidence: Float = 0.50
  private let recentSpokenWordLimit = 3
  private let robustSingleTokenLookAhead = 4
  private let robustLocalLookAhead = 15
  private let robustDeepLookAhead = 200
  private var recentSpokenWords: [String] = []
  private var acceptsRecognitionCallbacks = false

  enum MatcherMode: Equatable {
    case startup
    case steady
    case catchUp(lagWords: Int)
  }

  init(
    recognitionBackend: SpeechRecognitionBackend? = nil,
    microphonePermissionGranted: @escaping () -> Bool = {
      AVAudioApplication.shared.recordPermission == .granted
    }
  ) {
    let wordTrackingBackend = recognitionBackend ?? WhisperSpeechRecognitionBackend()
    self.wordTrackingRecognitionBackend = wordTrackingBackend
    self.highlightRecognitionBackend = recognitionBackend ?? AppleSpeechRecognitionBackend()
    self.microphonePermissionGranted = microphonePermissionGranted
    configureRecognitionBackendCallbacks()
  }

  init(
    recognitionBackend: SpeechRecognitionBackend? = nil,
    highlightRecognitionBackend: SpeechRecognitionBackend?,
    microphonePermissionGranted: @escaping () -> Bool = {
      AVAudioApplication.shared.recordPermission == .granted
    }
  ) {
    let wordTrackingBackend = recognitionBackend ?? WhisperSpeechRecognitionBackend()
    self.wordTrackingRecognitionBackend = wordTrackingBackend
    self.highlightRecognitionBackend =
      highlightRecognitionBackend ?? recognitionBackend ?? AppleSpeechRecognitionBackend()
    self.microphonePermissionGranted = microphonePermissionGranted
    configureRecognitionBackendCallbacks()
  }

  private func configureRecognitionBackendCallbacks() {
    let handleProcessingChanged: @MainActor (Bool) -> Void = { [weak self] isProcessing in
      guard let self else { return }
      if isProcessing {
        self.isHumanSpeechActive = true
      }
    }
    for backend in uniqueRecognitionBackends {
      backend.onRecognizedWord = { [weak self] token in
        self?.handleRecognizedWordToken(token)
      }
      (backend as? PartialSpeechRecognitionBackend)?.onRecognizedWords = {
        [weak self] words, isFinal in
        self?.handleRecognizedWords(words, isFinal: isFinal)
      }
      backend.onProcessingChanged = handleProcessingChanged
    }
  }

  private var activeRecognitionBackend: SpeechRecognitionBackend? {
    voiceScrollMode == .wordTracking ? wordTrackingRecognitionBackend : highlightRecognitionBackend
  }

  private var uniqueRecognitionBackends: [SpeechRecognitionBackend] {
    var backends: [SpeechRecognitionBackend] = []
    let configuredBackends = [
      wordTrackingRecognitionBackend,
      highlightRecognitionBackend,
    ].compactMap { $0 }
    for backend in configuredBackends {
      guard !backends.contains(where: { $0 === backend }) else { continue }
      backends.append(backend)
    }
    return backends
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
    isHumanSpeechActive = false
    recentSpokenWords = []
    previousPartialTokens = []
    acceptsRecognitionCallbacks = true
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
    for backend in uniqueRecognitionBackends {
      backend.stop()
    }
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
    isHumanSpeechActive = false
    audioLevelMonitor?.reset()
    recognitionEnabled = false
    recognitionDrivesScroll = true
    scriptWords = []
    visibleWordRange = 0..<0
    recentSpokenWords = []
    previousPartialTokens = []
    diagnostics = DiagnosticsState()
    acceptsRecognitionCallbacks = false
  }

  func togglePause() {
    isPausedByUser.toggle()
  }

  func enableRecognitionIfNeeded() {
    guard !recognitionEnabled else { return }
    recognitionEnabled = true
    prepareRecognitionBackendIfNeeded()
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
      recentSpokenWords = []
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
      recentSpokenWords = []
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
    currentWordIndex = clampedIndex
    highlightedWordRange = 0..<clampedIndex
    recentSpokenWords = []
    previousPartialTokens = []
  }

  func requestManualLineNudge(direction: CGFloat) {
    guard direction != 0 else { return }
    manualLineNudgeDirection = direction
    manualLineNudgeID += 1
  }

  // MARK: - Permissions

  private func startWithRecognitionIfAuthorized() {
    let microphoneGranted = microphonePermissionGranted()
    AiraLogger.shared.info(
      "voiceSync.authorization microphoneGranted=\(microphoneGranted)",
      category: "voice"
    )

    if microphoneGranted {
      prepareRecognitionBackendThenStartEngine()
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

  private func prepareRecognitionBackendThenStartEngine() {
    let generation = recognitionGeneration
    AiraLogger.shared.info("voiceSync.prepareBackend begin", category: "voice")
    Task { @MainActor [weak self] in
      guard let self, generation == self.recognitionGeneration else { return }
      do {
        try await self.activeRecognitionBackend?.prepare()
        guard generation == self.recognitionGeneration else { return }
        AiraLogger.shared.info("voiceSync.prepareBackend completed", category: "voice")
        self.startEngine()
      } catch {
        self.recognitionEnabled = false
        AiraLogger.shared.error(
          error, category: "voice", context: "Failed to prepare speech backend")
      }
    }
  }

  private func startEngine() {
    AiraLogger.shared.info("voiceSync.startEngine begin", category: "voice")
    diagnostics = DiagnosticsState()
    diagnostics.sessionStart = Date()
    removeDiagnosticsObservers()
    let engine = AVAudioEngine()
    audioEngine = engine
    observeAudioEngineConfigurationChanges(engine)

    let inputNode = engine.inputNode
    if Self.enablesPlatformVoiceProcessingDSP {
      do {
        try inputNode.setVoiceProcessingEnabled(true)
        AiraLogger.shared.info("voiceSync.voiceProcessing enabled=true", category: "voice")
      } catch {
        AiraLogger.shared.info(
          "voiceSync.voiceProcessing enabled=false error=\"\(error.localizedDescription)\"",
          category: "voice"
        )
      }
    } else {
      AiraLogger.shared.info(
        "voiceSync.voiceProcessing enabled=false reason=captureOnly", category: "voice")
    }

    let inputFormat = inputNode.inputFormat(forBus: 0)
    let format = inputNode.outputFormat(forBus: 0)
    AiraLogger.shared.info(
      "voiceSync.input format input=\(inputFormat.voiceSyncDebugDescription) output=\(format.voiceSyncDebugDescription)",
      category: "voice"
    )

    inputNode.installTap(onBus: 0, bufferSize: Self.inputTapBufferSize, format: format) {
      [weak self] buffer, _ in
      if self?.recognitionEnabled == true,
        let samples = VoiceSyncRecognitionInput.makeRecognitionSamples(from: buffer)
      {
        Task { @MainActor [weak self] in
          await self?.activeRecognitionBackend?.acceptAudio(samples)
        }
      }
      Task { @MainActor [weak self] in
        self?.recordTapDiagnostics(for: buffer)
        self?.audioLevelMonitor?.processBuffer(buffer)
      }
    }

    if recognitionEnabled {
      prepareRecognitionBackendIfNeeded()
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

  private func prepareRecognitionBackendIfNeeded() {
    guard recognitionEnabled else { return }
    let generation = recognitionGeneration
    Task { @MainActor [weak self] in
      guard let self, generation == self.recognitionGeneration else { return }
      do {
        try await self.activeRecognitionBackend?.prepare()
      } catch {
        AiraLogger.shared.error(
          error, category: "voice", context: "Failed to prepare speech backend")
      }
    }
  }

  // MARK: - Word Matching

  private func handleRecognizedWords(
    _ recognizedWords: [VoiceSyncMatching.RecognizedWord],
    isFinal: Bool
  ) {
    defer {
      if isFinal {
        previousPartialTokens = []
      }
    }

    guard acceptsRecognitionCallbacks else { return }
    guard voiceScrollMode != .wordTracking else { return }
    guard !isPausedByUser else { return }
    guard !recognizedWords.isEmpty else { return }

    scheduleSilenceDeadline()
    recordRecognitionDiagnostics(recognizedWords: recognizedWords, isFinal: isFinal)
    if state == .paused {
      state = .running
    }
    isHumanSpeechActive = true

    let searchRange = normalizedSearchRange()
    logSearchWindowStateIfNeeded(recognizedWords: recognizedWords, searchRange: searchRange)
    guard !searchRange.isEmpty else { return }
    processHighlightPartialDelta(recognizedWords, searchRange: searchRange)
  }

  private func processHighlightPartialDelta(
    _ recognizedWords: [VoiceSyncMatching.RecognizedWord],
    searchRange: Range<Int>
  ) {
    let partialTokens = recognizedWords.map(\.token)
    let stablePrefixCount = VoiceSyncMatching.commonPrefixLength(
      lhs: previousPartialTokens,
      rhs: partialTokens
    )

    let hasEstablishedMatch = currentWordIndex != nil || !previousPartialTokens.isEmpty
    let searchLowerBound = min(
      max(
        Self.startupSearchLowerBound(
          cursorIndex: cursorIndex,
          visibleWordLowerBound: searchRange.lowerBound,
          hasEstablishedMatch: hasEstablishedMatch
        ),
        0
      ),
      scriptWords.count
    )
    let searchUpperBound = min(max(searchRange.upperBound, searchLowerBound), scriptWords.count)
    let visualSearchRange = searchLowerBound..<searchUpperBound

    guard !visualSearchRange.isEmpty else {
      previousPartialTokens = partialTokens
      return
    }

    let matcherMode = matcherMode(
      hasEstablishedMatch: hasEstablishedMatch,
      lagWords: max(visibleWordRange.lowerBound - cursorIndex, 0)
    )

    if matcherMode == .startup,
      let startupSeedMatch = Self.startupSeedMatch(
        scriptWords: scriptWords,
        recognizedWords: recognizedWords,
        searchRange: visualSearchRange
      )
    {
      publishHighlightOnlyMatch(startupSeedMatch)
      previousPartialTokens = partialTokens
      return
    }

    var nextCursor = cursorIndex
    var lastMatch: VoiceSyncMatching.Match?
    for token in partialTokens.dropFirst(stablePrefixCount) {
      let searchStart = min(
        max(
          Self.startupSearchLowerBound(
            cursorIndex: nextCursor,
            visibleWordLowerBound: searchRange.lowerBound,
            hasEstablishedMatch: hasEstablishedMatch
          ),
          visualSearchRange.lowerBound
        ),
        visualSearchRange.upperBound
      )
      let lookAhead = min(
        max(visualSearchRange.upperBound - searchStart, 0),
        Self.recommendedVisualMatchLookAhead(
          visibleWordCount: visualSearchRange.count,
          mode: matcherMode
        )
      )
      guard lookAhead > 0 else { continue }
      guard
        let match = VoiceSyncMatching.findDetailedMatch(
          scriptWords: scriptWords,
          spokenWindow: [token],
          cursorIndex: searchStart,
          lookAhead: lookAhead,
          minimumOverlap: 1
        )
      else { continue }
      guard
        Self.isLowOverlapMatchPlausible(
          matchStartIndex: match.startIndex,
          searchStart: searchStart,
          minimumOverlap: 1,
          mode: matcherMode
        )
      else { continue }

      nextCursor = match.currentWordIndex + 1
      lastMatch = match
    }

    cursorIndex = nextCursor
    if let lastMatch {
      publishHighlightOnlyMatch(lastMatch)
    }
    previousPartialTokens = partialTokens
  }

  private func publishHighlightOnlyMatch(_ match: VoiceSyncMatching.Match) {
    currentWordIndex = match.currentWordIndex
    highlightedWordRange = 0..<match.currentWordIndex
    cursorIndex = max(cursorIndex, match.currentWordIndex + 1)
  }

  private func handleRecognizedWordToken(_ token: SpokenWordToken) {
    guard acceptsRecognitionCallbacks else { return }
    guard voiceScrollMode == .wordTracking else { return }
    guard !isPausedByUser else { return }
    scheduleSilenceDeadline()
    recordRecognitionTokenDiagnostics(token)
    if state == .paused {
      state = .running
    }
    isHumanSpeechActive = true
    guard let match = matchRecognizedWordToken(token) else {
      AiraLogger.shared.info(
        "voiceSync.wordTokenNoMatch token=\"\(token.word)\" cursorIndex=\(cursorIndex) words=\(scriptWords.count)",
        category: "voice"
      )
      return
    }

    currentWordIndex = match.currentWordIndex
    highlightedWordRange = 0..<match.currentWordIndex
    cursorIndex = max(cursorIndex, match.currentWordIndex)

    switch voiceScrollMode {
    case .classicScroll:
      break
    case .soundBased:
      break
    case .wordTracking:
      if recognitionDrivesScroll {
        scrollOffset = VoiceSyncMatching.scrollOffset(
          cursorIndex: cursorIndex,
          totalWords: scriptWords.count
        )
        AiraLogger.shared.info(
          "voiceSync.wordTrackingScroll token=\"\(token.word)\" currentWordIndex=\(match.currentWordIndex) scrollOffset=\(scrollOffset)",
          category: "voice"
        )
      }
    }
  }

  private func matchRecognizedWordToken(_ token: SpokenWordToken) -> VoiceSyncMatching.Match? {
    guard let normalized = VoiceSyncMatching.normalizeToken(token.word) else { return nil }
    let confidence = token.confidence ?? 1
    guard confidence >= minimumRecognizedWordConfidence else {
      AiraLogger.shared.info(
        "voiceSync.wordTokenRejected reason=lowConfidence token=\"\(token.word)\" confidence=\(confidence)",
        category: "voice"
      )
      return nil
    }
    appendRecentSpokenWord(normalized)

    let searchStart = min(max(cursorIndex, 0), scriptWords.count)
    return VoiceSyncMatching.findRobustMatch(
      scriptWords: scriptWords,
      recentSpokenWords: recentSpokenWords,
      currentIndex: searchStart,
      singleTokenLookAhead: robustSingleTokenLookAhead,
      localLookAhead: min(robustLocalLookAhead, tokenLookAhead),
      deepLookAhead: robustDeepLookAhead
    )
  }

  private func appendRecentSpokenWord(_ normalized: String) {
    recentSpokenWords.append(normalized)
    if recentSpokenWords.count > recentSpokenWordLimit {
      recentSpokenWords.removeFirst(recentSpokenWords.count - recentSpokenWordLimit)
    }
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

  private func recordRecognitionTokenDiagnostics(_ token: SpokenWordToken) {
    diagnostics.recognitionPartialCount += 1
    if diagnostics.recognitionPartialCount <= 3 {
      AiraLogger.shared.info(
        "voiceSync.recognition token seq=\(diagnostics.recognitionPartialCount) word=\"\(token.word)\" confidence=\(token.confidence ?? -1) t=\(diagnosticElapsedText())",
        category: "voice"
      )
    }
    if !diagnostics.didLogFirstRecognitionPartial {
      diagnostics.didLogFirstRecognitionPartial = true
      firstRecognitionTimeoutTask?.cancel()
      firstRecognitionTimeoutTask = nil
      AiraLogger.shared.info(
        "voiceSync.recognition firstToken word=\"\(token.word)\" t=\(diagnosticElapsedText())",
        category: "voice"
      )
    }
  }

  private func recordRecognitionDiagnostics(
    recognizedWords: [VoiceSyncMatching.RecognizedWord],
    isFinal: Bool
  ) {
    diagnostics.recognitionPartialCount += 1
    if diagnostics.recognitionPartialCount <= 3 {
      let tokenPreview = recognizedWords.prefix(6).map(\.token).joined(separator: " ")
      AiraLogger.shared.info(
        "voiceSync.recognition applePartial seq=\(diagnostics.recognitionPartialCount) isFinal=\(isFinal) words=\(recognizedWords.count) t=\(diagnosticElapsedText()) tokens=\"\(tokenPreview)\"",
        category: "voice"
      )
    }
    if !diagnostics.didLogFirstRecognitionPartial {
      diagnostics.didLogFirstRecognitionPartial = true
      firstRecognitionTimeoutTask?.cancel()
      firstRecognitionTimeoutTask = nil
    }
    if isFinal {
      diagnostics.didLogFirstRecognitionFinal = true
    }
  }

  private struct DiagnosticsState {
    var sessionStart: Date?
    var didLogFirstTap = false
    var didLogFirstNontrivialAudio = false
    var didLogFirstRecognitionPartial = false
    var didLogFirstRecognitionFinal = false
    var didLogFirstStartupSeed = false
    var didLogFirstStrictMatch = false
    var didLogFirstScrollPublish = false
    var didLogFirstSearchWindow = false
    var didLogFirstStartupSeedMiss = false
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
      "voiceSync.startupSeed miss search=\(searchRange.lowerBound)..<\(searchRange.upperBound) cursor=\(cursorIndex) visible=\(visibleWordRange.lowerBound)..<\(visibleWordRange.upperBound) t=\(diagnosticElapsedText()) tokens=\"\(tokenPreview)\"",
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
      "voiceSync.searchWindow seq=\(diagnostics.recognitionPartialCount) cursor=\(cursorIndex) visible=\(visibleWordRange.lowerBound)..<\(visibleWordRange.upperBound) search=\(searchRange.lowerBound)..<\(searchRange.upperBound) t=\(diagnosticElapsedText()) tokens=\"\(tokenPreview)\"",
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

  static func recommendedRecoveryMatchLookAhead(
    visibleWordCount: Int,
    consecutiveMisses: Int
  ) -> Int {
    let normalizedVisibleCount = max(visibleWordCount, 0)
    let missBonus = min(max(consecutiveMisses, 0) * 2, 10)
    return min(max(normalizedVisibleCount / 3, 12) + missBonus, 24)
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

struct VoiceSyncRecognitionInput {
  static let minimumInputPeak: Float = 0.004
  static let targetPeak: Float = 0.18
  static let maxGain: Float = 12
  static let targetSampleRate: Double = 16_000

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
    guard sourcePeak >= minimumInputPeak else {
      return nil
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

  static func makeRecognitionSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
    guard let monoBuffer = makeRecognitionBuffer(from: buffer) else {
      return nil
    }

    guard let convertedBuffer = resampleForRecognitionIfNeeded(monoBuffer) else {
      return nil
    }
    guard let monoChannel = convertedBuffer.floatChannelData?[0],
      convertedBuffer.frameLength > 0
    else {
      return nil
    }

    let sampleCount = Int(convertedBuffer.frameLength)
    let samples = UnsafeBufferPointer(start: monoChannel, count: sampleCount)
    return Array(samples)
  }

  private static func resampleForRecognitionIfNeeded(
    _ monoBuffer: AVAudioPCMBuffer
  ) -> AVAudioPCMBuffer? {
    guard monoBuffer.format.sampleRate != targetSampleRate else {
      return monoBuffer
    }

    guard
      let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: targetSampleRate,
        channels: 1,
        interleaved: false
      ),
      let converter = AVAudioConverter(from: monoBuffer.format, to: targetFormat)
    else {
      return nil
    }

    let ratio = targetSampleRate / monoBuffer.format.sampleRate
    let targetCapacity = AVAudioFrameCount(
      max(1, Int(ceil(Double(monoBuffer.frameLength) * ratio)) + 16)
    )
    guard
      let convertedBuffer = AVAudioPCMBuffer(
        pcmFormat: targetFormat,
        frameCapacity: targetCapacity
      )
    else {
      return nil
    }

    var didProvideInput = false
    let inputBlock: AVAudioConverterInputBlock = { _, status in
      if didProvideInput {
        status.pointee = .noDataNow
        return nil
      }
      didProvideInput = true
      status.pointee = .haveData
      return monoBuffer
    }

    var conversionError: NSError?
    converter.convert(to: convertedBuffer, error: &conversionError, withInputFrom: inputBlock)
    guard conversionError == nil,
      convertedBuffer.frameLength > 0
    else {
      if let conversionError {
        AiraLogger.shared.error(
          conversionError,
          category: "voice",
          context: "Failed to resample recognition input"
        )
      }
      return nil
    }

    return convertedBuffer
  }

  private static func recognitionGain(forPeak peak: Float) -> Float {
    guard peak > 0 else { return 1 }
    return max(1, min(maxGain, targetPeak / peak))
  }
}

struct VoiceSyncMatching {
  static let stopWords: Set<String> = [
    "a",
    "an",
    "and",
    "in",
    "is",
    "it",
    "of",
    "so",
    "that",
    "the",
    "to",
    "for",
    "i",
    "on",
    "uh",
    "um",
    "you",
  ]

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

  static func findRobustMatch(
    scriptWords: [String],
    recentSpokenWords: [String],
    currentIndex: Int,
    singleTokenLookAhead: Int = 4,
    localLookAhead: Int = 15,
    deepLookAhead: Int = 200
  ) -> Match? {
    guard !scriptWords.isEmpty, let latestWord = recentSpokenWords.last else { return nil }

    let searchStart = min(max(currentIndex, 0), scriptWords.count)
    let localPhrase = Array(recentSpokenWords.suffix(min(recentSpokenWords.count, 3)))
    let localSearchEnd = min(searchStart + max(localLookAhead, 0), scriptWords.count)
    if localPhrase.count >= 2, searchStart < localSearchEnd {
      for index in searchStart..<localSearchEnd {
        guard scriptWords[index] == localPhrase[0] else { continue }
        guard index + localPhrase.count <= scriptWords.count else { continue }
        let scriptPhrase = scriptWords[index..<(index + localPhrase.count)]
        if Array(scriptPhrase) == localPhrase {
          return Match(startIndex: index, overlap: localPhrase.count)
        }
      }
    }

    let singleTokenSearchEnd = min(searchStart + max(singleTokenLookAhead, 0), scriptWords.count)
    if searchStart < singleTokenSearchEnd {
      for index in searchStart..<singleTokenSearchEnd {
        guard scriptWords[index] == latestWord else { continue }
        let distance = index - searchStart
        if distance > 1 && stopWords.contains(latestWord) { continue }
        return Match(startIndex: index, overlap: 1)
      }
    }

    guard recentSpokenWords.count >= 3 else { return nil }
    let spokenPhrase = Array(recentSpokenWords.suffix(3))
    guard isDeepSearchPhraseMeaningful(spokenPhrase) else { return nil }
    let deepSearchEnd = min(searchStart + max(deepLookAhead, 0), scriptWords.count)
    guard searchStart < deepSearchEnd else { return nil }

    for index in searchStart..<deepSearchEnd {
      guard scriptWords[index] == spokenPhrase[0] else { continue }
      guard index + spokenPhrase.count <= scriptWords.count else { return nil }
      let scriptPhrase = scriptWords[index..<(index + spokenPhrase.count)]
      if Array(scriptPhrase) == spokenPhrase {
        return Match(startIndex: index, overlap: spokenPhrase.count)
      }
    }

    return nil
  }

  private static func isDeepSearchPhraseMeaningful(_ spokenPhrase: [String]) -> Bool {
    spokenPhrase.filter { !stopWords.contains($0) }.count >= 2
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

  static func scrollOffset(cursorIndex: Int, totalWords: Int, lookaheadWords: Int = 15) -> CGFloat {
    let boundedTotalWords = max(totalWords, 1)
    let boundedLookahead = max(lookaheadWords, 0)
    let effectiveLookahead = boundedTotalWords >= boundedLookahead * 4 ? boundedLookahead : 0
    let adjustedIndex = min(max(cursorIndex + effectiveLookahead, 0), boundedTotalWords)
    return CGFloat(adjustedIndex) / CGFloat(boundedTotalWords)
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
