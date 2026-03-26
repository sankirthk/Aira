# Aira — Claude Code Guide

    ## What is Aira

    Aira is a native macOS teleprompter app for presenters, podcasters, and video creators. It displays a scrolling script in a
    floating overlay window that sits beneath the camera notch (or anywhere on screen as a free-moving Pill Window), allowing natural
     eye contact with the audience. The overlay is excluded from screen-share output (Zoom, Teams) via macOS stealth APIs — remote
    participants never see the prompter.

    Core capabilities:
    - **Voice-Sync**: script scroll position tracks the user's spoken words in real time using on-device speech recognition
    (SFSpeechRecognizer). Scroll pauses when the user stops speaking.
    - **Stealth Mode**: overlay windows are invisible to screen capture using `NSWindow.sharingType = .none`.
    - **Script Editor**: built-in editor with speech cue annotations (pause, emphasis, breath).
    - **Local-First**: no account, no telemetry, no cloud. All data stays on device.
    - **AI Converter** (future): converts formal documents to spoken scripts using a user-supplied API key (BYOK). Not in v1.

    Tech stack: SwiftUI (Manager App) + AppKit NSPanel (overlay windows) + AVAudioEngine + SFSpeechRecognizer + FileManager/JSON
    storage.

    ---

    ## How to Orient Yourself

    Before starting any implementation work, read these documents in order:

    1. `requirements.md` — the normative behavioral spec (33 REQs across 9 areas). This is the source of truth for what the app must
    do.
    2. `design.md` — UI design: screens, components, design tokens, interaction states.
    3. `architecture.md` — technical design: module structure, API choices, data flow, performance mandates, security checklist.
    4. `todo.md` — the task list. Check this to understand what has been done and what is next.
    5. `tests.md` — test plan and status. Check which tests are passing before marking anything done.

    ---

    ## Documentation-First Rule

    Before implementing any feature or fix:
    1. Check `design.md` for contradictions with what will be built — correct them first.
    2. Add or update the task in `todo.md` (use sub-task IDs like `T-020a` when a parent task was
       prematurely marked done).
    3. Add the test ID to `tests.md` (mark `[w]` once written, `[x]` once passing).
    4. Only then write implementation code.

    This order prevents `design.md` from drifting out of sync with the actual implementation.

    ---

    ## Definition of Done

    A task is **only complete** when ALL of the following are true:

    1. **Implementation matches the requirement** — the behavior described in `requirements.md` for the relevant REQ(s) is fully
    realized in code.
    2. **Tests pass** — all unit and integration tests for the module are written and passing, as defined in `tests.md` and
    `architecture.md` Section 6.
    3. **Security review items cleared** — any security checklist item in `architecture.md` Section 7 that is relevant to the task
    has been verified.
    4. **`todo.md` updated** — the task is marked `[x]` in `todo.md` with a brief note on what was done.

    Do not mark a task done if tests are skipped, stubbed, or failing. Do not mark a task done if the security review item for that
    area has not been checked.

    ---

    ## Important Constraints (do not violate)

    - **Zero third-party Swift packages.** Use only Apple frameworks.
    - **App bundle must be under 10 MB** after Archive build.
    - **AVAudioEngine runs only during an active presenter session.** It must be fully stopped and released when the session ends.
    - **No polling loops.** Use Combine or async/await for reactive state. Scroll uses `CADisplayLink`, not `Timer`.
    - **No network calls** except a user-initiated AI conversion call (v1 has no AI — so no network calls at all in v1).
    - **`requiresOnDeviceRecognition = true`** must be set on SFSpeechRecognizer. No audio leaves the device.
    - **Stealth must never fail silently.** Verify `NSWindow.sharingType = .none` before session starts; show a warning banner if it
    cannot be confirmed (REQ-007).
    - **AI integration is deferred.** Do not implement `AIIntegration/` or `KeychainStore.swift` in v1.

    ---

    ## UI Implementation Rules (learned from building the Manager App)

    ### Always read the React mockup before implementing any UI
    The source of truth for visual design is `Notchapp/src/app/components/`. Read the relevant `.tsx` file
    before writing any SwiftUI. Do not guess at colors, fonts, spacing, or shapes.

    ### Font names
    - Custom fonts use the **PostScript name**, not the family name, in `.font(.custom(name, size:))`.
    - The confirmed working name for Indie Flower is `"IndieFlower"` (not `"IndieFlower-Regular"`).
    - Crimson Text: `"CrimsonText-Regular"`. Manrope: `"Manrope-Bold"`.
    - Custom font files must be added to the **Aira target's Copy Bundle Resources** in Xcode and listed
      under `Fonts provided by application` in Info.plist or the font will silently fall back to system.
    - Use the debug print in `AiraApp.init()` to discover PostScript names at runtime.

    ### SVG → SwiftUI path translation
    - Translate SVG paths (Q, T, L, M, Z commands) into `Path` using `addQuadCurve`, `addLine`, `move`,
      `closeSubpath`. Scale all coordinates with `sx = rect.width / sourceW`, `sy = rect.height / sourceH`.
    - **WavySeparator**: source viewBox 200×2, 10 segments, `amp = rect.height * 0.25`, alternating `cpY`.
    - **OrganicButtonBorder**: source 200×46, exact path from `SidebarButton.tsx`.
    - **NotchWrapShape**: source 250×110, clip path from `NotchPreview.tsx` — overlay wraps *around* the
      notch, not below it. Notch cutout at x=65..185, y=0..30 with inner 14pt bezier curves.

    ### Sidebar layout
    - Use a custom `VStack` + `HStack` layout instead of `NavigationSplitView`. The system split view
      cannot be fully styled (background color, divider appearance).
    - Sidebar background: `Color("colorPrimary")`. Content background: `Color("colorBackground")`.
    - Section separators in the sidebar: `WavySeparator`, not `Divider()`. Only two — one above Library,
      one above Preferences.
    - Sidebar action buttons (New Script, Go Live) use `OrganicButtonBorder` stroke, not `RoundedRectangle`.
    - Nav item labels: `CrimsonText-Regular` 16pt. Action button labels: `CrimsonText-Regular` 16pt.
    - The sidebar toggle icon must have `animated: false` — it should not bounce on hover.

    ### Settings modal
    - Use a custom `VStack` layout: sage green top bar (title + close button + horizontal tab row), then
      cream content area below. Do NOT use the system `TabView`.
    - Tab buttons fill the full row equally: `HStack` with `frame(maxWidth: .infinity)` on each button.
    - Do not show a subtitle or description under each tab button label.
    - Do not show a repeated tab title + blurb inside the content area — content starts immediately.
    - The Intelligence/AI tab is **deferred** — only Appearance, The Notch, and System tabs exist in v1.
    - Font picker for the overlay belongs in **The Notch** tab, not the Appearance tab.
    - Voice sync toggle comes **before** sensitivity options; sensitivity is disabled when the toggle is off.
    - The Overlay Color panel has **two separate swatch rows**: Background Color and Text Color, separated
      by a `Divider().padding(.vertical, 8)`. Each row has a `FieldLabel` header above it.
    - Overlay color swatches use `frame(maxWidth: .infinity)` + `aspectRatio(1)` so all items fill the
      row equally without needing fixed pixel sizes.
    - **Background color presets** (5 + Custom): Sage `#849688`, Clay `#C98B7A`, Ink `#2B2B2B`,
      Slate `#6B8E99`, Warm Tan `#D4A574`.
    - **Text color presets** (4 + Custom): Cream `#F5F2EC`, White `#FFFFFF`, Charcoal `#2B2B2B`,
      Warm Tan `#D4A574`.
    - Light swatches (Cream, White) need a subtle inner border so they read against the cream panel
      background: `.overlay(RoundedRectangle(cornerRadius:).stroke(Color(hex: "#2B2B2B").opacity(0.15), lineWidth: 1))`.
    - The **Color ↔ hex bridge** pattern for `ColorPicker` bindings: wrap `appState.settings.defaultOverlayAppearance.xColor`
      in a `Binding<Color>` that gets via `Color(hex:)` and sets via `NSColor(newColor).usingColorSpace(.sRGB)`
      then `String(format: "#%02X%02X%02X", ...)`. Both `overlayColorBinding` and `overlayTextColorBinding`
      in `NotchTabContent` follow this pattern.

    ### Document Library — bulk selection model
    - Selection state lives in `DocumentLibraryView` as `@State var selectedScriptIDs: Set<UUID>`.
      It is not in AppState — it is transient, view-local, and has no persistence.
    - **Select All checkbox** in the sort/filter bar: 3 states (unchecked / mixed / checked). Drives the
      full visible set into/out of `selectedScriptIDs`. Mixed state when some but not all are selected.
    - **Per-card checkbox**: hidden by default; visible on card hover OR when `selectedScriptIDs` is non-empty.
    - **⌘+click**: toggle individual card. **Shift+click**: select inclusive range using sorted card index.
    - **Trash icon**: shown in sort bar only when `!selectedScriptIDs.isEmpty`. Confirmation alert before delete.
    - Bulk delete loops `AppState.deleteScript(id:)` for each ID then clears `selectedScriptIDs`.
    - Escape key exits selection mode (clears `selectedScriptIDs`).
    - In selection mode, per-card Edit/Cast/Duplicate actions are hidden — only checkbox + metadata shown.

    ### New script creation — deferred write pattern
    - "New Script" opens the editor with a blank **in-memory** draft. `AppState.createScript()` is NOT
      called at this point — no UUID, no file, no index entry yet.
    - On explicit **Save**: call `AppState.saveScript(_:)` — creates the file if new, overwrites if existing.
    - On **Back (dismiss)**: check two conditions —
      - `script.body` is non-empty → save
      - `script.title != "Untitled Script"` → save
      - Both still default/empty → **silently discard**; no file written, no index entry
    - For **existing scripts** on dismiss: save only if title or body differ from last persisted values.
    - No dirty indicator in the UI. Auto-save on dismiss makes it unnecessary.
    - No limit on script count.
    - T-004 and T-012 both need rework to implement this — see todo.md.

    ### Pill window settings model
    - Pills are **opt-in** — `AppSettings.pillsEnabled = false` by default.
    - `AppSettings.maxPillCount: Int` — 1 or 2 only. `OverlayWindowController` caps pill configs at this value.
    - Pills share `defaultOverlayAppearance` with the Notch window — there are no separate per-pill appearance
      fields in `AppSettings`. Per-pill customisation is done in-session via `OverlayAppearancePopover` only.
    - Settings > Overlays tab pill section: enable toggle + segmented count control (1 | 2). Count control is
      disabled/dimmed when the toggle is off.

    ### Notch window screen targeting
    - The Notch window must **always** appear on the built-in laptop display — never use `NSScreen.main`
      (that tracks the key window and changes when the user focuses an external monitor).
    - Detection order in `NotchWindowController.builtInScreen`:
      1. `NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })` — the notch screen on notch Macs.
      2. `CGDisplayIsBuiltin(id) != 0` via `screen.deviceDescription["NSScreenNumber"]` — fallback for non-notch Macs.
      3. `NSScreen.screens[0]` — last resort if neither yields a result.
    - Pill windows use `NSScreen.main` (or wherever the user drags them) — that is correct for pills.

    ### Notch preview in Settings
    - The overlay **wraps around** the notch — it is not a strip below it.
    - Use `NotchWrapShape` (clip path translated from `NotchPreview.tsx`) to cut the notch hole out of
      the overlay rectangle. Dark background shows through the cutout, making the notch visible.
    - Screen background in the preview: `#1F1F1F`. If the notch pill (black) is invisible, lighten the
      background to `#333333` so it reads clearly.
    - Text in the preview needs `padding(.top, ~44pt)` to appear below the notch cutout area.
    - Use `.offset(y: notchH)` to position the overlay flush under the notch — not a `Color.clear` spacer
      inside a VStack.

    ### AiraIcon
    - All icons drawn via `Canvas` in a 24×24 coordinate space scaled by `s = canvasSize.width / 24`.
    - `animated: Bool = true` parameter — pass `animated: false` for toolbar/utility icons (sidebar toggle).
    - Spring bounce: `scaleEffect(1.15)`, `rotationEffect(-5°)`, `.spring(response:0.35, dampingFraction:0.5)`.

    ### Color assets
    - `colorPrimary` = #849688 (sage green). `colorSecondary` = #C98B7A (terracotta).
    - `colorBackground` = #F5F2EC (cream) light / dark variant. `colorText` = #2B2B2B (charcoal).
    - Always use `Color("colorX")` for asset-based colors. Use `Color(hex:)` for one-off hex values.
    - The `Color(hex:)` extension is defined in the project — do not redefine it.