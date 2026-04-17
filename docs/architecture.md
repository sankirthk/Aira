# Aira — Architecture Document

## Purpose

This document defines the technical architecture for Aira: the Swift/macOS module structure, framework choices, key data flows, storage design, and non-functional constraints.

This document does not define UI layout, visual design, or interaction patterns. Those belong in `design.md`.

The developer is new to Swift. Technical decisions are explained clearly, including why a choice was made and what it means in practice.

---

## 0. Performance and Efficiency Mandate

These constraints apply to every decision in this document. They are non-negotiable.

- **Binary size.** Keep dependencies minimal. Sparkle is the only approved third-party package in the current direct-distribution build; all other functionality must use Apple's native frameworks. Target app bundle under 10 MB after Archive build.
- **Memory.** Overlay windows hold only the active script segment in memory during a session, not the full document.
- **Battery.** The microphone tap (`AVAudioEngine`) runs **only during an active presenter session**. It is fully stopped and released when the session ends or the overlays are closed. Zero audio capture at idle.
- **CPU.** No polling loops. Use Combine publishers or `async/await` for all reactive state. Scroll animation is driven by a single frame-synced session playhead clock (`CADisplayLink` / AppKit display link host) rather than `Timer` loops or per-view sleep loops.
- **Startup.** Cold launch must not block the main thread. Scripts are loaded lazily from disk — the library view loads metadata only; full script body is read on demand when the editor opens.
- **No telemetry, no unrelated background network activity.** Zero ambient analytics or service traffic is permitted. The only allowed outbound network path in direct-distribution builds is Sparkle update traffic over HTTPS (appcast checks and signed update downloads). Charles Proxy / Network Instruments should show no other outbound traffic during a full idle session.

---

## 1. Technology Stack

| Layer | Choice | Why |
|---|---|---|
| UI framework | SwiftUI | Declarative and modern. Good fit for the Manager App's panels, settings sheets, and document library. New Swift developers find it more approachable than UIKit/AppKit. |
| Overlay windows | AppKit (`NSPanel`) | SwiftUI alone cannot control the window-level flags required for stealth (`sharingType = .none`) or precise always-on-top behavior. The overlay windows are AppKit at the controller layer, with SwiftUI views hosted inside them via `NSHostingView`. |
| Voice detection | `SFSpeechRecognizer` + `AVAudioEngine` | On-device speech recognition. `requiresOnDeviceRecognition = true` keeps all audio processing on the device — no audio is sent to Apple's servers. Recognizes actual speech content (words), not just volume. |
| Voice Activity Detection (VAD) | Hybrid of `AudioLevelMonitor` activity and `SFSpeechRecognizer` result cadence | Live voice motion stays active while either recent audio activity or recent recognition results indicate speech. Recognition pauses still halt anchored speech progress, and matcher output continues to correct playhead position. |
| Stealth (screen capture exclusion) | `NSWindow.sharingType = .none` | A single macOS API flag that excludes a window from all screen capture streams, including Zoom and Teams. Must be set at window creation time. |
| Global keyboard shortcut | `CGEvent` tap via `CGEventTap` | Captures keyboard events globally, regardless of which window has focus. Used for the Voice-Sync toggle shortcut. |
| Updater | Sparkle | Direct-distribution updater for signed ZIP-based in-place updates. Supports appcast verification, EdDSA update signing, and sandbox-compatible installer launch services. |
| Script import | `NSOpenPanel` + `FileManager` | Standard macOS file picker for `.txt` import. Drag-and-drop handled via `NSPasteboard` UTType. No third-party dependency. |
| Local storage — scripts | `FileManager` + `JSON` (`Codable`) | Plain JSON files in `~/Library/Application Support/Aira/Scripts/`. No database, no ORM. Scripts are plain text with metadata — no relational structure is needed. Zero added binary weight. |
| Local storage — collections | `FileManager` + `JSON` (`Codable`) | Single `collections.json` file in `~/Library/Application Support/Aira/`. Contains collection definitions and script membership lists. |
| Local storage — settings | `UserDefaults` | Standard macOS preference storage. Handles all scalar settings (font size, opacity, shortcuts, countdown duration) with zero overhead. |
| Distribution | Xcode Archive + `notarytool` | Standard Apple notarization pipeline. Required for Gatekeeper to pass without warnings. |
| AI converter | **Deferred — future release** | Not in v1 scope. No `URLSession`, no `Keychain`, no API key UI, no networking code ships in v1. The requirements (REQ-017–REQ-020) remain normative for a future release. |

**A note on `NSHostingView`.** This is how you embed SwiftUI views inside AppKit windows. When you create an `NSPanel` for the overlay, you wrap your SwiftUI view in `NSHostingView(rootView: MySwiftUIView())` and set it as the panel's `contentView`. This is the bridge between the two worlds.

---

## 2. Module Structure

```
Aira/
├── App/
│   ├── AiraApp.swift            — @main entry point, AppDelegate, menu bar setup
│   ├── AppState.swift           — global ObservableObject (active script, session state, settings, open pills)
│   ├── AppUpdaterConfiguration.swift — resolves Sparkle feed/public-key bundle configuration and fail-closed state
│   ├── AppUpdaterController.swift — owns Sparkle updater startup and Check for Updates availability
│   ├── AiraSparkleUserDriver.swift — custom Sparkle user driver that replaces stock update prompts
│   ├── AppUpdatePromptContent.swift — copy model for Aira-branded updater prompts
│   └── AppUpdatePromptWindowController.swift — branded floating update prompt window controller
│
├── ManagerWindow/
│   ├── ManagerWindowView.swift  — main NSWindow host; sidebar + content area layout
│   ├── Sidebar/
│   │   └── SidebarView.swift    — navigation items, Collections section, New Script, Go Live buttons
│   ├── DocumentLibrary/
│   │   ├── DocumentLibraryView.swift  — script grid, sort/filter bar, import drop zone, empty state
│   │   └── ScriptCardView.swift       — card with Edit, Cast, Duplicate, Delete, right-click menu
│   ├── ScriptEditor/
│   │   ├── ScriptEditorView.swift     — title input, text area, toolbar
│   │   └── CuePanelView.swift         — right-side cue annotation buttons
│   └── Settings/
│       └── SettingsView.swift         — 3-tab sheet: Appearance, Overlays, System
│
├── OverlayWindows/
│   ├── OverlayWindowController.swift  — creates and manages NSPanel instances; shared entry point
│   ├── NotchWindow/
│   │   ├── NotchWindowController.swift — positions NSPanel beneath notch; reads safeAreaInsets
│   │   └── NotchContentView.swift      — SwiftUI view hosted in the notch NSPanel
│   ├── PillWindow/
│   │   ├── PillWindowController.swift  — creates free-moving NSPanel; handles drag; owns content mode
│   │   ├── PillContentView.swift       — SwiftUI view hosted in each pill NSPanel
│   │   └── PillSetupView.swift         — setup sheet: content mode picker + script selector
│   └── Shared/
│       ├── PrompterContentView.swift      — shared script text + cue rendering + scroll logic
│       ├── VisualBeamView.swift           — animated bar chart driven by audio level
│       ├── CountdownView.swift            — countdown overlay with fade transitions
│       ├── ContentModeIndicator.swift     — badge shown on hover in pill windows
│       └── OverlayAppearancePopover.swift — per-window appearance override popover
│
├── VoiceSync/
│   ├── VoiceSyncEngine.swift    — AVAudioEngine tap + SFSpeechRecognizer + word-matching; publishes scroll events; started/stopped per session
│   └── AudioLevelMonitor.swift  — reads RMS from the same AVAudioEngine; feeds VisualBeam
│
├── Storage/
│   ├── ScriptStore.swift        — FileManager CRUD for scripts; lazy loading; index.json management; import
│   ├── CollectionStore.swift    — FileManager CRUD for collections; membership management
│   └── SettingsStore.swift      — UserDefaults wrapper for all AppSettings properties
│
└── Models/
    ├── Script.swift             — Codable struct: id, title, body, cues, timestamps, collectionIds
    ├── ScriptMeta.swift         — lightweight index entry: id, title, lastEdited, wordCount, starred
    ├── Collection.swift         — Codable struct: id, name, scriptIds
    ├── AppSettings.swift        — all user preference properties with defaults (including pillsEnabled, maxPillCount)
    ├── OverlayAppearance.swift  — Codable struct: textColor, backgroundColor, opacity, fontName, fontSize
    └── MoodPreset.swift         — named OverlayAppearance bundle

# Future modules (not in v1):
# AIIntegration/               — URLSession calls to third-party AI providers
# KeychainStore.swift          — secure API key storage
```

