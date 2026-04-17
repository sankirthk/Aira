# NotchPrompt Control Hub - Complete Color Audit

## 🎨 PRIMARY COLOR PALETTE (Brand Colors)

### 1. **Sage Green** - `#849688`
**Brand Primary | Accent | Interactive**

#### Backgrounds:
- **Sidebar** (`ManagerApp.tsx`): Full sidebar background
- **WobblyPanel** (`DocumentLibrary.tsx`, `ScriptEditor.tsx`): Panel backgrounds with `bgColor="#849688"`
- **Settings panels** (`Settings.tsx`, `NotchPreview.tsx`): Sage green accent panels
- **Script Editor header** (`ScriptEditor.tsx`): Top toolbar background
- **SettingsModal tabs** (`SettingsModal.tsx`): Active tab background
- **VoiceOscilloscope** (`VoiceOscilloscope.tsx`): Main waveform stroke, glow effects

#### Interactive States:
- **Hover states**: `hover:bg-[#849688]/20` (navigation items, toolbar buttons)
- **Dark mode hover**: `dark:hover:bg-[#849688]/30` (enhanced visibility in dark)
- **Button backgrounds**: Toggle switches in "ON" state
- **Border accent**: `border-[#849688]` (selected theme cards, focused inputs)

#### Opacity Variations:
- `#849688` (100% - solid backgrounds)
- `rgba(132, 150, 136, [opacity])` or `#849688/[percentage]`:
  - `/10` - Very light tint (keyboard shortcut rows, toggle backgrounds)
  - `/20` - Light hover states (buttons, links)
  - `/30` - Dark mode hover enhancement
  - `0.15` - VoiceOscilloscope screen radial gradient center
  - `0.6` - Phosphor glow drop-shadow effect

#### Text/Labels:
- Slider value indicators: `text-[#849688]` (Settings sliders)
- Edit icons: `color="#849688"` (HandDrawnIcon in Settings)

---

### 2. **Off-white Linen** - `#F5F2EC`
**Background Light | Text Light | Accent Light**

#### Backgrounds:
- **App background**: `bg-[#F5F2EC]` (light mode main container)
- **WobblyPanel default**: Default `bgColor` parameter
- **Light theme cards**: Theme selector backgrounds
- **Input fields**: Form inputs, textareas in light mode
- **Toggle knobs**: Circle inside toggle switches

#### Text Colors (on dark backgrounds):
- **Primary text on sage/charcoal**: `text-[#F5F2EC]` (sidebar labels, panel headings on dark)
- **Secondary text**: `text-[#F5F2EC]/90` (sidebar navigation items)
- **Tertiary text**: `text-[#F5F2EC]/80` (collection sub-items, descriptions)
- **Muted text**: `text-[#F5F2EC]/70` (helper text, subtitles)
- **Disabled text**: `text-[#F5F2EC]/60` (Recent items timestamps)
- **Very muted**: `text-[#F5F2EC]/50` (sidebar section headers)
- **Ultra muted**: `text-[#F5F2EC]/30` (counts, metadata) → hover: `/50`

#### Interactive States:
- **Hover backgrounds**: `hover:bg-[#F5F2EC]/10` (sidebar items on sage green)
- **Light hover**: `hover:bg-[#F5F2EC]/20` (Script Editor back button)
- **Very light backgrounds**: `bg-[#F5F2EC]/5` (preview containers in SettingsModal)

#### Borders:
- `border-[#F5F2EC]/10` (dark mode borders on nav bar)
- `border-[#F5F2EC]/20` (dark mode form inputs, theme cards)
- `border-2 border-[#F5F2EC]/20` (VoiceOscilloscope housing)
- `border-t-2 border-[#F5F2EC]/30` (section dividers in dark panels)

#### VoiceOscilloscope:
- Grid lines: `stroke="#F5F2EC"` at 0.15 opacity
- Center line: `stroke="#F5F2EC"` at 0.3 opacity
- Label text: `color: '#F5F2EC'`
- Housing gradient: `rgba(245, 242, 236, 0.2)`

