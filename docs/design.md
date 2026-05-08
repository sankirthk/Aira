# Aira — Design Document

## Purpose

This document defines the visual design language, screen inventory, component catalog, and interaction patterns for Aira. It is the authoritative reference for how the app looks and behaves from the user's perspective.

This document does not define implementation technology, frameworks, or OS APIs. Those belong in `architecture.md`.

---

## 1. Design Principles

**Organic and calm.** Aira uses an earthy palette — sage green, terracotta, cream — and soft geometric forms. The app should feel like a warm tool, not a clinical dashboard. Users are often in high-pressure presentation moments; the UI must not add to that stress.

**High legibility under pressure.** Script text in the prompter must be readable at a glance, mid-sentence, without any cognitive friction. Font choice, size, line height, and contrast are all calibrated for this.

**Invisible when it needs to be.** During a presenter session, the overlay exists only for the user. It must not distract, and it must be hidden from everyone else (screen share exclusion).

**Prominent when it needs to be.** The Manager App is a comfortable workspace for authoring and organizing scripts. It should feel substantive and focused — not sparse or toy-like.

**No friction at the start.** No account, no onboarding wizard, no permission walls before the user reaches their script. The first action should be creating or opening a script.

---

## 2. Design Tokens

These tokens define the visual language. All colors, type scales, and spacing values throughout the app derive from these definitions.

### Color Palette

| Token | Value | Name | Usage |
|---|---|---|---|
| `colorPrimary` | `#849688` | Sage Green | Sidebar background, active states, selection rings |
| `colorSecondary` | `#C98B7A` | Terracotta | CTAs, accent buttons, progress indicators |
| `colorBackground` | `#F5F2EC` | Cream | Main content area background |
| `colorSurface` | `#FFFFFF` | White | Cards, panels, modal sheets |
| `colorText` | `#2B2B2B` | Charcoal | Body text, primary labels |
| `colorMuted` | `#6B8E99` | Slate Blue | Secondary labels, metadata, placeholder text |
| `colorWarm` | `#D4A574` | Warm Tan | Highlights, hover states, warm accents |

**Dark mode equivalents** — each token has a dark variant. Dark mode uses the same semantic names; only the underlying hex values change. Dark mode background is `#2B2B2B` (Charcoal), surfaces become near-black (`#1A1A1A`), text becomes Cream (`#F5F2EC`). Sage Green and Terracotta remain consistent in both modes as they read well on dark backgrounds.

**Scrollbar accent** — `#849688` (Sage Green) for scrollbar thumbs in the Manager App. Sidebar scrollbars use a translucent cream variant (`rgba(245, 242, 236, 0.2)`) against the sage green sidebar background.

### Typography

| Role | Font | Weight | Notes |
|---|---|---|---|
| Headings, nav labels | Manrope | Bold (700) | Section titles, sidebar labels, modal headers |
| Script body, editor | Crimson Text | Regular (400) | All script text in editor and prompter — humanist serif optimized for reading long-form prose |
| UI labels, controls | Inter | Regular (400), Medium (500) | Button labels, settings fields, metadata |
| Decorative headings | Indie Flower | Regular | Empty states, section intro copy — used sparingly |

**Bundled fonts.** Google Fonts are not available natively in a macOS app. Manrope, Inter, Crimson Text, Indie Flower, and OpenDyslexic are bundled as custom font resources in the app bundle. SF Pro is available as a system fallback only; it is not used as a primary design choice.

**Overlay font options.** The user chooses the prompter typeface from the single Overlay Font picker in Settings > The Notch (REQ-038, REQ-022a). The bundled options include:
- **Crimson Text** (default) — warm, humanist serif; easiest for long-form reading
- **Manrope** — clean geometric sans; better for short dense content (notes, outlines)
- **Inter** — neutral system-adjacent sans; highest familiarity for quick scanning
- **OpenDyslexic** — dyslexia-friendly sans with heavier weighted bases for improved letter differentiation

**Type scale** (base 16pt):

| Label | Size | Usage |
|---|---|---|
| Display | 32pt | Empty state headlines |
| Title | 24pt | Screen titles, modal headers |
| Heading | 18pt | Section headers within screens |
| Body | 16pt | Default body copy, card text |
| Small | 13pt | Metadata, timestamps, secondary labels |
| Script (default) | 20pt | Prompter text — user-adjustable from Settings |

### Spacing

Base grid: 4pt. All spacing values are multiples of 4.

| Step | Value | Usage |
|---|---|---|
| xs | 4pt | Icon padding, tight inline spacing |
| sm | 8pt | Intra-component spacing |
| md | 12pt | Between label and input |
| base | 16pt | Standard component padding |
| lg | 24pt | Section spacing |
| xl | 32pt | Major section breaks |
| 2xl | 48pt | Screen-level padding |
| 3xl | 64pt | Large whitespace, empty state spacing |

### Corner Radii

| Context | Value |
|---|---|
| Cards, inputs | 8pt |
| Panels, sidebar | 16pt |
| Pill windows, overlays, toggles | 24pt |
| Circular elements | 50% |

### Elevation

Aira does not use heavy drop shadows. Elevation is communicated through:
- **Background contrast**: panels sit on a slightly different background color than their container
- **1pt border**: `rgba(0, 0, 0, 0.08)` for cards in light mode; `rgba(255, 255, 255, 0.06)` in dark mode
- No blur or glow effects on Manager App elements
- The Notch/Pill overlay uses `backdropFilter: blur(8px)` to separate from the desktop — this is the one intentional blur usage

---

## 3. Screen Inventory

### Screen 1: Manager App Shell

The persistent main window. This is the user's home base for authoring and managing scripts.

**Window behavior:**
- Standard macOS `NSWindow` with title bar and traffic lights
- Minimum size: 900 × 600pt
- Opens centered on launch; position is saved and restored across sessions

**Layout:**
- Left sidebar (fixed width options: 64pt collapsed, 256pt expanded)
- Right content area (fills remaining width, hosts all sub-screens)
- Sidebar collapse state persists across sessions