**Why this structure?** Each folder matches a feature area. When you (or a future contributor) need to find where the notch window is created, you look in `OverlayWindows/NotchWindow/`. When you need to understand how scripts are saved, you look in `Storage/ScriptStore.swift`. The structure tells you where everything lives without needing to search.

---

## 3. Key Technical Approaches

### 3.1 Stealth Mode — REQ-005, REQ-006, REQ-007

```swift
// In NotchWindowController and PillWindowController, at window creation time:
panel.sharingType = .none
```

This single flag excludes the window from all screen capture streams, including Zoom, Teams, and macOS `ScreenCaptureKit`-based recorders. The window remains fully visible to the local user.

**Important:** This flag must be set before the session starts, at window creation time. It cannot be changed mid-session.

**Failure detection (REQ-007):** Before calling `VoiceSyncEngine.start()`, verify that the flag was accepted. If the running macOS version or system configuration does not honor `sharingType = .none` (detectable by checking the panel's actual `sharingType` property after setting it), display a yellow warning banner in the Manager App above the "Go Live" button. The warning informs the user that stealth cannot be guaranteed. The session is not blocked — the user decides how to proceed.

---

### 3.2 Notch Window Positioning — REQ-008

The camera notch is part of the built-in display's menu bar safe area. To position the NSPanel directly beneath it:

```swift
// In NotchWindowController:

/// Returns the built-in display — the screen that physically has the camera notch.
/// NEVER use NSScreen.main here: that returns whichever screen contains the key window,
/// which changes as the user moves focus and may be an external monitor.
private var notchScreen: NSScreen {
    // Primary: the screen whose safeAreaInsets.top > 0 is the notch screen.
    if let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
        return screen
    }
    // Fallback for non-notch Macs: find the built-in display via CGDisplayIsBuiltin.
    let builtIn = NSScreen.screens.first { screen in
        guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? CGDirectDisplayID else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }
    return builtIn ?? NSScreen.screens[0]
}

let screen = notchScreen
let notchHeight = screen.safeAreaInsets.top  // height of the notch region in points

// NotchWrapShape has the notch region at 30/110 of the total panel height.
// Scale minimum height so that proportion matches the actual notch on this Mac model.
let minHeightForNotch = notchHeight * (110.0 / 30.0)
let panelHeight = max(minHeightForNotch, appearance.fontSize * 4.2 + 46)
let panelWidth = min(max(460, appearance.fontSize * 22), 520)

// Panel top MUST be at screen.frame.maxY (the very top of the screen).
// NotchWrapShape clips the physical notch cutout within the panel bounds.
// Positioning the top below screen.frame.maxY creates a visible gap between
// the overlay and the actual notch.
let x = screen.frame.midX - panelWidth / 2
let y = screen.frame.maxY - panelHeight
panel.setFrame(CGRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
```

**Why not `NSScreen.main`?** `NSScreen.main` returns the screen containing the current key window — it changes as the user moves focus between a laptop and an external monitor. The notch is a physical feature of the built-in display only, so the window must always be anchored there regardless of which screen is "main".

**Why `safeAreaInsets.top`?** On MacBook Pro models with a notch, this value is the height of the notch region (approximately 32–38pt depending on the model). On non-notch displays, it is 0. The `CGDisplayIsBuiltin` fallback handles non-notch Macs: if `safeAreaInsets.top` is 0 on all screens, the built-in display is still correctly identified so the window sits at the top of the screen below the menu bar.

---

### 3.3 Session Playhead Engine — REQ-001, REQ-002, REQ-003, REQ-034, REQ-039

The long-term scroll architecture is a single shared session playhead.

**Source of truth:**

- `progress: Double` — normalized script progress `0.0 ... 1.0`
- `velocity: Double` — normalized progress units per second
- `isPaused: Bool`

The playhead is updated once per display-linked frame:

```swift
progress = clamp(progress + velocity * deltaTime, 0 ... 1)
```

This means the timing model is centralized and view-independent.

**Why this architecture?**

- One authority for motion prevents competing offset writers.
- Sync mode becomes a projection problem, not a shared-offset hack.
- Manual wheel input, keyboard nudges, WPM auto-scroll, and voice-driven pacing all feed the same coordinator.
- Different window sizes can show the same content progress while moving at different pixel speeds.

**Projection rule:**

Each overlay computes its own local offset from the shared playhead:

```swift
localOffset = project(progress, localLineMetrics, viewportHeight, contentHeight)
```

The projection can use line anchors, word anchors, or a future denser lookup table, but the playhead remains the sole timing authority.

**Primary manual velocity rule:**

In Sync mode, only the primary overlay calculates shared manual playhead velocity. That velocity is derived from the primary overlay's measured rendered line density rather than the total document duration:

```swift
pointsPerWord = totalSpeakableLineHeight / totalSpeakableWords
absolutePixelSpeed = (configuredWPM / 60) * pointsPerWord
normalizedVelocity = absolutePixelSpeed / (totalContentHeight - viewportHeight)
```

This avoids coupling the apparent on-screen speed to total script length. Longer scripts run for longer, but should not visually crawl at the same configured WPM.

**Current implementation status:**

- The current codebase has partially adopted this model.
- Manual scroll is already display-linked.
- Sync mode already uses shared logical progress.
- Manual `Sync` rendering no longer uses the legacy synchronized line-index channel; that older channel remains only for the not-yet-refactored voice-driven path.
- Voice-driven motion still has legacy hybrid paths and is not fully refactored onto the shared playhead.

### 3.4 Voice-Sync Pipeline — REQ-001, REQ-002

This is Aira's core technical feature. The app supports a single Voice mode built on a cinematic shared-playhead model with hybrid voice-activity gating and anchor correction.

**Shared Pipeline:**

```
AVAudioEngine (microphone input)
    ↓
SFSpeechRecognizer (on-device, requiresOnDeviceRecognition = true)
    ↓ partial + final transcription results (real-time stream)
VoiceSyncEngine.matchTranscription(_ words: [String])
    ↓ matched word index / anchor information
    ↓
    └── Voice Mode: update playhead motion state and anchor correction
```

**The Tiered Word-Matching Algorithm (The Engine):**

To handle speech recognition latency and Apple's tendency to revise previous partial results, Aira uses a resilient sliding-window matcher with **Tiered Look-Ahead Bounds** to prevent jitter (false jumps).

1. At session start, tokenize the script into a word array: lowercase, strip punctuation, skip cue annotations.
2. Maintain a `cursorIndex: Int` (current position in the script word array).
3. On each `SFSpeechRecognitionResult`, extract the recent spoken words (e.g., the last 1–3 words) and run a string-overlap match against the script near the `cursorIndex`.
4. **Tiered Bounds:** To prevent jumping 40 words ahead just because the user said a common word like "the", the maximum allowed jump distance scales with match confidence:
    - **High confidence (3 consecutive words matched):** Allowed to jump up to 45 words ahead (speaker skipped a paragraph).
    - **Medium confidence (2 consecutive words):** Allowed to jump up to 12 words ahead (speaker skipped a line).
    - **Low confidence (1 word):** Allowed to jump up to 4 words ahead (speaker skipped a filler word).
5. **Cursor only moves forward.** This prevents the scroll from jumping backward if the user repeats a phrase.
6. The exact matched word position is published so the shared playhead can anchor against speech without requiring inline visual emphasis.

**Voice Mode:**
In this mode, voice motion uses a hybrid activity signal. Recent audio activity can keep motion alive moment-to-moment, while `SFSpeechRecognizer` results provide the matched script anchor and also contribute to the active-speaking state.

The engine publishes two signals into the shared playhead path:

1. **Voice activity state** — whether recent audio or recent recognition activity indicates that speech is still underway.
2. **Anchor correction** — the current matched line / word position, used to keep the playhead close to the spoken location without hard visual jumps.

**Silence handling (REQ-002):**
If no recent speech recognition results arrive for >500ms, scrolling pauses and the current playhead position is preserved.

---

### 3.5 Audio Level for VisualBeam — REQ-004

`AudioLevelMonitor` shares the same `AVAudioEngine` instance as `VoiceSyncEngine` (they are not separate engines — one engine, two uses). It installs an audio tap on the input node to read the RMS level:

```swift
// In AudioLevelMonitor, using the shared AVAudioEngine:
inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
    let rms = self.calculateRMS(buffer: buffer)
    DispatchQueue.main.async {
        self.audioLevel = rms  // @Published, observed by VisualBeamView
    }
}
```

`VisualBeamView` observes `audioLevel` and maps it to bar heights using a simple non-linear scale (square root to make quiet speech still look alive).

For the Notch Window, the audio indicator is not embedded at the bottom of the script area. The shared `audioLevel` instead drives a small corner-wave ornament rendered beside the notch cutout so the readable text region stays clear. Pill windows continue to use the embedded `VisualBeamView`.

**Why one engine?** Two `AVAudioEngine` instances would conflict on the microphone input node and double the resource usage. The engine is started once in `VoiceSyncEngine.start()` and stopped once in `VoiceSyncEngine.stop()`. `AudioLevelMonitor` is a coordinator within `VoiceSyncEngine`, not an independent object.

**VisualBeam in Manual mode pills:** Manual mode pills still display the VisualBeam. They share the same published `audioLevel` — they do not have their own audio tap. This gives the presenter awareness of their microphone level even when the pill is not voice-synced.

---

### 3.6 Hover-to-Pause — REQ-010, REQ-011

`NSTrackingArea` is installed on the content view of each overlay window. Tracking areas are the AppKit mechanism for receiving mouse enter/exit events.

```swift
// In PrompterContentView (AppKit layer):
let trackingArea = NSTrackingArea(
    rect: bounds,
    options: [.mouseEnteredAndExited, .activeAlways],
    owner: self,
    userInfo: nil
)
addTrackingArea(trackingArea)

override func mouseEntered(with event: NSEvent) {
    scrollController.pause()   // preserves current offset
    NSCursor.pointingHand.set()
}

override func mouseExited(with event: NSEvent) {
    scrollController.resume()  // resumes from preserved offset
    NSCursor.arrow.set()
}
```

The `currentOffset` (scroll position at pause time) is stored as a state variable in `PrompterContentView`. It is not reset until the session ends.

---

### 3.6 Local Script Storage — REQ-015

Scripts are stored as individual JSON files in `~/Library/Application Support/Aira/Scripts/`. Each file is named by its UUID (e.g., `550e8400-e29b-41d4-a716-446655440000.json`).

An index file at `~/Library/Application Support/Aira/Scripts/index.json` holds lightweight metadata for all scripts:

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Q3 All-Hands",
    "lastEdited": "2026-03-21T14:30:00Z",
    "wordCount": 842,
    "starred": false
  }
]
```

**Lazy loading:** On app launch, `ScriptStore` reads only `index.json` — not the individual script files. The Document Library renders from index metadata only. The full script body (`body: String`) is read from disk only when the user opens the editor or casts the script to the overlay. This keeps startup fast even with hundreds of scripts.

**CRUD operations:**
- **Create:** generate a UUID, write the JSON file, append to `index.json`
- **Read:** read the individual JSON file by UUID (on demand)
- **Update:** overwrite the JSON file, update the `lastEdited` timestamp in `index.json`
- **Delete:** delete the JSON file, remove the entry from `index.json`
- **Duplicate (REQ-036):** read the source file body, generate a new UUID, write a new JSON file with title prefixed "Copy of", append to `index.json`. Source file is not modified.

**File permissions:** `FileManager` creates files with default POSIX permissions (`0644` owner read/write, no group/world write). No sensitive content is written to `/tmp` or shared directories.

---

### 3.7 Manual Scroll Override — REQ-003

The user can drag within the overlay window to adjust the scroll position at any time. `PrompterContentView` listens for scroll wheel events and pan gesture recognizers:

```swift
// AppKit layer on the overlay content view:
override func scrollWheel(with event: NSEvent) {
    let deltaY = event.scrollingDeltaY
    scrollController.adjustOffset(by: deltaY)
    // VoiceSyncEngine cursor position is updated to match new scroll position
    // Voice-sync can re-engage from the new position when speech resumes
}
```

Manual scroll does not disable Voice-Sync permanently. After a manual adjustment, `VoiceSyncEngine` updates its `cursorIndex` to the word corresponding to the new scroll position. Voice-sync re-engages from there when speech resumes.

---

### 3.8 Countdown Timer — REQ-012, REQ-013

`CountdownView` manages its own timer internally. When the overlay is presented:

1. If countdown duration > 0: `CountdownView` starts, covering the script text
2. It counts from the configured duration down to 1, displaying each numeral with a fade transition
3. On reaching 0: `CountdownView` fades out, emits a `sessionDidStart` signal
4. `PrompterContentView` receives `sessionDidStart` and calls `VoiceSyncEngine.start()`

```swift
// CountdownView logic (simplified):
func startCountdown(from duration: Int) async {
    for i in stride(from: duration, through: 1, by: -1) {
        withAnimation(.easeInOut(duration: 0.3)) { currentNumber = i }
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    withAnimation { isVisible = false }
    onComplete()  // triggers VoiceSyncEngine.start()
}
```

If countdown duration is 0 (user set to zero in Settings), `CountdownView` is not shown and `VoiceSyncEngine.start()` is called immediately.

`CountdownView` uses the window's `OverlayAppearance` for its background and numeral colors so it respects per-window appearance settings.

---

### 3.9 Session Lifecycle

The full lifecycle of a presenter session:

```
User clicks "Go Live" in Manager App
    → session picker: Notch / Pill / Both
    → if Pill or Both: PillSetupView sheet (content mode + script)
    → OverlayWindowController.presentSession(script:, pillConfigs:)
    → NotchWindowController.present(script:, appearance:)   [creates NSPanel, sets sharingType = .none]
    → for each pill config: PillWindowController.present(config:) [creates NSPanel, sets sharingType = .none]
    → Stealth check: verify sharingType accepted → show warning banner if not
    → CountdownView starts (if duration > 0)
    → CountdownView completes → VoiceSyncEngine.start()
        → AVAudioEngine starts (microphone tap begins)
        → SFSpeechRecognizer starts recognition task
    → Sync pills subscribe to the shared session scroll state
    → Manual pills load their assigned scripts independently; no subscription
    → VoiceSyncKeyboardMonitor.start() — begins listening for ⌘⇧Space
    → PrompterContentView scrolls as VoiceSyncEngine publishes scroll events

User ends session (Escape key or ⌘W or closes overlay)
    → VoiceSyncEngine.stop()
        → SFSpeechRecognizer recognition task cancelled
        → AVAudioEngine stopped and released
        → Microphone access relinquished
    → VoiceSyncKeyboardMonitor.stop()
    → NSPanel windows closed and released
    → AppState.sessionActive = false
```

**Battery guarantee:** `AVAudioEngine` is created inside `VoiceSyncEngine.start()` and released in `stop()`. At idle, no audio engine exists. Activity Monitor should show zero microphone usage when no session is active.

---

### 3.10 Direct Distribution Updater — REQ-030

Aira uses Sparkle for direct-distribution updates outside the Mac App Store.

**Bundle configuration:**

- `SUFeedURL` points to the hosted `appcast.xml`
- `SUPublicEDKey` embeds the Sparkle public signing key shipped with the app
- `SUEnableInstallerLauncherService = true` enables Sparkle's sandbox-compatible installer launcher

The current build settings embed:

- `SPARKLE_FEED_URL = https://raw.githubusercontent.com/sankirthk/aira-releases/main/appcast.xml`
- `SPARKLE_PUBLIC_ED_KEY = <public EdDSA key>`

**App-side flow:**

1. `AppUpdaterController` reads `SUFeedURL` and `SUPublicEDKey` from the bundle via `AppUpdaterConfiguration`
2. If either value is missing or invalid, the updater fails closed and `Check for Updates…` remains disabled
3. If configured, `SPUUpdater` starts using `AiraSparkleUserDriver`
4. `AiraSparkleUserDriver` replaces Sparkle's stock `update found` and `ready to install` alerts with Aira-branded popup windows
5. Download progress, extraction progress, and updater errors continue through Sparkle's standard user-driver surfaces for now

**Release artifacts:**

The release workflow produces:

- a notarized DMG for humans
- a signed ZIP for Sparkle
- `appcast.xml` hosted at the stable feed URL

The appcast and ZIP may live in a separate public distribution repository from the private source repository.

**Release triggering:**

- Releases are cut from immutable version tags such as `v1.0.0-beta.1`
- The GitHub Actions release workflow validates the tagged commit, builds/signs/notarizes the app, generates Sparkle artifacts, and publishes them to `sankirthk/aira-releases`

---

### 3.11 Per-Window Overlay Appearance — REQ-038

Each overlay window has an `OverlayAppearance` that can be overridden independently from the global defaults.

**`OverlayAppearance` model:**

```swift
struct OverlayAppearance: Codable, Equatable {
    var textColor: String        // hex string, e.g. "#F5F2EC"
    var backgroundColor: String  // hex string, e.g. "#849688"
    var opacity: Double          // 0.2 to 1.0 — applies to background only; text is always fully opaque
    var fontName: String         // "CrimsonText-Regular", "Manrope-Bold", "Inter-Regular"
    var fontSize: CGFloat        // 14 to 32
}
```

**Default appearance** is stored in `AppSettings.defaultOverlayAppearance` (a single `OverlayAppearance` value). The Settings > Overlays tab edits this value. `UserDefaults` stores it via `SettingsStore`. Both Notch and Pill windows are initialised from this single value — there are no separate per-pill appearance defaults.

**Pill settings** are two additional fields on `AppSettings`:
- `pillsEnabled: Bool = false` — gates whether pills can be launched. The "Go Live" pill flow checks this before presenting `PillSetupView`.
- `maxPillCount: Int = 1` — 1 or 2. `OverlayWindowController.presentSession` caps the number of pill configs it accepts at this value.

**Per-window overrides:** Each `NSPanel` controller (`NotchWindowController`, `PillWindowController`) holds a `var currentAppearance: OverlayAppearance`. At creation, it is initialized from `AppSettings.defaultOverlayAppearance`. When the user changes it via `OverlayAppearancePopover`, only `currentAppearance` on that specific controller is updated — other windows are unaffected.

**Persistence:** Per-window overrides are in-session only and are not persisted when the session ends. Each new session starts from `AppSettings.defaultOverlayAppearance`. This keeps the data model simple; if persistent per-window settings become a requirement, it can be added by storing a `[String: OverlayAppearance]` keyed by window type in `UserDefaults`.

**Live preview in popover:** `OverlayAppearancePopover` observes the controller's `currentAppearance` and renders a miniature preview strip as a `RoundedRectangle` with the chosen colors and a sample word in the chosen font and size. Updates happen synchronously as sliders move — no debounce needed since there is no disk write on each change.

**Mood Presets (REQ-024):** `MoodPreset` is a named `OverlayAppearance` bundle. Applying a preset sets `currentAppearance` on the target window to the preset's values. Presets are also available in Settings > Overlays to update the global defaults.

---

### 3.12 Pill Content Mode — REQ-034

Each `PillWindowController` holds a `contentMode: PillContentMode` enum:

```swift
enum PillContentMode {
    case voiceSync                  // "Sync" in the UI: follows Notch Window script + shared session scroll
    case manual(scriptId: UUID)     // independently assigned script, user scrolls
}
```

**Sync pills:** subscribe to the shared session scroll state owned by `SessionScrollCoordinator`. They load the same script body that was passed to the Notch Window. Their `PrompterContentView` receives the same normalized scroll offset as the Notch Window. Only the primary synced overlay owns scroll advancement; additional synced pills are followers. Multiple Sync pills can be open; they all track the same cursor, scroll position, and paused/running state.

**Manual pills:** do not subscribe to `VoiceSyncEngine`. At creation, `PillWindowController` calls `ScriptStore.load(id: scriptId)` to read the assigned script body. The pill's `PrompterContentView` manages its own scroll offset independently. A manual pill does not require `AVAudioEngine` to be running — if no Voice-Sync pills or Notch Window exist, the audio engine may not be active, but the manual pill still functions.

**Switching modes during a session:** The right-click context menu on a Pill Window exposes "Switch to Voice-Sync Mode" / "Switch to Manual Mode". Switching to Manual opens a script picker popover. Switching to Voice-Sync immediately subscribes to the engine's scroll events and jumps to the current `cursorIndex` position.

**`PillSetupView`:** A SwiftUI sheet presented before the pill is created. It writes the chosen `contentMode` to the `PillWindowController` before `present()` is called. The setup sheet is presented modally over the Manager App window.

---

### 3.13 Script Import — REQ-035

**Drag-and-drop:** The Document Library's `NSView` layer implements `NSDraggingDestination`. On drag enter, it highlights the import drop zone. On drag perform, it reads the dragged URL from `NSPasteboard` and calls `ScriptStore.importFromURL(_:)`.

**File picker:** An `NSOpenPanel` filtered to `UTType.plainText` (which covers `.txt`). The result URL is passed to the same `ScriptStore.importFromURL(_:)` method.

**Import implementation:**

```swift
// In ScriptStore:
func importFromURL(_ url: URL) throws -> Script {
    let content = try String(contentsOf: url, encoding: .utf8)
    let title = url.deletingPathExtension().lastPathComponent
    let script = Script(
        id: UUID(),
        title: title,
        body: content,
        cues: [],
        createdAt: Date(),
        lastEdited: Date()
    )
    try save(script)   // writes {uuid}.json and updates index.json
    return script
}
```

After import, `AppState.scripts` is refreshed and the app navigates to the editor with the imported script open. The original file at `url` is never modified.

**Security note:** Only `.txt` files are accepted. The content is read as a plain string — no HTML parsing, no code execution. Binary files or oversized files (> 10 MB) are rejected with a user-facing error.

---

### 3.14 Collections — REQ-037

Collections are stored in a single JSON file at `~/Library/Application Support/Aira/collections.json`:

```json
[
  {
    "id": "a1b2c3d4-...",
    "name": "Product Demos",
    "scriptIds": [
      "550e8400-...",
      "661f9511-..."
    ]
  }
]
```

**`CollectionStore`** handles all reads and writes:
- `loadAll() -> [Collection]` — reads and parses `collections.json`
- `create(name:) -> Collection` — appends a new collection and saves
- `rename(id:to:)` — updates the name and saves
- `delete(id:)` — removes the collection entry; does not touch script files
- `addScript(scriptId:toCollection:)` — appends scriptId to collection's scriptIds
- `removeScript(scriptId:fromCollection:)` — removes scriptId from collection's scriptIds

**Script model update:** `Script.swift` gains a `collectionIds: [UUID]` field. This is the source of truth for a script's collection membership (the `collections.json` scriptIds array is the same data from the collection's perspective; both are kept in sync by `CollectionStore`). On script delete, `CollectionStore.removeScript` is called for all collections.