#### Shadows/Effects:
- `rgba(245, 242, 236, 0.2)` - VoiceOscilloscope border
- WavySeparator: `color="#F5F2EC"` at 0.3 opacity

---

### 3. **Charcoal Black** - `#2B2B2B`
**Background Dark | Text Dark | Borders | Structure**

#### Backgrounds:
- **Dark mode app background**: `dark:bg-[#2B2B2B]` (WobblyPanel, nav bar)
- **Intermediate dark**: `#3a3a3a` (main content area in dark mode)
- **Very dark**: `#1a1a1a` (NotchPreview screen mockup, SettingsModal notch)
- **Toggle OFF state**: `bg-[#2B2B2B]` (inactive toggles)
- **NotchPreview panel**: Dark preview panel background
- **Modal overlay**: `bg-[#2B2B2B]/60` with backdrop-blur

#### Text Colors (on light backgrounds):
- **Primary headings**: `text-[#2B2B2B]` (all page titles, section headers)
- **Secondary text**: `text-[#2B2B2B]/70` (descriptions, helper text)
- **Muted text**: `text-[#2B2B2B]/60` (document metadata, timestamps)
- **Very muted**: `text-[#2B2B2B]/50` (word counts)

#### Dark Mode Text:
- Light text switched: `dark:text-[#F5F2EC]` (headings in dark mode)
- Muted: `dark:text-[#F5F2EC]/70`, `/60`, `/50` (matching light mode hierarchy)

#### Borders:
- **Primary borders**: `border-3px solid #2B2B2B` (WobblyPanel hand-drawn border)
- **Input borders**: `border-2 border-[#2B2B2B]` (cue buttons)
- **Light borders**: `border-[#2B2B2B]/20` (form inputs, theme cards, toggle inactive)
- `border-[#2B2B2B]/10` (light mode nav bar bottom border, toggle backgrounds)

#### Interactive States:
- **Hover**: `hover:bg-[#2B2B2B]/5` (light mode button hover)
- `dark:hover:bg-[#F5F2EC]/5` (dark mode inverse)

#### Structural SVG:
- WobblyPanel border: `stroke="#2B2B2B"` strokeWidth="2.5"
- WobblyButton tertiary variant: `stroke="#2B2B2B"` or `rgba(43,43,43,0.15)`

#### VoiceOscilloscope:
- Housing gradient: `rgba(43, 43, 43, 0.4)` → `rgba(43, 43, 43, 0.2)`
- Screen gradient: `rgba(43, 43, 43, 0.8)`
- Label background: `rgba(43, 43, 43, 0.6)`

#### Shadows:
- `rgba(0,0,0,0.08)` - Light box-shadow
- `rgba(0,0,0,0.15)` - Cue button shadow
- `rgba(0,0,0,0.3)` - Inset shadow (VoiceOscilloscope)

---

### 4. **Terracotta Rust** - `#C98B7A`
**Secondary Accent | Warning | Active States**

#### Backgrounds:
- **Cue buttons**: `bg-[#C98B7A]` (ScriptEditor performance cue buttons)
- **Toggle ON state**: Voice-activated scroll toggles
- **Badge backgrounds**: Collection count badges
- **Voice visualizer**: Activity indicator bars in Settings
- **Slider accents**: `accentColor: '#C98B7A'` (NotchPreview, Settings sliders)

#### Interactive States:
- **Test Signal button**: `bg-[#C98B7A] hover:bg-[#C98B7A]/80` (NotchPreview)
- **Active toggle knobs**: Terracotta background for "ON" state

#### Text/Labels:
- **Slider values**: `text-[#C98B7A]` (volume percentage, scroll speed)
- **Icon colors**: `color="#C98B7A"` (trash icons in DocumentLibrary)

