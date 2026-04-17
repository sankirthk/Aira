# Aira — Task List

## How To Use This File

Each task maps to one or more REQs from `requirements.md`. A task is **done** only when:
1. Implementation matches the REQ acceptance criteria
2. All tests defined in `tests.md` for that task are written and passing
3. Relevant security checklist items in `architecture.md §7` are cleared
4. This file is updated with `[x]` and a brief note

Work one task at a time. Read the REQ, read the relevant design/architecture sections, write tests first, then implement.

---

## Phase 0 — Project Setup

- [x] Create Xcode project (SwiftUI, macOS, no SwiftData)
- [x] Scaffold all module folders and Swift files (stubs)
- [x] Add Hardened Runtime + Microphone capability in Xcode
- [x] Add NSMicrophoneUsageDescription and NSSpeechRecognitionUsageDescription to Info.plist
- [x] Bundle custom fonts: Manrope-Bold, Inter-Regular, CrimsonText-Regular, IndieFlower-Regular — register all in Info.plist under `Fonts provided by application`
- [x] Add color assets to Assets.xcassets (colorPrimary, colorSecondary, colorBackground, colorSurface, colorText, colorMuted, colorWarm — light + dark variants)

---

## Phase 1 — Data Layer

Wire the stores into AppState so all views have a consistent, reactive source of truth.

- [x] **T-001** Wire AppState to ScriptStore: load index on init, expose createScript / saveScript / deleteScript / duplicateScript / toggleStarred / loadScript(id:) / importScript(from:) — REQ-014, REQ-015, REQ-035, REQ-036. Added AppState script APIs, preserved starred state across saves, and verified with unit/integration tests.
- [x] **T-002** Wire AppState to CollectionStore: expose createCollection / renameCollection / deleteCollection — REQ-037. Added AppState collection APIs, refreshed collection state on init and mutation, and verified CollectionStore persistence behavior with unit tests.
- [x] **T-003** Wire AppState to SettingsStore: load settings on init, persist on every change — REQ-022, REQ-023, REQ-024, REQ-013, REQ-039. AppState now loads persisted settings at startup, autosaves every settings mutation through SettingsStore, and is covered by SettingsStore/AppState tests.

---

## Phase 2 — Document Library

- [x] **T-004** New Script: "New Script" / "Create Script" buttons open editor with blank **in-memory** draft (no disk write on open). Save button persists. Back dismissal auto-saves if body non-empty OR title ≠ "Untitled Script"; otherwise silently discards. No script limit. — REQ-014. Reworked manager/editor flow to create in-memory drafts, persist only on save or qualifying back-dismiss, and preserve collection membership on first save.
- [x] **T-004a** New Script autosave guard: starting a new draft from the sidebar/library must first run the same dismiss/autosave path as Back navigation so unsaved editor changes are never dropped when replacing the current draft. — REQ-014. `ManagerWindowView.createAndOpenScript()` now reuses the editor dismiss/autosave path before replacing the current draft.
- [x] **T-005** Script card: Edit action → loads script body from ScriptStore, opens ScriptEditorView — REQ-014. Edit now loads the full script through AppState and opens the in-app editor from the library card/context menu.
- [x] **T-006** Script card: Delete action → calls AppState.deleteScript(id:), confirms before deleting — REQ-014. Delete is now wired with a confirmation alert before removing the script from local storage and the library index.
- [x] **T-007** Script card: Duplicate action → calls AppState.duplicateScript(id:) — REQ-036. Duplicate now creates a local copy, refreshes the library, and opens the copy in the editor for immediate renaming.
- [x] **T-007a** Duplicate/index regression fix: preserve collection membership when duplicating a script and count indexed words across all whitespace so library metadata stays correct for multi-paragraph content. — REQ-014, REQ-036. `ScriptStore` now indexes words using whitespace-aware tokenization and retains `collectionIds` on duplicate, with unit coverage for both regressions.
- [x] **T-008** Script card: Star toggle → calls AppState.toggleStarred(id:) — REQ-014. Script cards now expose a starred toggle and persist the starred state through AppState/ScriptStore.
- [x] **T-009** Drag-and-drop .txt import → calls AppState.importScript(from:), opens result in editor — REQ-035. DocumentLibraryView now accepts dropped `.txt` file URLs, imports them locally, and opens the imported script in the editor.
- [x] **T-010** File picker .txt import → NSOpenPanel filtered to .txt, calls AppState.importScript(from:) — REQ-035. The library header now includes an Import Script button backed by `NSOpenPanel`, with imported content opening directly in the editor.
- [x] **T-010a** Bulk selection + delete: Select All checkbox in sort bar (3-state), per-card checkboxes (visible on hover or when selection active), ⌘+click / Shift+click range select, trash icon appears when 1+ selected → confirmation alert → AppState.deleteScript for each → exit selection mode. Escape cancels. — REQ-045. Added library bulk-selection state, selection-mode cards, range selection, confirmed multi-delete, and Escape-to-clear behavior.
- [x] **T-010b** Active-session library locks: hide Select All and bulk delete while a presenter session is active, block individual script deletion during the session, and prevent opening any script currently used by the active notch/pill session for editing. — REQ-014, REQ-045. Live sessions now publish active script IDs through `AppState`, the library hides delete/bulk-delete affordances during sessions, and scripts currently on-air are blocked from editor entry while the existing editor becomes read-only if its script is live.

