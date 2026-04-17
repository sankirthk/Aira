# Aira — Test Plan

## How To Use This File

Each test maps to a task in `todo.md` and one or more REQs in `requirements.md`. Tests are written **before** the implementation of their corresponding task. A task is not done until its tests are written and passing.

Test status:
- `[ ]` — not yet written
- `[w]` — written, not yet passing
- `[x]` — written and passing

Tests live in the `AiraTests` target in Xcode (XCTest).

Repository automation is tracked here when it materially gates shipping quality. CI checks are not a substitute for the app's unit/integration/manual coverage, but they do enforce formatting, linting, and test execution on shared branches.

---

## Unit Tests

### ScriptStore (Task T-001)

| ID | Test | Status |
|---|---|---|
| UT-001 | `save()` writes a JSON file to Application Support and the file can be decoded back to the same Script | `[x]` |
| UT-002 | `loadIndex()` returns an empty array when no index file exists | `[x]` |
| UT-003 | `loadIndex()` returns correct ScriptMeta entries after one or more saves | `[x]` |
| UT-003a | `save()` indexes `wordCount` by all whitespace so multi-line and tab-delimited scripts report the correct count | `[x]` |
| UT-004 | `load(id:)` throws when the file does not exist | `[x]` |
| UT-005 | `delete(id:)` removes the script file and removes the entry from the index | `[x]` |
| UT-006 | `duplicate(id:)` creates a new file with a different UUID, same body, and title prefixed with "Copy of" | `[x]` |
| UT-006a | `duplicate(id:)` preserves the source script's `collectionIds` so copies remain visible in the same collections | `[x]` |
| UT-007 | `importFromURL(_:)` creates a new Script whose body matches the file contents | `[x]` |
| UT-008 | `importFromURL(_:)` throws `ImportError.fileTooLarge` for a file over 10 MB | `[x]` |
| UT-009 | Script Codable round-trip: encode then decode produces identical struct | `[x]` |
| UT-009a | Production `ScriptStore` path resolution falls back to a non-crashing local directory when Application Support lookup is unavailable | `[x]` |

### CollectionStore (Task T-002)

| ID | Test | Status |
|---|---|---|
| UT-010 | `create(name:)` appends a new AiraCollection and persists it | `[x]` |
| UT-011 | `loadAll()` returns an empty array when no collections file exists | `[x]` |
| UT-012 | `rename(id:to:)` updates the name and persists | `[x]` |
| UT-013 | `delete(id:)` removes the collection but does not delete any script files | `[x]` |
| UT-014 | `addScript(_:toCollection:)` adds the scriptId and does not duplicate it on repeated calls | `[x]` |
| UT-015 | `removeScript(_:fromCollection:)` removes the scriptId from the collection | `[x]` |
| UT-016 | AiraCollection Codable round-trip | `[x]` |
| UT-016a | Production `CollectionStore` path resolution falls back to a non-crashing local directory when Application Support lookup is unavailable | `[x]` |

### SettingsStore (Task T-003)

| ID | Test | Status |
|---|---|---|
| UT-017 | `load()` returns default AppSettings when UserDefaults has no stored value | `[x]` |
| UT-018 | `save(_:)` followed by `load()` returns the same AppSettings | `[x]` |
| UT-019 | AppSettings Codable round-trip | `[x]` |
| UT-019a | `textColor` mutation via `SettingsStore` persists across store re-initialization — REQ-023 | `[x]` |
| UT-019b | `pillsEnabled` and `maxPillCount` mutations persist across store re-initialization — REQ-044 | `[x]` |
| UT-019c | `AppSettings.maxPillCount` is normalized to the supported `1...2` range during init and decode — REQ-044 | `[x]` |

### App Updater (Tasks T-043a, T-043b, T-043c)

| ID | Test | Status |
|---|---|---|
| UT-019d | `AppUpdaterConfiguration` reports configured only when both a valid `SUFeedURL` and a non-empty `SUPublicEDKey` are present | `[w]` |
| UT-019e | Sparkle sandbox wiring is present: app sandbox entitlement, network/audio entitlements, Sparkle mach-lookup exceptions, and `SUEnableInstallerLauncherService` in `Info.plist` | `[w]` |
| UT-019f | `AppUpdatePromptContent.updateFound(version:)` and `.readyToInstall(version:)` produce the branded copy and action labels expected by the custom updater popup | `[w]` |

