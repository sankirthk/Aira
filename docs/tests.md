# Aira — Test Plan

## How To Use This File

Each test maps to a task in `todo.md` and one or more REQs in `requirements.md`. Tests are written **before** the implementation of their corresponding task. A task is not done until its tests are written and passing.

Test status:
- `[ ]` — not yet written
- `[w]` — written, not yet passing
- `[x]` — written and passing

Tests live in the `AiraTests` target in Xcode (XCTest).

Repository automation is tracked here when it materially gates shipping quality. CI checks are not a substitute for the app's unit/integration/manual coverage, but they do enforce formatting, linting, and test execution on shared branches.

### Repository Automation

| ID | Test | Status |
|---|---|---|
| CI-001 | GitHub Actions `ci.yml` runs direct `Aira` build/test and App Store variant build without requiring local signing identities on hosted macOS runners | `[x]` |

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
| UT-019b | `maxPillCount` mutations persist across store re-initialization and continue driving Pill Window launch count after store re-initialization — REQ-044 | `[x]` |
| UT-019b-b | Per-slot Pill Window appearance/readability overrides resolve to shared Notch defaults when unset and persist independently once customized — REQ-044 | `[x]` |
| UT-019b-c | Pill Window settings slot editing writes overrides only for the selected slot and preserves inherited fallback for untouched slots — REQ-044 | `[x]` |
| UT-019c | `AppSettings.maxPillCount` is normalized to the supported `1...2` range during init and decode — REQ-044 | `[x]` |
| UT-019b-a | Legacy persisted Pill Window enable/content-assignment fields are ignored on decode and stripped on the next save so Settings keeps count plus appearance/readability defaults only — REQ-044 | `[x]` |
| UT-019k | `AppState.settings.autoScrollWPM` mutations normalize in memory before persistence so the live value and reloaded store value remain identical — REQ-023 | `[x]` |
| UT-019l | `MenuBarStatusItemController` status item uses template rendering so macOS can switch between black and white automatically — REQ-021 | `[x]` |
| UT-019m | Menu bar quick-access popover dismisses only for outside interactions, not clicks inside the popover or on the status-item button itself — REQ-021 | `[x]` |
| UT-019n | Menu bar quick-access uses status-bar-level, all-Spaces popover behavior and launches the selected radio-row script from the primary Notch / Notch + Pills buttons — REQ-014, REQ-021 | `[x]` |
| UT-019o | Menu bar quick-access derives presenter voice-motion enablement from `voiceScrollMode`, matching Manager launch behavior instead of using the stale legacy voice-sync toggle — REQ-014, REQ-039 | `[x]` |

### App Updater (Tasks T-043a, T-043b, T-043c, T-043d, T-043e)

