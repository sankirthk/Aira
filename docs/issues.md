# Known Issues

## 2026-04-19: Overlay Scroll Regression After Readability Renderer Refactor

- Status: open
- Area: overlay scroll / text layout
- Files:
  - `Aira/OverlayWindows/Shared/PrompterContentView.swift`
  - `Aira/App/OverlayStyledTextView.swift`
  - `Aira/Models/OverlayAppearance.swift`
  - `Aira/OverlayWindows/Shared/PrompterTextMetrics.swift`

### Symptom

Overlay scroll can appear frozen or non-responsive after the readability/alignment renderer refactor, even though the previous committed version still scrolled correctly.

This can affect:

- notch voice-sync sessions
- notch manual WPM sessions
- synced pill followers
- any path that depends on `contentHeight - viewportHeight` becoming valid after text layout

### Observed Cause

The refactor introduced a custom AppKit text renderer (`OverlayStyledTextView`) so overlay text could support:

- text alignment
- custom line spacing
- letter spacing
- word spacing
- text shadow
- configurable content padding

That renderer changed when final text layout metrics become known.

The scroll system still configures movement early, before the final measured text height is guaranteed to be stable. The older implementation had a safety path that re-synchronized scroll state whenever `contentHeight` changed. The current refactor removed that general re-sync path and now relies too heavily on initial setup plus `reportsPrimaryMetrics`.

Result:

- scroll controllers can be configured with zero or stale scrollable range
- playhead/manual driver state can remain bound to stale geometry
- voice/manual projection can become a no-op because the normalized range never updates correctly

### Architectural Problem

The current overlay path computes layout in too many places:

1. `OverlayStyledTextView` lays out attributed text for rendering
2. `OverlayTextStyle.measuredHeight(...)` separately measures total text height
3. `PrompterTextMetrics.calculateLines(...)` separately computes line metrics
4. scroll code consumes those values after they are produced asynchronously

Those calculations are related but not owned by one canonical layout snapshot, so renderer state and scroll state can drift.

### Proposed Fix

Refactor overlay text/layout into one canonical snapshot pipeline:

1. Build one attributed-layout snapshot from `script.body + appearance + width`
2. Derive rendered text, total height, line metrics, and `pointsPerWord` from that single snapshot
3. Feed the same snapshot to renderer and scroll math
4. Reconfigure scroll/playhead state whenever that snapshot changes
5. Remove dead split layout paths after the snapshot is authoritative

This is a clean refactor, not another local patch.

Latest implementation note:

1. Keep one canonical `OverlayTextLayoutSnapshot` for attributed text, line metrics, and pacing math
2. Stop deriving session scroll range from SwiftUI `PreferenceKey` height reads on the AppKit text renderer
3. Compute `contentHeight` directly from snapshot text height plus fixed leading/trailing paddings
4. Shift line-metric `y` anchors by the same leading inset so scroll range and voice/manual anchoring share one geometry basis

### Follow-Up Testing Needed

Manual verification still needed after refactor:

1. Notch-only voice-sync session scrolls again
2. Notch-only manual WPM session scrolls again
3. Sync notch + pill session stays aligned
4. Manual pill session still scrolls independently
5. Appearance changes (alignment, spacing, padding, font) update both layout and scroll range without freezing scroll
6. Long scripts do not regress into per-frame layout churn
7. Final lines remain visible and pace remains stable
8. Hover-pause and pause/resume still work
9. Countdown `0` and non-`0` sessions both start correctly

### Attempt History For Paused/Wheel Regressions

The overlay wheel regression around notch hover-pause, notch explicit pause, and manual-mode pill scrolling has already had several targeted fixes. Keep this list current so future work does not repeat the same theories.

1. `T-033b-a` attempted to decouple manual-pill wheel input from the `Pause on mouse hover` preference by separating pointer-presence tracking from hover-pause suppression.
   Result: not sufficient. The current bug still reproduces.
2. `T-033b-b` attempted to scope hover pause to motion suppression only so hover-paused notch overlays would still accept wheel input.
   Result: not sufficient. Hover-paused notch scrolling still fails in current manual verification.
3. `T-033b-c` attempted to remove hover-pause behavior from pill windows entirely and rely on direct panel wheel forwarding for pills.
   Result: not sufficient. Manual pill scrolling is still broken.