**Filtering in DocumentLibraryView:** When a collection is selected in the sidebar, `DocumentLibraryView` filters `AppState.scripts` by `script.collectionIds.contains(selectedCollectionId)`. This is an in-memory filter — no re-read from disk.

---

### 3.15 Keyboard Voice-Sync Toggle — REQ-039

The Voice-Sync pause/resume shortcut must fire regardless of which window has keyboard focus. Standard `NSEvent` local monitors only fire when the app is in the foreground and a specific window is key. A global `CGEvent` tap is required.

```swift
// In VoiceSyncKeyboardMonitor:
class VoiceSyncKeyboardMonitor {
    private var eventTap: CFMachPort?

    func start(shortcut: KeyboardShortcut, handler: @escaping () -> Void) {
        // CGEventTap intercepts events at the system level
        // Only runs while a session is active — started in session lifecycle, stopped on session end
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in
                // check if event matches the configured shortcut
                // if match: call handler(), suppress event (return nil)
                // if not match: pass through (return Unmanaged.passRetained(event))
            },
            userInfo: nil
        )
        // Enable the tap via RunLoop source
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }
}
```

**Why CGEvent tap?** `NSEvent.addGlobalMonitorForEvents` can observe events but cannot suppress them. `CGEvent.tapCreate` at `cgSessionEventTap` can both observe and optionally suppress. For the voice-sync toggle we do not need to suppress, so either would work — but `CGEventTap` is used for consistency and future-proofing.

