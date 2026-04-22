

# Aira — Product Requirements

## Purpose

This document defines the business requirements and externally observable behavior for Aira.

This is the normative source for:
- the voice-synchronization contract
- window, layout, and stealth behavior
- script editing, import, and storage rules
- script organization and library operations
- AI conversion and BYOK obligations
- appearance and personalization rules
- session control behavior
- privacy, data, and distribution commitments
- experimental feature expectations

This document does not define storage technology, framework choices, OS API internals, or implementation architecture. Those belong in `design.md`.

## How To Read This Document

The document is intentionally linear:
1. Canonical terms
2. Global invariants
3. Requirements, grouped by capability area
4. Dependency summary
5. Non-goals

Later sections may extend earlier definitions, but they must not redefine them.

## Spec Map

- `requirements.md` — business rules and externally observable behavior
- `design.md` — technical realization of those rules
- `todo.md` — execution plan for implementing the design

## Canonical Terms

### User

A person running Aira on their macOS device. No account or registration is required.

### Presenter Session

An active period of use during which the user is delivering a presentation, meeting, or recording with Aira running.

### Script

A body of text authored or imported by the user and used as the content source for the prompter.

### Prompter

The visible overlay that displays the current script and scrolls in response to voice or manual input.

### Notch Window

The primary prompter window anchored beneath the camera notch region of the display.

### Pill Window

A free-moving, resizable overlay window that the user can place anywhere on screen. Each Pill Window operates in a content mode that determines what it displays and how it scrolls.

### Pill Content Mode

The operational mode of a Pill Window. A pill in **Sync mode** follows the same script and shared scroll position as the Notch Window, driven by the active presenter session. A pill in **Manual mode** displays an independently assigned script that the user scrolls by hand; Sync mode does not drive it.

### Voice-Sync

The behavior by which the prompter scroll position advances in real time in response to the user's detected speech.

### Visual Beam

The real-time audio-level indicator rendered within the prompter that reflects current microphone input volume.

### Stealth Mode

The operational state in which Aira's windows are excluded from the screen-share output visible to remote participants.

### Countdown

A pre-session timer that counts down before Voice-Sync begins, giving the user time to settle.

### Report-to-Natural Converter

The AI-powered feature that transforms a formal document or report into a script formatted for natural spoken delivery.

### BYOK

Bring Your Own Key. The model by which a user supplies their own third-party AI API key to enable the Report-to-Natural Converter. Aira does not supply or proxy this key.

### Mood Preset

A named bundle of appearance settings — text color, background color, opacity, font, and contrast — that the user can apply in one action.

### Collection

A named group of scripts created by the user to organize related material. A script can belong to zero or more collections.

### Live Answer Mode

An experimental, opt-in feature that listens to meeting audio and surfaces suggested responses to questions from other participants.

### Local-First

The data architecture principle that all user content, scripts, settings, and keys reside exclusively on the user's device and are never transmitted to any Aira-controlled server.

## Global Invariants

These rules apply across all of Aira's behavior.

- Aira requires no user account, login, or registration at any point.
- All scripts, settings, appearance preferences, and API keys remain on the user's device at all times.
- Aira collects no analytics, telemetry, usage data, or crash reports that leave the device.
- No network connection is required to use any core authoring or presenter feature. The only permitted network activity in direct-distribution builds is Sparkle update traffic over HTTPS (appcast checks and signed update downloads). App Store builds do not use Sparkle and therefore must not perform updater traffic. If the future AI converter ships, its user-initiated BYOK request is the only additional permitted network path.
- Stealth Mode must never fail silently; if the prompter cannot be excluded from screen-share output, the user must be informed before a presenter session begins.
- Voice-Sync and manual scroll are always independently available; one must never depend on the other being active.
- The Notch Window and Pill Windows are independent surfaces; the failure or closure of one must not affect the other.
- Experimental features must be clearly labeled as such and must require an explicit opt-in before activating.

