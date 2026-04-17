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

**Bundled fonts.** Google Fonts are not available natively in a macOS app. Manrope, Inter, Crimson Text, and Indie Flower are bundled as custom font resources in the app bundle. SF Pro is available as a system fallback only; it is not used as a primary design choice.

**Overlay font options.** The user can select the font for prompter display from three bundled options (REQ-038):
- **Crimson Text** (default) — warm, humanist serif; easiest for long-form reading
- **Manrope** — clean geometric sans; better for short dense content (notes, outlines)
- **Inter** — neutral system-adjacent sans; highest familiarity for quick scanning

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
| Pills, overlays, toggles | 24pt |
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
3. **Go Live** action button — sage green fill, launches session picker (Notch / Pill / Both)
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

---

### Screen 2: Document Library

The default view in the content area. Shows all user scripts (or a filtered subset if a Collection is selected).

**Layout:**
- Sort/filter bar at top: "Sort by" dropdown (Last edited, Alphabetical, Duration), search input
- Script card grid: 3 columns, responsive (drops to 2 at narrow widths)
- **Import drop zone**: a subtle dashed border area at the top of the grid with an Indie Flower label "Drop a .txt file to import". Visible at all times, not just on drag-hover. On drag-hover: border becomes solid sage green, background tints lightly.
- Empty state below grid if no scripts exist

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
- Starred toggle (top-right corner of card, filled/outline star)
- Primary action: **Edit** button
- Secondary action: **Cast to Notch** button
- Tertiary action: **Duplicate** button (creates a "Copy of [title]" script immediately; the copy opens in the editor for renaming)
- Destructive action: **Delete** button (with confirmation)
- Right-click context menu on card: Edit, Duplicate, Add to Collection…, Cast to Notch, Delete

**Add to Collection popover** (from right-click):
- List of existing collections with checkboxes (a script can be in multiple)
- "+ New Collection" option at the bottom
- Applies immediately; no save button needed

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
- **Cast to Notch** button (terracotta)

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

**No AI button in v1.** The AI enhancement feature is deferred. No AI-related controls appear in the editor.

---

### Screen 4: Settings

A three-tab modal sheet (SwiftUI `.sheet` / AppKit panel), accessible from the sidebar Settings link.

**Tabs:**

#### Tab 1: Appearance
- Light / Dark mode toggle (system default is an additional option)
- Manager App font selector: dropdown with Crimson Text (default), Manrope, Inter
- Text size: segmented control with S / M / L options (maps to 16pt / 20pt / 26pt in the prompter)

#### Tab 2: Overlays
This tab sets the **global defaults** that apply when any new overlay window (Notch or Pill) is first created. Per-window overrides are applied directly on the overlay window via right-click (see Screen 8).