### VoiceSyncEngine (Tasks T-034, T-035, T-036, T-037)

| ID | Test | Status |
|---|---|---|
| UT-020 | `tokenize(_:)` strips punctuation, lowercases, and splits on whitespace correctly | `[x]` |
| UT-021 | `tokenize(_:)` handles empty string and returns empty array | `[x]` |
| UT-022 | Exact match: given a 6-word transcription window matching the script at position N, cursor advances to N | `[x]` |
| UT-023 | Fuzzy match: a 5-word window with one mismatch still advances the cursor to the best overlap position | `[x]` |
| UT-024 | Cursor only moves forward: a match found earlier in the script than the current cursor does not move the cursor backward | `[x]` |
| UT-025 | No match: cursor remains at current position when no overlap is found | `[x]` |
| UT-026 | Scroll offset calculation: cursor at word N in a 100-word script produces an offset proportional to N/100 | `[x]` |

### Models (Tasks T-001, T-002, T-003)

| ID | Test | Status |
|---|---|---|
| UT-027 | ScriptMeta Codable round-trip | `[ ]` |
| UT-028 | OverlayAppearance Codable round-trip | `[ ]` |
| UT-029 | MoodPreset.day and MoodPreset.night produce valid OverlayAppearance values (no nil fields) | `[x]` |
| UT-030 | AppSettings default countdown + related settings values match the configured defaults | `[x]` |
| UT-030a | `AppSettings.autoScrollWPM` defaults to 135 and is clamped to the supported `100...300` range by the System-tab binding/helpers | `[x]` |

### CountdownView Logic (Task T-029)

| ID | Test | Status |
|---|---|---|
| UT-031 | Countdown fires exactly N callbacks over N seconds (mock clock) | `[x]` |
| UT-032 | Countdown emits session-start signal when it reaches zero | `[x]` |
| UT-033 | Countdown with duration 0 emits session-start signal immediately without firing any interval callbacks | `[x]` |

### Script Editor Cue Insertion (Task T-013)

| ID | Test | Status |
|---|---|---|
| UT-034 | Inserting a cue into empty text produces a single cue token and moves the cursor to the end of it | `[x]` |
| UT-035 | Inserting a cue at a mid-text cursor position inserts the token at that position and preserves surrounding words | `[x]` |
| UT-036 | Inserting a cue adjacent to existing whitespace does not add duplicate spaces | `[x]` |
| UT-036a | Cue annotation styling identifies inline cue tokens and applies distinct editor attributes so cues remain visually separate from prose | `[x]` |
| UT-036b | Script editor word counts treat newlines and tabs as separators so live editor metadata matches the library index for multiline scripts | `[x]` |

### Keyboard Shortcuts (Task T-025)

| ID | Test | Status |
|---|---|---|
| UT-037 | Formatting a command-shift letter shortcut produces the stored display string shown in Settings | `[x]` |
| UT-038 | Formatting a control-option special key shortcut preserves modifier order and special-key naming | `[x]` |
| UT-039 | Modifier-only key presses are rejected so the shortcut editor only stores complete shortcuts | `[x]` |
| UT-050 | Manual scroll line nudge math converts one rendered line into the expected normalized offset delta for a measured viewport | `[x]` |

### Collections UI Logic (Tasks T-014, T-015, T-016, T-017)

| ID | Test | Status |
|---|---|---|
| UT-040 | Collection names are trimmed before create/rename actions are submitted from the sidebar | `[x]` |
| UT-041 | Blank collection names are rejected by the sidebar logic | `[x]` |
| UT-042 | Deleting the currently selected collection falls back to `All Scripts` navigation | `[x]` |
| UT-043 | Filtering the Document Library by collection returns only scripts in that collection | `[x]` |
| UT-044 | Filtering by a missing collection returns an empty library list | `[x]` |
| UT-044a | `duplicateScript(id:)` syncs preserved collection memberships back into CollectionStore so collection-filtered views keep showing the copy | `[x]` |
| UT-044b | `deleteCollection(id:)` removes the deleted collection ID from persisted scripts so script files cannot retain orphaned memberships | `[x]` |
| UT-044c | `NotchOverlayGeometry.sideOverscan(for:)` remains `0` for physical notch widths, and the runtime cutout stays flush to the measured left/right notch walls | `[x]` |