## Requirements

### Voice Synchronization

#### REQ-001: Voice-Driven Scroll

The app shall advance the script scroll position in real time using a single Voice mode.

Acceptance criteria:
- **Voice Mode:** The prompter scrolls continuously using the shared playhead. Voice activity keeps motion running, recent recognition results anchor the playhead so the script does not drift far from the spoken position, and the overlay highlights the currently matched spoken word or short matched phrase inline.
- Voice-Sync is the default active mode when a presenter session starts.
- The user can enable or disable Voice mode in Settings.
- While Voice-Sync is active, the speech matcher publishes the current spoken position to the shared session playhead and visually emphasizes the currently spoken word inline without adding a separate overlay surface.
- When spoken-word highlighting is enabled, clicking a visible overlay word reseeds the spoken-word highlight/search anchor to that word for subsequent recognition updates without changing the current scroll position.

#### REQ-002: Pause On Silence

The app shall pause script scrolling immediately when the user stops speaking.

Acceptance criteria:
- Scrolling halts when no speech is detected.
- The script position is preserved at the point of pause.
- Scrolling resumes from that position when speech resumes.

#### REQ-003: Manual Scroll Override

The user shall be able to manually control scroll position and speed at any time, independent of Voice-Sync state.

Acceptance criteria:
- The user can scroll forward or backward during a presenter session using mouse wheel or trackpad gestures on the overlay surface.
- The user can nudge the script up or down by one rendered line at a time using configurable keyboard shortcuts during a presenter session.
- The user can adjust manual auto-scroll speed on the fly from Settings > System using a bounded points-per-second control.
- Manual auto-scroll speed is configurable from 10 pt/s to 100 pt/s, with a default of 50 pt/s.
- Manual auto-scroll is driven by a single display-synced session playhead rather than timer-style per-view loops.
- Manual wheel, keyboard, and WPM auto-scroll inputs all feed the same session playhead model.
- In Sync mode, overlays share the same script progress but each overlay projects that progress into its own local geometry and therefore may move at different pixel speeds.
- In Sync mode, the primary overlay derives shared manual playhead velocity from a fixed configured points-per-second value rather than document size, word count, or rendered line density so short and long scripts move at the same physical speed.
- Manual override does not permanently disable Voice-Sync; the user can re-engage it.

#### REQ-004: Visual Beam Feedback

The app shall display a real-time audio-level indicator as part of the overlay presentation that reflects the user's current microphone input volume.

Acceptance criteria:
- The Visual Beam responds visibly to changes in microphone volume.
- The Visual Beam provides sufficient signal for the user to gauge whether they are at an appropriate speaking level.
- The audio-level indicator remains visually attached to the active overlay and does not require a separate window.

### Stealth And Screen Share Invisibility

#### REQ-005: Prompter Hidden From Screen Share

The app shall exclude all Aira windows from the screen-share stream visible to remote participants.

Acceptance criteria:
- When the user shares their screen in Zoom, Microsoft Teams, or equivalent tools, no Aira window appears in the shared output.
- Screen-share exclusion is enabled by default, but the user may explicitly disable it in Preferences > System when they want overlays to appear in screenshots, recordings, or video calls.
- This behavior applies to both the Notch Window and all Pill Windows.
- Stealth Mode is active by default; the user does not need to enable it manually.

#### REQ-006: Prompter Visible To User During Share

The user shall always see the prompter on their own display while Stealth Mode is active.

Acceptance criteria:
- The prompter remains fully visible to the local user while screen sharing is in progress.
- Stealth Mode does not reduce the local visibility, opacity, or functionality of the prompter.

#### REQ-007: Stealth Failure Notification

The app shall notify the user if it cannot guarantee that the prompter is excluded from a screen-share stream.

Acceptance criteria:
- If Stealth Mode cannot be confirmed before or during a presenter session, the user receives a visible warning.
- The warning does not interrupt or terminate the presenter session automatically; the user decides how to proceed.