| ID | Test | Status |
|---|---|---|
| UT-019d | `AppUpdaterConfiguration` reports configured only when both a valid `SUFeedURL` and a non-empty `SUPublicEDKey` are present | `[x]` |
| UT-019e | Sparkle sandbox wiring is present: app sandbox entitlement, network/audio entitlements, Sparkle mach-lookup exceptions, and `SUEnableInstallerLauncherService` in `Info.plist` | `[x]` |
| UT-019f | `AppUpdatePromptContent.updateFound(version:)` and `.readyToInstall(version:)` produce the branded copy and action labels expected by the custom updater popup | `[w]` |
| UT-019i | App Store entitlements omit Sparkle mach-lookup exceptions and App Store plist/build inputs omit Sparkle `SU*` configuration keys | `[x]` |
| UT-019j | App updater factory returns Sparkle-backed behavior for direct builds and no-op behavior for App Store builds | `[x]` |
| UT-019g | `OverlayStealthConfiguration` maps the persisted screen-share exclusion preference to the expected window `sharingType` and stealth-warning behavior | `[x]` |
| UT-019h | `screenCaptureExclusionEnabled` persists across `SettingsStore` save/load and `AppState` mutations | `[x]` |

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
| UT-026b | `VoiceSyncEngine.inputTapBufferSize` stays at 128 frames so recognition/highlight updates use lower microphone capture latency without touching scroll math | `[x]` |
| UT-026c | Classic/highlight-only visual updates publish a prefix dulling range for already spoken words while keeping current spoken word separate for underline-only emphasis | `[x]` |
| UT-026d | Click-to-reseed keeps scroll offset unchanged while resetting spoken-word visual/search cursors to the clicked overlay word | `[x]` |
| UT-026e | `CinematicScrollController.stop()` halts further scroll tick callbacks so replaced undocked/fullscreen notch views cannot keep mutating shared playhead state in background | `[x]` |
| UT-026f | `OverlayWindowController.endSession()` resets shared voice/playhead state so a later classic/manual session cannot inherit prior voice-session scroll or highlight state | `[x]` |
| UT-026g | Active overlay controllers accept live updates for voice-driven scroll and pause-on-hover flags so session behavior can switch cleanly without relaunching the app | `[x]` |
| UT-026h | Voice-Sync recognition preprocessing selects the strongest captured input channel instead of always using channel 0 when creating the speech-recognition buffer | `[ ]` |
| UT-026i | Voice-Sync recognition preprocessing applies bounded gain normalization to quiet speech buffers before appending them to speech recognition, while preserving frame count and mono float format | `[ ]` |
| UT-026j | Audio-level metering uses the strongest captured channel instead of always channel 0, so call-route voice arcs react to normal speaking volume when the dominant speech channel is not the first channel | `[x]` |
| UT-026k | Audio-level metering applies bounded gain normalization for quiet speech so call-route voice arcs respond at normal volume without clipping direct-mic sessions to full scale | `[ ]` |
| UT-026l | Voice-Sync accepts early single-word partials during startup highlighting so the first spoken-word visual feedback does not wait for a long/high-confidence suffix window | `[x]` |
| UT-026m | Voice-Sync search/look-ahead window expands enough to let spoken-word highlighting catch up at higher `pt/s` overlay speeds instead of lagging behind the visible reading position | `[x]` |
| UT-026n | Current spoken-word startup styling keeps the overlay text color and uses a stronger underline so the first highlighted word stays visible without introducing background/theme contrast problems | `[x]` |
| UT-026o | Session scroll keyboard nudges are consumed only by synchronized primary overlays; Manual Pill Windows ignore the shared shortcut event and follow only their own local scroll state | `[x]` |
| UT-026p | Voice-Sync highlight matching keeps single-word / visual catch-up searches within a bounded forward window so repeated/common words do not jump the highlight to unrelated later script positions | `[x]` |
| UT-026q | Voice-Sync uses staged startup/steady/catch-up matcher plans so initial highlighting and high `pt/s` recovery widen only when anchored, while low-overlap matches still reject implausible forward jumps | `[x]` |
| UT-026r | Voice-Sync startup mode accepts the first low-overlap spoken-word highlight inside its startup window, then immediately tightens back to steady/catch-up plausibility rules after the first lock | `[x]` |
| UT-026s | Voice-Sync startup seeding uses the earliest plausible token from the first multi-word recognition partial so initial highlighting does not jump straight to the last word of that first chunk | `[x]` |
| UT-026t | Voice-Sync startup search anchoring keeps the unconfirmed search window rooted at the visible word range instead of the forward-shifted cursor so early partials can match the first spoken words before steady/catch-up tightening resumes | `[x]` |
| UT-026u | Manual seek never synthesizes a replacement active underline from the visible window while Voice-Sync is active | `[ ]` |
| UT-026v | Overlay dulling follows the original worktree-start `visualHighlightedWordRange` delta renderer rather than the later committed-prefix path, so prior spoken words render correctly again after the rollback | `[x]` |
| UT-026w | Advancing the current spoken-word underline does not remove the dull foreground color from words that just moved into the spoken prefix | `[x]` |
| UT-026x | Established Voice-Sync matching searches forward from the engine cursor even when the visible word window has advanced past that cursor | `[x]` |
| UT-027 | `SpeechRecognitionBackend` can be faked so `VoiceSyncEngine` matching and mode behavior are tested without loading WhisperKit/Core ML | `[x]` |
| UT-027a | A recognized word token advances the spoken cursor only to the next localized script match and never backwards to a repeated earlier word | `[x]` |
| UT-027b | Classic scroll mode updates spoken-word highlighting without mutating `VoiceSyncEngine.scrollOffset` | `[x]` |
| UT-027c | Word-tracking mode maps the matched current word index to bounded scroll progress | `[x]` |
| UT-027d | Voice-Sync teardown stops the recognition backend and rejects stale spoken-word callbacks | `[x]` |
| UT-027e | Sound-based mode does not scroll from recognized words; volume-driven motion remains owned by the audio monitor/cinematic driver | `[x]` |
| UT-027f | Voice scroll modes expose Settings menu labels/descriptions for Classic, Sound-based, and Word tracking so the persisted modes are user-selectable | `[x]` |
| UT-027g | Voice scroll mode policy separates manual scrolling, volume-based motion, speech-recognition word tracking, and optional spoken-word highlighting microphone use | `[x]` |
| UT-027h | Bundled Whisper model resources include tokenizer files required for fully offline word recognition | `[x]` |
| UT-027i | Voice recognition preprocessing converts native 48 kHz microphone buffers to 16 kHz mono samples before feeding WhisperKit | `[x]` |
| UT-027j | Word-tracking ignores low-confidence Whisper hallucinations and duplicate overlap tokens instead of jumping to repeated single words far ahead | `[x]` |
| UT-027k | Voice recognition preprocessing drops sub-threshold environmental noise before applying gain normalization for WhisperKit | `[x]` |
| UT-027l | Word-tracking widens its forward recovery window after consecutive plausible missed tokens without lowering the normal confidence threshold | `[x]` |
| UT-027m | Word-tracking recovery does not use far repeated filler words as widened single-token anchors | `[x]` |
| UT-027n | Whisper backend uses phrase-length transcription chunks, overlapping context, bounded emitted-word cache, and bundled base.en preference with tiny.en fallback | `[x]` |
| UT-027o | Bundled Whisper resources include both preferred `base.en` and fallback `tiny.en` models with offline tokenizer files | `[x]` |
| UT-027p | Word-tracking fallback scroll progress uses bounded optical lookahead so the current spoken word is carried into the readable area instead of hugging the bottom edge | `[x]` |
| UT-027q | Exact word-tracking scroll progress advances to the next speakable rendered line when the spoken word is the last word on its line | `[x]` |
| MT-049f | Voice-Sync startup diagnostics show exact ordering and timing for first recognition partial, startup seed, first strict match, and first published highlight during one live session | `[ ]` |
| MT-049g | Voice-Sync startup search-window diagnostics show first-partial cursor state, visible range, normalized search range, and startup-seed misses during one live session | `[ ]` |

### Models (Tasks T-001, T-002, T-003)