---

## Integration Tests

### Session Lifecycle (Tasks T-033, T-034, T-039)

| ID | Test | Status |
|---|---|---|
| IT-001 | Cast to Notch: calling `OverlayWindowController.presentSession(script:appearance:countdownDuration:)` results in a visible NSPanel and VoiceSyncEngine in `.running` state after countdown | `[x]` |
| IT-002 | Session end: calling `OverlayWindowController.endSession()` stops VoiceSyncEngine, releases AVAudioEngine, and closes all panels | `[ ]` |
| IT-003 | Microphone released: after `endSession()`, AVAudioEngine is no longer running (isRunning == false) | `[ ]` |
| IT-016 | Voice-Sync off session: launching an overlay with a saved non-zero `autoScrollWPM` starts manual auto-scroll in the presented prompter instead of leaving the script stationary | `[ ]` |
| IT-017 | Session scroll shortcuts: configured up/down shortcuts nudge the active session scroll position regardless of which window has keyboard focus | `[ ]` |
| IT-018 | System-tab manual scroll speed control persists a changed WPM value through `AppState` and `SettingsStore` | `[x]` |
| IT-019 | Mouse wheel / trackpad scrolling on an active overlay updates the rendered script position without disabling Voice-Sync state | `[ ]` |
| IT-020 | Voice-Sync partial transcription updates advance the cursor in capped forward steps instead of jumping directly to the end of a long spoken window | `[ ]` |
| IT-029 | When `SUFeedURL` or `SUPublicEDKey` is missing, `AppUpdaterController` fails closed and `Check for Updates…` remains disabled | `[ ]` |
| IT-030 | When Sparkle reports an available update, Aira shows the custom update popup instead of Sparkle's stock update-found alert | `[ ]` |
| IT-031 | When Sparkle finishes downloading an update, Aira shows the custom `Install & Relaunch` popup instead of the stock ready-to-install alert | `[ ]` |

### Hover Pause (Task T-028)

| ID | Test | Status |
|---|---|---|
| IT-004 | Hover enter: scroll offset does not change while isHovered == true even when VoiceSyncEngine publishes new offsets | `[x]` |
| IT-005 | Hover exit: scroll resumes from the same offset that was active when hover began | `[x]` |

### Bulk Selection Logic (Task T-010a)

| ID | Test | Status |
|---|---|---|
| UT-045 | Selecting all scripts sets `selectedScriptIDs` to the full visible set | `[x]` |
| UT-046 | Deselecting one script after Select All leaves the rest selected and sets checkbox to mixed state | `[x]` |
| UT-047 | Shift+click from index A to index B selects the inclusive range A…B | `[x]` |
| UT-048 | Confirming bulk delete calls `AppState.deleteScript` for each selected ID and clears `selectedScriptIDs` | `[x]` |
| UT-049 | Cancelling the bulk delete confirmation leaves all scripts intact and selection unchanged | `[x]` |
| UT-053 | `AppState` tracks the current active-session script IDs and reports whether a script is locked for session editing | `[x]` |
| UT-054 | `AppState.deleteScript(id:)` rejects deletion while a presenter session is active | `[x]` |
| UT-055 | Library session rules hide bulk-selection/delete controls during an active session and block editing of scripts currently used by the session | `[x]` |

### New Script Lifecycle (Tasks T-004, T-012)

| ID | Test | Status |
|---|---|---|
| IT-012 | New draft dismissed with empty body and default title → ScriptStore index does not gain a new entry | `[x]` |
| IT-013 | New draft dismissed after body edited → script file created on disk and appears in ScriptStore index | `[x]` |
| IT-014 | New draft dismissed after only title changed (body still empty) → script file created on disk | `[x]` |
| IT-015 | Existing script dismissed without changes → no additional save call; lastEdited timestamp unchanged | `[x]` |