---

## Phase 3 — Script Editor

- [x] **T-011** Save: wire Save button → calls AppState.saveScript(_:), updates lastEdited — REQ-014, REQ-015. ScriptEditorView Save now persists through AppState, refreshes the editor with the saved timestamp, and reports save failures via alert.
- [x] **T-012** Auto-save on dismiss: when editor is dismissed, save if body is non-empty OR title ≠ "Untitled Script"; silently discard if both still default/empty (new script case). For existing scripts: save if title or body changed from last persisted state. — REQ-014. Dismiss logic now matches the task spec exactly: empty untitled drafts are discarded, retitled/non-empty drafts are saved, and persisted scripts auto-save only when title or body changed.
- [x] **T-013** Cue insertion: CuePanelView buttons insert cue marker text at cursor position in TextEditor — REQ-016. Replaced the plain TextEditor with an NSTextView bridge that tracks caret selection, and cue buttons now insert markers at the current cursor position instead of appending at the end.
- [x] **T-013b** Cue annotation rendering: keep persisted cue tokens in the script body, but render them as distinct inline annotations in the editor so cue formatting stays visually separate from spoken prose. — REQ-016. The script editor now restyles bracketed cue tokens inline in the NSTextView and includes focused styling tests.
- [x] **T-013c** Script editor metrics alignment: use whitespace-aware word counting in the editor so multiline/tabbed scripts show the same word count and duration metadata as the library index. — REQ-014, REQ-015. The editor now uses the same all-whitespace tokenization rule as `ScriptStore`, with focused coverage for newline/tab-separated content.
- [x] **T-013a** Script Editor token audit: replace cue-panel hardcoded sage/cream values with shared color assets so the Script Editor follows the repository token rules from `best-practices.md`. — REQ-021. CuePanelView now uses shared asset colors instead of inline hex literals.

---

## Phase 4 — Collections

- [x] **T-014** Create collection: inline TextField submit in SidebarView → calls AppState.createCollection(name:) — REQ-037. SidebarView now creates collections inline, trims names, selects the new collection, and surfaces validation/action errors in-app.
- [x] **T-015** Rename collection: context menu → inline rename or alert — REQ-037. Collection rows now enter inline rename mode from the context menu and persist the updated name through AppState.
- [x] **T-016** Delete collection: context menu → confirm → calls AppState.deleteCollection(id:) — REQ-037. Collection rows now confirm destructive deletes, remove the collection through AppState, and return navigation to All Scripts if the deleted collection was active.
- [x] **T-017** Filter library by collection: SidebarNav.collection(id) already routes to DocumentLibraryView — verify filter logic in filteredScripts — REQ-037. DocumentLibraryView now uses shared collection filter logic covered by tests so collection navigation only shows scripts belonging to the selected collection.
- [x] **T-017a** Collections audit cleanup: replace the sidebar stealth warning hardcoded highlight color with a shared asset token and remove `DispatchQueue.main.async` from the manager window accessor in favor of `Task { @MainActor ... }` per `best-practices.md`. — REQ-021, REQ-037. The collections shell now uses shared theme tokens and main-actor task dispatch for window resolution.
- [x] **T-017b** Collection duplication membership fix: when duplicating a script, sync the duplicate's collection memberships back into CollectionStore so collection-filtered views do not drop the copy. — REQ-036, REQ-037. AppState duplication now mirrors preserved `collectionIds` into CollectionStore and refreshes collection state, with regression coverage.
- [x] **T-017c** Collection deletion membership cleanup: when deleting a collection, remove the deleted collection ID from every persisted script so script metadata cannot retain orphaned memberships. — REQ-037. `AppState.deleteCollection(id:)` now scrubs removed collection IDs from script files and includes regression coverage.

