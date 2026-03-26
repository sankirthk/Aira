import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
class VoiceSyncEngine: ObservableObject {
    @Published var state: EngineState = .idle
    @Published var isPausedByUser: Bool = false
    @Published var scrollOffset: CGFloat = 0
    @Published var manualLineNudgeID: Int = 0
    @Published var manualLineNudgeDirection: CGFloat = 0
    @Published var currentWordIndex: Int?
    @Published var isHumanSpeechActive: Bool = false

    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let recognizer = SFSpeechRecognizer(locale: .current)
    weak var audioLevelMonitor: AudioLevelMonitor?
    private var silenceDeadlineTask: Task<Void, Never>?

    private var scriptWords: [String] = []
    private var cursorIndex: Int = 0
    private let silenceThresholdNanoseconds: UInt64 = 500_000_000
    private var recognitionEnabled: Bool = false

    // MARK: - Public API

    func loadScript(text: String, startingAt offset: CGFloat = 0) {
        scriptWords = VoiceSyncMatching.tokenize(text)
        cursorIndex = Int(CGFloat(max(scriptWords.count, 1)) * offset)
        scrollOffset = offset
        isPausedByUser = false
        currentWordIndex = nil
        isHumanSpeechActive = false
    }

    func start() {
        guard state == .idle else { return }
        recognitionEnabled = true
        requestPermissionsAndStartWithRecognition()
    }

    func startAudioMonitoring() {
        guard state == .idle else { return }
        recognitionEnabled = false
        requestMicrophonePermissionAndStart()
    }

    func stop() {
        silenceDeadlineTask?.cancel()
        silenceDeadlineTask = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        cursorIndex = 0
        scrollOffset = 0
        isPausedByUser = false
        manualLineNudgeID = 0
        manualLineNudgeDirection = 0
        currentWordIndex = nil
        isHumanSpeechActive = false
        audioLevelMonitor?.reset()
        recognitionEnabled = false
        state = .idle
    }

    func togglePause() {
        isPausedByUser.toggle()
    }

    func nudgeScroll(by delta: CGFloat) {
        let updatedOffset = min(max(scrollOffset + delta, 0), 1)
        scrollOffset = updatedOffset
        cursorIndex = Int(CGFloat(max(scriptWords.count, 1)) * updatedOffset)
        currentWordIndex = nil
    }

    func nudgeScroll(to offset: CGFloat) {
        let clamped = min(max(offset, 0), 1)
        scrollOffset = clamped
        cursorIndex = Int(CGFloat(max(scriptWords.count, 1)) * clamped)
        currentWordIndex = nil
    }

    func requestManualLineNudge(direction: CGFloat) {
        guard direction != 0 else { return }
        manualLineNudgeDirection = direction
        manualLineNudgeID += 1
    }

    // MARK: - Permissions