**Sidebar anatomy (top to bottom):**
1. App wordmark ("Aira") and sidebar toggle button
2. **New Script** action button — terracotta fill, Manrope Bold label
3. **Go Live** action button — sage green fill, launches session picker (Notch / Pill Window / Both)
4. Navigation section divider
5. Library navigation:
   - All Scripts
   - Starred
   - Recent
   - **Collections** — expandable section showing the user's named collections
     - Each collection name is a navigation item; clicking shows filtered library
     - A "+" icon beside the "Collections" heading opens an inline text field to create a new collection
     - Right-click on a collection name: Rename, Delete (with confirmation that scripts are not deleted)
6. Bottom: Settings link with gear icon

**Sidebar states:**
- Expanded (256pt): icon + label visible
- Collapsed (64pt): icon only, tooltip on hover reveals label
- Active item: sage green fill behind the label, charcoal icon and text

**Content area header bar:**
- Sidebar toggle icon (leftmost)
- Back / forward navigation (when drilling into editor or settings)
- Screen title (center-aligned, Manrope Bold 18pt)
- Context actions (right side, screen-dependent)

**Menu bar quick access:**
- The menu bar popover must appear above the currently active app, including when Aira is not the foreground app, and should follow the user to the active Space.
- Recent script rows are selection rows, not launch rows. Each row shows the script name, word count, and a radio indicator.
- The two primary actions launch the selected script: `Cast [Script Name] to Notch` and `Cast [Script Name] to Notch + Pills`.

---

### Screen 2: Document Library

The default view in the content area. Shows all user scripts (or a filtered subset if a Collection is selected).

**Layout:**
- Sort/filter bar at top: "Sort by" dropdown (Last edited, Alphabetical, Duration), search input
- Script card grid: 3 columns, responsive (drops to 2 at narrow widths)
- **Import drop zone**: a subtle dashed border area at the top of the grid with an Indie Flower label "Drop a .txt file to import". Visible at all times, not just on drag-hover. On drag-hover: border becomes solid sage green, background tints lightly.
- Empty state below grid if no scripts exist
- Entering `Scripts` or returning from editor must render current library contents immediately; document grid must not appear blank until user opens a recent script or otherwise forces a second navigation pass

**Sort/filter bar — selection mode controls:**
- Left side: **Select All checkbox** (always visible). Unchecked by default. Three states: unchecked (none selected), mixed/dash (some selected), checked (all selected). Clicking unchecked → selects all visible scripts and enters selection mode. Clicking checked or mixed → deselects all and exits selection mode.
- Right side: **Trash icon button** — appears only when 1+ scripts are selected. Terracotta color. Clicking shows a confirmation alert: "Delete [N] script[s]? This cannot be undone." with destructive Delete + Cancel. After confirming, deletes all selected, refreshes grid, exits selection mode.

**Script card — selection state:**
- **Checkbox** in the top-left corner of each card. Hidden by default; visible on card hover OR when any script is selected (i.e., selection mode is active).
- Clicking the checkbox toggles that script's selection.
- **⌘+click** anywhere on the card toggles its selection (same as checkbox).
- **Shift+click** anywhere on the card selects the contiguous range from the last-clicked card to the current one.
- Selected cards: sage green ring (same 3pt ring used elsewhere for active state) and a light sage tint behind the card content.
- Escape key exits selection mode, deselecting everything.
- In selection mode, Edit / Cast / Duplicate actions on individual cards are hidden — only the checkbox and card metadata are visible.
- Entering or exiting selection mode must not visually translate existing cards or header content; action areas keep their layout footprint and only change visibility/interactivity.

**Script card anatomy:**
- Title (Manrope Bold, 16pt)
- Last edited timestamp (Inter Regular, 13pt, Slate Blue)
- Estimated duration (Inter Regular, 13pt, Slate Blue) — derived from word count at ~130 WPM
- Collection tags (small Inter pills in sage green, if the script belongs to any collection)
- Hover utility action: **Add to Collection** button shown to the left of the star toggle. Uses `folder.badge.plus` in terracotta, reserves layout space so hover reveal does not shift other utility buttons, and opens the same collection-membership manager used by the context menu.
- Starred toggle (top-right corner of card, filled/outline star)
- Primary action: **Edit** button
- Secondary action: **Cast to Notch** button
- Pill Window launch is intentionally excluded from library-card quick actions in this pass; Pill Window-inclusive launch belongs to the Script Editor where per-Pill Window content choice can be made explicitly.
- Tertiary action: **Duplicate** button (creates a "Copy of [title]" script immediately; the copy opens in the editor for renaming)
- Destructive action: **Delete** button (with confirmation)
- Right-click context menu on card: Edit, Duplicate, Add to Collection…, Cast to Notch, Delete

**Add to Collection manager** (from right-click or hover button):
- List of existing collections with checkboxes (a script can be in multiple)
- "+ New Collection" option at the bottom
- Applies immediately; no save button needed

**Collection drag-and-drop:**
- Script cards are draggable from the Document Library.
- Dropping a script card onto a collection row in the sidebar adds that script to the target collection without removing any existing collection memberships.
- Dropping onto a collection the script already belongs to is a no-op.
- Dragging to collections is available alongside the hover button and context-menu entry; all three paths operate on the same underlying membership state.

**Empty state:**
- Illustration (SVG, hand-drawn style — pencil/page motif)
- Headline in Indie Flower: "Your first script is waiting"
- Sub-copy in Crimson Text
- Large **Create Script** CTA in terracotta

**Import via file picker:**
- "Import Script" button in the content area header bar (right side, alongside New Script)
- Opens macOS standard open panel filtered to `.txt` files
- Same outcome as drag-and-drop: new script created and opened in editor

---

### Screen 3: Script Editor

The full-screen authoring experience within the content area.

**New script lifecycle:**
- Clicking "New Script" opens the editor with a blank in-memory draft. Nothing is written to disk yet.
- On explicit Save: always persists (creates or updates the file).
- On Back (dismiss): auto-save fires if the draft has meaningful content — body is non-empty, or title was changed from "Untitled Script". If both are still default/empty, the draft is silently discarded. No file is created for empty scripts.
- No dirty indicator is shown. Auto-save on dismiss makes it unnecessary.
- No limit on the number of scripts.

