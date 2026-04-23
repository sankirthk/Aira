# First Session Launch Latency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the cold app launch -> first `Cast to Notch` beachball by making the first visible overlay appear before expensive session systems start.

**Architecture:** Keep all required work, but move it out of the user-visible blank gap. First instrument the current path, then split manager-window hiding into prepare/finish phases, show the notch shell before hiding the manager, defer voice/audio startup until after the first overlay paint, and prewarm layout only if measurement proves text layout is a major contributor.

**Tech Stack:** SwiftUI, AppKit `NSPanel` / `NSWindow`, `AVAudioEngine`, `SFSpeechRecognizer`, `ContinuousClock`, XCTest.

---

## File Structure

- Modify `docs/todo.md`: split `T-048c` into small implementation subtasks and mark them as they land.
- Modify `docs/tests.md`: add automated and manual test IDs for launch sequencing and cold-launch verification.
- Create `Aira/OverlayWindows/SessionLaunchTrace.swift`: lightweight launch-span recorder using `ContinuousClock` and `AiraLogger`.
- Create `AiraTests/SessionLaunchTraceTests.swift`: verifies timing marks are monotonic and formatted without touching AppKit.
- Modify `Aira/OverlayWindows/OverlayWindowController.swift`: pass a trace through session launch and expose the moment the primary overlay is ordered front.
- Modify `Aira/OverlayWindows/NotchWindow/NotchWindowController.swift`: mark panel construction, hosting view creation, positioning, and ordered-front timing.
- Modify `Aira/App/AppWindowCoordinator.swift`: split session window transition into prepare and finish operations so the manager is not hidden before the overlay exists.
- Modify `Aira/ManagerWindow/ManagerWindowView.swift`: sequence `prepare -> present overlay -> finish` instead of hiding the manager before `presentSession`.
- Modify `Aira/OverlayWindows/Shared/PrompterContentView.swift`: defer `VoiceSyncEngine.start()` until after the first main-actor yield/frame when countdown is zero.
- Create `AiraTests/SessionLaunchPolicyTests.swift`: pure tests for sequencing and voice-start deferral policy.
- Optionally modify `Aira/Models/OverlayAppearance.swift`: add a named layout prewarm API over the existing `layoutSnapshot` cache if tracing shows first layout is expensive.

---

## Task 1: Document Atomic Subtasks

**Files:**
- Modify: `docs/todo.md`
- Modify: `docs/tests.md`

- [ ] **Step 1: Add todo subtasks under `T-048c`**

Add these rows directly after `T-048c` in `docs/todo.md`:

```markdown
- [x] **T-048c.1** First-session launch instrumentation: add low-overhead timing marks around manager transition, overlay controller launch, notch panel creation, first prompter layout, and voice engine startup. — T-048c
- [ ] **T-048c.2** Session presentation sequencing: keep the manager visible until the primary notch overlay has been ordered front, then hide the manager and switch to session presentation mode. — T-048c
- [ ] **T-048c.3** Voice startup deferral: when countdown is zero, let the overlay render first and start `AVAudioEngine` / `SFSpeechRecognizer` on the next main-actor turn instead of inside the first `onAppear` pass. — T-048c
- [ ] **T-048c.4** Layout cold-path mitigation: use launch trace data to decide whether to prewarm or reuse the existing `OverlayTextStyle.layoutSnapshot` cache before session launch. — T-048c
- [ ] **T-048c.5** Cold-launch verification: verify first `Cast to Notch` no longer shows a beachball with Voice-Sync on and off, then update manual test status. — T-048c
```

- [ ] **Step 2: Add automated test IDs**

Add these rows near the existing integration launch tests in `docs/tests.md`:

```markdown
| UT-001a-d | Session launch tracing records monotonic marks for manager preparation, overlay ordering, and deferred voice startup without depending on AppKit windows | `[x]` |
| UT-001a-e | Zero-countdown sessions schedule Voice-Sync startup after the first overlay render turn instead of starting audio/speech synchronously during first `onAppear` | `[ ]` |
| IT-001a-b | Presenter launch keeps the manager visible until the primary notch overlay has been ordered front, then transitions to session presentation mode | `[ ]` |
```

- [ ] **Step 3: Run documentation diff**

