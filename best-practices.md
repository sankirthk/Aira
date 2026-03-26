# Aira — Best Practices

This document is a checklist for agents reviewing or writing code in this repository. Every item maps to a real risk or past mistake in the codebase. Check all relevant sections before marking any task done.

---

## 1. DRY (Don't Repeat Yourself)

### 1.1 Shared view logic belongs in `Shared/`
`PrompterContentView`, `CountdownView`, `VisualBeamView`, and `ContentModeIndicator` exist precisely because both the Notch window and Pill windows render the same prompter. Before writing any view logic in `NotchContentView` or `PillContentView`, ask: "does this belong in `PrompterContentView` or a new shared component?"

**Violation to watch for:** copying scroll or session-start logic into `PillContentView` rather than extracting it.

### 1.2 One source of truth per setting
`AppSettings` in `AppSettings.swift` is the only place where user preferences live. Overlay appearance during a session is owned by `NotchContentView`/`PillContentView` as `@State private var currentAppearance`, intentionally forked from `AppSettings` at session start. This is correct; do not replicate additional settings fields there.

**Violation to watch for:** duplicating shortcut strings, font sizes, or color values as hardcoded literals inside view files instead of reading from `AppSettings` or the design token constants.

### 1.3 Keyboard shortcut matching in one place
`KeyboardShortcutDisplay.matches(event:shortcut:)` is the single matching function. Do not write inline keyCode comparisons (e.g., `event.keyCode == 125`) anywhere else in the codebase — call `matches` instead.

### 1.4 Color and font tokens
- Asset-catalog colors: use `Color("colorPrimary")`, `Color("colorBackground")`, etc. — never paste the hex values inline.
- One-off hex values: use the `Color(hex:)` extension — never construct `NSColor(red:green:blue:alpha:)` manually.
- Font names: defined in `CLAUDE.md` (`IndieFlower`, `CrimsonText-Regular`, `Manrope-Bold`). Do not re-derive or guess.

**Violation to watch for:** `Color(hex: "#849688")` inline in a view that should use `Color("colorPrimary")`.

### 1.5 Store operations go through `AppState`
`AppState.swift` wraps `ScriptStore`, `CollectionStore`, and `SettingsStore`. Views must not call store methods directly — they call `AppState` methods. This keeps the observer graph correct and prevents the UI from going stale.

### 1.6 Session lifecycle owned by `OverlayWindowController`
`presentSession`, `endSession`, `addPill`, `removePill` are the only entry points to change overlay state. Do not manipulate `notchController` or `pillControllers` from views or from `AppState`. Route through `OverlayWindowController`.

---

## 2. Test Requirements

Tests live in the `AiraTests` XCTest target. A task is **not done** until its tests are written and passing (see `tests.md`).

### 2.1 What every new module must test

| Module type | Required test coverage |
|---|---|
| Store (ScriptStore, CollectionStore, SettingsStore) | CRUD round-trip; empty-state load; error paths (file missing, corrupt JSON); Codable round-trip |
| Pure logic (VoiceSyncMatching, KeyboardShortcutDisplay, ScriptEditorSessionLogic) | All branches; edge inputs (empty string, zero, negative); boundary values |
| Engine (VoiceSyncEngine) | Start/stop lifecycle; state transitions; output given controlled input |
| OverlayWindowController | Session start sets `sessionActive`; `endSession` stops audio and clears windows |

### 2.2 Edge cases that must always be covered

- **Empty inputs:** `tokenize("")`, `findMatch` with empty `spokenWindow`, `loadIndex` on a fresh install.
- **Boundary values:** `nudgeScroll` clamped at 0 and 1; `minimumOverlap` threshold; `maxPillCount` cap at 2.
- **Codable failure:** corrupt or missing JSON file — stores must throw, not crash.
- **Nil/missing resources:** `SFSpeechRecognizer` unavailable; `AVAudioEngine` fails to start; `NSScreen.screens` empty.
- **Concurrent mutation:** two rapid `presentSession` calls — second must not create a duplicate notch window.
- **Script count extremes:** 0 scripts (empty library); 1 word script; very long script (5000+ words).

### 2.3 Test isolation rules

- **No real file system in unit tests.** Inject a temp directory via `FileManager` and clean up in `tearDown`. Never write to `~/Library/Application Support/Aira/` in tests.
- **No real `SFSpeechRecognizer` in unit tests.** Test `VoiceSyncMatching` (pure functions) and engine state machines in isolation.
- **No `Task.sleep` in tests.** Use `XCTestExpectation` with explicit `fulfill()` callbacks.
- **No `@MainActor` shortcuts.** If a test requires main-thread execution, annotate the test function with `@MainActor`, not `DispatchQueue.main.sync`.

### 2.4 Test naming convention

```
func test_<subject>_<scenario>_<expectedOutcome>()
// Examples:
func test_tokenize_emptyString_returnsEmptyArray()
func test_nudgeScroll_belowZero_clampsToZero()
func test_presentSession_sameScriptTwice_resumesFromLastOffset()
```