- Live preview — a miniature rendering of the overlay appearance at the top of the tab
- **Text color**: 4 preset swatches (Cream, White, Charcoal, Warm Tan) + custom color picker
- **Background color**: 5 preset swatches (Sage #849688, Clay #C98B7A, Ink #2B2B2B, Slate #6B8E99, Warm Tan #D4A574) + custom color picker. Default: Sage Green (#849688).
- **Opacity slider**: 20–100%, default 75%. Controls background opacity; text is always fully opaque.
- **Font selector**: Crimson Text (default) / Manrope / Inter — three bundled options
- **Font size**: slider 14pt–32pt, default 20pt
- **Width** (Notch only): slider 400–800pt, default 600pt
- **Countdown duration**: stepper control (0–10 seconds, default 3)
- **Mood Presets**: a row of preset swatches at the bottom of the tab. Clicking a preset applies all appearance settings at once. At launch: "Day" (Sage Green bg, Cream text) and "Night" (Charcoal bg, Warm Tan text). Each preset is a circular swatch + Inter label. Sage green ring indicates the active preset.

**Pill Windows section** (below Mood Presets, within the Overlays tab):
- **Enable Pill Windows** toggle. Off by default. When off, the controls below are disabled/dimmed.
- **Number of Pills**: segmented control with options 1 and 2. Enabled only when the toggle is on. Defaults to 1 on first enable.
- Note text below the count selector: "Pill windows inherit the appearance settings above. Customise each pill in-session via right-click." — shown in `CrimsonText-Regular` 14pt, muted.

#### Tab 3: System
- Keyboard shortcuts: 6 editable shortcut rows
  - Toggle Notch Overlay (default: ⌘⇧N)
  - Toggle Pill Window (default: ⌘⇧P)
  - **Pause / Resume Voice-Sync** (default: ⌘⇧Space) — new in v1
  - Scroll Up (default: ↑ or ⌘↑)
  - Scroll Down (default: ↓ or ⌘↓)
  - End Session (default: ⌘W or Escape)
- Voice panel:
  - Support text: "Moves only when human speech is recognized, uses your configured WPM, and keeps the script anchored smoothly."
- Manual Scroll & Voice Pace panel:
  - WPM slider with live value label, shown as `NNN WPM`
  - Range: `100...300 WPM`
  - Default: `135 WPM`
  - Support text: "Sets the speed for Manual scroll and Cinematic Voice-Sync."
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
- In dark mode, script overview cards use `#3A3A3A` as the card surface.
- The Cast to Notch button on script cards always uses the light text color.
- The sidebar New Script action uses pure white label/icon color.
- The script-card Cast button label/icon match the Edit button's white label color.
- Script cards use a slightly larger gap between the outer solid border and inner dashed border than the previous implementation.
- The Pill Windows enable control uses the same switch dimensions and sage-green tint treatment as the Voice Tracking toggle.
- The Sidebar Scripts navigation item uses a document icon with scribble lines, distinct from the New Script plus icon.
- Speech sensitivity: slider (Low / Medium / High), affects VAD threshold
- Voice-activated scroll: toggle (on by default)
- While Voice-Sync is active, the currently spoken word is emphasized inline using bold weight and a slightly larger size rather than a colored highlight box.

**No Intelligence tab in v1.** The AI/API Key settings tab is deferred. It does not appear in the Settings sheet.

---

### Screen 5: Notch Window (Overlay)

The primary prompter surface. Fixed in position, anchored beneath the camera notch.

**Window characteristics:**
- `NSPanel` subclass, always-on-top, excluded from screen capture (`sharingType = .none`)
- No title bar, no traffic lights, no visible chrome
- Positioned: horizontally centered on the built-in display, top edge touching the bottom of the notch
- The runtime notch cutout matches the measured hardware width exactly; the live cutout does not add left/right overscan beyond the physical notch walls
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
- Spoken-word tracking does not visibly bold or enlarge the current word

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

**Background appearance (per-window, inherits global defaults):**
- Default: background color at 75% opacity (user-adjustable per-window)
- `backdropFilter: blur(8px)` to separate from desktop content
- No top border (flush merge with the notch's bottom edge)
- Bottom corners: 16pt radius

**Right-click context menu on the Notch Window:**
- **Appearance…** — opens the Overlay Appearance Popover (Screen 8) for this window
- **Reset to Defaults** — resets this window's appearance to current global defaults
- **End Session** — equivalent to pressing Escape

---

### Screen 6: Pill Window (Floating Overlay)

A free-moving overlay window that can operate in Sync mode (follows the same script and scroll state as the Notch) or Manual mode (shows an independently assigned script).

**Window characteristics:**
- Free-moving `NSPanel`, draggable by clicking and dragging anywhere on the window body
- Resizable by dragging edges or corners
- Can be moved to secondary monitors
- Multiple Pill Windows can be open simultaneously
- Each Pill Window operates independently — closing one does not affect others or the Notch Window
- Same stealth behavior as Notch Window: excluded from screen capture
- All four corners are rounded (16pt radius)

**Content mode indicator:**
- A small badge in the top-left corner of the pill (3pt inside the window edge)
- Sync mode: small sage green waveform icon (same style as VisualBeam but smaller)
- Manual mode: small hand-pointer icon in Warm Tan
- The badge is only visible on hover; it disappears after 1.5 seconds to avoid distracting during a session

**Content anatomy:**
- **Sync mode**: identical to Notch Window — same script, same scroll position, same pause state, same VisualBeam. Multiple Sync pills all track the same cursor position.
- **Manual mode**: the assigned script's text + cue annotations + a VisualBeam (still reflects microphone level for awareness, but does not drive scroll). Scroll is driven by user input only.

**Assigned script label (Manual mode only):**
- A small Inter label at the bottom edge of the pill showing the script title in Slate Blue
- Visible on hover only, fades after 1.5 seconds

**Default size:** 600pt × 180pt (shows 3–4 lines of script)

**Dragging:** The entire window body is the drag handle. No title bar or handle strip is shown.

**Right-click context menu on any Pill Window:**
- **Switch to Sync Mode** / **Switch to Manual Mode** (toggles)
- **Assign Script…** (Manual mode only) — opens the script picker popover
- **Appearance…** — opens the Overlay Appearance Popover (Screen 8) for this window
- **Reset to Defaults** — resets this window's appearance to current global defaults
- **Close Pill** — closes this pill window only

---

### Screen 7: Pill Setup Sheet

Shown when the user creates a new Pill Window — either from the "Go Live" session picker or the "Add Pill" action during an active session.

**Trigger:** User selects "Pill Window" or "Both" in the Go Live session picker, or clicks "Add Pill" from the Manager App during a live session.

**Layout:** A compact sheet (400pt wide, ~260pt tall) that appears centered over the Manager App window.

**Controls (top to bottom):**
1. **Sheet title**: "New Pill Window" in Manrope Bold
2. **Content Mode** — segmented control:
   - [Sync] — follows the same script and scroll state as the Notch
   - [Manual] — shows a different script, user scrolls by hand
3. **Script selector** (shown only when Manual is selected):
   - Dropdown listing all scripts from the library, sorted by last edited
   - Search field at the top of the dropdown
   - Default: the most recently edited script
4. **Launch** button (terracotta, full-width) — creates the pill and dismisses the sheet
5. **Cancel** link (Slate Blue, small Inter)

**Multiple pills:** Each pill goes through its own setup sheet when created. Sync pills all share the same cursor position and paused/running state as the active session.

---

### Screen 8: Overlay Appearance Popover

A per-window appearance override panel. Accessed via right-click on any overlay window → "Appearance…".

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

### Screen 9: Update Prompt

A compact Aira-branded update popup shown when Sparkle finds a newer version or finishes downloading one.

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
| `MoodPreset` | Circular color swatch + Inter label. Selection indicated by sage green ring. Applies full appearance bundle. | REQ-024 |
| `OverlayWindow` | Shared layout shell for Notch and Pill windows. No title bar, no chrome. Hosts script text, cue labels, countdown, and the appropriate audio indicator for that overlay style. | REQ-005, REQ-006, REQ-008, REQ-009 |
| `ContentModeIndicator` | Small badge (waveform icon for Sync, hand icon for Manual) in top-left corner of Pill windows. Visible on hover only. | REQ-034 |
| `CueAnnotation` | Small pill-shaped inline label in terracotta, rendered within script text flow. Distinct from plain text. | REQ-016, REQ-018 |
| `PillSetupSheet` | Compact sheet for configuring a new Pill Window: content mode selector + script picker (Manual mode). | REQ-034 |
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
| Right-click on overlay window | Context menu for per-window controls | Native macOS context menu |
| Overlay Appearance Popover open | Per-window appearance controls visible | Live preview strip updates in real-time as controls change |
| Sparkle update found | Small branded update prompt appears instead of the stock Sparkle alert | Version badge visible; `Update Now` / `Cancel` actions use Aira button styling |
| Sparkle update ready to install | Same branded prompt style reused for install step | Primary action changes to `Install & Relaunch` |
| Pill content mode switch (Sync ↔ Manual) | Pill immediately switches source | ContentModeIndicator badge changes icon |
| Assign Script to Manual Pill | Script picker popover | Dropdown list of scripts, search field |
| Sidebar collapsed | Navigation icons only | Tooltip on hover reveals label |
| Settings open | Content area dims slightly | Sheet slides up from bottom of Manager App window |
| Collection nav item clicked | Document Library filters to show only scripts in that collection | Header bar shows collection name; "All Scripts" link to clear filter |
| Create Collection (sidebar "+") | Inline text field appears | Type name, press Enter to confirm |
| Cue button click | Cue annotation inserted at cursor | Inline pill label appears in editor text |

---

## 7. Accessibility Considerations

- All color choices meet WCAG AA contrast ratio for body text (4.5:1 minimum) against their backgrounds. The custom background color picker in Settings does not prevent users from choosing low-contrast combinations, but the live preview in the Overlay Appearance Popover makes the result immediately visible.
- Font sizes are user-adjustable through Settings (S/M/L and font size slider in Overlays tab)
- Interactive controls are keyboard-navigable following standard macOS tab order
- Overlay windows do not trap keyboard focus — the user's main window remains active during a presenter session
- The VisualBeam provides audio feedback via visual animation; it is not the sole indicator of session state
- Tooltip labels on collapsed sidebar icons ensure icon-only navigation remains accessible
- The ContentModeIndicator badge uses both color and icon shape to distinguish Voice-Sync vs. Manual (not color-only)
- The import drop zone has a visible affordance at rest (dashed border + label), not only on drag-hover

---

## Requirement Coverage

| Requirement | Covered by |
|---|---|
| REQ-001 Voice-Driven Scroll | Notch Window, Voice-Sync mode Pill Windows — script advances with speech |
| REQ-002 Pause On Silence | All Voice-Sync windows — scroll halts; VisualBeam dims |
| REQ-003 Manual Scroll Override | Mouse wheel / trackpad scrolling in overlay windows; line-by-line keyboard nudges; WPM speed slider in Settings > System |
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
| REQ-024 Mood Presets | MoodPreset row in Settings > Overlays; includes text color, background color, opacity |
| REQ-025 Local-First Architecture | No sync UI, no account UI, no upload affordances |
| REQ-026 No Telemetry | No analytics consent dialogs, no reporting UI |
| REQ-027 No Account Required | No sign-in screen, no profile UI |
| REQ-028 Free Distribution | No paywall UI, no subscription prompts |
| REQ-029 Signed And Notarized | No UI impact — build/distribution concern |
| REQ-030 Distribution Channels | Screen 9 Update Prompt plus GitHub Releases / Sparkle distribution surfaces |
| REQ-031 Closed-Source Policy | No UI impact — repository concern |
| REQ-032 Live Answer Mode | Experimental — opt-in toggle in Settings (labeled "Experimental"), disabled by default |
| REQ-033 Experimental Transparency | Plain-language disclosure modal shown before first activation of Live Answer Mode |
| REQ-034 Pill Content Mode | Screen 7 PillSetupSheet; Screen 6 right-click → Switch Mode; ContentModeIndicator badge |
| REQ-035 Script Import | ImportDropZone in Document Library; "Import Script" button in header bar |
| REQ-036 Script Duplication | Duplicate button on ScriptCard; right-click context menu |
| REQ-037 Collections | CollectionRow in sidebar; CollectionTag on script cards; Add to Collection popover |
| REQ-038 Per-Window Overlay Appearance | Screen 8 OverlayAppearancePopover; Settings > Overlays for global defaults |
| REQ-039 Keyboard Voice-Sync Toggle | Settings > System > Pause/Resume Voice-Sync shortcut row (default ⌘⇧Space) |
| REQ-040 Scroll Progress Indicator | Deferred — no UI in v1 |
| REQ-041 Session Elapsed Timer | Deferred — no UI in v1 |
| REQ-042 Jump-To-Top | Deferred — no UI in v1 |
| REQ-043 Mirror Mode | Deferred — no UI in v1 |
