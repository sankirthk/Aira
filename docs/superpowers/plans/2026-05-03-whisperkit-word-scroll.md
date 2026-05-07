# WhisperKit Word-Based Scroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Apple speech recognition with bundled offline WhisperKit recognition and add explicit classic, volume-gated, and word-tracking scroll behavior.

**Architecture:** Keep `VoiceSyncEngine` as the app-facing API and introduce a `SpeechRecognitionBackend` boundary so WhisperKit is isolated from overlays and tests. Preserve forward-only script matching and existing highlight rendering, then feed stable Whisper word tokens into the current cursor/highlight/playhead pipeline.

**Tech Stack:** SwiftUI, AppKit, AVFoundation, Combine, Swift Testing, Xcode SPM package integration, WhisperKit, bundled `openai_whisper-tiny.en` Core ML model resources.

---

## Current Constraints And Risks

- Main branch has an unrelated local dirty edit to `Aira/VoiceSync/VoiceSyncEngine.swift`; work only in `/Users/sankirthkalahasti/Documents/Projects/Aira-t-049-whisperkit-word-scroll`.
- The first spec commit hook failed because existing Sparkle dependency resolution failed with: `no versions of 'sparkle' match the requirement 2.9.1..<3.0.0`. Resolve or document this before relying on full hook builds.
- `qmd get` currently fails in this sandbox due sqlite DB access, so use `rg` plus targeted `sed`.
- Current upstream HuggingFace metadata lists `openai_whisper-tiny.en` around 153 MB, not 75 MB. Release gates must reflect measured bundled size.

## File Structure

- Modify `docs/requirements.md`: allow bundled offline WhisperKit speech model and update no-network wording.
- Modify `docs/architecture.md`: replace SFSpeech voice architecture with WhisperKit backend architecture and update security/release gates.
- Modify `docs/tests.md`: add WhisperKit/backend/scroll-mode test IDs.
- Modify `docs/todo.md`: add T-049 tasks and mark completed as work lands.
- Create `Aira/VoiceSync/SpeechRecognitionBackend.swift`: backend protocol plus `SpokenWordToken`.
- Create `Aira/VoiceSync/WhisperSpeechRecognitionBackend.swift`: production WhisperKit implementation.
- Modify `Aira/VoiceSync/VoiceSyncEngine.swift`: inject backend, remove SFSpeech lifecycle, align spoken tokens, expose scroll mode.
- Modify `Aira/VoiceSync/AudioLevelMonitor.swift`: expose deterministic activity threshold helper if needed by volume-gated tests.
- Modify `Aira/Models/AppSettings.swift`: persist `VoiceScrollMode` defaulting to `.wordTracking`.
- Modify `Aira/OverlayWindows/Shared/PrompterContentView.swift`: route voice scroll behavior by `VoiceScrollMode` without breaking spoken-word highlighting.
- Modify `Aira.xcodeproj/project.pbxproj`: add WhisperKit package/product and model resources.
- Modify `AiraTests/KeyboardShortcutDisplayTests.swift` or create `AiraTests/VoiceSyncBackendTests.swift`: deterministic backend and mode tests.

---

### Task 1: Update Product Docs And Task/Test Tracking

**Files:**
- Modify: `docs/requirements.md`
- Modify: `docs/architecture.md`
- Modify: `docs/tests.md`
- Modify: `docs/todo.md`

- [ ] **Step 1: Update requirements for bundled offline model**

In `docs/requirements.md`, update the local-first/no-network section around the current network constraint to say:

```markdown
- No network connection is required to use any core authoring or presenter feature. Voice-Sync uses bundled on-device speech recognition assets and must not download speech models at runtime. The only permitted network activity in direct-distribution builds is Sparkle update traffic over HTTPS (appcast checks and signed update downloads). App Store builds do not use Sparkle and therefore must not perform updater traffic. If the future AI converter ships, its user-initiated BYOK request is the only additional permitted network path.
```