---

## 3. Code Standards (Swift / SwiftUI / AppKit)

### 3.1 Concurrency

- All `@Published` properties and `@ObservableObject` instances that drive UI must be isolated to `@MainActor`. `VoiceSyncEngine`, `AudioLevelMonitor`, `OverlayWindowController`, and `AppState` are all `@MainActor`.
- `AVAudioEngine` input tap callbacks arrive on an audio thread. Never touch `@MainActor` state from inside the tap closure directly — dispatch via `Task { @MainActor in ... }`.
- Do not use `DispatchQueue.main.async` in new code. Use `Task { @MainActor in ... }` or `await MainActor.run { ... }`.
- No `Timer` polling loops. Reactive state uses Combine or `async/await`. Scroll timing uses `CADisplayLink` / `SessionPlayheadCoordinator`.

### 3.2 Memory management

- `OverlayWindowController` holds `weak var appState: AppState?` — this is intentional to avoid a retain cycle between the controller and the SwiftUI environment. Never make it `strong`.
- Closures passed to `NotchWindowController.present(onEndSession:)` and `PillWindowController.present(onClose:)` must capture `self` as `[weak self]`.
- `NSEvent` monitors (`addLocalMonitorForEvents`, `addGlobalMonitorForEvents`) return opaque tokens that must be stored and explicitly removed in `onDisappear` / `stop()`. Leaking a monitor causes duplicate event handling across sessions.
- `CGEvent.tapCreate` userInfo must use `passUnretained` (not `passRetained`) — the monitor owns its own lifetime; the tap does not need an extra retain.

### 3.3 SwiftUI patterns

- Use `@State` for transient, view-local state (selection, hover, show/hide flags).
- Use `@ObservedObject` for shared engine references passed in from outside the view.
- Use `@EnvironmentObject` for `AppState` — never pass it as an explicit parameter through many layers.
- Prefer `.onChange(of:)` over `onReceive(publisher)` for observing `@Published` properties.
- Sheets and popovers that need to trigger AppKit window operations (e.g., `orderFrontRegardless`) must use `sheet(isPresented:onDismiss:)` — the `onDismiss` closure fires after the sheet's dismiss animation completes, avoiding modal-interference bugs. Do NOT use `onChange(of: showSheet)` for this purpose.

### 3.4 AppKit / NSPanel

- Overlay panels must always set `sharingType = .none` at creation. Verify stealth before setting `sessionActive = true`.
- Use `panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]` so the overlay survives Mission Control transitions.
- `NSPanel` with `.nonactivatingPanel` does not take key focus. This means `NSEvent.addLocalMonitorForEvents` and `addGlobalMonitorForEvents` may miss events when the manager window is miniaturized. Use `CGEvent.tapCreate` at `.cgSessionEventTap` for any shortcut that must work during a live session.
- Never use `NSScreen.main` for the notch window. Use the built-in screen detection logic in `NotchWindowController.builtInScreen`.

### 3.5 Naming

- `Controller` suffix: AppKit-layer classes that own `NSPanel` lifecycle (`NotchWindowController`, `PillWindowController`, `OverlayWindowController`).
- `View` suffix: SwiftUI view structs.
- `Store` suffix: classes that own persistence (`ScriptStore`, `CollectionStore`, `SettingsStore`).
- `Engine` suffix: stateful processing classes (`VoiceSyncEngine`).
- `Coordinator` suffix: classes that mediate between multiple consumers (`SessionPlayheadCoordinator`, `SessionScrollCoordinator`).
- Pure functions / static utilities: prefer `enum` with `static func` (no instance state) — e.g., `VoiceSyncMatching`, `KeyboardShortcutDisplay`, `ManualScrollConfiguration`.

### 3.6 Error handling

- Store operations that touch the file system must throw typed errors, not return optionals silently.
- View code catches thrown errors and assigns them to an error-message `@State var` that drives an `.alert(...)`. Never `print` an error and continue as if nothing happened.
- Recognition task callback errors must be logged (`print("VoiceSyncEngine: ...")`) and, unless they are cancellation codes (216, 301, 1110), must trigger a recognition restart via `restartRecognitionIfNeeded()`. Silent swallowing with `guard let result else { return }` is not acceptable.

---

## 4. Security

### 4.1 Stealth (screen capture exclusion) — REQ-005, REQ-007

- `NSWindow.sharingType = .none` must be set on **every** overlay `NSPanel` at creation, before it is shown.
- Before setting `appState.sessionActive = true`, call `stealthIsHonored` (private getter on `OverlayWindowController`). If it returns `false`, set `appState.stealthWarning = true` to surface a banner. Never fail silently.
- Do not test stealth by visually checking — check `panel.sharingType == .none` programmatically.

### 4.2 On-device speech recognition — REQ-006