### Window And Layout

#### REQ-008: Notch Window

The app shall provide a primary prompter window anchored beneath the camera notch region, enabling natural eye contact with the audience.

Acceptance criteria:
- The Notch Window is positioned at the top of the **built-in laptop display**, beneath the camera, regardless of how many external monitors are connected or which screen is currently "main".
- The Notch Window cannot be freely repositioned; its anchor is fixed to the notch region of the built-in display.
- The Notch Window is available regardless of whether a Pill Window exists.
- The runtime notch cutout must align to the physical notch width with **no horizontal side overscan**; both cutout side-overscan clamps remain `0.0` so the overlay edge sits flush against the notch walls.
- The readable script area begins below the notch cutout so active text does not disappear behind the notch while being read.
- Script motion in the Notch Window follows a teleprompter-style lower reading zone, with lines entering from lower in the overlay and progressing upward.

#### REQ-009: Pill Windows

The app shall support up to two free-moving, resizable Pill Windows that the user can place anywhere on screen.

Acceptance criteria:
- Pill Windows are opt-in; they are disabled by default and must be enabled in Settings before they can be launched.
- When enabled, the user can open 1 or 2 Pill Windows (configured in Settings) during a presenter session.
- Pill Windows are independently positionable and resizable.
- A Pill Window can be placed on a secondary monitor.
- Closing a Pill Window does not affect the Notch Window or any other Pill Window.
- Each Pill Window operates in a content mode (Voice-Sync or Manual) as defined in REQ-034.

#### REQ-044: Pill Window Settings

The app shall expose pill configuration in Settings > Overlays so the user can opt in to pill windows and choose how many to use.

Acceptance criteria:
- An "Enable Pill Windows" toggle controls whether pills can be launched. Off by default.
- When the toggle is on, a pill count control (1 or 2, segmented) becomes active.
- The pill count defaults to 1 when first enabled.
- Pill Windows inherit their initial appearance from `defaultOverlayAppearance` (the shared Notch/Pill defaults). There are no separate per-pill appearance settings in Settings — per-pill customisation is done in-session via the right-click popover (REQ-038).
- The enabled state and count persist across app restarts.

#### REQ-010: Hover-To-Pause

Hovering the cursor over the Notch Window shall instantly pause scrolling for that window.

Acceptance criteria:
- Hover-pause is controlled by a persisted Settings toggle and defaults to enabled.
- Spoken-word highlighting is controlled by a persisted Settings toggle in the System > During Session section, defaults to disabled, and affects only visual emphasis rather than scroll behavior.
- Moving the cursor over the Notch Window pauses scroll for as long as the cursor remains over it.
- The script position is preserved during the hover pause.
- Pill Windows ignore the hover-pause setting so floating overlays remain manually scrollable while hovered.

#### REQ-011: Resume After Hover Pause

The app shall resume scrolling from the paused position when the cursor leaves the prompter window.

Acceptance criteria:
- Scroll resumes from the exact position at which it paused.
- No user action other than moving the cursor away is required to resume.

#### REQ-034: Pill Content Mode

A Pill Window shall support two content modes: Sync and Manual.

Acceptance criteria:
- In Sync mode, the pill displays the same script position as the Notch Window and is driven by the active shared session playhead state.
- In Manual mode, the pill is assigned any script from the user's library independently of the Notch Window.
- In Manual mode, scroll is controlled entirely by the user; Voice-Sync does not advance a manual-mode pill.
- The user selects a pill's content mode when the pill is created.
- A manual-mode pill does not require an active VoiceSyncEngine or a microphone to display and scroll its assigned script.
- Multiple Sync pills can be open simultaneously; they all follow the same shared content progress and paused/running state.
- Sync pills are not required to share one rendered pixel offset or one pixel velocity; each projects the shared session playhead into its own window geometry.

### Countdown Timer

#### REQ-012: Pre-Session Countdown