#### Decorative:
- **DocumentLibrary dots**: `fill="#C98B7A"` (SVG decoration circles)
- **VoiceOscilloscope accent**: `stroke="#C98B7A"` at 0.4 opacity (highlight waveform)

#### Borders/Warnings:
- `border-2 border-[#C98B7A]/30` (warning panel borders in Settings)
- `bg-[#C98B7A]/10` (warning panel background)

#### Dark Mode Variations:
- Badge alternative: `dark:bg-[#849688]` (switches to sage in dark mode for readability)

---

## 🌓 DARK MODE COLOR SYSTEM

### Background Hierarchy:
1. **App container**: `dark:bg-[#3a3a3a]` (lighter than pure charcoal)
2. **Panels/Cards**: `dark:bg-[#2B2B2B]` (pure charcoal)
3. **Sidebar**: Remains `#849688` (sage - no dark mode change)
4. **Inputs**: `dark:bg-[#2B2B2B]`

### Text Hierarchy (on dark backgrounds):
- **H1/H2 headings**: `dark:text-[#F5F2EC]` (full brightness)
- **Body text**: `dark:text-[#F5F2EC]` (full brightness for readability)
- **Secondary**: `dark:text-[#F5F2EC]/70` (subtle dimming)
- **Tertiary**: `dark:text-[#F5F2EC]/60`
- **Muted**: `dark:text-[#F5F2EC]/50`

### Border Colors:
- **Light borders**: `dark:border-[#F5F2EC]/10` (very subtle)
- **Medium borders**: `dark:border-[#F5F2EC]/20` (visible but soft)