**Lifecycle:** `VoiceSyncKeyboardMonitor.start()` is called during session start. `stop()` is called when the session ends. The monitor does not exist at idle — no background event tap when there is no active session.

**Shortcut configuration:** The shortcut (default ⌘⇧Space) is stored as a `KeyboardShortcut` value in `AppSettings` and displayed in Settings > System alongside other shortcuts. The user can change it via a `ShortcutRow` control. The change takes effect on the next session start.

**Toggle behavior:** Each invocation of the handler calls `VoiceSyncEngine.togglePause()`. The engine's published state changes from `.running` to `.paused` (or vice versa), and all subscribed `PrompterContentView` instances react immediately.

### 3.16 Manual Scroll Controls — REQ-003

Manual scroll needs one consistent source of truth for session-level scroll behavior. The same session can be driven by three inputs:

- manual auto-scroll when Voice-Sync is off
- keyboard scroll shortcuts during a session
- mouse wheel / trackpad scrolling directly on the overlay

To keep these aligned, the session owns a single display-synced scroll driver. That driver is the only code allowed to advance the rendered offset. It consumes measured viewport metrics plus higher-level inputs like “move one line,” “scroll by wheel delta,” or “advance at N WPM,” and emits the next normalized scroll offset on each display refresh.

**Settings model:** `AppSettings.autoScrollWPM` remains persisted in `UserDefaults`, but is clamped to a bounded presenter-safe range of `100...300`. The System tab renders this as a slider with a live `NNN WPM` label. The default remains `135`.