The app shall provide a built-in countdown timer that runs before Voice-Sync begins, giving the user time to settle before the script starts scrolling.

Acceptance criteria:
- The countdown is visible to the user before the presenter session starts.
- Voice-Sync does not begin until the countdown reaches zero.
- The default countdown duration is three seconds.

#### REQ-013: Configurable Countdown Duration

The user shall be able to configure the countdown duration.

Acceptance criteria:
- The user can set a countdown duration other than the default.
- The configured duration persists across sessions.
- Setting the countdown to zero disables the countdown entirely.

### Script Editor

#### REQ-045: Bulk Script Selection and Deletion

The Document Library shall allow the user to select multiple scripts and delete them in a single action.

Acceptance criteria:
- A "Select All" checkbox in the sort/filter bar enters selection mode and selects every visible script. Clicking it again deselects all and exits selection mode.
- Individual script cards show a checkbox on hover (or whenever any selection exists). Clicking the checkbox toggles that script's selection.
- ⌘+click on a card toggles its selection. Shift+click selects a contiguous range from the last-clicked card to the clicked card.
- A trash icon appears in the sort/filter bar (replacing or alongside the Select All checkbox) when one or more scripts are selected.
- Pressing the trash icon shows a confirmation alert: "Delete [N] script[s]? This cannot be undone." with Delete and Cancel actions.
- Confirming bulk deletes all selected scripts and their files from disk, updates the index, and exits selection mode.
- Pressing Escape exits selection mode without deleting anything.
- Bulk delete is not available while a presenter session is active.
- The Select All control and bulk delete control are hidden while a presenter session is active.
- Individual script deletion is not available while a presenter session is active.
- A script currently used by the active notch or any active pill session cannot be opened for editing until that session ends.

#### REQ-014: Built-In Script Editor

The app shall include a native script editor where the user can draft, edit, and organize scripts without leaving the app.

Acceptance criteria:
- Starting a new draft from the sidebar or library while another script is open first runs the same dismiss/autosave logic as Back navigation.
- If the currently open editor script is being presented in an active session, the editor becomes read-only until that session ends.

Acceptance criteria:
- The user can create a new script from within the app.
- Clicking "New Script" opens the editor with a blank in-memory draft. **No file is written to disk at this point.**
- A script is only persisted when the user explicitly saves (Save button) OR dismisses the editor and the draft has meaningful content — defined as: body is non-empty, OR the title was changed from the default "Untitled Script". If both fields are unchanged/empty on dismiss, the draft is silently discarded with no file created.
- There is no limit on the number of scripts a user can create.
- The user can edit an existing script from within the app.
- Multiple scripts can be stored and named independently.
- Auto-save on dismiss: when the user navigates away from the editor without explicitly saving, the app saves automatically if the draft has meaningful content (as defined above). No dirty indicator is shown — auto-save makes it unnecessary.
- The editor toolbar exposes a split-button launch control: primary `Cast to Notch` plus adjacent dropdown.
- Pressing the primary `Cast to Notch` action is deterministic and never launches Satellite windows.
- Opening the dropdown exposes `Cast to Notch` and `Cast with Satellite…`.
- Choosing `Cast with Satellite…` opens a launch panel listing each enabled Satellite and its content assignment controls.

#### REQ-015: Local Script Storage

All scripts shall be stored exclusively on the user's device.

Acceptance criteria:
- Scripts are not uploaded to any remote server, including any Aira-controlled service.
- Scripts remain available offline.
- Deleting the app or its data container removes all locally stored scripts.

#### REQ-016: Speech Cue Formatting

The script editor shall support formatting that allows the user to annotate scripts with cues for breath, emphasis, and pacing.

Acceptance criteria:
- The user can apply at least one type of cue annotation (e.g., a pause marker, an emphasis marker) within the editor.
- Cue annotations are preserved when the script is loaded into the prompter.
- Cue annotations are visible to the user in the editor distinct from plain script text.