---

## Phase 5 — Settings

- [x] **T-018** Appearance tab: light/dark mode toggle (Light Paper / Dark Studio cards) wired to AppSettings.appearanceMode; custom two-pane SettingsView with sage sidebar tabs + cream content — REQ-021
- [x] **T-018a** Theme preview swatch fix: keep the Light Paper and Dark Studio preview chips visually light/dark regardless of the currently active app theme by using fixed preview colors instead of adaptive asset colors. — REQ-021. The Appearance tab previews now always display the intended paper/studio tones.
- [x] **T-019** Appearance tab: text size S/M/L wired to AppSettings.defaultOverlayAppearance.fontSize — REQ-022
- [x] **T-020** Notch tab: overlay defaults (background color w/ 5 presets + custom ColorPicker, opacity slider, font size slider, full system font picker via NSFontManager) wired to AppSettings.defaultOverlayAppearance; live notch preview using NotchWrapShape clip path — REQ-023, REQ-024, REQ-038
- [x] **T-020a** Text color picker: add text color row (4 presets: Cream, White, Charcoal, Warm Tan + custom ColorPicker) to the Overlay Color panel in Settings > Notch tab — wired to AppSettings.defaultOverlayAppearance.textColor — REQ-023. Implemented in `SettingsView` with preset swatches and custom picker.
- [x] **T-020b** Pill settings section in Settings > Overlays tab: Enable Pill Windows toggle + pill count segmented control (1 or 2) — wired to AppSettings.pillsEnabled / maxPillCount; count control disabled when toggle is off — REQ-044. Implemented in `SettingsView` and persisted through `AppSettings` / `SettingsStore`.
- [x] **T-020c** Settings chunk-1 audit cleanup: rename the settings notch tab to `The Notch`, route Escape recording through `KeyboardShortcutDisplay.matches`, and normalize `AppSettings.maxPillCount` to the supported `1...2` range during init/decoding. — REQ-021, REQ-044. Chunk-1 settings now align with the repo tab naming and settings normalization rules.
- [x] **T-021** Overlays tab: mood preset selector (Day / Night) wired to AppSettings — REQ-024. Added Day and Night preset cards to the overlay settings tab; applying a preset updates the full default overlay appearance in one action, and the active preset is derived from the current appearance values.
- [x] **T-022** System tab: countdown duration stepper wired to AppSettings.countdownDuration — REQ-013. Added a bounded 0–10 second stepper in the System tab, with `0` shown as Off, and covered the default countdown contract in settings tests.
- [x] **T-023** System tab: speech sensitivity (Low/Medium/High) wired to AppSettings.speechSensitivity; disabled when voice sync is off — REQ-001
- [x] **T-024** System tab: voice-activated scroll toggle wired to AppSettings.voiceSyncEnabled; toggle appears before sensitivity; sensitivity disabled when toggle is off — REQ-001
- [x] **T-025** System tab: keyboard shortcut editor (ShortcutRow) for all configured shortcuts — REQ-039. Replaced static shortcut labels with a recorder control that captures key combinations into display strings, added formatter tests, and verified persistence through AppState/SettingsStore tests.
- [x] **T-025a** System tab: manual scroll speed slider wired to `AppSettings.autoScrollWPM`, clamped to `100...300 WPM`, with a live WPM label and explanatory copy that it applies when Voice-Sync is off. — REQ-003. Added the System-tab Manual Scroll panel, persisted the WPM setting with bounded helpers, and covered the range/default behavior in settings tests.
- [x] **T-025b** Settings modal visual parity: make the Preferences tab strip use the mockup cream paper color, use sage for the active tab in both light and dark mode, and shrink the App Theme preview swatches to the mockup square size. Add/update shared color assets instead of hardcoding the paper tone. — REQ-021
- [ ] **T-025c** Color audit token sweep: replace remaining manager/settings/library hardcoded sage, linen, charcoal, and terracotta values with shared asset tokens (`colorPrimary`, `colorSecondary`, `colorBackground`, `colorSurface`, `colorText`, `colorMuted`, `colorTertiary`, `colorPaper`) where they represent the audited palette. — REQ-021
- [x] **T-025d** Settings modal polish: use the themed surface color for the top Preferences chrome in both light and dark mode, center the App Theme preview swatches, and use Crimson Text for System-tab control labels/body copy while keeping Indie Flower for section headings. — REQ-021
- [x] **T-025d-a** System tab copy/style audit: align the Manual Scroll panel copy with the persisted Manual-mode behavior and render the Speech Sensitivity field label in the System-tab Crimson Text style instead of the shared decorative field-label treatment. — REQ-021, REQ-003. The System tab now describes Manual mode accurately and keeps control labels in Crimson Text.
- [x] **T-025e** Settings visual regression fixes: keep selected Preferences tab text white in dark mode, force the dark top chrome to `#484C49`, keep the Light Paper preview stable across themes, set dark-mode script cards to `#3A3A3A`, use `#434343` for the notch preview background, and keep script-card Cast to Notch text/icons on the light text color. — REQ-021
- [x] **T-025f** Manager chrome polish: force the sidebar New Script action to pure white, align script-card Cast button text/icon color with the Edit button, and slightly widen the script-card double-border gap. — REQ-021
- [x] **T-025g** Sidebar/settings control polish: make the Pill Windows enable control match the Voice Tracking switch sizing and sage tint, and replace the Sidebar Scripts plus icon with a document/scribble icon while keeping the New Script action as a plus. — REQ-021
- [x] **T-025h** System tab consistency: remove the special highlighted background from the Voice Tracking enable row so it matches the rest of the System settings panel styling. — REQ-021. The Voice Tracking row now uses the same neutral panel treatment as the rest of the System tab.
- [x] **T-025i** Voice-Sync smoothing: reduce per-result cursor jumps so speech tracking advances smoothly instead of skipping ahead (fixed the double smoothing bug that was causing permanent cursor lag) and publish the currently matched word index for scroll-tracking logic without visible spoken-word emphasis in the overlay. — REQ-001, REQ-002
- [x] **T-025j** Document Library selection-mode stability: keep the Select All / trash bar and script cards layout-stable when entering selection mode so buttons disappear without causing visible card/header jitter or translation. — REQ-045
- [x] **T-025k** System tab cleanup: remove the special background styling from keyboard shortcut rows so they match the rest of the System settings panel presentation. — REQ-021. Shortcut rows now sit directly in the shared settings panel without the old highlighted row chrome.
- [x] **T-025l** Notch teleprompter readability: keep the readable script region below the notch cutout, make script lines enter from lower in the overlay like a teleprompter, and move the notch voice indicator out of the text area into corner sound waves. — REQ-004, REQ-008
- [x] **T-025m** Overlay text presentation cleanup: remove spoken-word emphasis, add a start marker above the opening line, and normalize editor line breaks into flowing overlay paragraphs so scripts stream cleanly in notch and pill overlays. — REQ-001, REQ-008
- [x] **T-025o** Manual scroll accuracy and smoothness: make WPM-driven manual scroll start from the top of a fresh session, match the configured WPM against the actual rendered scroll distance, avoid snapping back toward a prior mid-script offset unless the user is explicitly resuming, and keep movement smooth under timer, keyboard, and wheel-driven manual scroll. — REQ-003
- [x] **T-025n** Countdown reveal behavior: keep script content hidden while the countdown is onscreen, then reveal the overlay text only after the countdown completes. — REQ-012, REQ-013
- [x] **T-025s** Session pause shortcut: make the pause keyboard shortcut pause the active scrolling mode itself rather than only toggling speech-engine state, so manual WPM scroll and voice-driven scroll both stop and resume reliably. — REQ-003. Pause now drives shared/manual session scroll state instead of only speech-engine state.
- [x] **T-025t** Synced overlay session state: in Sync mode, notch and all synced pills must share one scroll authority and one paused/running state; only Manual pills may diverge independently. — REQ-034, REQ-039. Sync sessions now share scroll and pause behavior while Manual pills keep local ownership.
- [x] **T-025u** Synced manual driver parity: route synced manual scroll through the same display-linked driver used by the primary notch path, with `SessionScrollCoordinator` publishing the shared rendered offset to follower pills. — REQ-003, REQ-034. The initial synced manual path now runs through the display-linked driver and has since been refined onto the shared playhead path.
- [x] **T-025v** Synced content-progress projection: in Sync mode, publish shared script/content progress rather than a shared rendered offset so each window keeps its own correct local WPM pacing while still showing the same content position. — REQ-003, REQ-034. Synced overlays now align on shared content progress with per-window projection.
- [x] **T-025w** Primary sync-driver isolation: prevent the primary synced notch window from re-projecting coordinator progress back into its own rendered offset so notch pacing stays smooth and matches the configured WPM while follower pills continue projecting shared progress locally. — REQ-003, REQ-034. The primary synced overlay no longer feeds coordinator progress back into its own local rendered path.
- [x] **T-025x** Script-specific token filtering: exclude non-spoken metadata tokens such as email addresses, raw URLs, and FAQ markers from WPM pacing, content-progress projection, and speech matching so administrative scripts do not glitch notch or synced scrolling. — REQ-001, REQ-003. Voice/token matching now ignores these non-spoken metadata tokens.
- [x] **T-025y** Sparse-layout manual pacing: drive manual WPM auto-scroll by speakable content progress rather than fixed rendered-offset speed so scripts with many short paragraphs, FAQ sections, or blank vertical gaps still move at the configured pace without visible slow zones or jitter. — REQ-003
- [x] **T-025z** Scroll refactor spec: document the target shared playhead architecture (`progress + velocity + paused`), identify current hybrid ownership points, and define the migration boundaries before continuing scroll fixes. — REQ-001, REQ-003, REQ-034, REQ-039. Added the current-vs-target scroll architecture spec and migration boundaries in `scroll.md` plus companion architecture docs.
- [x] **T-025aa** Session playhead coordinator introduction: add a dedicated playhead coordinator that owns shared normalized session progress, velocity, and pause state without changing visible behavior yet. — REQ-003, REQ-034, REQ-039. Added `SessionPlayheadCoordinator` and wired it through the overlay session stack.
- [x] **T-025ab** Manual playhead migration: move manual WPM scroll, wheel input, and keyboard line nudges to the shared playhead so manual motion no longer depends on local rendered-offset ownership in `PrompterContentView`, and derive shared manual WPM velocity from the primary overlay's measured rendered line density rather than total script duration. — REQ-003, REQ-039. Manual Sync sessions now move through the shared playhead path, and the primary overlay derives manual velocity from rendered density instead of naive total script duration.
- [x] **T-025ac** Sync overlay projection cleanup: make synced notch and pills pure projections of shared playhead progress, with per-window local geometry mapping and no shared rendered offset state; remove the legacy synchronized line-index channel from manual `Sync` sessions so only the voice path still relies on it. — REQ-003, REQ-034. Manual Sync rendering now follows shared playhead projection directly and no longer depends on the legacy line-index channel.
- [x] **T-025ad** Unified voice-mode integration: collapse the old multi-mode voice behavior into a single shared-playhead Voice mode that publishes bounded target updates instead of mutating rendered offsets or view-local scroll state directly. — REQ-001, REQ-002
- [ ] **T-025af** Local projection precision: replace coarse line-anchor projection with a denser anchor lookup as needed so sparse-layout scripts and FAQ-style documents pace correctly without local glitches. — REQ-003
- [ ] **T-025ag** Scroll ownership cleanup: remove dead hybrid paths from `PrompterContentView`, `VoiceSyncEngine`, and `OverlayWindowController` after the shared playhead is authoritative. — REQ-001, REQ-003, REQ-034, REQ-039
- [x] **T-025ah** Long-script render performance: stop rebuilding full overlay text presentation during per-frame scroll updates so long scripts do not introduce visible lag or jitter from render cost alone. — REQ-003. `PrompterContentView` now caches the rendered script text and only rebuilds it when script content or appearance changes.