**Toolbar (top):**
- Back button (returns to Document Library)
- Script title input (Manrope Bold, editable inline, 20pt)
- Word count + estimated duration (Slate Blue, right-aligned)
- **Save** button (sage green, with hand-drawn save icon)
- **Split launch control**: `[ Cast to Notch ] [ chevron ]`

**Launch behavior:**
- Primary button press on `Cast to Notch` is deterministic and launches only the Notch Window with the current editor script.
- The split launch control renders as one connected button, not as two detached buttons.
- The split launch control keeps compact toolbar height consistent with the original `Cast to Notch` button.
- The primary half does not repeat a second chevron beside the text; only the trailing chevron segment acts as dropdown affordance.
- The dropdown panel uses Aira manager-app styling rather than native macOS menu chrome.
- Clicking outside the dropdown panel dismisses it.
- Chevron dropdown menu entries:
  - `Cast with Pill Windows`
- Choosing the Pill Windows dropdown entry opens follow-up Pill Window launch flow.
- The launch panel shows one section per enabled Pill Window.
- Each Pill Window section offers:
  - `Mirror current script`
  - `Manual`
- A Pill Window set to `Mirror current script` launches with the current editor script mirrored from the notch session; mirrored Pill Windows inherit live Notch session behavior because they are following that shared session.
- A Pill Window set to `Manual` exposes script picker controls inside the same launch panel.
- Missing assignment never falls back silently to mirrored content; the app launches only valid targets and shows lightweight feedback for skipped Pill Windows.