### Script Library Operations

#### REQ-035: Script Import

The app shall allow the user to import plain text files as scripts.

Acceptance criteria:
- The user can drag a `.txt` file onto the Document Library to create a new script from its contents.
- The user can open a system file picker to import a `.txt` file as an alternative to drag-and-drop.
- The imported content becomes editable in the script editor immediately after import.
- The original file is not modified; import creates a new independent script in Aira's local storage.
- Import does not require a network connection.

#### REQ-036: Script Duplication

The user shall be able to duplicate any existing script in the Document Library.

Acceptance criteria:
- A duplicate action is available for each script in the Document Library.
- The duplicate is created with the same body and cue annotations as the source script.
- The duplicate is given a distinguishable name (e.g., "Copy of [title]") and the user can rename it immediately.
- Duplicating does not modify or delete the source script.

### Script Organization

#### REQ-037: Collections

The user shall be able to create named collections to organize scripts.

Acceptance criteria:
- The user can create, rename, and delete collections from within the app.
- The user can add any script to one or more collections.
- A script can belong to multiple collections simultaneously.
- Deleting a collection does not delete the scripts it contains.
- Collections and their membership data are stored locally on the user's device and never transmitted remotely.
- The Document Library can be filtered to show only the scripts in a selected collection.

### AI Script Converter

#### REQ-017: Report-To-Natural Conversion

The app shall include a converter that transforms a formal document or report into a script formatted for natural spoken delivery.

Acceptance criteria:
- The user can paste or import a formal document and receive a rewritten script.
- The output script is structured for spoken delivery, not written reading.
- The converter output preserves the substantive content of the source document.

#### REQ-018: Cues In Converter Output

The converter shall produce output that includes speech cues for breath, emphasis, and pacing.

Acceptance criteria:
- The converted script includes explicit cue annotations, not just reworded prose.
- Cue annotations are consistent with the editor's formatting model defined in REQ-016.

#### REQ-019: BYOK Requirement

The Report-to-Natural Converter shall operate exclusively using an API key supplied by the user.

Acceptance criteria:
- The user must provide their own third-party AI API key to use the converter.
- Aira does not supply, fund, or proxy an API key on behalf of the user.
- The converter is unavailable until the user provides a valid key.

#### REQ-020: API Key And Content Privacy

The app shall never transmit the user's API key or source document content to any Aira-controlled server.

Acceptance criteria:
- The API key is stored locally on the user's device.
- Conversion requests are made directly from the user's device to the third-party AI provider using the user's key.
- No Aira-controlled intermediary receives the key or the document content at any point.

### Appearance And Personalization

#### REQ-021: Window Size Adjustment

The user shall be able to adjust the size of each prompter window freely.

Acceptance criteria:
- Window size can be changed by the user at any time, including during a presenter session.
- Size changes persist across sessions.

#### REQ-022: Text Size Adjustment

The user shall be able to adjust the font size displayed in the prompter freely.

Acceptance criteria:
- Text size can be changed independently of window size.
- The change applies immediately to the active prompter display.
- The chosen size persists across sessions.

#### REQ-022a: Overlay Readability Controls

The app shall provide additional readability controls for overlay text.

Acceptance criteria:
- Font selection remains in a single Overlay Font control; the Accessibility section does not duplicate font choice.
- A dyslexia-friendly bundled overlay font option remains available through the Overlay Font picker.
- The user can choose between left-aligned, center-aligned, and justified overlay text.
- The user can adjust overlay line spacing within a bounded range and see the preview update immediately.
- The user can adjust letter spacing, word spacing, text shadow, and inner text padding within bounded ranges and see the preview update immediately.
- The chosen readability settings persist across sessions and apply to newly launched overlay windows.

#### REQ-023: Custom Text Colors

The user shall be able to choose custom text colors for the prompter display.