| ID | Test | Status |
|---|---|---|
| UT-027 | ScriptMeta Codable round-trip | `[ ]` |
| UT-028 | OverlayAppearance Codable round-trip, including alignment, spacing, shadow, and padding defaults | `[w]` |
| UT-030 | AppSettings default countdown + related settings values match the configured defaults | `[x]` |
| UT-030a | `AppSettings.autoScrollWPM` defaults to 50 and is clamped to the supported `10...100` range by the System-tab binding/helpers | `[x]` |
| UT-030b | `PrompterScrollMath.lineHeight(fontSize:lineSpacing:)` reflects the configured overlay line spacing and stays positive | `[x]` |
| UT-030c | Overlay readability settings persist through `SettingsStore` save/load and `AppState` mutations, including justified alignment, tracking, word spacing, text shadow, and padding | `[w]` |
| UT-030d | Overlay text measurement uses the same TextKit layout path as the AppKit renderer, and readability spacing changes still yield a positive multi-line scrollable height instead of collapsing the prompter range | `[x]` |
| UT-030e | Manual auto-scroll velocity derives from fixed configured points-per-second instead of document size, so short and long scripts move at the same physical speed | `[x]` |
| UT-030f | Overlay appearance previews derive width, alignment, padding, and line spacing from the same layout snapshot inputs as live overlay rendering so justified alignment and readability spacing are visible in preview state | `[w]` |
| UT-030m | Overlay spoken-word highlight updates use temporary TextKit display attributes and do not alter intrinsic height when only the current spoken token changes | `[x]` |
| UT-030n | Expanding the spoken-word dull prefix across repeated temporary-attribute updates does not alter intrinsic height, covering the incremental prefix-update path used during live classic/voice highlighting | `[x]` |
| UT-030o | Exact word-tracking scroll progress places line-end and final-paragraph targets in the upper reading band instead of leaving only the lower half of the sentence visible | `[x]` |
| UT-030ad | Audio level monitoring uses speech-focused activation thresholds, and reseeding/highlighting updates the same current-word cursor used by Whisper word tracking | `[x]` |
| UT-030ae | Voice-sync startup uses the plain capture input path without enabling platform voice-processing DSP, avoiding repeated downlink timestamp faults while keeping software audio thresholds active | `[x]` |
| UT-030af | Whisper recognition keeps a 3-second sliding context window but triggers inference every 0.5 seconds of new 16 kHz audio, with bounded emitted-token deduplication across overlapping windows | `[x]` |
| UT-030ag | Whisper word tracking keeps single-token matches local, allows deep jumps only after a three-word spoken phrase, and clears spoken context when the user manually reseeds by clicking a word | `[x]` |
| UT-030ah | Whisper word tracking rejects deep jumps for repeated low-information stop-word phrases while preserving meaningful phrase recovery | `[x]` |
| UT-030ai | Voice recognition source policy routes Classic and Sound-based spoken-word highlighting through Apple's speech backend, and Word Tracking through WhisperKit only | `[x]` |
| UT-030aj | Spoken-word highlighting and word tracking use sequential cursor-only matching so speech cannot jump the highlight to repeated words ahead; manual click/reseed remains the jump path | `[x]` |
| UT-030ak | User pause/mic control stops active recognition capture and restarts it on resume without clearing script/highlight state | `[x]` |
| UT-030al | Passive non-consuming session keyboard shortcuts use a listen-only event tap so Escape can still reach macOS fullscreen while ending the presenter session | `[x]` |
| UT-030am | Manager window session transition preserves fullscreen manager windows and avoids style-mask repair/stripping during hide/restore | `[x]` |
| UT-030an | Spoken-word highlight matching accepts content words up to two positions ahead while keeping stop-word jumps constrained to one position | `[x]` |
| UT-030ao | Word-tracking recovery accepts 2+ word clean phrases inside the visible forward window, rejects phrase matches beyond that window, and clamps scroll to monotonic forward progress | `[x]` |
| UT-030ap | Word-tracking physical playhead progress blocks backward correction after line-end overshoot while permitting explicit backward reseed | `[x]` |
| UT-030aq | Sound-based passive scroll offset updates preserve the Apple speech highlight cursor and existing dull-prefix state, so volume-driven motion cannot starve spoken-word highlighting | `[x]` |
| UT-030ar | Spoken-word highlight rendering is scoped to the shared voice engine's active script ID, so synced pill windows with a different script after a notch/manual-pill swap do not render stale index-based highlights | `[x]` |
| UT-030n-a | Overlay spoken-word dull-prefix updates only emit the changed tail when the visible range moves forward, backward, or shifts after a reseed | `[x]` |
| UT-030n-b | Spoken-word dulling stays monotonic when the incoming visible highlight window jumps forward or shrinks during manual navigation | `[x]` |
| UT-030n-c | Current-word underline attributes stay separate from committed spoken-history dulling so manual navigation does not clear the active marker | `[x]` |
| UT-030o | Prompter spoken-word visuals clamp dull-prefix/current-word rendering to the visible word window so off-screen spoken ranges cannot expand overlay redraw scope | `[x]` |
| UT-030o | Duplicate overlay scroll-wheel deliveries with the same timestamp/delta/phase collapse to one signature so local/global/direct monitor overlap cannot triple-apply a single manual scroll gesture | `[x]` |
| UT-030p | Overlay scroll monitor routing ignores global wheel-monitor delivery while app is active, but still accepts local delivery when app is active and global delivery when app is inactive | `[x]` |
| UT-030q | Overlay wheel input remains enabled for both notch and manual-pill overlays, while notch classic/highlight-only sessions still use strict source routing to avoid duplicate monitor delivery | `[x]` |
| UT-030r | Manual pill mode suppresses spoken-word highlighting even when shared highlight setting is on | `[x]` |
| UT-030s | Manual pill mode keeps overlay wheel input enabled independently from notch-only highlight guards and hover-pause preference changes | `[x]` |
| UT-030t | Sync pills in classic/manual presenter mode show sync badge and suppress voice waveform lane, while true voice-sync pills keep voice chrome | `[x]` |
| UT-030u | Hover-pause state activates only when both pointer is inside overlay and the setting is enabled, so disabling `Pause on mouse hover` cannot disable manual wheel input on Manual-mode pills | `[x]` |
| UT-030v | Pill windows ignore the hover-pause setting entirely, so floating pill interactions stay live while notch hover-pause remains unchanged | `[x]` |
| UT-030x | Shared pause semantics stop only automatic motion: synced overlays publish paused state to the shared playhead, while manual pills ignore notch pause state and keep manual wheel behavior independent | `[w]` |
| UT-030y | Overlay panels own wheel capture directly so notch and pill windows still deliver direct/local/global wheel input even when the SwiftUI-hosted interceptor view is not the active responder | `[w]` |
| UT-030z | Overlay panel monitoring installs once per effective configuration and raw panel `sendEvent(_:)` observation can confirm whether AppKit routes scroll-wheel events to the overlay before monitor/dedupe logic runs | `[w]` |
| UT-030aa | Shared session-start restore state survives overlay view rebuilds, so closing a pill cannot make the remaining notch overlay restart from the top just because voice sync is idle during manual/classic sessions | `[x]` |
| UT-030ab | Notch and pill window controllers reuse their existing `NSHostingView` during content refreshes, so chrome/script updates do not replace the panel `contentView` and unnecessarily tear down the live overlay view hierarchy | `[ ]` |
| UT-030ac | Repeated overlay layout requests with the same normalized script body, width, and appearance reuse a cached `OverlayTextLayoutSnapshot` result so notch+pill launch does not redo identical initial TextKit layout work | `[x]` |
| UT-030w | Overlay wheel dedupe drops only cross-source duplicate deliveries and keeps repeated same-source wheel steps live even when AppKit reuses wheel identity fields | `[x]` |
| UT-030h | Overlay appearance popover preview stays clipped inside its rounded strip even when preview copy or readability settings produce taller text | `[ ]` |
| UT-030i | `AppSettings.pauseOnHoverEnabled` defaults to `true` and persists through store load/save plus `AppState` mutations | `[x]` |
| UT-030j | Settings > The Notch default preview copy fits within the default notch preview bounds instead of overlapping the notch cutout | `[x]` |
| UT-030k | Settings > The Notch preview auto-expands from saved notch dimensions when readability settings need more room, and the sample still fits within the resolved preview bounds | `[x]` |
| UT-030l | Settings reset buttons and custom color swatches use the full visible hit target instead of text-only or center-only interaction regions | `[x]` |
| UT-030l-a | Settings custom color swatches use a full-tile AppKit panel-opening control rather than an inner color-well hit region, so clicking anywhere in the tile opens the system color picker | `[w]` |
| UT-030g | `NotchWidthConfiguration.defaultWidth` stays at the intended narrower default and `NotchWindowController` uses persisted width/height values instead of falling back to the old hardcoded launch width | `[w]` |
| UT-030t | Manual pill windows keep overlay wheel deduplication enabled so direct/local/global overlay delivery still collapses duplicates instead of bypassing the shared working wheel path | `[x]` |

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
| UT-044d | `NotchOverlayGeometry` keeps side overscan at `0` while applying only a sub-point inward seam compensation on the rendered cutout walls | `[x]` |
| UT-044e | Runtime notch overlay keeps a flat top edge outside the notch cutout while preserving the rounded cutout corners and flat fallback geometry | `[x]` |
| UT-044f | Even-width notch panels use side-specific seam compensation so the left cutout wall does not leave a raster gap while side overscan stays `0` | `[x]` |
| UT-044g | Collection-move logic adds a dropped/selected collection ID without removing existing memberships or duplicating an existing membership | `[x]` |
| UT-044h | Drag payload parsing accepts a valid script UUID string and rejects invalid payloads before sidebar collection-drop handling runs | `[x]` |