**Main text area:**
- Full-height, no visible border — blends with content area background
- Font: Crimson Text, 18pt default (respects user's size setting from Settings)
- Line height: 1.7 — intentionally generous for readability during delivery rehearsal
- Cue annotations rendered inline as colored pill badges (see Cue formatting below)
- Vertical scroll only; no horizontal overflow

**Cue annotations (REQ-016):**
- Applied via the right Cue panel buttons
- Rendered inline as small pill-shaped labels in terracotta
- Examples: `[Smile]`, `[Pause 2s]`, `[Eye Contact]`, `[Gesture]`, `[Breathe]`, `[Emphasize]`
- Visually distinct from plain script text at a glance
- Preserved when script is loaded into the prompter (rendered as subtle markers in the overlay)

**Right cue panel:**
- Fixed width (200pt), scrollable if cue list grows
- Header: "Performance Cues" in Manrope Bold
- Cue buttons: pill-shaped `RoundedRectangle` buttons in cream with terracotta border
- Clicking a cue inserts the annotation at the current cursor position
- Supporting copy tells users they can create custom cues by typing any cue inside square brackets, such as `[Look up]`.

**No AI button in v1.** The AI enhancement feature is deferred. No AI-related controls appear in the editor.

---

### Screen 4: Settings

A four-tab modal sheet (SwiftUI `.sheet` / AppKit panel), accessible from the sidebar Settings link.

**Tabs:**

#### Tab 1: Appearance
- Light / Dark mode toggle (system default is an additional option)
- Typography panel controls only manager app UI scale. Manager app font faces are fixed: `CrimsonText-Regular` for readable UI text and `IndieFlower` for decorative/display labels.
- Text size: segmented control with Small / Medium / Large options for manager app UI scale

#### Tab 2: The Notch
This tab sets the **shared overlay appearance defaults** plus notch-only sizing controls. Per-window overrides are applied directly on the overlay window via hover chrome / per-window controls (see Screen 8).

- Live preview — a miniature rendering of the overlay appearance at the top of the tab
- Live preview auto-expands within its preview canvas when readability controls need more room, so sample text stays fully visible instead of clipping into the notch cutout
- **Text color**: 4 preset swatches (Cream, White, Charcoal, Warm Tan) + custom color picker
- **Background color**: 5 preset swatches (Sage #849688, Clay #C98B7A, Ink #2B2B2B, Slate #6B8E99, Warm Tan #D4A574) + custom color picker. Default: Sage Green (#849688).
- **Opacity slider**: 20–100%, default 75%. Controls background opacity; text is always fully opaque.
- **Font selector**: Crimson Text (default) / Manrope / Inter / OpenDyslexic — four bundled options
- **Font size**: slider 14pt–32pt, default 20pt
- **Accessibility**: grouped readability controls for text alignment (`Left` / `Center` / `Justified`), line spacing, letter spacing, word spacing, text shadow, and inner text padding
- **Width** (Notch only): slider 400–800pt, default 600pt
- **Height** (Notch only): notch body height slider

#### Tab 3: Pill Windows
- This tab is configuration-only. It defines how Pill Windows look and read; it does not decide what they show during a session.
- If a Pill Window slot has never been customized, it inherits the shared Notch appearance/readability defaults.
- `Pill Window count` segmented control: choose how many Pill Windows are enabled for the session launch flow (`1` or `2`).
- Top switcher: `Pill Window 1` / `Pill Window 2`
- The selected count controls how many Pill Window assignment rows appear in the launch flow and how many mirrored Pill Windows launch from `Cast with Pill Windows`.
- Live preview for selected Pill Window slot
- Appearance controls:
  - opacity
  - font size
  - font
  - background color
  - text color
- Accessibility/readability controls:
  - alignment
  - line spacing
  - letter spacing
  - word spacing
  - text shadow
  - inner text padding
- Supporting note: "Pill Window content is chosen when launching from the Script Editor." — shown in `CrimsonText-Regular` 14pt, muted.

#### Tab 4: System
- **Before your session**
  - Countdown duration: stepper control (0–10 seconds, default 3)
  - Scroll speed: points-per-second slider with live value label, default `10 pt/s`, clamped to `10...30 pt/s`
- **During your session**
  - Voice-activated scroll: toggle (on by default)
  - Spoken-word highlighting: toggle (off by default, visual only, does not alter scroll behavior)
  - Show script progress: toggle (off by default). When enabled, active Notch and Pill overlays show a thin bottom-edge progress line.
  - Mic sensitivity: Low / Medium / High segmented control, enabled for Sound-based and Word tracking modes, disabled for Classic
  - Pause on mouse hover: toggle (on by default)
- **Controls**
  - Keyboard shortcuts: 6 editable shortcut rows
  - Toggle Notch Overlay (default: ⌘⇧N)
  - Toggle Pill Window (default: ⌘⇧P)
  - **Pause / Resume Voice-Sync** (default: ⌘⇧Space) — new in v1
  - Scroll Up (default: ↑ or ⌘↑)
  - Scroll Down (default: ↓ or ⌘↓)
  - End Session (default: ⌘W or Escape)
- **Privacy**
  - Screen sharing visibility toggle
- Scroll Up / Scroll Down shortcuts nudge the text by one rendered line per press, not by a large page jump.

#### Settings modal visual parity update
- The horizontal Preferences tab strip uses the themed surface color: warm cream in light mode and dark charcoal in dark mode.
- The active tab chip uses sage green fill in both light and dark mode.
- Active tab label text stays white in both light and dark mode.
- In dark mode, the Preferences top chrome uses `#484C49`.
- Theme preview swatches in the App Theme panel are small square boxes matching the mockup proportions, not wide rectangles.
- The App Theme preview swatches are horizontally centered within their cards.
- The Light Paper preview swatch remains the same warm cream preview in both light and dark mode; it does not inherit the app theme.
- In the System tab, only section headings use `IndieFlower`; action labels, helper copy, field values, and control labels use `CrimsonText-Regular` for readability.
- The Notch preview canvas background uses `#434343`.
- In Settings, reset/default action buttons and custom color swatches use the full visible control surface as the hit target; interaction must not collapse to text-only or center-only regions.
- In dark mode, script overview cards use `#3A3A3A` as the card surface.
- The Cast to Notch button on script cards always uses the light text color.
- The sidebar New Script action uses pure white label/icon color.
- The script-card Cast button label/icon match the Edit button's white label color.
- Script cards use a slightly larger gap between the outer solid border and inner dashed border than the previous implementation.
- The Pill Windows count/config controls use the same switch dimensions and sage-green tint treatment as the Voice Tracking toggle.
- The Sidebar Scripts navigation item uses a document icon with scribble lines, distinct from the New Script plus icon.
- While Voice-Sync is active, the currently spoken word or short matched phrase is highlighted inline inside the visible reading window using high-contrast emphasis that remains legible against the current overlay appearance.

**No Intelligence tab in v1.** The AI/API Key settings tab is deferred. It does not appear in the Settings sheet.

---

### Screen 5: Notch Window (Overlay)

The primary prompter surface. Fixed in position, anchored beneath the camera notch.

**Window characteristics:**
- `NSPanel` subclass, always-on-top, excluded from screen capture (`sharingType = .none`) by default. Preferences > System includes a user-controlled "Hide overlays from screen sharing" toggle; when off, overlays intentionally remain shareable for screenshots, recordings, and video calls without changing overlay layout/behavior.
- No title bar, no traffic lights, no visible chrome
- Positioned: horizontally centered on the built-in display, top edge touching the bottom of the notch
- The runtime notch cutout keeps left/right overscan at zero relative to the measured notch width. A small sub-point inward seam compensation is allowed on the rendered inner walls to eliminate visible raster slivers without reopening the widened-cutout behavior, and the left/right compensation may differ slightly when needed to avoid even-width raster gaps.
- Width: user-configured (400–800pt range), default 600pt (from global defaults)
- Height: auto-calculated to show approximately 2–3 lines of script text

**Content anatomy (top to bottom):**
1. Start marker — a small downward-pointing triangle above the opening line
2. Notch-safe reading zone — script text starts below the notch cutout rather than directly at the top edge
3. Cue annotations — rendered as small inline labels within the text flow
4. Teleprompter lead-in space — the first unread line enters from lower in the overlay and travels upward through the reading zone
5. Corner audio indicator — sound-wave arcs radiating from a notch corner, outside the text flow

**Script formatting in overlays:**
- Overlay rendering does not preserve every manual line break from the editor verbatim
- Single line breaks inside a paragraph are normalized into flowing wrapped text
- Blank-line paragraph breaks remain visible as paragraph spacing
- Spoken-word tracking visibly highlights the current spoken word or matched phrase inline
- When spoken-word highlighting is enabled, clicking a visible word in the notch or pill overlay reseeds the spoken-word highlight/search anchor to that word without changing the current scroll position
- Spoken-word highlighting is visual only and is clipped to the currently visible overlay word window so off-screen spoken ranges cannot trigger large redraws or influence scroll pacing. If the user skips ahead and speaks a different visible line, a meaningful 3+ word phrase match may become the new highlight anchor without moving the scroll offset.
- Regression note: do not feed whole spoken-prefix ranges into live overlay rendering for classic/manual mode. Large off-screen dull-prefix redraws made classic scroll look jerky and slower even though scroll math itself was unchanged.
- Session-mode switches must fully reset voice-session state. Ending a voice-driven session and later starting a classic/manual session must not inherit any prior recognition callbacks, speech-activity flags, scroll offsets, or voice-mode rendering behavior; a fresh post-quit launch and a post-voice mode switch must behave identically.
- Overlay wheel input must accept intentional manual scrolling without amplifying one physical wheel gesture into multiple scroll mutations. When app is active, global scroll monitors must not double-apply same gesture already delivered through local/AppKit paths, and repeated back-and-forth wheel input in classic/manual highlight-only sessions must never yank script to top or random offset.
- Notch-specific classic/highlight-only guard: when spoken-word highlighting is used in classic/manual notch sessions, wheel gestures over the notch overlay must not mutate script position at all. This guard is notch-only. Manual pill windows continue to accept wheel scrolling, manual pill mode does not render spoken-word highlighting, and manual pill wheel input must still work when the pill is a nonactivating panel by forwarding scroll-wheel events through the pill window's direct AppKit event path before duplicate-collapse logic.
- Pill chrome must reflect actual live behavior, not only stored pill mode. A pill in Sync mode with voice-driven scrolling enabled may show voice chrome, but a pill in Sync mode while presenter is using classic/manual scrolling must not show waveform chrome or reserve a bottom audio lane; it should instead show a sync badge in top-left so users can tell it is shared-position sync, not manual and not voice-driven.
- Active overlay sessions must also react to live System-tab session-setting changes (`Voice-activated scroll`, `Spoken-word highlighting`, `Show script progress`, `Pause on mouse hover`) by rebuilding the overlay content with the new behavior immediately, and overlay close must detach the hosted SwiftUI/AppKit content before the panel is destroyed so stale monitors or display-link work cannot leak into the next session.
- When the System-tab `Show script progress` setting is enabled, active overlays render a 3pt bottom-edge progress line using the current overlay text color for fill and a subtle dark track. The indicator is hidden during countdown and is a visual-only surface; it must not reserve a separate bottom lane, alter scroll math, or intercept pointer input.

**Corner audio indicator:**
- Rendered as 3 animated sound-wave arcs emerging from a top corner of the notch cutout
- Color: Sage Green (#849688), always — not affected by background color settings
- Animation amplitude responds to live microphone RMS level
- Sits outside the script text area so it never obscures readable copy
- Serves as the session activity indicator for the Notch Window

**Countdown overlay:**
- Displayed before Voice-Sync begins, covering the script text
- Full-width, semi-transparent background using the window's current background color
- Centered numeral: Manrope Bold, 48pt, using the window's current text color
- Counts 3 → 2 → 1 → fades out, revealing script text as Voice-Sync starts
- The script text is fully hidden while the countdown is visible; no background copy shows through behind the numeral
- If countdown is set to 0 in Settings, this overlay is skipped entirely

**Hover-to-pause behavior:**
- When cursor enters the window: scroll pauses, cursor changes to a hand icon with a pause indicator
- When cursor exits: scroll resumes from the exact paused position
- No visual change to the overlay content during pause — the pause state is communicated solely through cursor change
- Hover chrome appears only while hovered: top-left `Undock`; when Classic mode is using spoken-word highlighting, a separate `Pause` / `Resume` button appears beside `Undock` so session pause is not conflated with the microphone affordance. Undocked mode also shows `Fullscreen` on the left. Top-right shows microphone and close controls when the mic is active, otherwise pause/resume and close. The microphone button mutes/unmutes capture without marking the session as paused.
- Scope: hover-to-pause applies to the Notch Window only. Pill Windows keep hover chrome but never pause on hover.

**Background appearance (per-window, inherits global defaults):**
- Default: background color at 75% opacity (user-adjustable per-window)
- `backdropFilter: blur(8px)` to separate from desktop content
- No top border (flush merge with the notch's bottom edge)
- Top edge stays flat outside the notch cutout and meets the screen flush without outward flare geometry
- Bottom corners: 16pt radius

**Hover chrome on the Notch Window:**
- Left-side button undocks the notch only when no pill windows are active
- In Classic mode with spoken-word highlighting enabled, a pause/resume button appears beside the dock/undock button
- Once undocked, the dock action remains left-aligned and a fullscreen action appears beside it
- Right-side buttons expose microphone and close affordances when the mic is active; otherwise they expose pause/resume and close. In Classic spoken-word highlighting, the microphone button only mutes/unmutes capture, while the left-side pause button owns session pause/resume.
- The close button ends the active presenter session for the notch, matching Escape / prior end-session action

**Notch sizing during session:**
- Runtime Notch overlay does not expose drag-resize handles or a context-menu size reset.
- Width and height changes for the Notch are made only in Preferences > The Notch and apply when the next session starts.
- Exception: when the notch is undocked, it becomes a free-moving rounded rectangle overlay with pill-style resize handles, no notch cutout, and optional borderless fullscreen on its current display.
- In undocked mode, the corner-wave notch ornament is removed and the shared bottom `VisualBeam` waveform is shown in its own reserved strip below the scrolling text so the script never scrolls behind the indicator.
- Undocking, redocking, or toggling undocked fullscreen must preserve one live voice-scroll driver only; replacing the notch content view must not leave background motion tasks running after the prior view disappears, and closing a session must fully release that motion state before next session starts.

---

### Screen 6: Pill Window (Floating Overlay)

A free-moving overlay window launched explicitly from the Script Editor. A Pill Window can either mirror current script/playhead state from the Notch session or show an explicitly assigned script that scrolls independently.

**Window characteristics:**
- Free-moving `NSPanel`, draggable by clicking and dragging anywhere on the window body
- Resizable by dragging edges or corners
- Can be moved to secondary monitors
- Multiple Pill Windows can be open simultaneously
- Each Pill Window operates independently — closing one does not affect others or the Notch Window
- Same stealth behavior as Notch Window: excluded from screen capture by default, with the same user-controlled System-tab toggle available when overlays should remain shareable
- All four corners are rounded (16pt radius)
- Hover chrome appears in top-right while hovered: `Swap`, `Fullscreen`, `Close`

**Launch relationship indicator:**
- A small badge in the top-left corner of the Pill Window (3pt inside the window edge)
- Mirror-current-script: small sage green sync indicator
- Explicit-script assignment: small hand-pointer icon in Warm Tan
- The badge is only visible on hover; it disappears after 1.5 seconds to avoid distracting during a session

**Content anatomy:**
- **Mirror current script**: identical to Notch Window session content — same script, same scroll position, same pause state, same VisualBeam. Multiple mirrored Pill Windows all track the same content progress.
- If no per-Pill Window appearance/readability override exists yet, a mirrored Pill Window initially renders with the same appearance/readability defaults as the Notch.
- **Explicit script assignment**: assigned script text + cue annotations + a VisualBeam (still reflects microphone level for awareness, but does not drive scroll). Scroll is driven by user input only.
- When `Show script progress` is enabled, mirrored Pill Windows use the shared session progress and manual assigned Pill Windows use their own local rendered progress.
- A Pill Window never opens with an empty or whitespace-only resolved script. Empty assigned Pill Windows are skipped, and a standalone Pill Window shortcut attempt shows an Aira-branded popup instead of opening an empty window.
- Mouse wheel / trackpad scrolling on an explicitly assigned Pill Window remains available whenever the pointer is over the Pill Window.
- The global **Pause on mouse hover** setting does not apply to Pill Windows. Hovering a Pill Window must never pause motion or block wheel / trackpad scrolling.

**Assigned script label (Manual mode only):**
- A small Inter label at the bottom edge of the pill showing the script title in Slate Blue
- Visible on hover only, fades after 1.5 seconds

**Default size:** 600pt × 180pt (shows 3–4 lines of script)

**Dragging:** The entire window body is the drag handle. No title bar or handle strip is shown.

**Hover chrome on any Pill Window:**
- Right-edge controls expose swap, fullscreen, and close affordances on hover
- Swap button is shown only for manual pills with an active notch and uses same script-exchange action previously exposed through pill controls
- Fullscreen button is enabled only when pill is on a secondary display; on built-in/main display it remains visible but disabled
- Pill fullscreen uses a borderless fill/restore treatment on the secondary display rather than entering a titled native fullscreen space, so exiting returns cleanly to the prior pill frame without adding a title bar
- The close button closes only that pill window

---

### Screen 7: Pill Window Launch Chooser + Assignment Popup
Shown from the Script Editor when the user opens the launch dropdown and selects `Cast with Pill Windows`.

**Trigger:** User clicks the chevron beside `Cast to Notch` and selects `Cast with Pill Windows`.

**Step 1: Launch dropdown**
- Anchored to the chevron side of the split button
- Options:
  - `Cast with Pill Windows`

**Step 2: Pill Window launch panel**
- Compact sheet or popup (~420pt wide) centered over the Script Editor
- One section per enabled Pill Window
- Each section includes:
  - slot label (`Pill Window 1`, `Pill Window 2`)
  - `Mirror current script` full-width choice button
  - `Manual` full-width choice button
  - when `Manual` selected: collapsed script dropdown showing the selected script title or `Select script`
  - opening the script dropdown lists library scripts sorted by last edited, with search affordance if list is long
  - selecting a script immediately collapses the dropdown
- Manual script dropdown rows are full-width click targets, not text-only targets.
- All interactive controls in the panel use a pointing-hand cursor across the whole visible hit target on hover.
- Primary action: `Launch`
- Secondary action: `Cancel`

**Multiple Pill Windows:**
- If one Pill Window is configured, one row is shown.
- If two Pill Windows are configured, two independent sections are shown.
- One Pill Window may mirror while the other uses an explicitly chosen script.
- Unassigned or empty `Manual` sections are skipped rather than silently mirrored; launch feedback explains skipped Pill Windows.

---

### Screen 8: Aira Message Popup

A compact in-window popup for manager-level messages that should match Aira's custom visual language instead of using native macOS alert chrome.

**Empty script launch error:**
- Triggered when `Cast to Notch` is pressed with a script body containing zero non-whitespace characters.
- The manager window remains visible; no presenter session starts.
- Popup content:
  - eyebrow: `Cast paused`
  - title: `Add script text first`
  - body: `Write or paste a few words before casting to the notch.`
  - primary action: `OK`
- Visual style matches the custom update prompt: cream card, sage border, Indie Flower title, Crimson body copy, and Aira-styled primary action.
- Dismissal clears the launch error message.

---

### Screen 9: Overlay Appearance Popover

A per-window appearance override panel. Accessed from overlay-local controls when appearance actions are exposed.

**Layout:** A floating popover (240pt wide) anchored near the cursor position, with an arrow pointing at the overlay window. Uses the Manager App's surface color.

**Controls (top to bottom):**
1. **Section label**: the window name ("Notch Window" or "Pill [n]") in Manrope Bold Small
2. **Mini live preview strip** — a 32pt tall preview showing the current font, colors, and opacity
3. **Text Color** — row of 4 presets (Cream, White, Warm Tan, HY) + custom color well
4. **Background Color** — row of 4 presets (Sage Green, Charcoal, Navy, Warm Brown) + custom color well
5. **Opacity** — slider 20–100%
6. **Font** — segmented control: [Crimson Text] [Manrope] [Inter]
7. **Font Size** — slider 14pt–32pt
8. **Reset to Defaults** link — restores this window's settings to the current global defaults from Settings > Overlays
9. Popover auto-dismisses when clicking outside it

Changes apply live as the user adjusts controls — no confirm step required.

---

### Screen 10: Update Prompt

A compact Aira-branded update popup shown when Sparkle finds a newer version or finishes downloading one.

This screen exists only in direct-distribution builds. Mac App Store builds do not show updater UI because App Store delivery owns update discovery and installation.

**Purpose:**
- Replaces Sparkle's stock "update found" and "ready to install" prompts
- Keeps update decisions inside Aira's visual language
- Uses the same calm, low-friction presentation as the rest of the app

**Window behavior:**
- Small floating panel centered over the key app window when possible
- Borderless panel with shadow
- Remains key and focusable while visible
- Dismissing the panel maps to Sparkle's cancel / dismiss action

**Layout:**
1. Version badge at top-left in a sage green capsule
2. Title in Indie Flower
3. Body copy in Crimson Text
4. Secondary `Cancel` button
5. Primary terracotta action button

**States:**
- **Update found**
  - Title: `Update ready`
  - Primary action: `Update Now`
  - Secondary action: `Cancel`
- **Ready to install**
  - Title: `Ready to install`
  - Primary action: `Install & Relaunch`
  - Secondary action: `Cancel`

**Visual styling:**
- Background: `colorBackground`
- Border: 1.5pt sage green at low opacity
- Corner radius: 22pt
- Width: ~360pt
- Height: ~220pt
- Primary button uses the same terracotta CTA treatment as other Aira actions
- Secondary button uses the app's subdued secondary style

**Scope:**
- Only the decision prompts are custom in v1
- Download progress, extraction progress, and updater errors may continue using Sparkle's standard UI until a later polish pass
- Mac App Store builds omit this screen entirely and do not expose a `Check for Updates…` command

---

## 4. Design Philosophy — Native with Character

Aira follows a "warm native" principle: the structural chrome of the app is clean macOS-native, and the personality lives in icons, typography, and color.

**What this means in practice:**

- `WobblyPanel` and `WobblyButton` from the React mockup are **not carried forward** into the Swift app. The wobbly SVG outlines are a browser/canvas trick that feels awkward in a native macOS app. Replace them with `RoundedRectangle` shapes using the earthy color tokens.

- The **hand-drawn SVG icons** from `HandDrawnIcon.tsx` **are carried forward** as SwiftUI `Shape` paths or bundled SVG image assets. These icons — library, edit, settings, notch, plus, trash, save, back — are the personality layer. They have a subtle imperfection (slight stroke weight variation) that distinguishes Aira from generic SFSymbol-heavy apps.

- **Crimson Text in the editor and prompter is preserved** as the default. It is warm, legible, and immediately distinct from system UI. It signals "this is a reading surface" without any additional chrome. Users may switch to Manrope or Inter if their content suits a sans-serif.

- **Indie Flower is used sparingly** — only in empty states and section headings where a bit of warmth is appropriate. It must not appear in functional UI controls.

- The result: macOS-credible structure (panels, cards, sheets behave as users expect) with Aira's personality expressed through color, custom icons, and typography.

---

## 5. Component Catalog

| Component | Description | Notes |
|---|---|---|
| `SidebarButton` | Custom icon (hand-drawn SVG path) + Manrope Bold label. Active state: sage green fill. Collapsed: icon only, tooltip on hover. | REQ-014 |
| `CollectionRow` | Sidebar nav item for a named collection. Expandable to show script count. Right-click for Rename/Delete. | REQ-037 |
| `ScriptCard` | `RoundedRectangle` card, 8pt radius, 1pt sage green border, cream fill. Title + metadata + collection tags + action buttons. | REQ-014, REQ-015, REQ-036, REQ-037 |
| `CollectionTag` | Small pill label in sage green on script cards. Shows which collections the script belongs to. | REQ-037 |
| `ImportDropZone` | Top area of Document Library with dashed border and Indie Flower label. Accepts `.txt` drag-and-drop. Border becomes solid sage green on drag-hover. | REQ-035 |
| `CueButton` | Pill-shaped `RoundedRectangle` button. Cream fill, terracotta border, Inter label. Click inserts annotation at cursor. | REQ-016 |
| `VisualBeam` | Row of 8 animated `RoundedRectangle` bars, sage green, heights driven by microphone RMS level. Used by Pill overlays and any embedded-audio indicator surfaces. | REQ-004 |
| `CountdownOverlay` | Full-overlay with large Manrope numeral centered. Background and text colors respect the window's current `OverlayAppearance`. Fades between counts. Skipped if duration is 0. | REQ-012, REQ-013 |
| `OverlayWindow` | Shared layout shell for Notch and Pill windows. No title bar, no chrome. Hosts script text, cue labels, countdown, and the appropriate audio indicator for that overlay style. | REQ-005, REQ-006, REQ-008, REQ-009 |
| `ContentModeIndicator` | Small badge in top-left corner of Pill Windows. Indicates mirrored-current-script vs explicitly assigned-script launch state. Visible on hover only. | REQ-034 |
| `CueAnnotation` | Small pill-shaped inline label in terracotta, rendered within script text flow. Distinct from plain text. | REQ-016, REQ-018 |
| `PillWindowLaunchChooser` | Chevron dropdown attached to `Cast to Notch`, with one `Cast with Pill Windows` menu item. | REQ-034 |
| `PillWindowAssignmentPopup` | Compact launch panel for per-Pill Window assignment, allowing each enabled Pill Window to choose `Mirror current script` or `Manual` before launch. | REQ-034 |
| `OverlayAppearancePopover` | Per-window appearance override panel accessed via right-click. Live preview strip + controls for text color, background color, opacity, font, font size. | REQ-038 |
| `UpdatePrompt` | Compact Aira-branded Sparkle update decision panel with version badge, calm copy, and `Update Now` / `Cancel` actions. | REQ-030 |
| `EmptyState` | Illustration + Indie Flower headline + Crimson Text sub-copy + terracotta CTA. Used in Document Library when no scripts exist. | — |
| `ShortcutRow` | Label + editable keyboard shortcut recorder. Used in Settings > System tab. | REQ-039 |
| `FontSelector` | Segmented control or dropdown offering Crimson Text / Manrope / Inter. Used in Settings > Overlays and OverlayAppearancePopover. | REQ-038 |

---

## 6. Interaction States

| Interaction | Behavior | Visual |
|---|---|---|
| Hover over overlay window | Scroll pauses | Cursor changes to hand with pause indicator; ContentModeIndicator badge fades in |
| Cursor exits overlay | Scroll resumes from paused position | Cursor returns to default; badge fades out |
| Voice detected | Script advances, VisualBeam animates | Bar heights increase with audio level |
| Silence / no speech | Scroll halts | VisualBeam bars settle to minimum height |
| Countdown active | Script does not scroll; countdown numeral shown | CountdownOverlay visible, fade between numerals |
| Keyboard Voice-Sync toggle (⌘⇧Space) | Voice-Sync pauses/resumes | VisualBeam dims on pause; brightens on resume |
| Stealth check fails (REQ-007) | Warning banner shown in Manager App before session starts | Yellow banner above "Go Live" button with explanatory copy |
| Script card hover | Subtle background tint on card; all action buttons fully visible | Warm Tan tint |
| Right-click on script card | Context menu: Edit, Duplicate, Add to Collection…, Cast, Delete | Native macOS context menu |
| Drag .txt file over Document Library | Import drop zone activates | Dashed border → solid sage green border, light tint fill |
| Drop .txt file | New script created, opens in editor | Smooth navigation to editor with imported content |
| Script Duplicate action | Copy created immediately | Library refreshes; new card appears with "Copy of [title]" |
| Hover overlay action controls | Per-window close / future overlay actions | Hover-only chrome inside overlay window |
| Overlay Appearance Popover open | Per-window appearance controls visible | Live preview strip updates in real-time as controls change |
| Sparkle update found (direct build only) | Small branded update prompt appears instead of the stock Sparkle alert | Version badge visible; `Update Now` / `Cancel` actions use Aira button styling |
| Sparkle update ready to install (direct build only) | Same branded prompt style reused for install step | Primary action changes to `Install & Relaunch` |
| `Cast with Pill Windows` dropdown choice | Launch panel opens | One section per enabled Pill Window appears |
| Assign script to Pill Window | Launch panel | Script picker appears in that Pill Window section |
| Sidebar collapsed | Navigation icons only | Tooltip on hover reveals label |
| Settings open | Content area dims slightly | Sheet slides up from bottom of Manager App window |
| Collection nav item clicked | Document Library filters to show only scripts in that collection | Header bar shows collection name; "All Scripts" link to clear filter |
| Create Collection (sidebar "+") | Inline text field appears | Type name, press Enter to confirm |
| Cue button click | Cue annotation inserted at cursor | Inline pill label appears in editor text |

---

## 7. Accessibility Considerations

- All color choices meet WCAG AA contrast ratio for body text (4.5:1 minimum) against their backgrounds. The custom background color picker in Settings does not prevent users from choosing low-contrast combinations, but the live preview in the Overlay Appearance Popover makes the result immediately visible.
- Font sizes are user-adjustable through Settings (S/M/L and font size slider in Overlays tab)
- Overlay readability controls separate font choice from layout tuning: the single Overlay Font picker includes OpenDyslexic, while Accessibility covers alignment, spacing, text shadow, and inner padding
- Interactive controls are keyboard-navigable following standard macOS tab order
- Overlay windows do not trap keyboard focus — the user's main window remains active during a presenter session
- The VisualBeam provides audio feedback via visual animation; it is not the sole indicator of session state
- Tooltip labels on collapsed sidebar icons ensure icon-only navigation remains accessible
- The ContentModeIndicator badge uses both color and icon shape to distinguish mirrored-current-script vs explicitly assigned-script state (not color-only)
- The import drop zone has a visible affordance at rest (dashed border + label), not only on drag-hover

---

## Requirement Coverage

| Requirement | Covered by |
|---|---|
| REQ-001 Voice-Driven Scroll | Notch Window, Voice-Sync mode Pill Windows — script advances with speech |
| REQ-002 Pause On Silence | All Voice-Sync windows — scroll halts; VisualBeam dims |
| REQ-003 Manual Scroll Override | Mouse wheel / trackpad scrolling in overlay windows; line-by-line keyboard nudges; `pt/s` speed slider in Settings > System |
| REQ-004 Visual Beam Feedback | VisualBeam component in all overlay windows |
| REQ-005 Prompter Hidden From Screen Share | OverlayWindow uses stealth flag; no visual cue needed |
| REQ-006 Prompter Visible To User | Overlay windows fully visible on local display at all times |
| REQ-007 Stealth Failure Notification | Yellow warning banner in Manager App before session starts |
| REQ-008 Notch Window | Screen 5 — fixed-position NSPanel beneath notch |
| REQ-009 Pill Windows | Screen 6 — free-moving, resizable, multi-instance NSPanel |
| REQ-010 Hover-To-Pause | Interaction state on all overlay windows |
| REQ-011 Resume After Hover | Cursor exit resumes from paused offset |
| REQ-012 Pre-Session Countdown | CountdownOverlay component in all overlay windows |
| REQ-013 Configurable Countdown | Settings > Overlays > countdown duration stepper |
| REQ-014 Built-In Script Editor | Screen 3 — full editor with title, body, cue panel |
| REQ-015 Local Script Storage | No cloud sync UI; no upload buttons; delete removes local file |
| REQ-016 Speech Cue Formatting | Cue panel in editor; CueAnnotation inline rendering |
| REQ-017 Report-To-Natural | Deferred — no UI in v1 |
| REQ-018 Cues In Converter Output | Deferred — no UI in v1 |
| REQ-019 BYOK Requirement | Deferred — no API key UI in v1 |
| REQ-020 API Key Privacy | Deferred — no UI in v1 |
| REQ-021 Window Size Adjustment | Pill Window drag-to-resize; Notch Window width slider in Settings > Overlays |
| REQ-022 Text Size Adjustment | Settings > Overlays > font size slider; OverlayAppearancePopover per-window |
| REQ-023 Custom Text Colors | Settings > Overlays > text color presets + custom picker; per-window via OverlayAppearancePopover |
| REQ-024 Mood Presets | Removed from Preferences. Overlay appearance is configured directly through the individual controls in Settings > The Notch. |
| REQ-025 Local-First Architecture | No sync UI, no account UI, no upload affordances |
| REQ-026 No Telemetry | No analytics consent dialogs, no reporting UI |
| REQ-027 No Account Required | No sign-in screen, no profile UI |
| REQ-028 Free Distribution | No paywall UI, no subscription prompts |
| REQ-029 Signed And Notarized | No UI impact — build/distribution concern |
| REQ-030 Distribution Channels | Direct build uses Screen 10 Update Prompt plus GitHub Releases / Sparkle surfaces; Mac App Store build omits in-app updater surfaces |
| REQ-031 Closed-Source Policy | No UI impact — repository concern |
| REQ-032 Live Answer Mode | Experimental — opt-in toggle in Settings (labeled "Experimental"), disabled by default |
| REQ-033 Experimental Transparency | Plain-language disclosure modal shown before first activation of Live Answer Mode |
| REQ-034 Pill Window Launch Assignment | Screen 3 split launch control; Screen 7 PillWindowLaunchChooser + PillWindowAssignmentPopup |
| REQ-035 Script Import | ImportDropZone in Document Library; "Import Script" button in header bar |
| REQ-036 Script Duplication | Duplicate button on ScriptCard; right-click context menu |
| REQ-037 Collections | CollectionRow in sidebar; CollectionTag on script cards; Add to Collection popover |
| REQ-038 Per-Window Overlay Appearance | Screen 9 OverlayAppearancePopover; Settings > Overlays for global defaults |
| REQ-039 Keyboard Voice-Sync Toggle | Settings > System > Pause/Resume Voice-Sync shortcut row (default ⌘⇧Space) |
| REQ-040 Scroll Progress Indicator | Settings > System toggle plus thin bottom-edge progress line in active Notch/Pill overlays |
| REQ-041 Session Elapsed Timer | Deferred — no UI in v1 |
| REQ-042 Jump-To-Top | Deferred — no UI in v1 |
| REQ-043 Mirror Mode | Deferred — no UI in v1 |