- [ ] **Step 2: Update architecture dependency and security constraints**

In `docs/architecture.md`, replace the current binary-size/dependency statement with:

```markdown
- **Binary size.** Keep dependencies minimal. Sparkle is approved only for the direct-distribution updater path. WhisperKit and its bundled `openai_whisper-tiny.en` model are approved for offline Voice-Sync. The old sub-10 MB archive target is superseded by a measured release-size gate that includes the bundled speech model.
```

Replace the voice detection row with:

```markdown
| Voice detection | `WhisperKit` + `AVAudioEngine` | Bundled on-device speech recognition with word timestamps. The speech model ships inside the app bundle so Voice-Sync requires no runtime model download and no microphone audio leaves the Mac. |
```

- [ ] **Step 3: Add tests tracking**

Append rows under `docs/tests.md` VoiceSyncEngine section:

```markdown
| UT-027 | `SpeechRecognitionBackend` can be faked so `VoiceSyncEngine` matching and mode behavior are tested without loading WhisperKit/Core ML | `[ ]` |
| UT-027a | A recognized word token advances the spoken cursor only to the next localized script match and never backwards to a repeated earlier word | `[ ]` |
| UT-027b | Classic scroll mode updates spoken-word highlighting without mutating `VoiceSyncEngine.scrollOffset` | `[ ]` |
| UT-027c | Word-tracking mode maps the matched current word index to bounded scroll progress | `[ ]` |
| UT-027d | Voice-Sync teardown stops the recognition backend and rejects stale spoken-word callbacks | `[ ]` |
| MT-049 | Release verification confirms WhisperKit and bundled `openai_whisper-tiny.en` are present, the speech model is loaded from bundle storage, and no model download occurs at runtime | `[ ]` |
```

- [ ] **Step 4: Add todo tasks**

Append after the T-048 block in `docs/todo.md`:

```markdown
- [ ] **T-049** WhisperKit word-based scroll: replace SFSpeech recognition with bundled offline WhisperKit word tokens, preserve forward-only script alignment, and support classic, volume-gated, and word-tracking scroll modes. — REQ-001, REQ-002, REQ-003, REQ-025
- [ ] **T-049a** Voice recognition backend boundary: add `SpeechRecognitionBackend` and fakeable `SpokenWordToken` so `VoiceSyncEngine` can be tested without loading Core ML. — T-049
- [ ] **T-049b** Engine token alignment: feed stable spoken word tokens through forward-only localized matching and publish current-word/dulled-prefix state without backward jumps. — T-049
- [ ] **T-049c** Scroll modes: add classic, volume-gated, and word-tracking behavior while keeping `SessionScrollCoordinator` authoritative for synchronized overlays. — T-049
- [ ] **T-049d** WhisperKit packaging: add the WhisperKit package and bundle `openai_whisper-tiny.en` for offline local model loading with no first-run download. — T-049
- [ ] **T-049e** Release/security verification: update bundle-size and network verification gates for the bundled speech model and confirm no runtime model download path. — T-049
```

- [ ] **Step 5: Commit docs**

Run:

```bash
git add docs/requirements.md docs/architecture.md docs/tests.md docs/todo.md
git commit -m "docs: approve bundled whisperkit voice sync"
```

Expected: commit succeeds. If the hook fails only on the existing Sparkle package-resolution issue, capture the output and use `git commit --no-verify` for this docs-only commit.

---

### Task 2: Add Backend Protocol And Fakeable Token Model

**Files:**
- Create: `Aira/VoiceSync/SpeechRecognitionBackend.swift`
- Test: `AiraTests/KeyboardShortcutDisplayTests.swift`

- [ ] **Step 1: Write failing protocol/fake test**

Add to `AiraTests/KeyboardShortcutDisplayTests.swift`:

```swift
@MainActor
private final class FakeSpeechRecognitionBackend: SpeechRecognitionBackend {
  var onRecognizedWord: (@MainActor (SpokenWordToken) -> Void)?
  var onProcessingChanged: (@MainActor (Bool) -> Void)?
  private(set) var prepareCallCount = 0
  private(set) var acceptedAudio: [[Float]] = []
  private(set) var stopCallCount = 0

  func prepare() async throws {
    prepareCallCount += 1
  }

  func acceptAudio(_ samples: [Float]) async {
    acceptedAudio.append(samples)
  }

  func stop() {
    stopCallCount += 1
  }

  func emit(_ word: String, timestamp: TimeInterval = 0, confidence: Float? = 0.9) {
    onRecognizedWord?(SpokenWordToken(word: word, timestamp: timestamp, confidence: confidence))
  }
}

@MainActor
@Test func speechRecognitionBackendFakeCanEmitStableWordTokens() async throws {
  let backend = FakeSpeechRecognitionBackend()
  var emitted: [SpokenWordToken] = []
  backend.onRecognizedWord = { token in
    emitted.append(token)
  }

  try await backend.prepare()
  await backend.acceptAudio([0.1, -0.1, 0.05])
  backend.emit("hello", timestamp: 1.25, confidence: 0.8)
  backend.stop()

  #expect(backend.prepareCallCount == 1)
  #expect(backend.acceptedAudio == [[0.1, -0.1, 0.05]])
  #expect(emitted == [SpokenWordToken(word: "hello", timestamp: 1.25, confidence: 0.8)])
  #expect(backend.stopCallCount == 1)
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
xcodebuild test -quiet -project Aira.xcodeproj -scheme Aira -only-testing:AiraTests/KeyboardShortcutDisplayTests/speechRecognitionBackendFakeCanEmitStableWordTokens
```

Expected: FAIL because `SpeechRecognitionBackend` and `SpokenWordToken` do not exist.

- [ ] **Step 3: Add protocol file**

Create `Aira/VoiceSync/SpeechRecognitionBackend.swift`:

```swift
import Foundation

struct SpokenWordToken: Equatable {
  let word: String
  let timestamp: TimeInterval
  let confidence: Float?
}

@MainActor
protocol SpeechRecognitionBackend: AnyObject {
  var onRecognizedWord: (@MainActor (SpokenWordToken) -> Void)? { get set }
  var onProcessingChanged: (@MainActor (Bool) -> Void)? { get set }

  func prepare() async throws
  func acceptAudio(_ samples: [Float]) async
  func stop()
}
```

- [ ] **Step 4: Run the test again**