---

## Integration Tests

### Session Lifecycle (Tasks T-033, T-034, T-039)

| ID | Test | Status |
|---|---|---|
| IT-001 | Cast to Notch: calling `OverlayWindowController.presentSession(script:appearance:countdownDuration:)` results in a visible NSPanel and VoiceSyncEngine in `.running` state after countdown | `[x]` |
| IT-001a | `Cast to Notch` launches notch only and does not create any Pill Windows even when Preferences `Pill Window count` is 1 or 2 | `[ ]` |
| IT-001a-a | `Cast to Notch` rejects scripts whose body has zero non-whitespace characters and leaves the manager visible instead of starting a presenter session | `[x]` |
| UT-001a-b | Empty-script launch errors use Aira-branded message popup copy instead of generic macOS alert content | `[x]` |
| UT-001a-c | Notch/Pill Window launch planning skips any mirror or manual script whose resolved body has zero non-whitespace characters | `[x]` |
| UT-001a-d | Session launch tracing records monotonic marks for manager preparation, overlay ordering, and deferred voice startup without depending on AppKit windows | `[x]` |
| UT-001a-e | Zero-countdown sessions schedule Voice-Sync startup after the first overlay render turn instead of starting audio/speech synchronously during first `onAppear` | `[x]` |
| IT-001a-b | Presenter launch sequencing follow-up is deferred because the cold-launch stall is not reproducible in the current build; reopen if the manager-to-overlay handoff stalls again | `[x]` |
| IT-001b | Chevron dropdown `Cast with Pill Windows` opens one panel for enabled Pill Windows, and Pill Windows set to `Mirror current script` launch against current editor script/shared playhead | `[x]` |
| UT-001b-a | Pill Window launch panel maps `Mirror current script` to a synced Pill Window mode and `Manual` with a selected script to an independent manual Pill Window mode | `[x]` |
| UT-001b-b | Pill Window launch panel manual script dropdown displays `Select script` before assignment and the chosen script title after assignment | `[x]` |
| UT-001b-c | Pill Window launch panel manual script dropdown rows are specified as full-width pointing-hand targets | `[x]` |
| UT-001b-d | Pill Window launch panel Mirror/Manual choice buttons are specified as full-width pointing-hand targets | `[x]` |
| UT-001b-e | Pill Window launch panel blocks the editor's I-beam cursor ownership while visible, so hover-tracked pointing-hand targets on Mirror/Manual buttons and the Manual script dropdown can win consistently | `[x]` |
| UT-001b-f | Two-Pill Window launch preserves independent per-slot `Mirror current script` / `Manual` choices in slot order, and the launch policy resolves them into matching mixed-mode launch plans | `[x]` |
| UT-001b-g | Pill Window launch request skips Manual sections whose selected script is missing or has zero words, while keeping valid Mirror/Manual sections in slot order | `[x]` |
| UT-001b-h | Pill Window launch panel shows inline skipped-Pill Window feedback when one or more requested sections do not have a valid launchable script | `[x]` |
| UT-001b-i | Overlay launch APIs model notch-only, mirrored-Pill Window, and assigned-Pill Window intent explicitly instead of overloading one shared `satelliteSelections` argument | `[x]` |
| IT-001b-a | If a Pill Window slot has no custom appearance/readability config, mirrored Pill Window initially uses Notch defaults instead of requiring separate Pill Window setup | `[ ]` |
| IT-001c | `Cast with Pill Windows` presents one per-Pill Window launch panel before launch and launches each `Manual` Pill Window with its explicitly assigned script | `[ ]` |
| IT-001d | When one of two Pill Window assignment slots is left empty, launch proceeds for valid targets only and shows lightweight feedback describing skipped Pill Window count | `[ ]` |
| IT-002 | Session end: calling `OverlayWindowController.endSession()` stops VoiceSyncEngine, releases AVAudioEngine, and closes all panels | `[ ]` |
| IT-003 | Microphone released: after `endSession()`, AVAudioEngine is no longer running (isRunning == false) | `[ ]` |
| IT-003a | Voice-Sync still receives microphone input and advances the shared playhead while the user is on an active call/meeting app using the microphone, without requiring them to leave the call first | `[x]` |
| IT-016 | Voice-Sync off session: launching an overlay with a saved non-zero `autoScrollWPM` starts manual auto-scroll in the presented prompter instead of leaving the script stationary | `[ ]` |
| IT-017 | Session scroll shortcuts: configured up/down shortcuts nudge the active session scroll position regardless of which window has keyboard focus | `[ ]` |
| IT-017a | Session scroll shortcuts do not move Manual-mode Pill Windows; only the notch and synced overlays sharing the active playhead respond to shortcut nudges | `[x]` |
| IT-018 | System-tab manual scroll speed control persists a changed WPM value through `AppState` and `SettingsStore` | `[x]` |
| IT-019 | Mouse wheel / trackpad scrolling on an active overlay updates the rendered script position without disabling Voice-Sync state, including hover-paused and button-paused notch sessions plus Manual-mode pill windows regardless of the hover-pause setting | `[ ]` |
| IT-020 | Voice-Sync partial transcription updates advance the cursor in capped forward steps instead of jumping directly to the end of a long spoken window | `[ ]` |
| IT-029 | When `SUFeedURL` or `SUPublicEDKey` is missing, `AppUpdaterController` fails closed and `Check for Updates…` remains disabled | `[ ]` |
| IT-030 | When Sparkle reports an available update, Aira shows the custom update popup instead of Sparkle's stock update-found alert | `[ ]` |
| IT-031 | When Sparkle finishes downloading an update, Aira shows the custom `Install & Relaunch` popup instead of the stock ready-to-install alert | `[ ]` |
| IT-032 | App Store build launches without Sparkle linkage, hides `Check for Updates…`, and keeps product behavior otherwise identical to the direct build | `[ ]` |

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
| MT-056 | Direct release workflow from tag produces notarized DMG, Sparkle ZIP, appcast update, public GitHub release, and website metadata update without involving App Store upload steps | `[ ]` |
| MT-057 | App Store workflow uploads `AppStoreRelease` artifact to App Store Connect, build finishes Apple processing, and uploaded build contains no updater UI or Sparkle config | `[ ]` |
| MT-058 | Optional review-submission automation, if enabled later, only runs after explicit approval/manual dispatch and never from direct-release tag flow | `[ ]` |