**Primary viewport metrics:** `PrompterContentView` reports its measured content height, viewport height, effective line height, and rendered line metrics to the shared session scroll driver. The notch window is the primary metrics source when present; otherwise the first active pill window is used. The notch presentation reports metrics for the readable region below the notch cutout, not the full panel bounds.

**Notch presentation:** The shared prompter shell supports a notch-specific bottom-entry mode. In that mode, the visible reading zone begins below the notch cutout and the content stack includes a lead-in spacer so the next unread line rises upward through the reading zone instead of starting flush against the top edge.

**Display sync:** On macOS, the manual scroll driver must use an AppKit display-linked callback (`NSView`/`NSScreen` display link on supported systems) instead of `Task.sleep` or `Timer`. Scroll advancement therefore lands on actual display refresh boundaries rather than an assumed 60 fps cadence.

**Keyboard nudges:** `VoiceSyncKeyboardMonitor` continues to capture the configured up/down shortcuts globally during an active session. Instead of directly mutating the offset, the handler asks the session scroll driver to enqueue a one-line nudge using the measured rendered line height.

**Pause shortcut:** The session pause shortcut must pause the active scroll mode itself, not just the speech recognizer state. Manual WPM scroll, classic voice-sync jumps, and cinematic voice-driven drift all need to respect one explicit user-pause flag so the shortcut behaves consistently regardless of how the overlay is currently moving.

**Mouse wheel / trackpad:** `PrompterContentView` continues to use an AppKit `NSViewRepresentable` interceptor because `.nonactivatingPanel` does not reliably deliver SwiftUI scroll gestures. Wheel deltas are forwarded into the same driver instead of bypassing it, so wheel input, keyboard nudges, and WPM auto-scroll cannot fight each other.