4. `T-033b-d` attempted to narrow wheel deduplication so only cross-source duplicate deliveries are collapsed.
   Result: not sufficient. This did not restore the missing wheel behavior.
5. `T-033b-e` attempted to keep manual-mode pills on the same shared wheel-deduplication path as the working overlay interceptor rather than bypassing it.
   Result: not sufficient. Manual pill scrolling still fails.
6. `T-033b-f` attempted to split shared pause semantics so notch pause state would only suppress automatic motion and would not leak into manual pills.
   Result: not sufficient. None of the three user-visible cases were fixed by this change.
7. Current follow-up attempt: `OverlayScrollForwardingPanel` was changed to forward wheel events from `scrollWheel(with:)` directly and to allow the overlay panel to become key/main instead of relying on `sendEvent(_:)` only.
   Result: not sufficient. Manual verification still reports that none of the three cases are working.
8. Next follow-up attempt: move primary wheel capture ownership to the overlay panel itself, including direct/local/global delivery plus dedupe/routing, so notch and pill windows do not depend on the SwiftUI-hosted interceptor view being the effective responder.
   Result: not sufficient. Manual verification still reports that none of the three cases are working.
9. Current debugging aid: targeted runtime instrumentation was added across the live wheel path.
   Coverage:
   - panel refresh of wheel monitoring
   - panel direct `scrollWheel(with:)`
   - panel local/global monitor routing decisions
   - panel dedupe drop/pass decisions
   - bridge callback into the SwiftUI/AppKit host
   - `manualScroll(deltaY:)` acceptance, rejection, and chosen path
   Result: diagnostic only. The first pass also exposed a separate logging bug where touching live `NSEvent.eventNumber` could trigger AppKit assertions, so runtime logging was updated to avoid `eventNumber` entirely.
10. Final root-cause fix: keep overlay wheel monitoring installed for the lifetime of the panel unless the effective monitoring configuration actually changes.
   Result: sufficient in latest manual repro. The bug was caused by repeatedly tearing down and recreating local/global wheel monitors during routine SwiftUI/AppKit updates, which left the active overlay wheel handler ephemeral and allowed scroll gestures to miss the live capture path. Caching the effective monitoring configuration and skipping redundant reinstall work restored the working wheel path.

Current conclusion:

- Do not re-try pause-policy-only, dedupe-only, or panel-forwarding-only fixes for this regression; those were not the root cause.
- The real failure was lifecycle churn in overlay wheel monitoring, not the pause policy itself.
- The `eventNumber` assertion was a debugging artifact, not the scroll regression.
- If this regresses again, inspect whether `refreshOverlayScrollMonitoring()` is reinstalling monitors during normal view updates before revisiting any of the earlier theories.

### Notes

- Root cause is not merely “alignment feature exists.”
- Root cause is layout timing + ownership drift after the readability renderer refactor.
- Last committed version still had a re-sync path when `contentHeight` changed, which masked this timing problem.

## 2026-04-19: Menu Bar Startup Crash on macOS 14.x

- Status: fixed in code, needs manual verification on macOS 14.x hardware
- Area: menu bar / app launch
- Files:
  - `Aira/App/MenuBarStatusItemController.swift`
  - `Aira/App/AppLifecycleDelegate.swift`

### Symptom

On some older macOS 14.x machines, Aira could crash immediately at launch before drawing any UI. The crash path pointed into AppKit and SkyLight while creating the menu bar status item.

### Observed Cause

The app had a startup timing bug around `NSStatusItem` creation.

`MenuBarStatusItemController` was being constructed very early during app startup, and the status item path touched AppKit/window-server state before launch had fully completed. On macOS 15 this appeared to be masked by different launch timing, but on macOS 14 the same code path could abort during startup.

An intermediate patch also proved that even querying app-global state too early was unsafe:

- touching `NSApp.isRunning` during controller initialization could itself crash because `NSApp` is an implicitly unwrapped AppKit global

### Proposed Fix

Only allow `NSStatusItem` creation after the real `applicationDidFinishLaunching` lifecycle callback has fired.

That means:

- do not create the menu bar item in a stored property initializer
- do not touch `NSApp` or `NSApplication.shared.isRunning` in `MenuBarStatusItemController.init()`
- treat `applicationDidFinishLaunching` as the source of truth for when menu bar creation is allowed

### Implemented Fix

The current code does the following:

1. `AppLifecycleDelegate.applicationDidFinishLaunching(_:)` sets `AppLifecycleDelegate.hasFinishedLaunching = true`
2. `AppLifecycleDelegate` posts `.airaApplicationDidFinishLaunching`
3. `MenuBarStatusItemController` listens for that notification
4. `MenuBarStatusItemController.createStatusItemIfNeeded()` only creates the `NSStatusItem` when `hasCompletedLaunch == true`
5. `install(...)` no longer uses `NSApplication.shared.isRunning` as a heuristic; it only trusts `AppLifecycleDelegate.hasFinishedLaunching`

### What Changed in Code

- `MenuBarStatusItemController.statusItem` is now optional and created lazily
- menu bar button setup moved into `createStatusItemIfNeeded()`
- launch readiness is gated by:
  - `AppLifecycleDelegate.hasFinishedLaunching`
  - `.airaApplicationDidFinishLaunching`

### Follow-Up Testing Needed

Manual verification is still needed on a macOS 14.x machine:

1. Launch the app repeatedly from Xcode and from the built app bundle
2. Confirm the app no longer crashes before showing UI
3. Confirm the menu bar item appears after launch
4. Confirm left click still opens the quick-access popover
5. Confirm right click still shows the native context menu

### Notes

- This issue appears to be OS-version timing-sensitive, not hardware-performance-sensitive.
- The bug was latent; newer macOS versions only made it harder to reproduce.

## 2026-04-23: Voice / Shortcut / Launch Follow-Up Regressions

- Status: open
- Area: voice sync / launch / keyboard shortcuts
- Files:
  - `Aira/VoiceSync/VoiceSyncEngine.swift`
  - `Aira/OverlayWindows/Shared/PrompterContentView.swift`
  - `Aira/OverlayWindows/OverlayWindowController.swift`
  - `Aira/VoiceSync/VoiceSyncKeyboardMonitor.swift`
  - `Aira/App/AppWindowCoordinator.swift`

### Symptom

Three related live-session issues are currently tracked:

1. Zero-countdown `Cast to Notch` can show a beachball on first launch, with trace logs showing the major stall happens when `VoiceSyncEngine.startEngine()` begins immediately after the first overlay render.
2. Voice-driven scrolling can fail entirely while the user is already on an active call/meeting app using the microphone.
3. Session scroll keyboard shortcuts currently move Manual-mode Pill Windows even though those windows are supposed to remain independent of the shared notch/synced playhead.

### Observed Cause

- Launch trace instrumentation shows notch creation and first layout are relatively fast, but zero-countdown voice startup immediately triggers the heaviest launch work:
  - `voiceSync.start requested`
  - `voiceSync.startEngine begin`
  - CoreAudio / HAL overload logging during startup
- Zero-countdown launch can also emit AppKit/SwiftUI recursive-layout warnings:
  - reentrant `NSHostingView` layout
  - `layoutSubtreeIfNeeded` while already laying out
  - `Invalid tile rect null passed to NSFullScreenSpace`
- Keyboard shortcut handling is still scoped too broadly across overlay types; Manual Pill Windows are responding to shared session nudges when they should ignore them.

### Proposed Fix

1. Defer zero-countdown `voiceSync.start()` until after the first overlay render turn instead of starting audio/speech synchronously inside the initial `onAppear` path.
2. Keep the manager visible until the primary notch overlay is actually ordered front, then switch to accessory/session presentation.
3. Audit the audio-session / speech-recognition path under active-call conditions so Voice-Sync keeps receiving mic input while another app is also using the microphone.
4. Tighten keyboard shortcut routing so only the notch and synced overlays sharing the active session playhead respond to scroll shortcuts; Manual Pill Windows must remain isolated.

### Follow-Up Testing Needed

1. Cold launch with countdown `0`: no beachball, notch appears first, then voice startup begins.
2. Zero-countdown launch emits no recursive-layout warnings in the debug log.
3. Voice-Sync continues advancing while the user is on a live call/meeting app.
4. Scroll-up / scroll-down shortcuts do not move Manual-mode Pill Windows.

### Notes

- Actionable tracking lives in `docs/todo.md` and `docs/tests.md` under `T-048d`, `T-048e`, `T-048f`, `IT-003a`, `IT-017a`, and `MT-049e`.
- The current launch trace suggests voice startup is the primary beachball driver, not notch panel creation or first text layout.