### Script Persistence (Tasks T-001, T-011)

| ID | Test | Status |
|---|---|---|
| IT-006 | Save script → re-init ScriptStore → load(id:) returns the same script body and title | `[x]` |
| IT-007 | Delete script → re-init ScriptStore → loadIndex() does not contain the deleted script's id | `[x]` |

`AppStateTests.saveScriptPersistsChangesAndRefreshesIndex()` also verifies the `lastEdited` timestamp advances when a script is saved, covering the `T-011` save contract in addition to persistence.

`AppStateTests.makeDraftScriptDoesNotPersistOnCreation()`, `saveDraftScriptPersistsOnFirstSave()`, and `saveDraftScriptInCollectionPersistsMembershipAndRefreshesCollections()` cover the in-memory draft and first-save persistence path for `T-004`. `ScriptEditorSessionLogicTests` covers the back-dismiss policy for empty drafts, edited drafts, retitled drafts, and unchanged existing scripts.

`AppStateTests.createCollectionPersistsAndRefreshesState()`, `renameCollectionPersistsAndRefreshesState()`, and `deleteCollectionRemovesItFromStateAndStorage()` cover the AppState/store wiring used by `T-014`, `T-015`, and `T-016`.

`AppStateTests.settingsMutationsPersistThroughSettingsStore()` also covers `T-025` by verifying all shortcut fields persist through `AppState` into `SettingsStore`.

### Stealth Flag (Task T-027)

| ID | Test | Status |
|---|---|---|
| IT-008 | NSPanel created by NotchWindowController has sharingType == .none before presentSession returns | `[ ]` |
| IT-009 | AppState.stealthWarning is set to true if sharingType cannot be confirmed (simulated by checking flag after creation) | `[ ]` |

### Import Flow (Tasks T-009, T-010)

| ID | Test | Status |
|---|---|---|
| IT-010 | Drop a .txt file onto DocumentLibraryView → AppState.scripts contains a new entry with matching title | `[x]` |
| IT-011 | Import creates a new script file on disk independently; original file is not modified | `[x]` |

---

## Manual / Exploratory Tests

These are verified by a human tester and noted in this file when confirmed. They cannot be automated.