---

## Phase 6 — Overlay Windows

- [x] **T-026** Notch window positioning: read NSScreen.main?.safeAreaInsets.top, position NSPanel frame directly below notch — REQ-008. NotchWindowController now uses the built-in display safe area and visible frame to place the borderless panel directly beneath the notch region.
- [x] **T-026a** Notch flush-fit polish: slightly tighten the live notch cutout depth so the overlay no longer shows a hairline gap under the physical notch’s lower inner curves. — REQ-008. The runtime notch clip now overscans upward very slightly to eliminate the visible seam.
- [x] **T-026b** Notch side-fit polish: slightly widen the live notch cutout so the overlay no longer shows hairline seams along the vertical inner notch edges. — REQ-008. The runtime notch clip now overscans outward slightly on both sides.
- [x] **T-027** Stealth flag: verify NSPanel.sharingType == .none before session starts; set AppState.stealthWarning = true if not honoured; show banner in ManagerWindowView — REQ-007. OverlayWindowController now verifies stealth across notch and pill panels and drives a warning banner in the sidebar when capture exclusion cannot be guaranteed.
- [x] **T-028** PrompterContentView: hover-to-pause via onHover, preserve scroll offset, resume on mouse exit — REQ-010, REQ-011. PrompterContentView now freezes the rendered scroll position while hovered and resumes from the latest Voice-Sync offset on exit.
- [x] **T-029** CountdownView: async countdown Task, fires at 1s intervals, signals session start at zero — REQ-012, REQ-013. CountdownView now runs through a shared async countdown runner, starts sessions immediately when duration is zero, and is covered by countdown tests.
- [x] **T-030** VisualBeamView: 8 bars animated with withAnimation, heights driven by AudioLevelMonitor.level — REQ-004. VoiceSyncEngine now forwards audio buffers into AudioLevelMonitor so VisualBeamView animates from live microphone RMS levels.
- [x] **T-031** Pill window launch flow: PillSetupView sheet → mode + script selection → OverlayWindowController.addPill(mode:) — REQ-009, REQ-034. The sidebar Go Live action now presents PillSetupView and launches a pill window through OverlayWindowController with the selected mode and script.
- [x] **T-032** Per-window appearance popover: OverlayAppearancePopover wired to currentAppearance @State in NotchContentView and PillContentView — REQ-038. Notch and pill overlays now keep independent `currentAppearance` state with popover overrides and reset-to-default support.
- [x] **T-033** Cast to Notch from ScriptCardView and ScriptEditorView → OverlayWindowController.presentSession(script:appearance:countdownDuration:) — REQ-008, REQ-012. Script cards and the editor toolbar now cast the selected script into a managed notch session using the saved overlay defaults and countdown duration.
- [x] **T-033c** Phase 6 overlay audit cleanup: remove the duplicate overlay-local `Color(hex:)` helper from `VisualBeamView` and use the shared `colorPrimary` asset for the audio beam bars instead of a hardcoded sage hex. — REQ-004, REQ-021. Overlay window visuals now follow the shared theme-token and shared-utility rules from the repo best-practices audit.
- [ ] **T-033a** Session manual-scroll plumbing: propagate the saved `autoScrollWPM` through manager, notch, and pill launch paths so manual auto-scroll remains available independently of Voice-Sync during live sessions. Also verify session scroll shortcuts continue nudging the shared scroll position. — Global Invariants, REQ-039
- [ ] **T-033b** Session manual scroll behavior: keyboard scroll shortcuts nudge by one rendered line using measured prompter metrics, and overlay mouse wheel / trackpad input manually scrolls text in active notch and pill sessions. — REQ-003