    private func requestPermissionsAndStartWithRecognition() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                guard granted else { return }
                Task { @MainActor [weak self] in
                    self?.startEngine()
                }
            }
        }
    }

    private func requestMicrophonePermissionAndStart() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard granted else { return }
            Task { @MainActor [weak self] in
                self?.startEngine()
            }
        }
    }

    // MARK: - Engine

    private func startEngine() {
        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            if self?.recognitionEnabled == true {
                self?.recognitionRequest?.append(buffer)
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
            recognitionRequest = request

            recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                if let result {
                    Task { @MainActor [weak self] in
                        self?.handleRecognitionResult(result)
                    }
                    // On-device recognition tasks have a ~1 minute limit.
                    // When isFinal is true the task is done — restart immediately
                    // so voice sync continues uninterrupted.
                    if result.isFinal {
                        Task { @MainActor [weak self] in
                            self?.restartRecognitionIfNeeded()
                        }
                    }
                }
                if let error {
                    let nsError = error as NSError
                    // Code 301 = audio session interrupted; Code 216 = task cancelled
                    // Code 1110 = no speech detected — ignore these
                    let ignoredCodes = [216, 301, 1110]
                    guard !ignoredCodes.contains(nsError.code) else { return }
                    print("VoiceSyncEngine: recognition error \(nsError.code) — \(error.localizedDescription)")
                    Task { @MainActor [weak self] in
                        self?.restartRecognitionIfNeeded()
                    }
                }
            }
        }

        do {
            try engine.start()
            state = .running
            if recognitionEnabled {
                scheduleSilenceDeadline()
            }
        } catch {
            print("VoiceSyncEngine: failed to start audio engine — \(error)")
        }
    }

    // MARK: - Word Matching

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        guard state != .idle else { return }
        guard !isPausedByUser else { return }

        scheduleSilenceDeadline()
        if state == .paused {
            state = .running
        }

        let spoken = result.bestTranscription.segments
            .compactMap { VoiceSyncMatching.normalizeToken($0.substring) }

        guard !spoken.isEmpty else { return }

        isHumanSpeechActive = true

        // Tiered Matching Strategy
        // Apple's partial results update the trailing words constantly. We use the
        // last few words to overlap against the script.
        // To prevent false jumps (jitter), we restrict the look-ahead distance
        // based on how much contextual overlap we have. This ensures we don't jump
        // 40 words ahead just because the user said "the".
        var match: VoiceSyncMatching.Match?

        // 1. High confidence: 3 words match -> safe to jump up to 45 words ahead (skipping a paragraph)
        if spoken.count >= 3 {
            let window = Array(spoken.suffix(3))
            match = VoiceSyncMatching.findDetailedMatch(
                scriptWords: scriptWords,
                spokenWindow: window,
                cursorIndex: cursorIndex,
                lookAhead: 45,
                minimumOverlap: 3
            )
        }

        // 2. Medium confidence: 2 words match -> safe to jump up to 12 words ahead (skipping a line)
        if match == nil, spoken.count >= 2 {
            let window = Array(spoken.suffix(2))
            match = VoiceSyncMatching.findDetailedMatch(
                scriptWords: scriptWords,
                spokenWindow: window,
                cursorIndex: cursorIndex,
                lookAhead: 12,
                minimumOverlap: 2
            )
        }

        // 3. Low confidence: 1 word match -> safe to jump up to 4 words ahead (skipping a filler word)
        if match == nil, spoken.count >= 1 {
            let window = Array(spoken.suffix(1))
            match = VoiceSyncMatching.findDetailedMatch(
                scriptWords: scriptWords,
                spokenWindow: window,
                cursorIndex: cursorIndex,
                lookAhead: 4,
                minimumOverlap: 1
            )
        }

        guard let match else { return }

        currentWordIndex = match.currentWordIndex

        // Directly use the matched index. Visual smoothing is handled by UI.
        guard match.currentWordIndex > cursorIndex else { return }

        cursorIndex = match.currentWordIndex
        let offset = VoiceSyncMatching.scrollOffset(
            cursorIndex: cursorIndex,
            totalWords: scriptWords.count
        )

        scrollOffset = offset
    }

    private func restartRecognitionIfNeeded() {
        guard state != .idle, audioEngine != nil else { return }
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        recognitionRequest = request

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                Task { @MainActor [weak self] in
                    self?.handleRecognitionResult(result)
                }
                if result.isFinal {
                    Task { @MainActor [weak self] in
                        self?.restartRecognitionIfNeeded()
                    }
                }
            }
            if let error {
                let nsError = error as NSError
                let ignoredCodes = [216, 301, 1110]
                guard !ignoredCodes.contains(nsError.code) else { return }
                print("VoiceSyncEngine: recognition error \(nsError.code) — \(error.localizedDescription)")
                Task { @MainActor [weak self] in
                    self?.restartRecognitionIfNeeded()
                }
            }
        }
    }

    private func scheduleSilenceDeadline() {
        silenceDeadlineTask?.cancel()
        silenceDeadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.silenceThresholdNanoseconds ?? 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
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
}

struct VoiceSyncMatching {
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
        text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .compactMap { normalizeToken($0) }
    }

    static func normalizeToken(_ token: String) -> String? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.hasPrefix("[") == false else { return nil }

        let normalized = trimmed
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
                if overlap > currentBest.overlap || (overlap == currentBest.overlap && index < currentBest.startIndex) {
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