**Single manual offset authority:** Legacy mirrored offset channels like direct `keyNudgeOffset` writes must not drive the overlay once the display-synced manual driver is active. The driver remains the only authority for rendered manual scroll position; other subsystems may publish intent such as “nudge one line” but not directly assign the displayed manual offset.

**Shared synced-session authority:** In Sync mode, `VoiceSyncEngine` remains responsible for speech matching and cursor tracking, but `SessionScrollCoordinator` owns the shared content progress for the whole session rather than a single rendered offset. The primary synced overlay advances progress using the same display-synced manual driver used by the notch-only path, then each follower synced window projects that shared progress into its own local offset using its own measured layout metrics. The primary overlay must not re-project coordinator progress back into itself, or it will fight its own display-linked motion and reintroduce jitter.

**Manual auto-scroll pacing:** Manual WPM scroll must derive its velocity from the actual rendered scrollable distance of the current overlay content and the total script read time implied by the configured WPM. In practice, the display-synced driver advances across the full normalized scroll range over `totalSpeakableWords / WPM` minutes, using the normalized overlay token count rather than a line-average heuristic, starts from the top of a fresh session unless the user is explicitly resuming the same session state, and stays perfectly linear at the display refresh cadence.

**Speakable token filtering:** WPM pacing, content-progress projection, and speech matching all share the same tokenization rules. Non-spoken metadata such as email addresses, raw URLs, and FAQ-style section markers like `Q)` / `A)` must be ignored by that tokenizer so scripts with administrative formatting do not distort scroll speed or tracking.

**Sparse-layout pacing:** Manual WPM auto-scroll must advance by speakable content progress, not by a fixed rendered-offset speed. Scripts with many paragraph breaks, headings, bullets, or FAQ formatting create sparse vertical regions; if the app advances raw offset linearly through those regions, the visible pace feels wrong. The display-linked driver therefore converts each frame's WPM progress step into that window's local rendered offset using the current line metrics, with continuous interpolation between adjacent speakable line anchors rather than snapping whole frames to the next line.

**Why this structure?** The earlier fixed `0.04` keyboard jump and `Task.sleep`-driven loops were brittle because they ignored actual script length, font size, viewport size, and display refresh timing. Centralizing all manual motion in one display-synced driver keeps WPM, keyboard nudges, and wheel scrolling coherent and prevents snapback or micro-stutter from competing offset writers.

---

## 4. Data Flow

```
Microphone
    → AVAudioEngine tap
    → VoiceSyncEngine (only during active session)
        → word match pipeline → scroll offset → PrompterContentView (Notch + Voice-Sync Pills)
        → RMS level → AudioLevelMonitor → VisualBeamView (all overlay windows, including Manual pills)

Session ends / overlays closed
    → VoiceSyncEngine.stop()
    → AVAudioEngine released
    → VoiceSyncKeyboardMonitor.stop()
    → Microphone freed
    → Zero battery usage at idle

User clicks "New Script"
    → ManagerWindowView first runs the same dismiss/autosave path used by Back navigation if an editor is already open
    → If dismiss succeeds, ScriptEditorView opens with a blank in-memory Script (UUID allocated, NOT yet written to disk)
    → Editor shows default title "Untitled Script", empty body

User presses Save in editor (explicit save)
    → AppState.saveScript(_:) — creates file if new, overwrites if existing
    → ScriptStore.save(script:) → {uuid}.json written, index.json updated
    → AppState.scripts refreshed

User presses Back (dismiss) from editor
    → ManagerWindowView checks: body non-empty OR title ≠ "Untitled Script"?
        → Yes (meaningful content): AppState.saveScript(_:) — same path as explicit save
        → No (empty draft): discard in-memory script silently; no file written; no entry in index
    → Returns to Document Library

User opens Document Library
    → ScriptStore.loadIndex()
    → reads index.json only (fast)
    → DocumentLibraryView renders from index metadata

User opens a script
    → ScriptStore.load(id:)
    → reads {uuid}.json on demand
    → ScriptEditorView populated

User drops .txt file on library (REQ-035)
    → NSDraggingDestination receives drop
    → ScriptStore.importFromURL(_:)
    → reads file contents as String
    → new Script written to {uuid}.json and index.json updated
    → AppState.scripts refreshed → editor opens with imported script

User duplicates a script (REQ-036)
    → ScriptStore.duplicate(id:)
    → reads source {uuid}.json
    → writes new {newuuid}.json with "Copy of" title prefix
    → index.json updated
    → AppState.scripts refreshed → new card appears in library

User clicks "Cast to Notch"
    → OverlayWindowController.presentSession(script:)
    → script body passed directly to PrompterContentView
    → VoiceSyncEngine.loadScript(text:) — tokenizes words for matching

User creates a Pill in Voice-Sync mode (REQ-034)
    → PillWindowController.present(mode: .voiceSync)
    → PillContentView subscribes to VoiceSyncEngine scroll events
    → Displays same script + tracks same cursor position as Notch

User creates a Pill in Manual mode (REQ-034)
    → PillWindowController.present(mode: .manual(scriptId:))
    → ScriptStore.load(id: scriptId) — reads assigned script body
    → PillContentView manages own scroll offset; no VoiceSyncEngine subscription

User changes overlay appearance via popover (REQ-038)
    → OverlayAppearancePopover writes to PillWindowController.currentAppearance
    → PrompterContentView re-renders with new OverlayAppearance values
    → Other windows unaffected

User creates a Collection (REQ-037)
    → SidebarView "+" tapped → inline name field
    → CollectionStore.create(name:)
    → collections.json updated
    → AppState.collections refreshed → new sidebar item appears

User adds script to Collection
    → ScriptCard right-click → Add to Collection → checkbox toggle
    → CollectionStore.addScript(scriptId:toCollection:)
    → Script.collectionIds updated in {uuid}.json
    → ScriptCard shows new CollectionTag

User changes settings (global defaults)
    → SettingsView slider/toggle
    → SettingsStore.set(_:forKey:)
    → UserDefaults updated
    → AppState (ObservableObject) notified
    → Affected views re-render

Keyboard shortcut ⌘⇧Space during session (REQ-039)
    → VoiceSyncKeyboardMonitor fires handler
    → VoiceSyncEngine.togglePause()
    → All Voice-Sync overlay windows pause/resume simultaneously
```

---

## 5. State Management

**`AppState`** is a global `ObservableObject` injected into the SwiftUI environment at the top level (`AiraApp.swift`). It holds:

```swift
class AppState: ObservableObject {
    @Published var scripts: [ScriptMeta] = []           // loaded from index.json
    @Published var collections: [Collection] = []        // loaded from collections.json
    @Published var activeScript: Script? = nil           // loaded on demand
    @Published var sessionActive: Bool = false
    @Published var settings: AppSettings                 // loaded from SettingsStore
    @Published var stealthWarning: Bool = false          // shown if sharingType check fails
    @Published var openPills: [PillWindowController] = [] // tracks active pill windows
}
```

All views that need global state receive it via `@EnvironmentObject`. Nested views that only need local state use `@State`. No global mutable singletons beyond `AppState`.