---

## Phase 7 — Voice Sync

- [x] **T-034** AVAudioEngine + SFSpeechRecognizer: wire start()/stop() in VoiceSyncEngine, requiresOnDeviceRecognition = true, install audio tap — REQ-001, REQ-002. VoiceSyncEngine now owns the shared AVAudioEngine lifecycle, configures on-device recognition, installs the microphone tap, and tears everything down on stop.
- [x] **T-035** Word tokenization + sliding window match: implement tokenize(), findMatch(), advance cursor forward only — REQ-001. Extracted tokenization and sliding-window matching into testable VoiceSyncMatching helpers with exact/fuzzy overlap coverage.
- [x] **T-036** Publish scroll offset: VoiceSyncEngine publishes scrollOffset to PrompterContentView via @Published — REQ-001. Scroll progress remains published from VoiceSyncEngine and is now derived through the shared matching helpers.
- [x] **T-037** Pause on silence: no transcription result within threshold → hold last scroll offset — REQ-002. VoiceSyncEngine now schedules a silence deadline and transitions to `.paused` after 500ms without new transcription, resuming when speech results return.
- [x] **T-038** AudioLevelMonitor: RMS tap on AVAudioEngine, normalize 0–1, publish level to VisualBeamView — REQ-004. AudioLevelMonitor continues to read RMS from the shared engine tap and publish normalized levels for VisualBeamView.
- [x] **T-039** Keyboard Voice-Sync toggle: CGEvent tap, maps to configured shortcut, calls VoiceSyncEngine.togglePause() — REQ-039. Added VoiceSyncKeyboardMonitor using a session-scoped CGEvent tap and wired ManagerWindowView to start and stop it with active sessions.