| ID | Test | Status |
|---|---|---|
| MT-001 | Overlay is invisible in Zoom screen share on macOS 14+ | `[ ]` |
| MT-002 | Overlay is invisible in Microsoft Teams screen share on macOS 14+ | `[ ]` |
| MT-003 | Notch window is correctly positioned on MacBook Pro 14" notch | `[ ]` |
| MT-004 | Notch window is correctly positioned on MacBook Pro 16" notch | `[ ]` |
| MT-043 | Runtime notch overlay sits flush against the physical notch with no visible hairline gap at the two lower inner curves | `[ ]` |
| MT-044 | Runtime notch overlay also sits flush against the vertical inner notch edges with no visible side seams, with live side overscan still clamped to `0.0` | `[ ]` |
| MT-044b | Runtime notch overlay top shoulders bow outward into the menu-bar edge instead of cutting inward or ending square | `[ ]` |
| MT-044a | Runtime notch overlay exposes no drag-resize affordance or size-reset menu item during an active session; notch size changes only through Preferences > The Notch | `[ ]` |
| MT-045 | Appearance tab preview chips keep Light Paper light and Dark Studio dark in both app themes | `[ ]` |
| MT-046 | System tab manual-scroll copy refers to Manual mode / Voice-Sync-off behavior, and the Speech Sensitivity field label matches the surrounding Crimson Text control styling | `[ ]` |
| MT-047 | Overlay audio beam uses the shared primary color token and no overlay-local `Color(hex:)` helper remains in the Phase 6 window stack | `[ ]` |
| MT-005 | Pill window is freely movable to a second display | `[ ]` |
| MT-006 | App bundle size is measured after Archive build and includes the bundled speech model size | `[ ]` |
| MT-007 | No outbound telemetry or unrelated network requests during launch → cast → session → quit; only Sparkle appcast/update HTTPS traffic is permitted in direct-distribution builds | `[ ]` |
| MT-008 | Notarized .dmg passes `spctl --assess --verbose` without warnings | `[ ]` |
| MT-009 | Voice-Sync scroll tracks spoken words in real time with < 1 second lag | `[ ]` |
| MT-010 | Script scroll pauses immediately when user stops speaking | `[ ]` |
| MT-011 | Settings modal matches the mockup chrome: cream Preferences strip, sage active tab in light and dark mode, and small square Light/Dark preview swatches | `[ ]` |
| MT-049 | Release verification confirms WhisperKit and bundled `openai_whisper-base.en` plus fallback `openai_whisper-tiny.en` are present, the speech model is loaded from bundle storage, and no model download occurs at runtime | `[x]` |
| MT-012 | Manager UI audit sweep: button chrome, script editor, document library controls, and sidebar badges use the shared audited color tokens consistently in light and dark mode | `[ ]` |
| MT-013 | Settings modal top chrome uses themed surface color in both light and dark mode, App Theme swatches are centered, and System-tab control labels/body copy use Crimson Text while section headings stay Indie Flower | `[ ]` |
| MT-014 | Dark-mode visual regression check: selected Preferences tab text stays white, top chrome uses `#484C49`, Light Paper preview stays cream, notch preview uses `#434343`, dark script cards use `#3A3A3A`, and Cast to Notch keeps light text/icon color | `[ ]` |
| MT-048 | The Notch readability controls update the live preview correctly: Overlay Font remains the only font picker, Accessibility alignment includes `Justified`, spacing controls visibly change line/letter/word density, text shadow improves contrast, and padding changes the inset inside the overlay | `[ ]` |
| MT-049 | Preferences tabs read `Appearance`, `The Notch`, `Pill Windows`, and `System`; Pill Window setup lives only in `Pill Windows`, and `System` sections appear in Before / During / Controls / Privacy order | `[ ]` |
| MT-049a | Preferences tabs read `Appearance`, `The Notch`, `Pill Windows`, and `System`; the `Pill Windows` tab contains `Pill Window count` plus appearance/readability controls only, with no separate enable toggle and no content-mode or script-assignment controls | `[ ]` |
| MT-049a-a | Leaving the `Pill Windows` tab untouched still allows Pill Window launch; an unconfigured Pill Window renders with Notch defaults until the user customizes that slot | `[ ]` |
| MT-049b | Script Editor shows one connected split launch control `[ Cast to Notch ] [ chevron ]` using app-styled chrome rather than native macOS menu UI, without a duplicate label-side chevron, and primary `Cast to Notch` never launches Pill Windows unexpectedly | `[x]` |
| MT-049c | Chevron dropdown offers one `Cast with Pill Windows` item with restored compact toolbar button height, app-styled dropdown chrome, and outside-click dismissal | `[x]` |
| MT-049d | Cold-launch beachball regression watch: currently not reproducible in the app, so further launch-latency work is deferred until a current build reproduces the stall with trace evidence | `[x]` |
| MT-049e | Zero-countdown recursive-layout warning regression watch: currently not reproducible in the app, so the AppKit/SwiftUI layout-warning fix is deferred until current console evidence returns | `[x]` |
| MT-049f | During an active call/meeting app and during screen recording with microphone enabled, Voice-Sync diagnostics clearly show whether failure occurs at engine start, first tap buffer, first non-trivial audio level, or first speech-recognition partial/final result | `[ ]` |
| MT-059 | Pill hover close button dismisses only clicked pill and leaves notch / other pills running after overlay context menus were removed | `[ ]` |
| MT-015 | Sidebar New Script action stays pure white, script-card Cast button text/icon matches Edit button text color, and the script-card double-border gap matches the updated mockup spacing | `[ ]` |
| MT-016 | Pill Window controls match the Voice Tracking switch size and sage tint, and the Sidebar Scripts nav icon is a document-with-scribble icon while New Script remains a plus icon | `[ ]` |
| MT-017 | Voice Tracking enable row uses the same plain System panel styling as adjacent controls, without a separate highlighted background container | `[ ]` |
| MT-018 | During Voice-Sync, the scroll progression no longer skips ahead by large blocks of unseen script, and the overlay does not visibly emphasize the currently spoken word | `[ ]` |
| MT-019 | Entering selection mode from Select All does not visually shift existing script cards or the selection bar; card actions simply disappear and the trash button appears without layout jitter | `[ ]` |
| MT-019a | Entering `Scripts` or returning from editor shows current script-card grid immediately and never requires opening a Recent item first to repopulate the library view | `[x]` |
| MT-020 | Keyboard shortcut rows in Settings > System no longer use a separate highlighted/cream background and match the surrounding panel styling | `[ ]` |
| UT-075 | `MenuBarStatusItemController` does not permit status-item creation until launch has completed, and it creates at most one item after launch | `[x]` |
| MT-021 | The Notch Window keeps active text below the notch cutout, unread lines rise upward from lower in the overlay like a teleprompter, and the live voice indicator appears as corner sound waves outside the script text area | `[ ]` |
| MT-022 | Overlay text shows a downward start marker above the opening line, ignores stray single-line breaks from the editor by flowing paragraphs cleanly, and does not visibly emphasize the currently spoken word | `[ ]` |
| MT-023 | During the countdown, the overlay shows only the countdown treatment with no script text visible behind it; the script appears only after the countdown finishes | `[ ]` |
| MT-024 | Manual scroll starts at the beginning of a fresh session, gets visibly faster as WPM increases, does not snap back toward the middle after manual repositioning, remains smooth under timer, keyboard, and wheel input, and shows a clear speed difference between low and high presets such as `100 WPM` and `260 WPM` | `[ ]` |
| MT-025 | Manual scroll remains visually smooth on the display refresh cadence with no micro-stutter from timer-style cadence mismatch during long runs at both low and high WPM | `[ ]` |
| MT-026 | Keyboard nudges, wheel scrolling, and WPM auto-scroll no longer fight each other or snap the script back after a fresh session launch, and repeated line nudges do not get overridden by any mirrored offset channel | `[ ]` |
| MT-027 | The pause keyboard shortcut pauses and resumes the active scrolling mode itself, including manual WPM scroll and voice-driven scroll, without needing to end the session | `[ ]` |
| MT-028 | In Sync mode, the notch and every synced pill scroll and pause together; only Manual pills can diverge to a different script or offset | `[ ]` |
| MT-050 | Turning Pause on mouse hover off keeps notch sessions scrolling while hovered; turning it on restores notch pause/resume behavior without changing scroll-position continuity, and pill windows remain unaffected in both cases | `[ ]` |
| MT-054 | Hovering notch and pill overlays reveals action chrome in expected corners: notch shows undock on left plus pause/close on right, pill shows swap/fullscreen/close on right, and non-hover state hides the chrome | `[ ]` |
| MT-060 | Clicking hover `Swap` on manual pill performs same script exchange as prior pill swap control, updating both manual pill and notch immediately from top of script | `[ ]` |
| MT-061 | Clicking notch hover `Pause` toggles live session pause/resume, and clicking notch hover `Close` ends active presenter session with same behavior as Escape / prior end-session action | `[ ]` |
| MT-062 | Pill hover `Fullscreen` is disabled on built-in/main display, becomes enabled after moving pill to a secondary display, and enters/exits macOS fullscreen there without affecting the notch overlay | `[ ]` |
| MT-063 | When notch session is paused, hover control shows resume glyph from mockup instead of pause bars; when running, it shows pause bars | `[ ]` |
| MT-064 | Disabled pill fullscreen button on built-in/main display is visibly dimmed and does not look interactive compared with enabled secondary-display state | `[ ]` |
| MT-065 | Secondary-display pill fullscreen exits cleanly back to prior pill size/position with no frame glitch and no title bar appearing during enter or exit | `[ ]` |
| MT-066 | Docked notch `Undock` is disabled while any pill window is active, becomes enabled when no pills remain, and undocking turns the notch into a free-moving rounded rectangle with no cutout | `[ ]` |
| MT-067 | Undocked notch shows `Dock` plus fullscreen controls on the left, can be resized/moved like a pill, and redocking restores the anchored notch presentation on the built-in display | `[ ]` |
| MT-068 | Undocked notch removes the corner-wave ornament, shows a bottom reserved `VisualBeam` strip, and scrolling text never passes behind that waveform area | `[ ]` |
| MT-029 | In Sync mode with one or more pills open, manual auto-scroll remains as fast and as smooth as notch-only operation, with the notch acting as the primary driver and synced pills showing the same content position through their own local window pacing rather than inheriting a slower shared rendered offset | `[ ]` |
| MT-030 | In Sync mode, the primary notch window keeps the same smooth configured point-based pacing it has by itself and does not become jittery from re-projecting shared progress back into its own rendered offset | `[ ]` |
| MT-031 | Administrative FAQ-style scripts containing repeated `Q)` markers, contact email addresses, and similar non-spoken metadata do not distort notch pacing, content-progress projection, or speech matching | `[ ]` |
| MT-032 | Scripts with sparse vertical layout such as FAQ sections, headings, and frequent paragraph breaks still move at the configured manual point-based speed without visually slow or jittery regions in the notch overlay | `[ ]` |
| MT-033 | Shared playhead refactor regression: manual scroll still works in notch-only, sync notch+pills, and manual pill-only sessions after playhead coordinator introduction | `[ ]` |
| MT-034 | In Sync mode, differently sized windows show the same content progress while moving at different pixel speeds appropriate to their own geometry | `[ ]` |
| MT-035 | Pause/resume operates on the shared session playhead, so all Sync overlays pause and resume together while Manual pills remain unaffected | `[ ]` |
| MT-036 | Long scripts and short scripts presented in the notch at the same configured point-based speed have consistent perceived manual scroll speed instead of long documents visually crawling | `[ ]` |
| MT-037 | Manual `Sync` sessions no longer exhibit visible lag from the legacy line-index sync path, while voice-driven sync still behaves correctly until the voice refactor lands | `[ ]` |
| MT-038 | Increasing total document length does not reduce the perceived manual scroll speed at the same configured point-based speed | `[ ]` |
| MT-039 | Long scripts do not introduce visible overlay lag or jitter from per-frame text rebuild cost while manual scrolling is active | `[ ]` |
| MT-040 | Script Editor cue panel uses shared theme tokens for its sage background and cream foreground so it stays visually consistent across theme audits | `[ ]` |
| MT-041 | Collections sidebar warning uses the shared warm token instead of an inline hex color, and collections navigation still behaves correctly after the manager window accessor main-actor cleanup | `[ ]` |
| MT-042 | Settings chunk-1 audit: tabs read `Appearance`, `The Notch`, `Pill Windows`, and `System`; Light Paper/Dark Studio swatches use shared theme tokens; and Pill Windows still behave correctly after `maxPillCount` normalization | `[ ]` |
| MT-048 | `Check for Updates…` is enabled only when the built app bundle resolves a valid Sparkle feed URL and public key | `[ ]` |
| MT-049 | The branded update prompt appears for both `update found` and `ready to install` states, and `Cancel` cleanly dismisses without starting installation | `[ ]` |
| MT-050 | A tagged release publishes DMG, ZIP, and `appcast.xml`, and an installed build successfully discovers the update from `https://raw.githubusercontent.com/sankirthk/aira-releases/main/appcast.xml` | `[ ]` |
| MT-051 | Main-repo CI runs Swift formatting checks, lint-style checks, `xcodebuild build`, and `xcodebuild test` on pull requests, while release tags skip redundant validation builds | `[ ]` |
| MT-052 | Installed pre-commit hook blocks a commit when formatting, linting, build, or tests fail, and allows the commit when the full local validation path passes | `[ ]` |
| MT-053 | `scripts/dev/graphify-watch.sh` starts scoped watchers for `Aira` and `docs`, keeps running until interrupted, and prints the docs semantic-refresh reminder when `graphify-out/needs_update` appears | `[ ]` |