Run:

```bash
git diff -- docs/todo.md docs/tests.md
```

Expected: only `T-048c.*` and `UT/IT` tracking rows changed.

- [ ] **Step 4: Commit documentation setup**

Run:

```bash
git add docs/todo.md docs/tests.md
git commit -m "docs: break down first session launch latency work"
```

---

## Task 2: Add Launch Timing Trace

**Files:**
- Create: `Aira/OverlayWindows/SessionLaunchTrace.swift`
- Create: `AiraTests/SessionLaunchTraceTests.swift`
- Modify: `Aira/OverlayWindows/OverlayWindowController.swift`
- Modify: `Aira/OverlayWindows/NotchWindow/NotchWindowController.swift`
- Modify: `Aira/OverlayWindows/Shared/PrompterContentView.swift`
- Modify: `Aira/VoiceSync/VoiceSyncEngine.swift`
- Modify: `docs/todo.md`
- Modify: `docs/tests.md`

- [x] **Step 1: Write failing trace tests**

Create `AiraTests/SessionLaunchTraceTests.swift`:

```swift
import Testing
@testable import Aira

struct SessionLaunchTraceTests {
  @Test func recordsMarksInOrder() {
    let trace = SessionLaunchTrace(label: "test")

    trace.mark("start")
    trace.mark("ordered-front")

    let names = trace.snapshot().map(\.name)
    #expect(names == ["start", "ordered-front"])
  }

  @Test func elapsedMillisecondsNeverGoBackward() {
    let trace = SessionLaunchTrace(label: "test")

    trace.mark("start")
    trace.mark("middle")
    trace.mark("end")

    let marks = trace.snapshot()
    #expect(marks[0].elapsedMilliseconds <= marks[1].elapsedMilliseconds)
    #expect(marks[1].elapsedMilliseconds <= marks[2].elapsedMilliseconds)
  }
}
```

- [x] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS' -only-testing:AiraTests/SessionLaunchTraceTests
```

Expected: FAIL because `SessionLaunchTrace` does not exist.

- [x] **Step 3: Add trace implementation**

Create `Aira/OverlayWindows/SessionLaunchTrace.swift`:

```swift
import Foundation

struct SessionLaunchTraceMark: Equatable {
  let name: String
  let elapsedMilliseconds: Double
}

@MainActor
final class SessionLaunchTrace {
  private let label: String
  private let clock = ContinuousClock()
  private let start: ContinuousClock.Instant
  private var marks: [SessionLaunchTraceMark] = []

  init(label: String) {
    self.label = label
    self.start = clock.now
  }

  func mark(_ name: String) {
    let elapsed = start.duration(to: clock.now)
    let milliseconds = Double(elapsed.components.seconds * 1_000)
      + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000
    let mark = SessionLaunchTraceMark(name: name, elapsedMilliseconds: milliseconds)
    marks.append(mark)
    AiraLogger.shared.info(
      "launchTrace[\(label)] \(name) \(String(format: "%.2f", milliseconds))ms",
      category: "session"
    )
  }

  func snapshot() -> [SessionLaunchTraceMark] {
    marks
  }
}
```

- [x] **Step 4: Thread trace through launch path**

In `OverlayWindowController.presentSession(...)`, create a trace at the top and pass it into `NotchWindowController.present`:

```swift
let launchTrace = SessionLaunchTrace(label: "presentSession")
launchTrace.mark("presentSession.begin")
endSession()
launchTrace.mark("presentSession.afterEndSession")
prepareSharedSession(script: script)
launchTrace.mark("presentSession.afterPrepareSharedSession")
```

Extend `NotchWindowController.present(...)` with:

```swift
launchTrace: SessionLaunchTrace? = nil,
```

Mark these points:

```swift
launchTrace?.mark("notch.present.begin")
let screen = builtInScreen
launchTrace?.mark("notch.screenResolved")
...
let panel = OverlayScrollForwardingPanel(...)
launchTrace?.mark("notch.panelCreated")
...
let hostingView = NSHostingView(rootView: makeContentView(for: script, notchSize: notchSize))
launchTrace?.mark("notch.hostingViewCreated")
...
panel.orderFrontRegardless()
launchTrace?.mark("notch.orderedFront")
```

In `PrompterContentView.onAppear`, add:

```swift
launchTrace?.mark("prompter.onAppear")
...
refreshRenderedLayout(width: viewportWidth)
launchTrace?.mark("prompter.afterFirstLayout")
```

This requires adding `let launchTrace: SessionLaunchTrace?` to `PrompterContentView`, `NotchContentView`, and `PillContentView` initializers only where the trace is needed. For pills, pass `nil` unless tracing Satellite launch is explicitly needed.

- [x] **Step 5: Mark voice startup**

In `VoiceSyncEngine.start()`:

```swift
AiraLogger.shared.info("voiceSync.start requested", category: "voice")
```

In `startEngine()`:

```swift
AiraLogger.shared.info("voiceSync.startEngine begin", category: "voice")
...
try engine.start()
AiraLogger.shared.info("voiceSync.engineStarted", category: "voice")
```

- [x] **Step 6: Run focused tests**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS' -only-testing:AiraTests/SessionLaunchTraceTests
```