### Interactive States:
- **Hover backgrounds**: `dark:hover:bg-[#849688]/30` (enhanced from light mode's /20)
- **Button hover**: `dark:hover:bg-[#F5F2EC]/10`
- **Card hover**: `dark:hover:bg-[#F5F2EC]/5`

---

## 🎯 SECONDARY/UTILITY COLORS

### **Slate Blue** - `#6B8E99`
- **Usage**: SettingsModal color picker option
- **Context**: Alternative overlay color choice

### **Pure Black** - `#000`
- **Usage**: NotchPreview camera notch border
- **Context**: Realistic hardware representation

### **Very Dark Gray** - `#1a1a1a`
- **Usage**: Screen mockup backgrounds
- **Context**: Display simulation in previews

### **Custom Colors** - User-definable
- **SettingsModal**: Custom color picker with hex input
- **Default**: `#849688` (sage green)

---

## 🔍 COMPLEX COLOR USAGE BY COMPONENT

### **SettingsModal.tsx** (Most Complex)
1. **Modal backdrop**: `bg-[#2B2B2B]/60` with `backdrop-blur-sm`
2. **Modal container**: `bg-[#F5F2EC] dark:bg-[#3a3a3a]`
3. **Header background**: `bg-[#849688]/10 dark:bg-[#849688]/20`
4. **Header border**: `border-[#2B2B2B]/10 dark:border-[#F5F2EC]/10`
5. **Active tab**: `bg-[#849688] text-[#F5F2EC]`
6. **Inactive tab**: `text-[#2B2B2B]/60 dark:text-[#F5F2EC]/60` → hover: full opacity
7. **Theme cards**: 
   - Selected: `border-[#849688]`
   - Unselected: `border-[#2B2B2B]/20 dark:border-[#F5F2EC]/20` + `opacity-60`
8. **Preview container**: `bg-[#2B2B2B]/5 dark:bg-[#F5F2EC]/5`
9. **Notch element**: `bg-[#1a1a1a]` with `border: 1px solid #000`
10. **Live preview overlay**: Dynamic `backgroundColor: selectedColor` with `opacity: opacity / 100`

### **VoiceOscilloscope.tsx**
1. **Housing**: Gradient `rgba(43, 43, 43, 0.4)` → `rgba(43, 43, 43, 0.2)`
2. **Screen**: Radial `rgba(132, 150, 136, 0.15)` → `rgba(43, 43, 43, 0.8)`
3. **Grid lines**: `#F5F2EC` at 0.5 strokeWidth, 0.15 opacity
4. **Center line**: `#F5F2EC` at 0.3 opacity
5. **Waveform glow**: `#849688` strokeWidth 4, 0.3 opacity, blur(3px)
6. **Main waveform**: `#849688` strokeWidth 2.5, drop-shadow `rgba(132, 150, 136, 0.8)`
7. **Accent waveform**: `#C98B7A` strokeWidth 1, 0.4 opacity
8. **Active glow**: `drop-shadow(0 0 4px rgba(132, 150, 136, 0.6))`

### **ManagerApp.tsx** (Sidebar)
1. **Sidebar background**: `bg-[#849688]` (always - no dark mode change)
2. **All text on sidebar**: `text-[#F5F2EC]` with opacity variants (/90, /80, /60, /50, /30)
3. **Hover states**: `hover:bg-[#F5F2EC]/10`
4. **Section headers**: `text-[#F5F2EC]/50` at text-xs
5. **Counts**: `text-[#F5F2EC]/30` → hover: `/50`
6. **Badges**: `bg-[#C98B7A] dark:bg-[#849688]` (color shift in dark mode)
7. **Item badges**: `bg-[#F5F2EC]/10 text-[#F5F2EC]/60`
8. **Icons**: All `color="#F5F2EC"` on sidebar
9. **WavySeparator**: `color="#F5F2EC"` opacity={0.3}

### **Settings.tsx**
1. **Shortcut rows**: `bg-[#849688]/10` → hover: `/20`
2. **Code display**: `bg-[#F5F2EC]` with `border-2 border-[#2B2B2B]/20`
3. **Voice panel**: `bgColor="#849688"` (full sage background)
4. **Toggle ON (voice)**: `bg-[#C98B7A]`
5. **Toggle ON (privacy)**: `bg-[#849688]`
6. **Toggle OFF**: `bg-[#2B2B2B]/20`
7. **Slider accents**: `accentColor: '#C98B7A'`
8. **Warning panel**: `bg-[#C98B7A]/10 border-2 border-[#C98B7A]/30`
9. **Warning icon**: `stroke="#C98B7A"`
10. **Voice bars**: `bg-[#C98B7A]` with height animation

---

## 📊 OPACITY SCALE REFERENCE

### Sage Green (#849688):
- `100%` - Solid backgrounds
- `30%` - Dark hover states
- `20%` - Light hover states
- `10%` - Very light tints
- `0.15` - Radial gradient centers
- `0.6` - Glow effects

### Linen (#F5F2EC):
- `100%` - Solid backgrounds, primary light text
- `90%` - Primary navigation text
- `80%` - Secondary navigation text
- `70%` - Helper text
- `60%` - Metadata text
- `50%` - Section headers
- `30%` - Counts/timestamps
- `20%` - Interactive hover backgrounds
- `10%` - Very light hover/active states
- `5%` - Container tints

### Charcoal (#2B2B2B):
- `100%` - Solid backgrounds, dark text
- `70%` - Secondary text
- `60%` - Muted text (modal backdrop opacity)
- `50%` - Very muted text
- `20%` - Light borders, inactive toggles
- `10%` - Very light borders
- `5%` - Subtle hover states

### Terracotta (#C98B7A):
- `100%` - Solid buttons, accents
- `80%` - Hover states
- `40%` - Waveform accent opacity
- `30%` - Warning borders
- `10%` - Warning backgrounds

---

## 🎭 SPECIAL EFFECTS & SHADOWS

### Box Shadows:
- **Light**: `0 2px 8px rgba(0,0,0,0.08)` - WobblyButton, WobblyPanel
- **Medium**: `0 4px 12px rgba(0,0,0,0.08)` - WobblyPanel
- **Strong**: `0 2px 4px rgba(0,0,0,0.15)` - Cue buttons
- **Inset**: `inset 0 2px 8px rgba(0,0,0,0.3)` - VoiceOscilloscope housing

### Drop Shadows:
- **Icon hover**: `drop-shadow(0 4px 6px rgba(0,0,0,0.2))` - HandDrawnIcon
- **Default**: `drop-shadow(0 1px 1px rgba(0,0,0,0.1))` - HandDrawnIcon
- **Waveform glow**: `drop-shadow(0 0 2px rgba(132, 150, 136, 0.8))`
- **Active oscilloscope**: `drop-shadow(0 0 4px rgba(132, 150, 136, 0.6))`

### Text Shadows:
- **NotchPreview text**: `text-shadow: 0 2px 4px rgba(0,0,0,0.3)`

### Filters:
- **Wobble effect**: `feTurbulence` + `feDisplacementMap` (SettingsModal)
- **Phosphor blur**: `filter: blur(3px)` (VoiceOscilloscope glow layer)
- **HandDrawnIcon hover blur**: `filter: blur(0.5px)` (voice activity bars)

### Backdrop Effects:
- **Modal**: `backdrop-blur-sm` with 60% opacity overlay
- **Notch overlay**: `backdropFilter: 'blur(8px)'` (NotchPreview)

---

## 🎨 GRADIENTS

### Linear Gradients:
1. **VoiceOscilloscope housing**: 
   - `linear-gradient(135deg, rgba(43, 43, 43, 0.4) 0%, rgba(43, 43, 43, 0.2) 100%)`

### Radial Gradients:
1. **VoiceOscilloscope screen**: 
   - `radial-gradient(ellipse at center, rgba(132, 150, 136, 0.15) 0%, rgba(43, 43, 43, 0.8) 100%)`

---

## 📝 COLOR NAMING CONVENTIONS

### Tailwind Arbitrary Values:
- `bg-[#849688]` - Direct hex reference
- `text-[#2B2B2B]` - Direct hex text color
- `border-[#F5F2EC]` - Direct hex border

### Opacity Modifiers:
- `/10`, `/20`, `/30` etc. - Tailwind opacity modifiers
- `rgba(R, G, B, alpha)` - Direct RGBA in style objects

### Dark Mode Prefix:
- `dark:` - All dark mode color overrides
- Example: `dark:bg-[#2B2B2B] dark:text-[#F5F2EC]`

---

## 🔧 WHERE EACH COLOR APPEARS

### Sage Green (#849688) - 47 instances
- ManagerApp: Sidebar background, hover states (9 instances)
- WobblyPanel: Panel backgrounds (5 instances)
- ScriptEditor: Header, cue panel (3 instances)
- Settings: Toggles, sliders, panels (8 instances)
- NotchPreview: Preview panel, sliders (6 instances)
- SettingsModal: Tabs, theme cards, borders (7 instances)
- VoiceOscilloscope: Waveform, glow, gradients (9 instances)

### Linen (#F5F2EC) - 112+ instances
- **Most used color** across all components
- ManagerApp: Text on sidebar (24 instances)
- All components: Light mode backgrounds (12 instances)
- All components: Dark mode text (35+ instances)
- Borders, hovers, opacity variants (40+ instances)

### Charcoal (#2B2B2B) - 89 instances
- All components: Light mode text (28 instances)
- WobblyPanel: Borders (6 instances)
- Dark mode backgrounds (18 instances)
- Toggle states, borders, shadows (37+ instances)

### Terracotta (#C98B7A) - 21 instances
- ScriptEditor: Cue buttons (7 instances)
- Settings: Warning panel, voice bars, sliders (8 instances)
- NotchPreview: Toggle, test button, slider accents (4 instances)
- VoiceOscilloscope: Accent waveform (1 instance)
- ManagerApp: Badge (1 instance)

---

**Total unique colors**: 4 primary + 3 utility = 7 core colors
**Total color instances**: 269+ across 12 component files
**Most complex component**: SettingsModal.tsx (23 different color applications)
**Second most complex**: VoiceOscilloscope.tsx (18 color/opacity combinations)
