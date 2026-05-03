# WhisperKit Word-Based Scroll Design

## Goal

Replace Aira's Apple speech-recognition backend with bundled, offline WhisperKit speech recognition and add explicit scroll behavior modes while preserving the existing overlay/session contracts.

## Product Decision

Aira will bundle the WhisperKit `tiny.en` model for v1 instead of downloading speech models at runtime. This intentionally relaxes the previous sub-10 MB bundle-size target in favor of a stronger v1 privacy and reliability guarantee:

- Voice Sync works immediately on first launch.
- Core presenter features do not make runtime network calls.
- The user can be told clearly that script text and microphone audio stay on the Mac.
- The app avoids first-use model download UI, partial-download recovery, corporate-network failures, and support ambiguity.

Current upstream model metadata lists `openai_whisper-tiny.en` at roughly 153 MB, so the release gate must be updated from "under 10 MB" to an explicit measured upper bound after the model is embedded.

## Approved Dependency Exception

WhisperKit becomes an approved v1 speech dependency alongside Sparkle:

- Direct-distribution builds may link Sparkle for app updates.
- All builds may link WhisperKit for on-device speech recognition.
- No analytics, telemetry, cloud speech, or unrelated network SDKs are allowed.
- Runtime network traffic remains limited to Sparkle update traffic in direct-distribution builds.

## Architecture

`VoiceSyncEngine` remains the app-facing API. Overlay windows, keyboard controls, menu-bar controls, and tests should not import WhisperKit directly.

Add a `SpeechRecognitionBackend` boundary under `Aira/VoiceSync/`:

```swift
struct SpokenWordToken: Equatable {
  let word: String
  let timestamp: TimeInterval
  let confidence: Float?
}

protocol SpeechRecognitionBackend: AnyObject {
  var onRecognizedWord: (@MainActor (SpokenWordToken) -> Void)? { get set }
  var onProcessingChanged: (@MainActor (Bool) -> Void)? { get set }

  func prepare() async throws
  func acceptAudio(_ samples: [Float]) async
  func stop()
}
```

The first production implementation is `WhisperSpeechRecognitionBackend`. It owns WhisperKit model loading and chunked transcription. Tests use a fake backend so matching, state transitions, and scroll behavior remain deterministic without a Core ML model.

## Audio Flow

`VoiceSyncEngine` continues to own `AVAudioEngine` lifecycle because the overlay system already depends on a single shared microphone tap:

1. `VoiceSyncEngine.start()` creates the engine, installs one input tap, and starts capture.
2. The tap forwards audio to `AudioLevelMonitor` for visual meters and activity detection.
3. The same tap converts/normalizes samples for `SpeechRecognitionBackend.acceptAudio(_:)`.
4. The backend emits stable `SpokenWordToken` values.
5. `VoiceSyncEngine` aligns each spoken token to the script and publishes the existing UI state.
6. `VoiceSyncEngine.stop()` removes the tap, stops and releases the audio engine, stops the backend, and clears session-owned state.

The microphone must still be active only during a presenter session.

## Matching Strategy

Do not delete the current forward-only script matching invariants. WhisperKit improves recognition stability but does not remove ambiguity in repeated words such as "the", "and", or repeated phrases.

The new matching path should:

- Normalize each `SpokenWordToken.word` with the same script-token normalization rules used today.
- Search forward from the current cursor, not backward.
- Use a localized look-ahead window for single-word token alignment.
- Keep the existing broader startup/reseed logic for cases where the engine has no established anchor.
- Publish the dulling range as `0..<currentWordIndex` so skipped words behind the spoken cursor are visually dulled.

## Scroll Modes

Introduce an explicit `VoiceScrollMode` model:

```swift
enum VoiceScrollMode: String, Codable, CaseIterable {
  case classicScroll
  case volumeGated
  case wordTracking
}
```

Mode behavior:

- `classicScroll`: existing manual/display-linked scroll remains authoritative. Voice may still update spoken-word highlighting when highlighting is enabled, but the engine does not push scroll offset.
- `volumeGated`: microphone activity keeps motion active; recognized words correct the anchor and highlighting.
- `wordTracking`: recognized word index drives the shared playhead target progress. This is the flagship mode and should eventually remove the need for users to tune WPM for voice-driven sessions.

`SessionScrollCoordinator` remains the shared progress authority for synchronized overlays. `VoiceSyncEngine` should publish progress targets rather than directly fighting rendered offsets in follower overlays.

## UI Scope

For the first implementation slice, keep the public setting surface minimal:

- Preserve the existing Voice Sync controls.
- Add mode plumbing and tests before adding new preference UI.
- Default new voice sessions to `wordTracking` once WhisperKit backend is functional.
- Keep classic/manual spoken-word highlighting behavior intact.

## Packaging

The Xcode project must add:

- Swift package reference: `https://github.com/argmaxinc/whisperkit`
- Product dependency: `WhisperKit`
- Bundled model resources for `openai_whisper-tiny.en`

The plan must verify which model folder layout WhisperKit expects for a bundled local model and must avoid implicit first-run downloads. If WhisperKit's default initializer attempts remote model resolution, Aira must initialize from an explicit bundled model path.

## Testing

Tests should cover:

- The backend protocol can be mocked without linking/loading a model.
- A single recognized token advances to the next matching script word without moving backward.
- Repeated common words stay localized to the cursor window.
- Word-tracking mode publishes scroll/progress from the matched index.
- Classic-scroll mode updates highlighting without changing scroll offset.
- Volume-gated mode responds to RMS activity separately from recognized-word correction.
- Session teardown stops backend processing and releases `AVAudioEngine`.
- Docs and release gates reflect the new bundle-size exception and no-runtime-network guarantee.

## Non-Goals

- No custom model downloader.
- No On-Demand Resources in the first implementation.
- No cloud speech recognition fallback.
- No removal of click-to-reseed spoken-word highlighting.
- No UI redesign of the preferences modal until backend and scroll-mode behavior are verified.