Expected: PASS.

- [x] **Step 7: Update docs and commit**

Mark `UT-001a-d` as `[x]` and `T-048c.1` as `[x]` after the test passes.

Run:

```bash
git add Aira/OverlayWindows/SessionLaunchTrace.swift AiraTests/SessionLaunchTraceTests.swift Aira/OverlayWindows/OverlayWindowController.swift Aira/OverlayWindows/NotchWindow/NotchWindowController.swift Aira/OverlayWindows/Shared/PrompterContentView.swift Aira/VoiceSync/VoiceSyncEngine.swift docs/todo.md docs/tests.md
git commit -m "chore: instrument first session launch latency"
```

---

## Task 3: Split Manager Transition From Overlay Presentation

**Files:**
- Create: `AiraTests/SessionLaunchPolicyTests.swift`
- Modify: `Aira/App/AppWindowCoordinator.swift`
- Modify: `Aira/ManagerWindow/ManagerWindowView.swift`
- Modify: `Aira/OverlayWindows/OverlayWindowController.swift`
- Modify: `docs/todo.md`
- Modify: `docs/tests.md`

- [ ] **Step 1: Write a pure sequencing test**

Create `AiraTests/SessionLaunchPolicyTests.swift`:

```swift
import Testing
@testable import Aira

struct SessionLaunchPolicyTests {
  @Test func managerHidesAfterPrimaryOverlayIsOrderedFront() {
    let events = PresenterSessionLaunchPolicy.eventsForPrimaryNotchLaunch()

    #expect(events == [
      .prepareManagerForOverlay,
      .presentPrimaryOverlay,
      .finishManagerHide,
    ])
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS' -only-testing:AiraTests/SessionLaunchPolicyTests
```

Expected: FAIL because `PresenterSessionLaunchPolicy` does not exist.

- [ ] **Step 3: Add launch policy type**

Create `Aira/OverlayWindows/PresenterSessionLaunchPolicy.swift`:

```swift
enum PresenterSessionLaunchEvent: Equatable {
  case prepareManagerForOverlay
  case presentPrimaryOverlay
  case finishManagerHide
}

enum PresenterSessionLaunchPolicy {
  static func eventsForPrimaryNotchLaunch() -> [PresenterSessionLaunchEvent] {
    [
      .prepareManagerForOverlay,
      .presentPrimaryOverlay,
      .finishManagerHide,
    ]
  }
}
```

- [ ] **Step 4: Split AppWindowCoordinator transition methods**

In `Aira/App/AppWindowCoordinator.swift`, keep existing behavior but split it:

```swift
@MainActor
static func prepareManagerWindowForSessionOverlay(in application: NSApplication? = nil) {
  let application = application ?? .shared
  closeAllTransientMenuBarWindows(in: application)
  application.setActivationPolicy(.accessory)
}

@MainActor
static func finishManagerWindowHideForSession(in application: NSApplication? = nil) {
  let application = application ?? .shared
  managerWindow(in: application)?.orderOut(nil)
  DispatchQueue.main.async {
    if let finder = NSWorkspace.shared.runningApplications
      .first(where: { $0.bundleIdentifier == "com.apple.finder" })
    {
      if #available(macOS 14.0, *) {
        finder.activate()
      } else {
        finder.activate(options: .activateIgnoringOtherApps)
      }
    }
  }
}
```