---

## Phase 8 — Distribution

- [ ] **T-040** Verify app bundle < 10 MB after Archive build
- [ ] **T-041** Confirm no outbound telemetry or unrelated network calls via Charles Proxy or Network Instruments; only Sparkle appcast/update HTTPS traffic is permitted in direct-distribution builds — REQ-025, REQ-026, REQ-030
- [ ] **T-042** Confirm microphone released after session end (Activity Monitor check)
- [ ] **T-043** Notarized release pipeline: `xcodebuild archive` → sign → `notarytool submit` → staple → signed DMG output — REQ-029. Release script/workflow exists but still needs a full successful dry run and verification.
- [ ] **T-043a** Sparkle sandbox wiring: App Sandbox entitlements, installer launcher service, feed URL, and public EdDSA key must be present in the built app bundle — REQ-030. App-side wiring and focused tests exist; release verification is still pending.
- [ ] **T-043b** In-app updater bootstrap: `AppUpdaterController` must fail closed when feed/public-key config is missing and expose `Check for Updates…` only when Sparkle is configured — REQ-030. Implementation landed; end-to-end verification is pending.
- [ ] **T-043c** Custom update prompt: replace Sparkle's stock update-found / ready-to-install prompt surfaces with the compact Aira-branded popup while preserving Sparkle's download/install flow — REQ-030. Prompt implementation and content tests exist; build validation is still pending.
- [ ] **T-044** Sparkle artifacts: create signed `Aira-<version>.zip`, generate/update `appcast.xml`, and host both at the stable public feed URL — REQ-030
- [ ] **T-045** Public release publishing: publish the notarized DMG and Sparkle ZIP to `sankirthk/aira-releases` from the tag-driven release workflow — REQ-030
- [ ] **T-045a** Website metadata sync: update `aira-site/src/content/release.ts` from the release workflow after the public artifacts are live — REQ-030
- [ ] **T-046** First tagged beta dry run: push a release tag, watch the workflow succeed, verify GitHub release assets, confirm `appcast.xml` is updated, and confirm an installed build sees the update — REQ-029, REQ-030

---

## Deferred — Post-v1

These tasks are documented for future reference. Do not implement in v1.

- [ ] AI Report-to-Natural Converter — REQ-017, REQ-018, REQ-019, REQ-020
- [ ] BYOK API key storage (Keychain) — REQ-019, REQ-020
- [ ] Live Answer Mode — REQ-032, REQ-033
- [ ] Homebrew Cask formula — REQ-030 (deferred until the direct-distribution + Sparkle pipeline is stable)
- [ ] Scroll Progress Indicator — REQ-040
- [ ] Session Elapsed Timer — REQ-041
- [ ] Jump-to-Top shortcut — REQ-042
- [ ] Mirror Mode — REQ-043