| ID | Test | Status |
|---|---|---|
| MT-001 | Overlay is invisible in Zoom screen share on macOS 14+ | `[ ]` |
| MT-002 | Overlay is invisible in Microsoft Teams screen share on macOS 14+ | `[ ]` |
| MT-003 | Notch window is correctly positioned on MacBook Pro 14" notch | `[ ]` |
| MT-004 | Notch window is correctly positioned on MacBook Pro 16" notch | `[ ]` |
| MT-043 | Runtime notch overlay sits flush against the physical notch with no visible hairline gap at the two lower inner curves | `[ ]` |
| MT-044 | Runtime notch overlay also sits flush against the vertical inner notch edges with no visible side seams, with live side overscan still clamped to `0.0` | `[ ]` |
| MT-045 | Appearance tab preview chips keep Light Paper light and Dark Studio dark in both app themes | `[ ]` |
| MT-046 | System tab manual-scroll copy refers to Manual mode / Voice-Sync-off behavior, and the Speech Sensitivity field label matches the surrounding Crimson Text control styling | `[ ]` |
| MT-047 | Overlay audio beam uses the shared primary color token and no overlay-local `Color(hex:)` helper remains in the Phase 6 window stack | `[ ]` |
| MT-005 | Pill window is freely movable to a second display | `[ ]` |
| MT-006 | App bundle size is under 10 MB after Archive build | `[ ]` |
| MT-007 | No outbound telemetry or unrelated network requests during launch → cast → session → quit; only Sparkle appcast/update HTTPS traffic is permitted in direct-distribution builds | `[ ]` |
| MT-008 | Notarized .dmg passes `spctl --assess --verbose` without warnings | `[ ]` |
| MT-009 | Voice-Sync scroll tracks spoken words in real time with < 1 second lag | `[ ]` |
| MT-010 | Script scroll pauses immediately when user stops speaking | `[ ]` |
| MT-011 | Settings modal matches the mockup chrome: cream Preferences strip, sage active tab in light and dark mode, and small square Light/Dark preview swatches | `[ ]` |
| MT-012 | Manager UI audit sweep: button chrome, script editor, document library controls, and sidebar badges use the shared audited color tokens consistently in light and dark mode | `[ ]` |
| MT-013 | Settings modal top chrome uses themed surface color in both light and dark mode, App Theme swatches are centered, and System-tab control labels/body copy use Crimson Text while section headings stay Indie Flower | `[ ]` |
| MT-014 | Dark-mode visual regression check: selected Preferences tab text stays white, top chrome uses `#484C49`, Light Paper preview stays cream, notch preview uses `#434343`, dark script cards use `#3A3A3A`, and Cast to Notch keeps light text/icon color | `[ ]` |
| MT-015 | Sidebar New Script action stays pure white, script-card Cast button text/icon matches Edit button text color, and the script-card double-border gap matches the updated mockup spacing | `[ ]` |
| MT-016 | Pill Windows toggle matches the Voice Tracking switch size and sage tint, and the Sidebar Scripts nav icon is a document-with-scribble icon while New Script remains a plus icon | `[ ]` |
| MT-017 | Voice Tracking enable row uses the same plain System panel styling as adjacent controls, without a separate highlighted background container | `[ ]` |
| MT-018 | During Voice-Sync, the scroll progression no longer skips ahead by large blocks of unseen script, and the overlay does not visibly emphasize the currently spoken word | `[ ]` |
| MT-019 | Entering selection mode from Select All does not visually shift existing script cards or the selection bar; card actions simply disappear and the trash button appears without layout jitter | `[ ]` |
| MT-020 | Keyboard shortcut rows in Settings > System no longer use a separate highlighted/cream background and match the surrounding panel styling | `[ ]` |
| MT-021 | The Notch Window keeps active text below the notch cutout, unread lines rise upward from lower in the overlay like a teleprompter, and the live voice indicator appears as corner sound waves outside the script text area | `[ ]` |
| MT-022 | Overlay text shows a downward start marker above the opening line, ignores stray single-line breaks from the editor by flowing paragraphs cleanly, and does not visibly emphasize the currently spoken word | `[ ]` |
| MT-023 | During the countdown, the overlay shows only the countdown treatment with no script text visible behind it; the script appears only after the countdown finishes | `[ ]` |
| MT-024 | Manual scroll starts at the beginning of a fresh session, gets visibly faster as WPM increases, does not snap back toward the middle after manual repositioning, remains smooth under timer, keyboard, and wheel input, and shows a clear speed difference between low and high presets such as `100 WPM` and `260 WPM` | `[ ]` |
| MT-025 | Manual scroll remains visually smooth on the display refresh cadence with no micro-stutter from timer-style cadence mismatch during long runs at both low and high WPM | `[ ]` |
| MT-026 | Keyboard nudges, wheel scrolling, and WPM auto-scroll no longer fight each other or snap the script back after a fresh session launch, and repeated line nudges do not get overridden by any mirrored offset channel | `[ ]` |
| MT-027 | The pause keyboard shortcut pauses and resumes the active scrolling mode itself, including manual WPM scroll and voice-driven scroll, without needing to end the session | `[ ]` |
| MT-028 | In Sync mode, the notch and every synced pill scroll and pause together; only Manual pills can diverge to a different script or offset | `[ ]` |
| MT-029 | In Sync mode with one or more pills open, manual WPM scroll remains as fast and as smooth as notch-only operation, with the notch acting as the primary driver and synced pills showing the same content position through their own local window pacing rather than inheriting a slower shared rendered offset | `[ ]` |
| MT-030 | In Sync mode, the primary notch window keeps the same smooth configured WPM pacing it has by itself and does not become jittery from re-projecting shared progress back into its own rendered offset | `[ ]` |
| MT-031 | Administrative FAQ-style scripts containing repeated `Q)` markers, contact email addresses, and similar non-spoken metadata do not distort notch pacing, content-progress projection, or speech matching | `[ ]` |
| MT-032 | Scripts with sparse vertical layout such as FAQ sections, headings, and frequent paragraph breaks still move at the configured manual WPM without visually slow or jittery regions in the notch overlay | `[ ]` |
| MT-033 | Shared playhead refactor regression: manual scroll still works in notch-only, sync notch+pills, and manual pill-only sessions after playhead coordinator introduction | `[ ]` |
| MT-034 | In Sync mode, differently sized windows show the same content progress while moving at different pixel speeds appropriate to their own geometry | `[ ]` |
| MT-035 | Pause/resume operates on the shared session playhead, so all Sync overlays pause and resume together while Manual pills remain unaffected | `[ ]` |
| MT-036 | Long scripts and short scripts presented in the notch at the same configured WPM have consistent perceived manual scroll speed instead of long documents visually crawling | `[ ]` |
| MT-037 | Manual `Sync` sessions no longer exhibit visible lag from the legacy line-index sync path, while voice-driven sync still behaves correctly until the voice refactor lands | `[ ]` |
| MT-038 | Increasing total document length without materially changing local line density does not reduce the perceived manual scroll speed at the same configured WPM | `[ ]` |
| MT-039 | Long scripts do not introduce visible overlay lag or jitter from per-frame text rebuild cost while manual scrolling is active | `[ ]` |
| MT-040 | Script Editor cue panel uses shared theme tokens for its sage background and cream foreground so it stays visually consistent across theme audits | `[ ]` |
| MT-041 | Collections sidebar warning uses the shared warm token instead of an inline hex color, and collections navigation still behaves correctly after the manager window accessor main-actor cleanup | `[ ]` |
| MT-042 | Settings chunk-1 audit: tabs read `Appearance`, `The Notch`, and `System`; Light Paper/Dark Studio swatches use shared theme tokens; and Pill Windows still behaves correctly after `maxPillCount` normalization | `[ ]` |
| MT-048 | `Check for Updates…` is enabled only when the built app bundle resolves a valid Sparkle feed URL and public key | `[ ]` |
| MT-049 | The branded update prompt appears for both `update found` and `ready to install` states, and `Cancel` cleanly dismisses without starting installation | `[ ]` |
| MT-050 | A tagged release publishes DMG, ZIP, and `appcast.xml`, and an installed build successfully discovers the update from `https://raw.githubusercontent.com/sankirthk/aira-releases/main/appcast.xml` | `[ ]` |
| MT-051 | Main-repo CI runs Swift formatting checks, lint-style checks, `xcodebuild build`, and `xcodebuild test` on pull requests and pushes to `main` | `[ ]` |
| MT-052 | Installed pre-commit hook blocks a commit when formatting, linting, build, or tests fail, and allows the commit when the full local validation path passes | `[ ]` |