**`OverlayAppearance` is not in `AppState`.** It is held per-window in `NotchWindowController` and `PillWindowController`. The Overlay Appearance Popover writes directly to the controller it was opened from. This avoids unnecessary re-renders of the entire view tree when one window's appearance changes.

**Combine for reactive updates:** `VoiceSyncEngine` publishes scroll events as a `PassthroughSubject<ScrollEvent, Never>`. `PrompterContentView` subscribes to this subject and updates its scroll position accordingly. This avoids polling and keeps the scroll loop frame-synced with `CADisplayLink`.

---

## 6. Permissions Required (Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Aira uses your microphone to follow along with your script as you speak.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>Aira uses on-device speech recognition to advance your script in sync with your voice. No audio leaves your device.</string>
```

**On-device enforcement:** `SFSpeechRecognizer` is configured with `requiresOnDeviceRecognition = true`. This ensures all speech processing happens locally. If on-device recognition is unavailable (e.g., the language model is not downloaded), Aira will prompt the user to download it via System Settings > Accessibility > Spoken Content, and disable Voice-Sync until it is available.

**Sandbox and entitlements:**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>

<key>com.apple.security.device.audio-input</key>
<true/>

<key>com.apple.security.network.client</key>
<true/>

<key>com.apple.security.files.user-selected.read-only</key>
<true/>

<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
</array>
```

Hardened Runtime and App Sandbox must both be enabled in Xcode build settings. The audio-input entitlement gates microphone access. `network.client` exists solely so Sparkle can fetch the appcast and signed update archive over HTTPS. The temporary mach-lookup exceptions are required for Sparkle's installer launcher service in a sandboxed app.

**Note on `CGEvent` tap:** A global event tap requires the app to have been granted Accessibility permission by the user via System Settings > Privacy & Security > Accessibility. The app must prompt for this permission on first use of the Voice-Sync keyboard toggle. If denied, the keyboard toggle is unavailable but the rest of the app functions normally. The permission is not required for core functionality (Voice-Sync still works via hover-to-pause).

---

## 7. Testing Requirements

Tests are co-authored alongside implementation. A feature is not considered complete until its tests exist and pass.

### Unit Tests

| Module | What to test |
|---|---|
| `VoiceSyncEngine` | Word tokenization and normalization (punctuation stripping, lowercase, cue skipping); sliding-window match accuracy for exact match; sliding-window match for off-script input (fuzzy, partial match); cursor-only-moves-forward invariant (repeated phrase does not move cursor back); scroll offset calculation from matched word index; togglePause() state transitions |
| `ScriptStore` | Create, Read, Update, Delete; JSON round-trip for `Script` Codable; duplicate (new UUID, "Copy of" title, source unchanged); importFromURL (content matches file, new UUID generated, oversized file rejected); handling of missing or corrupt files (graceful error) |
| `CollectionStore` | Create, rename, delete (scripts not deleted); addScript; removeScript; filtering by collection returns correct script IDs; JSON round-trip for `Collection` Codable |
| `SettingsStore` | Read/write for every settings key; default value initialization; `OverlayAppearance` Codable round-trip; persistence across store re-initialization |
| `Models` | `Script` Codable round-trip including `collectionIds`; `AppSettings` Codable round-trip; `MoodPreset` application (all OverlayAppearance properties set correctly); `OverlayAppearance` Equatable (same values = equal) |
| `CountdownView` logic | Timer fires at 1-second intervals; stops at zero; emits `sessionDidStart` signal exactly once; duration = 0 skips immediately to `sessionDidStart`; uses window's OverlayAppearance colors |
| `VoiceSyncKeyboardMonitor` | `start()` installs event tap; `stop()` removes event tap; handler called exactly once per matching keypress; non-matching keypresses pass through |

### Integration Tests

| Scenario | What to verify |
|---|---|
| Cast to Notch → session start | Script loaded into `PrompterContentView`; `VoiceSyncEngine` starts after countdown; countdown uses window's `OverlayAppearance`; `AppState.sessionActive = true` |
| Session end | `VoiceSyncEngine.stop()` called; `AVAudioEngine` is nil after stop; microphone not in use; `VoiceSyncKeyboardMonitor` stopped; `AppState.sessionActive = false` |
| Hover pause | `scrollController.pause()` called on `mouseEntered`; offset preserved; `scrollController.resume()` called on `mouseExited`; resumes from preserved offset |
| Keyboard Voice-Sync toggle | ⌘⇧Space fires `VoiceSyncEngine.togglePause()`; all Voice-Sync windows pause/resume; Manual pills unaffected |
| Pill in Voice-Sync mode | Pill subscribes to `VoiceSyncEngine`; scroll position matches Notch Window; closing pill does not affect Notch |
| Pill in Manual mode | Pill loads its own script; `VoiceSyncEngine` scroll events do not move Manual pill; user scroll moves only that pill |
| Pill mode switch | Switch Voice-Sync → Manual: subscription removed, script picker shown; Switch Manual → Voice-Sync: subscription added, pill jumps to current cursor position |
| Script import via drag-and-drop | Drop `.txt` file → new script created with file's title and content; source file unmodified; editor opens with imported script |
| Script duplication | Duplicate action → new entry in library with "Copy of" title; source script body unchanged; both scripts independently editable |
| Per-window appearance change | Change appearance on Notch via popover → only Notch updates; Pill windows retain their own appearance |
| Appearance reset to defaults | "Reset to Defaults" in popover → window appearance matches `AppSettings.defaultOverlayAppearance` |
| Collection create/filter | Create collection → sidebar shows new item; add script to collection → filtering by collection shows that script; delete collection → scripts still in library |
| Script save → reload | Script written to `{uuid}.json`; app cold-starts; same body content readable via `ScriptStore.load(id:)` |
| Stealth flag | `NSPanel` created with `sharingType = .none`; verify flag is set; if check fails, `AppState.stealthWarning = true` |

### Manual / Exploratory Tests (document outcomes in `todo.md`)

- Confirm overlay is invisible in Zoom screen share (live test on MacBook Pro)
- Confirm overlay is invisible in Teams screen share (live test)
- Confirm notch window position on MacBook Pro 14" (notch height ≈ 34pt)
- Confirm notch window position on MacBook Pro 16" (notch height ≈ 38pt)
- Confirm Pill Window (Manual mode, different script) is independently scrollable while Notch Window voice-syncs
- Confirm multiple Voice-Sync pills track the same cursor position simultaneously
- Confirm per-window appearance popover changes apply live without lag
- Confirm keyboard shortcut fires correctly when Manager App window is in focus (not the overlay)
- Confirm Accessibility permission prompt appears on first use of keyboard shortcut
- Confirm app bundle size is under 10 MB after Archive build (`du -sh Aira.app`)
- Confirm `otool -L Aira` shows no third-party analytics or telemetry libraries
- Confirm Charles Proxy trace shows zero outbound network traffic during a full session
- Confirm `.txt` file over 10 MB is rejected gracefully with a user-facing error message

---

## 8. Security Review Checklist

The following must be verified before any release build is signed and distributed.