Leave `hideManagerWindowForSession` as a compatibility wrapper:

```swift
@MainActor
static func hideManagerWindowForSession(in application: NSApplication? = nil) {
  prepareManagerWindowForSessionOverlay(in: application)
  finishManagerWindowHideForSession(in: application)
}
```

- [ ] **Step 5: Sequence manager transition in ManagerWindowView**

Replace `miniaturizeManagerWindow()` before `overlayController.presentSession(...)` with:

```swift
AppWindowCoordinator.prepareManagerWindowForSessionOverlay()
overlayController.presentSession(
  script: script,
  appearance: appState.settings.defaultOverlayAppearance,
  countdownDuration: appState.settings.countdownDuration,
  voiceSyncEnabled: appState.settings.voiceSyncEnabled,
  autoScrollWPM: ManualScrollConfiguration.clampedWPM(appState.settings.autoScrollWPM),
  voiceSyncMode: appState.settings.voiceSyncMode,
  pillModes: enabledPillModes
)
AppWindowCoordinator.finishManagerWindowHideForSession()
```

Keep `miniaturizeManagerWindow()` only if other call sites still need the old one-shot behavior.

- [ ] **Step 6: Re-order primary overlay after finish if needed**

If manual testing shows `.accessory` transition can still hide or de-key the panel, add this method to `OverlayWindowController`:

```swift
func bringPrimaryOverlayToFront() {
  notchController?.orderFrontRegardless()
}
```

Add this method to `NotchWindowController`:

```swift
func orderFrontRegardless() {
  panel?.orderFrontRegardless()
}
```

Then call after finish:

```swift
AppWindowCoordinator.finishManagerWindowHideForSession()
overlayController.bringPrimaryOverlayToFront()
```

- [ ] **Step 7: Run focused tests**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS' -only-testing:AiraTests/SessionLaunchPolicyTests
```

Expected: PASS.

- [ ] **Step 8: Update docs and commit**

Mark `IT-001a-b` as `[w]` because this is partly manual/AppKit-visible, and mark `T-048c.2` as `[x]` once focused tests pass and manual launch does not hide the overlay.

Run:

```bash
git add Aira/App/AppWindowCoordinator.swift Aira/ManagerWindow/ManagerWindowView.swift Aira/OverlayWindows/OverlayWindowController.swift Aira/OverlayWindows/NotchWindow/NotchWindowController.swift Aira/OverlayWindows/PresenterSessionLaunchPolicy.swift AiraTests/SessionLaunchPolicyTests.swift docs/todo.md docs/tests.md
git commit -m "fix: show overlay before hiding manager window"
```

---

## Task 4: Defer Zero-Countdown Voice Startup

**Files:**
- Modify: `AiraTests/SessionLaunchPolicyTests.swift`
- Modify: `Aira/OverlayWindows/PresenterSessionLaunchPolicy.swift`
- Modify: `Aira/OverlayWindows/Shared/PrompterContentView.swift`
- Modify: `docs/todo.md`
- Modify: `docs/tests.md`

- [ ] **Step 1: Add deferral policy tests**

Append to `AiraTests/SessionLaunchPolicyTests.swift`:

```swift
@Test func zeroCountdownDefersVoiceStartupUntilAfterFirstRenderTurn() {
  #expect(PresenterSessionLaunchPolicy.shouldDeferVoiceStartup(countdownDuration: 0))
}