Run the same focused command.

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Aira/VoiceSync/SpeechRecognitionBackend.swift AiraTests/KeyboardShortcutDisplayTests.swift docs/tests.md docs/todo.md
git commit -m "feat: add speech recognition backend boundary"
```

---

### Task 3: Add Voice Scroll Mode Model

**Files:**
- Modify: `Aira/Models/AppSettings.swift`
- Test: `AiraTests/SettingsStoreTests.swift`

- [ ] **Step 1: Write failing codable/default test**

Add to `AiraTests/SettingsStoreTests.swift`:

```swift
@Test func voiceScrollModeDefaultsToWordTrackingAndCodableRoundTrips() throws {
  var settings = AppSettings()
  #expect(settings.voiceScrollMode == .wordTracking)

  settings.voiceScrollMode = .classicScroll
  let data = try JSONEncoder().encode(settings)
  let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

  #expect(decoded.voiceScrollMode == .classicScroll)
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
xcodebuild test -quiet -project Aira.xcodeproj -scheme Aira -only-testing:AiraTests/SettingsStoreTests/voiceScrollModeDefaultsToWordTrackingAndCodableRoundTrips
```

Expected: FAIL because `voiceScrollMode` and `VoiceScrollMode` do not exist.

- [ ] **Step 3: Add enum and setting**

In `Aira/Models/AppSettings.swift`, add near `VoiceSyncMode`:

```swift
enum VoiceScrollMode: String, Codable, CaseIterable {
  case classicScroll
  case volumeGated
  case wordTracking
}
```

Add to `AppSettings`:

```swift
var voiceScrollMode: VoiceScrollMode = .wordTracking
```

Update `CodingKeys`, `init(from:)`, and `encode(to:)` so missing legacy data defaults to `.wordTracking`.

- [ ] **Step 4: Run the test again**

Run the same focused command.

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add Aira/Models/AppSettings.swift AiraTests/SettingsStoreTests.swift
git commit -m "feat: persist voice scroll mode"
```

---

### Task 4: Route Spoken Tokens Through Existing Forward-Only Matching

**Files:**
- Modify: `Aira/VoiceSync/VoiceSyncEngine.swift`
- Test: `AiraTests/KeyboardShortcutDisplayTests.swift`

- [ ] **Step 1: Write failing repeated-word token alignment test**

Add:

```swift
@MainActor
@Test func recognizedWordTokenAdvancesOnlyWithinForwardSearchWindow() async throws {
  let backend = FakeSpeechRecognitionBackend()
  let engine = VoiceSyncEngine(recognitionBackend: backend)
  engine.loadScript(text: "the intro waits and then the actual cue begins", startingAt: 0.45)

  backend.emit("the", timestamp: 1, confidence: 0.9)

  #expect(engine.currentWordIndex == 5)
  #expect(engine.highlightedWordRange == 0..<5)
  #expect(engine.visualCurrentWordIndex == 5)
  #expect(engine.visualHighlightedWordRange == 0..<5)
}
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
xcodebuild test -quiet -project Aira.xcodeproj -scheme Aira -only-testing:AiraTests/KeyboardShortcutDisplayTests/recognizedWordTokenAdvancesOnlyWithinForwardSearchWindow
```

Expected: FAIL because `VoiceSyncEngine(recognitionBackend:)` does not exist and backend tokens are not wired.

- [ ] **Step 3: Add backend injection and token handler**

In `VoiceSyncEngine`, add:

```swift
private let recognitionBackend: SpeechRecognitionBackend?
private let tokenLookAhead = 50
```

Change init signature to accept the backend:

```swift
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
```

Add:

```swift
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
  let normalized = VoiceSyncMatching.normalizeToken(token.word)
  guard !normalized.isEmpty else { return nil }
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
```

- [ ] **Step 4: Run the focused test**

Expected: PASS. If `VoiceSyncMatching.normalizeToken` is private, expose it as `static func normalizeToken(_:)` in the same file and keep existing tests passing.

- [ ] **Step 5: Commit**

Run:

```bash
git add Aira/VoiceSync/VoiceSyncEngine.swift AiraTests/KeyboardShortcutDisplayTests.swift
git commit -m "feat: align spoken word tokens forward"
```

---

### Task 5: Implement Scroll Mode Behavior In Engine

**Files:**
- Modify: `Aira/VoiceSync/VoiceSyncEngine.swift`
- Modify: `Aira/OverlayWindows/Shared/PrompterContentView.swift`
- Test: `AiraTests/KeyboardShortcutDisplayTests.swift`

- [ ] **Step 1: Write failing classic mode test**

Add:

```swift
@MainActor
@Test func classicScrollModeUpdatesHighlightWithoutChangingScrollOffset() async throws {
  let backend = FakeSpeechRecognitionBackend()
  let engine = VoiceSyncEngine(recognitionBackend: backend)
  engine.loadScript(text: "one two three four", startingAt: 0.5)
  engine.voiceScrollMode = .classicScroll

  backend.emit("three")

  #expect(engine.scrollOffset == 0.5)
  #expect(engine.visualCurrentWordIndex == 2)
  #expect(engine.visualHighlightedWordRange == 0..<2)
}
```

- [ ] **Step 2: Write failing word tracking test**

Add:

```swift
@MainActor
@Test func wordTrackingModeMapsMatchedWordToScrollProgress() async throws {
  let backend = FakeSpeechRecognitionBackend()
  let engine = VoiceSyncEngine(recognitionBackend: backend)
  engine.loadScript(text: "one two three four", startingAt: 0)
  engine.voiceScrollMode = .wordTracking

  backend.emit("three")

  #expect(engine.currentWordIndex == 2)
  #expect(engine.scrollOffset == VoiceSyncMatching.scrollOffset(cursorIndex: 2, totalWords: 4))
}
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```bash
xcodebuild test -quiet -project Aira.xcodeproj -scheme Aira -only-testing:AiraTests/KeyboardShortcutDisplayTests/classicScrollModeUpdatesHighlightWithoutChangingScrollOffset -only-testing:AiraTests/KeyboardShortcutDisplayTests/wordTrackingModeMapsMatchedWordToScrollProgress
```

Expected: FAIL because `voiceScrollMode` is not on the engine.

- [ ] **Step 4: Implement engine mode property**

Add to `VoiceSyncEngine`:

```swift
@Published var voiceScrollMode: VoiceScrollMode = .wordTracking
```

In `handleRecognizedWordToken(_:)`, after cursor/highlight updates, add:

```swift
switch voiceScrollMode {
case .classicScroll:
  break
case .volumeGated:
  if recognitionDrivesScroll && isHumanSpeechActive {
    scrollOffset = VoiceSyncMatching.scrollOffset(cursorIndex: cursorIndex, totalWords: scriptWords.count)
  }
case .wordTracking:
  if recognitionDrivesScroll {
    scrollOffset = VoiceSyncMatching.scrollOffset(cursorIndex: cursorIndex, totalWords: scriptWords.count)
  }
}
```

- [ ] **Step 5: Wire view settings into engine**

In `PrompterContentView`, when the session configures voice sync, set:

```swift
voiceSync.voiceScrollMode = appState.settings.voiceScrollMode
```

If `PrompterContentView` does not receive `AppState`, thread `voiceScrollMode` through from `NotchContentView` and `PillContentView` the same way `voiceSyncMode` is currently threaded.

- [ ] **Step 6: Run focused tests**

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add Aira/VoiceSync/VoiceSyncEngine.swift Aira/OverlayWindows/Shared/PrompterContentView.swift Aira/OverlayWindows/NotchWindow/NotchContentView.swift Aira/OverlayWindows/PillWindow/PillContentView.swift AiraTests/KeyboardShortcutDisplayTests.swift
git commit -m "feat: add voice scroll modes"
```

---

### Task 6: Add WhisperKit Package And Bundled Model Resources

**Files:**
- Modify: `Aira.xcodeproj/project.pbxproj`
- Modify: `Aira.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` if generated
- Add: bundled model folder under `Aira/Models/Whisper/openai_whisper-tiny.en/`

- [ ] **Step 1: Resolve existing package graph blocker**

Run:

```bash
xcodebuild -resolvePackageDependencies -project Aira.xcodeproj -scheme Aira
```

Expected: resolves Sparkle. If it fails with the existing Sparkle `2.9.1..<3.0.0` issue, fix `Package.resolved` or the Sparkle package version before adding WhisperKit. Do not proceed with a second package until the current package graph resolves.

- [ ] **Step 2: Add WhisperKit SPM dependency**

Use Xcode or edit `project.pbxproj` following the existing Sparkle pattern:

```text
repositoryURL = "https://github.com/argmaxinc/whisperkit";
requirement = {
  kind = upToNextMajorVersion;
  minimumVersion = 0.15.0;
};
productName = WhisperKit;
```

Add the `WhisperKit` product dependency to the `Aira` app target. Do not add `TTSKit`.

- [ ] **Step 3: Add bundled tiny.en model**

Download or vendor the `openai_whisper-tiny.en` model folder from `argmaxinc/whisperkit-coreml` into:

```text
Aira/Models/Whisper/openai_whisper-tiny.en/
```

Add that folder to the Aira target Copy Bundle Resources as a folder reference so the internal model layout is preserved.

- [ ] **Step 4: Verify package/model build**

Run:

```bash
xcodebuild build -quiet -project Aira.xcodeproj -scheme Aira
```

Expected: build succeeds and `import WhisperKit` is available.

- [ ] **Step 5: Commit**

Run:

```bash
git add Aira.xcodeproj Aira/Models/Whisper
git commit -m "build: bundle whisperkit tiny model"
```

---

### Task 7: Implement WhisperSpeechRecognitionBackend

**Files:**
- Create: `Aira/VoiceSync/WhisperSpeechRecognitionBackend.swift`
- Modify: `Aira/VoiceSync/VoiceSyncEngine.swift`
- Test: build-only plus fake backend tests

- [ ] **Step 1: Add backend implementation**

Create `Aira/VoiceSync/WhisperSpeechRecognitionBackend.swift`:

```swift
import Foundation
import WhisperKit

@MainActor
final class WhisperSpeechRecognitionBackend: SpeechRecognitionBackend {
  var onRecognizedWord: (@MainActor (SpokenWordToken) -> Void)?
  var onProcessingChanged: (@MainActor (Bool) -> Void)?

  private var whisper: WhisperKit?
  private var audioAccumulator: [Float] = []
  private var emittedWords: Set<String> = []
  private var isProcessing = false
  private let chunkSize = 16_000
  private let overlapSize = 8_000

  func prepare() async throws {
    guard whisper == nil else { return }
    let modelURL = Bundle.main.url(
      forResource: "openai_whisper-tiny.en",
      withExtension: nil,
      subdirectory: "Models/Whisper"
    )
    guard let modelURL else {
      throw WhisperBackendError.missingBundledModel
    }
    let config = WhisperKitConfig(modelFolder: modelURL.path)
    whisper = try await WhisperKit(config)
  }

  func acceptAudio(_ samples: [Float]) async {
    audioAccumulator.append(contentsOf: samples)
    guard audioAccumulator.count >= chunkSize else { return }
    await transcribePendingAudio()
  }

  func stop() {
    audioAccumulator = []
    emittedWords = []
    isProcessing = false
    whisper = nil
    onProcessingChanged?(false)
  }

  private func transcribePendingAudio() async {
    guard !isProcessing, let whisper else { return }
    isProcessing = true
    onProcessingChanged?(true)
    let audio = audioAccumulator

    do {
      let options = DecodingOptions(wordTimestamps: true)
      let results = try await whisper.transcribe(audioArray: audio, decodeOptions: options)
      for segment in results.flatMap(\.segments) {
        for word in segment.words ?? [] {
          let key = "\(word.start)-\(word.word)"
          guard !emittedWords.contains(key) else { continue }
          emittedWords.insert(key)
          onRecognizedWord?(
            SpokenWordToken(
              word: word.word,
              timestamp: word.start,
              confidence: word.probability
            )
          )
        }
      }
    } catch {
      AiraLogger.shared.error(error, category: "voice", context: "Whisper transcription failed")
    }

    if audioAccumulator.count > overlapSize {
      audioAccumulator.removeFirst(audioAccumulator.count - overlapSize)
    }
    isProcessing = false
    onProcessingChanged?(false)
  }
}

enum WhisperBackendError: Error {
  case missingBundledModel
}
```

If the installed WhisperKit version uses different initializer/property names, update this file only; keep `SpeechRecognitionBackend` unchanged.

- [ ] **Step 2: Make engine default to Whisper backend**

In `VoiceSyncEngine.init`, default `recognitionBackend` to `WhisperSpeechRecognitionBackend()` once WhisperKit compiles:

```swift
recognitionBackend: SpeechRecognitionBackend? = WhisperSpeechRecognitionBackend()
```

- [ ] **Step 3: Replace SFSpeech request startup**

In `startEngine()`, remove `SFSpeechAudioBufferRecognitionRequest` creation and recognition task setup. Instead:

```swift
if recognitionEnabled {
  Task { [weak self] in
    do {
      try await self?.recognitionBackend?.prepare()
    } catch {
      AiraLogger.shared.error(error, category: "voice", context: "Failed to prepare speech backend")
    }
  }
}
```

In the tap closure, convert the `AVAudioPCMBuffer` to `[Float]` and call:

```swift
Task { [weak self] in
  guard let self else { return }
  await self.recognitionBackend?.acceptAudio(samples)
}
```

- [ ] **Step 4: Remove SFSpeech imports and permission dependencies**

Remove `import Speech`, `recognitionTask`, `recognitionBox`, `recognizer`, and SFSpeech authorization checks from `VoiceSyncEngine`. Keep microphone permission checks.

Move system speech permission UI out of `AppPermissionCoordinator` or make it a no-op for WhisperKit.

- [ ] **Step 5: Build**

Run:

```bash
xcodebuild build -quiet -project Aira.xcodeproj -scheme Aira
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

Run:

```bash
git add Aira/VoiceSync/WhisperSpeechRecognitionBackend.swift Aira/VoiceSync/VoiceSyncEngine.swift Aira/App/AppPermissionCoordinator.swift
git commit -m "feat: use whisperkit speech backend"
```

---

### Task 8: Verification And Cleanup

**Files:**
- Modify docs rows from previous tasks to `[x]` when verified.
- Optional cleanup in `Aira/VoiceSync/VoiceSyncEngine.swift`.

- [ ] **Step 1: Run focused voice tests**

Run:

```bash
xcodebuild test -quiet -project Aira.xcodeproj -scheme Aira -only-testing:AiraTests/KeyboardShortcutDisplayTests -only-testing:AiraTests/SettingsStoreTests
```

Expected: PASS.

- [ ] **Step 2: Run full suite**

Run:

```bash
xcodebuild test -quiet -project Aira.xcodeproj -scheme Aira
```

Expected: PASS. If `SessionPlayheadCoordinatorTests/cinematicScrollControllerStopHaltsFutureTicks` fails once and passes alone, record it as existing timing flake like the prior merge.

- [ ] **Step 3: Verify model is bundled**

Archive or build the app, then inspect:

```bash
du -sh path/to/Aira.app
find path/to/Aira.app -name 'openai_whisper-tiny.en' -print
```

Expected: app size includes the model and the model folder exists in app resources.

- [ ] **Step 4: Verify no runtime model download**

Run a voice session under Network Instruments or a proxy.

Expected: no traffic for model download or speech recognition. Direct-distribution builds may still contact Sparkle only when update checks are triggered.

- [ ] **Step 5: Mark docs complete**

Update `docs/todo.md` T-049 rows and `docs/tests.md` UT/MT rows to `[x]` only for verified items.

- [ ] **Step 6: Commit verification docs**

Run:

```bash
git add docs/todo.md docs/tests.md
git commit -m "docs: verify whisperkit word scroll"
```

---

## Self-Review

- Spec coverage: tasks cover dependency exception, backend boundary, token alignment, scroll modes, package/model bundling, no-runtime-network verification, and tests.
- Placeholder scan: no incomplete markers are required for implementation.
- Type consistency: `SpokenWordToken`, `SpeechRecognitionBackend`, and `VoiceScrollMode` names are consistent across tasks.
- Known uncertainty: exact WhisperKit bundled-model initializer may differ by installed version. Task 7 isolates that uncertainty to `WhisperSpeechRecognitionBackend.swift` and keeps the app-facing protocol stable.