Acceptance criteria:
- The user can select a text color suited to their environment (e.g., high-contrast for bright rooms, softer tones for low-light conditions).
- Color changes apply immediately.
- The chosen color persists across sessions.

#### REQ-024: Mood Presets

The app shall not provide pre-built appearance preset shortcuts in Preferences. Overlay appearance shall be configured directly through the individual text color, background color, opacity, and contrast controls.

Acceptance criteria:
- No preset row or preset cards are shown in Settings > The Notch.
- Users can still achieve the same visual outcomes through the direct overlay appearance controls.
- The user can switch between presets without losing the ability to make further manual adjustments.

#### REQ-038: Per-Window Overlay Appearance

Each overlay window shall support independent appearance settings, separate from the global defaults.

Acceptance criteria:
- The user can set text color, background color, background opacity, font, and font size per overlay window individually.
- Global appearance defaults apply when a new overlay window is first created.
- Per-window changes take effect immediately on that window only and do not affect other open windows.
- The global defaults are configurable in Settings.

### Session Controls

#### REQ-039: Keyboard Voice-Sync Toggle

The user shall be able to pause and resume Voice-Sync via keyboard shortcut during a presenter session, without requiring cursor interaction with the overlay window.

Acceptance criteria:
- A configurable keyboard shortcut pauses the active session playhead when it is active.
- The same or a separate configurable shortcut resumes the active session playhead from the paused position.
- The shortcut is effective regardless of which window has keyboard focus.
- The shortcut is listed in Settings > System alongside other session shortcuts and is user-editable.

### Privacy And Data

#### REQ-025: Local-First Architecture

All user data shall reside exclusively on the user's device.

Acceptance criteria:
- Scripts, settings, appearance preferences, and API keys are never uploaded to any remote server.
- The app functions fully offline for all core features.
- No Aira-controlled server receives any user data under any operating condition.

#### REQ-026: No Telemetry Or Analytics

The app shall collect no analytics, usage data, diagnostics, or telemetry that leave the device.

Acceptance criteria:
- No usage events are sent to any remote endpoint.
- No crash reports are automatically transmitted.
- No third-party analytics SDK is embedded in the distributed app.

#### REQ-027: No Account Required

The app shall require no user account, login, or registration to use any feature.

Acceptance criteria:
- The app is fully functional immediately after installation with no sign-in step.
- No personal information is collected at any point.

### Distribution

#### REQ-028: Free Distribution

The app shall be free to download and use with no purchase or subscription required for core features.

Acceptance criteria:
- No payment is required to install or use any requirement defined in this document except REQ-019, which requires the user's own third-party API key.
- There is no trial period or feature-gating for core functionality.

#### REQ-029: Signed And Notarized Installer

The app shall be distributed as a signed and notarized `.dmg` for macOS.

Acceptance criteria:
- The installer passes macOS Gatekeeper without a security warning for the user.
- The app is code-signed with a valid Apple Developer certificate.
- The `.dmg` is notarized by Apple before distribution.

#### REQ-030: Distribution Channels

The app shall support two release paths from one shared codebase: direct distribution and Mac App Store distribution.

Acceptance criteria:
- **Direct distribution:** A user can download signed and notarized install media from the public GitHub Releases page.
- **Direct distribution:** An installed direct-distribution copy can check a hosted Sparkle `appcast.xml` over HTTPS and install a newer signed update archive in place.
- **Direct distribution:** The manual-download DMG and the Sparkle update archive represent the same released app version/build.
- **Direct distribution:** When an update is found, Aira presents an in-app update prompt before Sparkle proceeds with download or install.
- **App Store distribution:** A Mac App Store build is produced from the same repository and product code, but without Sparkle-linked binaries, Sparkle configuration keys, or Sparkle-specific entitlements.
- **App Store distribution:** The Mac App Store build exposes no in-app self-update UI and relies on App Store distribution/update mechanics instead.
- **App Store distribution:** App Store upload/submission automation, if configured, must run through a release path separate from the direct-distribution GitHub Releases + Sparkle publishing flow.