@Test func positiveCountdownDoesNotNeedExtraVoiceStartupDeferral() {
  #expect(!PresenterSessionLaunchPolicy.shouldDeferVoiceStartup(countdownDuration: 3))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS' -only-testing:AiraTests/SessionLaunchPolicyTests
```

Expected: FAIL because `shouldDeferVoiceStartup(countdownDuration:)` does not exist.

- [ ] **Step 3: Add policy implementation**

In `Aira/OverlayWindows/PresenterSessionLaunchPolicy.swift`:

```swift
static func shouldDeferVoiceStartup(countdownDuration: Int) -> Bool {
  countdownDuration == 0
}
```

- [ ] **Step 4: Add cancellable deferred voice startup**

In `PrompterContentView`, add state:

```swift
@State private var deferredVoiceStartupTask: Task<Void, Never>?
```

Add helper:

```swift
private func startVoiceSubsystemAfterFirstRenderTurnIfNeeded() {
  deferredVoiceStartupTask?.cancel()
  deferredVoiceStartupTask = Task { @MainActor in
    await Task.yield()
    guard !Task.isCancelled else { return }
    startVoiceSubsystemIfNeeded()
  }
}
```

Replace zero-countdown startup:

```swift
if PresenterSessionLaunchPolicy.shouldDeferVoiceStartup(countdownDuration: countdownDuration) {
  startVoiceSubsystemAfterFirstRenderTurnIfNeeded()
} else {
  startVoiceSubsystemIfNeeded()
}
startAutoScrollIfNeeded()
```

In `onDisappear`, cancel it:

```swift
deferredVoiceStartupTask?.cancel()
deferredVoiceStartupTask = nil
```

Do not defer the countdown completion path unless testing shows countdown completion also blocks before the overlay has already rendered.

- [ ] **Step 5: Run focused tests**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS' -only-testing:AiraTests/SessionLaunchPolicyTests
```

Expected: PASS.

- [ ] **Step 6: Update docs and commit**

Mark `UT-001a-e` as `[x]` and `T-048c.3` as `[x]`.

Run:

```bash
git add Aira/OverlayWindows/PresenterSessionLaunchPolicy.swift Aira/OverlayWindows/Shared/PrompterContentView.swift AiraTests/SessionLaunchPolicyTests.swift docs/todo.md docs/tests.md
git commit -m "fix: defer voice startup until overlay renders"
```

---

## Task 5: Decide Layout Mitigation From Trace Data

**Files:**
- Modify: `Aira/Models/OverlayAppearance.swift`
- Modify: `Aira/ManagerWindow/ManagerWindowView.swift`
- Modify: `AiraTests/SessionLaunchPolicyTests.swift`
- Modify: `docs/todo.md`

- [ ] **Step 1: Manually capture trace output before changing layout**

Run the app from the worktree, cold launch it, cast a medium/large script to Notch, and capture launch trace lines.

Expected trace interpretation:

```text
prompter.afterFirstLayout - prompter.onAppear < 100ms: skip layout prewarm
prompter.afterFirstLayout - prompter.onAppear >= 100ms: implement layout prewarm
```

- [ ] **Step 2: If layout is below threshold, document the decision**

If first layout is below `100ms`, mark `T-048c.4` as `[x]` with this note:

```markdown
Layout prewarm skipped after launch traces showed first prompter layout below the mitigation threshold; sequencing and voice deferral remain the active fixes.
```

Then commit:

```bash
git add docs/todo.md
git commit -m "docs: record layout prewarm decision"
```

- [ ] **Step 3: If layout is above threshold, write prewarm test**

Append to `AiraTests/SessionLaunchPolicyTests.swift`:

```swift
@Test func layoutPrewarmUsesSameSnapshotCacheKeyAsSessionLayout() {
  let appearance = OverlayAppearance.default
  let script = "Opening line\nSecond line"
  let width: CGFloat = 320

  let prewarmed = OverlayTextStyle.prewarmLayoutSnapshot(
    for: script,
    width: width,
    appearance: appearance
  )
  let session = OverlayTextStyle.layoutSnapshot(
    for: script,
    width: width,
    appearance: appearance
  )

  #expect(prewarmed == session)
}
```

- [ ] **Step 4: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS' -only-testing:AiraTests/SessionLaunchPolicyTests
```

Expected: FAIL because `prewarmLayoutSnapshot` does not exist.

- [ ] **Step 5: Add explicit prewarm API**

In `Aira/Models/OverlayAppearance.swift`:

```swift
@discardableResult
static func prewarmLayoutSnapshot(
  for string: String,
  width: CGFloat,
  appearance: OverlayAppearance
) -> OverlayTextLayoutSnapshot {
  layoutSnapshot(for: string, width: width, appearance: appearance)
}
```

- [ ] **Step 6: Call prewarm before session presentation**

In `ManagerWindowView.startOverlaySession(with:)`, before `prepareManagerWindowForSessionOverlay()`:

```swift
let normalized = PrompterDisplayText.normalizedDisplayBody(from: script.body)
let notchWidth = NotchWindowController.resolvedPanelWidth(appState.settings.notchWindowWidth)
let measuredWidth = max(notchWidth - (appState.settings.defaultOverlayAppearance.contentPadding * 2), 1)
OverlayTextStyle.prewarmLayoutSnapshot(
  for: normalized,
  width: measuredWidth,
  appearance: appState.settings.defaultOverlayAppearance
)
```

This still runs on the main actor, but it happens while the manager remains visible, not after it disappears. Do not move TextKit layout to a detached background task in this task.

- [ ] **Step 7: Run focused tests**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS' -only-testing:AiraTests/SessionLaunchPolicyTests
```

Expected: PASS.

- [ ] **Step 8: Update docs and commit**

Mark `T-048c.4` as `[x]`.

Run:

```bash
git add Aira/Models/OverlayAppearance.swift Aira/ManagerWindow/ManagerWindowView.swift AiraTests/SessionLaunchPolicyTests.swift docs/todo.md
git commit -m "perf: prewarm first session text layout"
```

---

## Task 6: Cold-Launch Manual Verification

**Files:**
- Modify: `docs/tests.md`
- Modify: `docs/todo.md`

- [ ] **Step 1: Build the app**

Run:

```bash
xcodebuild build -scheme Aira -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Verify cold launch with Voice-Sync on**

Quit Aira completely. Launch the built app. Immediately open a non-empty script and press `Cast to Notch`.

Expected:

```text
No macOS beachball appears.
The manager remains visible until the Notch overlay appears.
The Notch overlay appears before Voice-Sync/audio startup can visually block launch.
Voice-Sync starts normally after the overlay is visible.
```

- [ ] **Step 3: Verify cold launch with Voice-Sync off**

Disable Voice-Sync in Preferences. Quit and relaunch Aira. Immediately cast the same script.

Expected:

```text
No macOS beachball appears.
The overlay appears with no speech/audio startup logs.
Manual scroll behavior remains unchanged.
```

- [ ] **Step 4: Verify countdown behavior**

Set countdown to `3`. Quit and relaunch Aira. Cast the same script.

Expected:

```text
The overlay appears immediately.
Countdown displays normally.
Voice-Sync starts only after countdown completes.
```

- [ ] **Step 5: Run focused automated tests**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS' -only-testing:AiraTests/SessionLaunchTraceTests -only-testing:AiraTests/SessionLaunchPolicyTests
```

Expected: PASS.

- [ ] **Step 6: Run full test suite**

Run:

```bash
xcodebuild test -scheme Aira -destination 'platform=macOS'
```

Expected: PASS. If only `SessionPlayheadCoordinatorTests/cinematicScrollControllerStopHaltsFutureTicks` fails while passing in isolation, record it as an existing timing flake and do not mark `T-048c` complete until launch-specific tests and manual checks pass.

- [ ] **Step 7: Update docs and commit**

Mark `MT-049d` as `[x]`, mark `T-048c.5` as `[x]`, then mark parent `T-048c` as `[x]`.

Run:

```bash
git add docs/todo.md docs/tests.md
git commit -m "docs: verify first session launch latency fix"
```

---

## Recommended First Implementation Task

Start with **Task 2: Add Launch Timing Trace**. It is the smallest safe implementation step because it does not change behavior, gives proof for the real bottleneck, and makes every later performance claim testable.

Do not start with layout prewarming. The layout cache already exists, and prewarming may just move the stall earlier unless trace data proves it is needed.

---

## Self-Review

- Spec coverage: `T-048c` is covered by instrumentation, sequencing, voice deferral, optional layout mitigation, and cold-launch verification.
- Placeholder scan: no `TBD`, `TODO`, or unbounded "handle later" steps remain.
- Type consistency: `SessionLaunchTrace`, `PresenterSessionLaunchPolicy`, `PresenterSessionLaunchEvent`, and `prewarmLayoutSnapshot` names are consistent across tests and implementation steps.
- Scope check: this plan stays focused on first-session launch latency and does not refactor unrelated overlay/session behavior.