| Check | Requirement |
|---|---|
| No plaintext secrets on disk | API key UI is deferred; no secrets written in v1. Verify via `grep -r "apiKey\|secret\|token" ~/Library/Application\ Support/Aira/` after a full session |
| No outbound telemetry or unrelated traffic | Charles Proxy / Network Instruments trace must show no outbound requests except Sparkle appcast/update traffic over HTTPS |
| Microphone access scoped correctly | `AVAudioEngine` tap installed only inside `VoiceSyncEngine.start()` and torn down in `stop()`. Verify in Activity Monitor: microphone indicator appears only during active session |
| No telemetry SDK | Binary must not link any analytics framework. Verify: `otool -L Aira.app/Contents/MacOS/Aira` — Sparkle is the only approved non-Apple framework; no Crashlytics, Mixpanel, Amplitude, Firebase, or similar |
| Script files readable only by user | Files in Application Support use default POSIX permissions. Verify: `ls -la ~/Library/Application\ Support/Aira/Scripts/` |
| Imported files not cached or duplicated | After import, only the new script JSON exists. Original `.txt` path is not retained or re-read after import completes. |
| No world-readable tmp files | No sensitive content written to `/tmp` or shared directories |
| CGEvent tap removed at session end | `VoiceSyncKeyboardMonitor.stop()` called in session teardown. Verify no event tap persists after session ends. |
| Gatekeeper passes | Notarized `.dmg` passes `spctl --assess --verbose Aira.dmg` without warnings |
| Sparkle sandbox wiring present | `SUEnableInstallerLauncherService = true`, app sandbox entitlement enabled, Sparkle mach-lookup exceptions present, and feed/public key values resolve in the built app |
| Hardened Runtime enabled | Xcode build settings: Hardened Runtime = Yes. Sandbox entitlements present and signing succeeds |
| On-device recognition enforced | `requiresOnDeviceRecognition = true` set on `SFSpeechRecognizer`. No speech data leaves the device |

---

## 9. Out of Scope for This Document

- UI layout code, visual design decisions, or color values (belong in `design.md`)
- AI/LLM integration, prompt engineering, or API provider selection (deferred to a future release)
- Notarization CI/CD pipeline automation details
- App Store submission (Aira distributes via GitHub Releases and Sparkle, not the Mac App Store)
- Import support for formats other than `.txt` (PDF, DOCX, RTF are out of scope for v1)

---

## Requirement Coverage

| Requirement | Architecture entry |
|---|---|
| REQ-001 Voice-Driven Scroll | §3.3 VoiceSyncEngine word-matching pipeline |
| REQ-002 Pause On Silence | §3.3 silence detection via recognition result gap |
| REQ-003 Manual Scroll Override | §3.7 scroll wheel + cursor update |
| REQ-004 Visual Beam Feedback | §3.4 AudioLevelMonitor RMS → VisualBeamView (all windows including Manual pills) |
| REQ-005 Prompter Hidden From Screen Share | §3.1 `NSWindow.sharingType = .none` |
| REQ-006 Prompter Visible To User | §3.1 flag affects capture only, not local display |
| REQ-007 Stealth Failure Notification | §3.1 sharingType check → AppState.stealthWarning |
| REQ-008 Notch Window | §3.2 NotchWindowController + notch positioning |
| REQ-009 Pill Windows | §3.2 PillWindowController, multi-instance NSPanel; max 2 pills, opt-in via AppSettings.pillsEnabled |
| REQ-044 Pill Window Settings | AppSettings.pillsEnabled + maxPillCount; Settings > Overlays tab pill section |
| REQ-010 Hover-To-Pause | §3.5 NSTrackingArea mouseEntered |
| REQ-011 Resume After Hover | §3.5 NSTrackingArea mouseExited, currentOffset preserved |
| REQ-012 Pre-Session Countdown | §3.8 CountdownView async timer |
| REQ-013 Configurable Countdown | §3.8 duration from SettingsStore, zero = skip |
| REQ-014 Built-In Script Editor | §2 ScriptEditorView, §4 data flow |
| REQ-015 Local Script Storage | §3.6 FileManager + JSON in Application Support |
| REQ-016 Speech Cue Formatting | §2 CuePanelView, cue tokenization in VoiceSyncEngine |
| REQ-017 Report-To-Natural Conversion | Deferred — no v1 architecture; noted in §1 stack table |
| REQ-018 Cues In Converter Output | Deferred — no v1 architecture |
| REQ-019 BYOK Requirement | Deferred — no v1 architecture; no Keychain or URLSession in v1 |
| REQ-020 API Key And Content Privacy | Deferred — no v1 architecture |
| REQ-021 Window Size Adjustment | Pill Window NSPanel resizable; Notch width from SettingsStore |
| REQ-022 Text Size Adjustment | OverlayAppearance.fontSize → PrompterContentView |
| REQ-023 Custom Text Colors | OverlayAppearance.textColor → PrompterContentView |
| REQ-024 Mood Presets | MoodPreset model applies full OverlayAppearance bundle |
| REQ-025 Local-First Architecture | §3.6, §3.14 storage; §1 no cloud frameworks in stack |
| REQ-026 No Telemetry | §8 security checklist; §0 zero ambient network activity |
| REQ-027 No Account Required | No auth framework, no Keychain in v1 |
| REQ-028 Free Distribution | No paywall framework |
| REQ-029 Signed And Notarized | §1 Xcode Archive + notarytool; §6 Hardened Runtime |
| REQ-030 Distribution Channels | §3.10 direct-distribution updater, Sparkle appcast/ZIP pipeline, and GitHub Releases DMG path |
| REQ-031 Closed-Source | Repository policy — no architecture impact |
| REQ-032 Live Answer Mode | Future release; experimental toggle in AppSettings |
| REQ-033 Experimental Transparency | Disclosure presented before first activation; stored in AppSettings |
| REQ-034 Pill Content Mode | §3.12 PillContentMode enum; PillWindowController; VoiceSyncEngine subscription model |
| REQ-035 Script Import | §3.13 NSDraggingDestination + NSOpenPanel + ScriptStore.importFromURL |
| REQ-036 Script Duplication | §3.6 ScriptStore.duplicate; §4 data flow |
| REQ-045 Bulk Selection and Deletion | `DocumentLibraryView` local `@State var selectedScriptIDs: Set<UUID>`; Select All checkbox (3-state); per-card checkbox visible on hover or when set non-empty; ⌘+click / Shift+click; bulk delete via AppState.deleteScript loop; selection/delete affordances hidden while `AppState.sessionActive`; scripts in `AppState.activeSessionScriptIDs` cannot be opened for editing |
| REQ-037 Collections | §3.14 CollectionStore; Collection model; collections.json; §5 AppState.collections |
| REQ-038 Per-Window Overlay Appearance | §3.11 OverlayAppearance model; per-controller currentAppearance; OverlayAppearancePopover |
| REQ-039 Keyboard Voice-Sync Toggle | §3.15 VoiceSyncKeyboardMonitor; CGEvent tap; VoiceSyncEngine.togglePause() |
| REQ-003 Manual Scroll Override | §3.16 Manual Scroll Controls; AppSettings.autoScrollWPM slider; session scroll coordinator; ScrollWheel interceptor |
| REQ-040 Scroll Progress Indicator | Deferred — no v1 architecture |
| REQ-041 Session Elapsed Timer | Deferred — no v1 architecture |
| REQ-042 Jump-To-Top | Deferred — no v1 architecture |
| REQ-043 Mirror Mode | Deferred — no v1 architecture |