### Planned Refactor Coverage (Tasks T-025z ... T-025ai)

| ID | Test | Status |
|---|---|---|
| IT-021 | Session playhead coordinator clamps normalized progress to `0...1` and preserves pause state across repeated start/stop transitions | `[x]` |
| IT-022 | Manual WPM input updates shared playhead velocity without directly mutating view-local rendered offsets | `[ ]` |
| IT-023 | Wheel and keyboard nudges both modify the same playhead state path instead of separate local offset channels | `[ ]` |
| IT-024 | Sync overlay projection maps shared playhead progress into different local offsets for notch and pill windows with different viewport sizes | `[ ]` |
| IT-025 | Unified Voice mode updates bounded playhead target progress without directly writing rendered offset state from `VoiceSyncEngine` | `[ ]` |
| IT-026 | Voice mode advances the same playhead used by manual scroll and moves only when recognized human speech is active, not on raw audio-level noise alone | `[ ]` |
| IT-029 | Voice spoken-word highlighting only searches the currently visible overlay word window, ignores low-confidence recognition segments, and never jumps backward automatically to already retired words unless the user explicitly clicks a word to reseed | `[ ]` |
| IT-030 | High-confidence 3-word suffix matches win over 2-word and 1-word matches, and common filler words do not falsely highlight unrelated visible text | `[ ]` |
| IT-027 | Primary manual playhead velocity is derived from measured rendered text density (`pointsPerWord`, `scrollableRange`, `autoScrollWPM`) rather than a naive `1 / totalSeconds` normalized step, so document length alone does not reduce physical scroll pace | `[x]` |
| IT-028 | Long-script manual sessions cache rendered overlay text instead of rebuilding the entire presentation during per-frame scroll updates | `[ ]` |
| IT-032 | One canonical overlay layout snapshot produces rendered attributed text, total content height, line metrics, and `pointsPerWord`, and scroll/playhead state consumes that same snapshot instead of separate measurement paths | `[x]` |
| IT-033 | Changing alignment, line spacing, letter spacing, word spacing, text shadow, content padding, or font rebinds overlay scroll geometry from the updated layout snapshot and does not leave scroll range at zero/stale values | `[x]` |
| MT-055 | Scroll regression check after T-025ai: notch voice-sync, notch manual WPM, sync notch+pill, and manual pill sessions all scroll correctly after readability settings changes and long-script content updates | `[ ]` |
| MT-069 | Voice mode inline highlighting follows spoken words only inside the currently visible overlay window in notch and pill sessions, retires words that scroll off the top, and does not highlight future off-screen words | `[ ]` |
| MT-070 | System > During Session spoken-word highlighting toggle defaults off, persists across relaunch, and only affects overlay visuals without changing pause, manual scroll, or voice-driven scroll behavior | `[ ]` |
| UT-071 | First-launch permission coordination requests Accessibility, speech recognition, and microphone access together, persists that onboarding ran, and later launches only retry the specific permissions still missing | `[w]` |