#### REQ-031: Closed-Source Repository Policy

The public GitHub repository shall be used exclusively for community issue tracking and feature requests. Source code shall not be published.

Acceptance criteria:
- No source code is committed to the public repository.
- Issues and feature requests can be filed by community members.
- The repository communicates the closed-source policy clearly.

### Experimental Features

#### REQ-032: Live Answer Mode

The app shall support an optional, opt-in mode that listens to meeting audio and surfaces suggested responses to questions asked by other participants.

Acceptance criteria:
- Live Answer Mode is disabled by default.
- The user must explicitly opt in before the feature activates.
- The feature can be disabled at any time during a presenter session.

#### REQ-033: Experimental Transparency Disclosure

Live Answer Mode shall be clearly labeled as experimental and must disclose its behavior to the user before activation.

Acceptance criteria:
- The feature is labeled "Experimental" wherever it appears in the app.
- Before the user opts in for the first time, a plain-language disclosure explains what the feature does, what audio it accesses, and any limitations.
- The user must acknowledge the disclosure before Live Answer Mode activates.

### Future Enhancements

The following requirements are defined here for completeness but are **not in scope for v1**. They are documented so that future implementation has a normative reference. None of these features ship in the initial release.

#### REQ-040: Scroll Progress Indicator

The prompter shall display a visual indicator of how far through the script the user has progressed.

Acceptance criteria:
- A progress element is visible within the overlay window during a session.
- The indicator reflects the current scroll position as a proportion of total script length.
- The indicator does not obstruct script text readability.

#### REQ-041: Session Elapsed Timer

The app shall display an elapsed time counter during a presenter session.

Acceptance criteria:
- A timer visible within the overlay shows how long the current session has been active.
- The timer starts when Voice-Sync begins (after the countdown completes).
- The timer can be hidden via a per-window setting.

#### REQ-042: Jump-To-Top

The user shall be able to return the script to the beginning of the document in one action during a session.

Acceptance criteria:
- A keyboard shortcut resets the scroll position to the top of the script.
- Voice-Sync cursor position is also reset to the beginning.
- The action works on both Notch and Pill windows individually.

#### REQ-043: Mirror Mode

The prompter shall support horizontally mirrored text rendering for use with physical teleprompter hardware.

Acceptance criteria:
- A per-window toggle flips the text display horizontally.
- All content including cue annotations is mirrored.
- Mirror mode can be toggled without ending the session.

## Dependency Summary

The core presenter session dependency chain is:

- script authored or imported → loaded into prompter → countdown completes → Voice-Sync begins → scrolling advances with speech

The core pill setup dependency chain is:

- pill created → content mode selected → (if Manual) script assigned → pill displays independently of Notch Window

The core AI conversion dependency chain is:

- user provides API key → user submits source document → conversion request sent directly to AI provider → output returned and loaded into editor

The core stealth dependency chain is:

- app launch → Stealth Mode verification → presenter session start → prompter excluded from screen-share stream

The core import dependency chain is:

- user drops .txt file or opens file picker → file read locally → new script created in Aira storage → script opens in editor

## Non-Goals

- This document does not define the OS APIs, window-level flags, or screen-capture filtering mechanisms used to implement Stealth Mode.
- This document does not define the speech recognition engine, audio pipeline, or VAD algorithm used to implement Voice-Sync.
- This document does not define AI provider selection, prompt engineering, or model configuration for the Report-to-Natural Converter.
- This document does not define UI layout, visual design language, animations, or interaction patterns beyond what is required to specify observable behavior.
- This document does not define administrator, support, or internal-operator workflows.
- This document does not define a web app, iOS app, or any non-macOS platform.
- This document does not define monetization, in-app purchase, or premium tier mechanics beyond REQ-028.
- This document does not define import support for formats other than plain text (.txt). Rich text, PDF, and DOCX import are not specified.