### Planned Refactor Coverage (Tasks T-025z ... T-025ag)

| ID | Test | Status |
|---|---|---|
| IT-021 | Session playhead coordinator clamps normalized progress to `0...1` and preserves pause state across repeated start/stop transitions | `[x]` |
| IT-022 | Manual WPM input updates shared playhead velocity without directly mutating view-local rendered offsets | `[ ]` |
| IT-023 | Wheel and keyboard nudges both modify the same playhead state path instead of separate local offset channels | `[ ]` |
| IT-024 | Sync overlay projection maps shared playhead progress into different local offsets for notch and pill windows with different viewport sizes | `[ ]` |
| IT-025 | Unified Voice mode updates bounded playhead target progress without directly writing rendered offset state from `VoiceSyncEngine` | `[ ]` |
| IT-026 | Voice mode advances the same playhead used by manual scroll and moves only when recognized human speech is active, not on raw audio-level noise alone | `[ ]` |
| IT-027 | Primary manual playhead velocity is derived from measured rendered text density (`pointsPerWord`, `scrollableRange`, `autoScrollWPM`) rather than a naive `1 / totalSeconds` normalized step, so document length alone does not reduce physical scroll pace | `[x]` |
| IT-028 | Long-script manual sessions cache rendered overlay text instead of rebuilding the entire presentation during per-frame scroll updates | `[ ]` |