- `request.requiresOnDeviceRecognition = true` must always be set on `SFSpeechAudioBufferRecognitionRequest`. This is non-negotiable.
- Do not add a fallback that silently sends audio to Apple's servers if on-device is unavailable. If on-device recognition is unavailable, surface an error state; do not degrade to server recognition.
- Audio capture (`AVAudioEngine` input tap) must be stopped and released in `VoiceSyncEngine.stop()`. Verify this is called by every `endSession()` path, including closure-based session endings from overlay context menus.

### 4.3 No network calls in v1

- Zero `URLSession`, `URLRequest`, or `URLComponents` in the Aira target at any point in v1. Charles Proxy at idle should show no outbound traffic.
- The `AIIntegration/` module and `KeychainStore.swift` are deferred. Do not create these files.

### 4.4 File access scope

- Scripts are read/written only within `~/Library/Application Support/Aira/`. Never construct file paths from user-provided strings without sanitization.
- Import via `NSOpenPanel` — the OS provides the sandboxed URL. Do not read arbitrary file paths from user input.
- Maximum import file size: 10 MB (`ImportError.fileTooLarge`). Always enforce this before reading file contents into memory.

### 4.5 User permissions (microphone + speech recognition)

- Request `SFSpeechRecognizer.requestAuthorization` and `AVAudioApplication.requestRecordPermission` before starting the engine, not at app launch.
- If either permission is denied, surface a clear message and do not attempt to start the engine. Do not crash or silently fail.
- `AXIsProcessTrustedWithOptions` (Accessibility) is required for `CGEvent.tapCreate`. Prompt for it when `VoiceSyncKeyboardMonitor.start(...)` is called, not at app launch.

---

## 5. Performance

### 5.1 Audio engine lifecycle

- `AVAudioEngine` input tap must only run during an active session. Check: after `endSession()`, confirm `voiceSync.state == .idle` and `audioEngine == nil`.
- Do not call `engine.start()` more than once without `engine.stop()` in between — this causes AVAudioSession conflicts.
- `installTap(onBus:bufferSize:format:)` must be matched by `removeTap(onBus:)` in `VoiceSyncEngine.stop()`. Leaked taps will prevent future sessions from starting.

### 5.2 Scroll animation

- Scroll is driven by `SessionPlayheadCoordinator` (a `CADisplayLink`-backed clock), not by `Timer` or `DispatchQueue.asyncAfter`. Do not introduce any polling loop for scroll position updates.
- `PrompterContentView` uses `.offset(y:)` on a `VStack` inside a `GeometryReader`. The `contentHeight` is measured once on layout and on `onChange(of: contentGeometry.size.height)`. Do not trigger layout passes on every frame.

### 5.3 Script loading

- `AppState.scripts` holds only `[ScriptMeta]` (UUID, title, timestamps, cues). The full script body is loaded on demand when the editor opens or a session is cast.
- Never load all script bodies into memory at once (e.g., for search). If full-text search is needed, implement incremental loading.

### 5.4 View rendering

- Avoid `@ObservedObject` on `VoiceSyncEngine` in views that do not need to redraw on every scroll tick. `PrompterContentView` observes `voiceSync` — this is intentional because it drives the display. Other views should only observe properties they actually use.
- Prefer `let` over `@State` / `@Binding` when a value does not change after view creation.
- Color assets (`Color("colorX")`) are resolved once per render. Do not call `Color(hex:)` inside a tight loop or animation callback.

### 5.5 App bundle size

- Zero third-party Swift packages. All dependencies are Apple frameworks: `SwiftUI`, `AppKit`, `AVFoundation`, `Speech`, `CoreGraphics`, `ApplicationServices`.
- Verify bundle size after Archive build stays under 10 MB. If custom fonts are added, confirm they are included in Copy Bundle Resources and listed in Info.plist.

---

## 6. Pre-Commit Checklist

Before marking any task `[x]` in `todo.md`, verify:

- [ ] `requirements.md` — does the implementation match the REQ(s) cited in the task?
- [ ] `design.md` — does the UI match the design tokens (colors, fonts, spacing)?
- [ ] `tests.md` — are new/changed tests marked `[w]` (written) and `[x]` (passing)?
- [ ] DRY — is there any logic duplication that should be extracted to `Shared/` or a utility enum?
- [ ] Concurrency — are all `@MainActor` boundaries respected? Are audio-thread callbacks dispatched safely?
- [ ] Memory — are closures capturing `[weak self]`? Are NSEvent monitors removed?
- [ ] Security — is stealth verified before setting `sessionActive`? Is `requiresOnDeviceRecognition = true` still set?
- [ ] Performance — is there any new `Timer`, polling loop, or `DispatchQueue.asyncAfter` where reactive state should be used instead?
- [ ] Bundle size — no new third-party packages?
- [ ] Error handling — are all thrown errors surfaced to the user, not silently swallowed?
