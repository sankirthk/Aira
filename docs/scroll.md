# Scroll Architecture

This document explains both:

- the current scroll implementation in Aira
- the target refactor direction for a pro-grade playhead engine

The goal is to make the difference explicit so future scroll work stops being reactive patching and becomes a controlled refactor.

## Goal

The scroll system is trying to satisfy four constraints at once:

1. Manual scrolling must feel smooth and display-synced.
2. Configured `WPM` must map to readable script progress, not just arbitrary pixel movement.
3. `Sync` mode must keep notch and synced pills on the same content position.
4. `Manual` pills must remain independent.

## Current Model

There are two different things in the system:

- `content progress`
  - Where the session is in the script logically.
  - In synced mode, this is the shared quantity.
- `local rendered offset`
  - How far a specific overlay has scrolled in its own viewport.
  - This depends on window size, content height, top inset, and line layout.

The current approach is:

- the primary overlay advances scroll using a display-linked manual driver
- in `Sync` mode, the primary overlay publishes shared content progress
- follower overlays project that shared content progress into their own local offset
- in `Manual` mode, each overlay uses its own local offset and can diverge

That split is important. If every overlay shares one rendered offset, larger pills distort the notch pacing. If every overlay shares only content progress, each window can keep its own local geometry.

## Target Model

The target architecture is a single physics-style playhead engine.

The core primitive is:

- `normalized progress`
  - `0.0` = start of script
  - `1.0` = end of script

The target source of truth is:

- `progress`
- `velocity`
- `paused`

The engine should update once per display-linked frame:

- `progress = progress + velocity * deltaTime`

That means:

- the coordinator owns temporal movement
- every overlay becomes a projection of the same playhead
- voice sync, wheel input, keyboard nudges, and manual auto-scroll all modify playhead state instead of directly mutating rendered offsets

## Why Refactor

The current implementation is a hybrid:

- manual scroll already has a display-linked driver
- synced mode already uses shared logical progress
- voice modes still have separate behavior paths
- rendering still relies on local offset/progress conversion helpers inside `PrompterContentView`

That hybrid works for many cases, but it has three structural problems:

1. More than one abstraction still "owns" movement.
2. Voice and manual paths are not fully unified.
3. Progress mapping depends too much on local line-anchor projection inside the view layer.

The target playhead engine fixes those issues by making the coordinator the only timing authority.

## Manual Scroll

Manual scroll lives in `PrompterContentView`.

### Frame driver

Manual scroll is driven by `ManualScrollDriver`, which is attached to an AppKit display link host instead of a `Timer` or `Task.sleep` loop.

Responsibilities:

- receive wheel / trackpad deltas
- receive keyboard line nudges
- receive manual auto-scroll steps when `WPM > 0` and voice sync is off
- update a single rendered offset owner on every display-linked frame

### Manual inputs

Manual movement comes from three sources:

- wheel / trackpad input
- keyboard line nudges
- manual auto-scroll from configured `WPM`

All three now flow through the same manual driver so they do not fight each other.

### WPM logic

Manual `WPM` is based on script progress, not a fixed pixel-per-second heuristic.

The basic idea is:

- count speakable words in the normalized script
- convert `WPM` into total seconds for the script
- convert each frame into a progress delta
- project that progress delta into a local offset for the current overlay

This is why the system now talks in `content progress` instead of directly moving raw offset at a constant rate.

In the target architecture, this will change slightly:

- `WPM` will set playhead velocity
- wheel and keyboard input will modify playhead velocity or progress directly
- the manual driver will become the frame clock for the shared playhead instead of just a local offset updater

## Sync Mode

`Sync` mode means:

- all synced overlays show the same script position
- they pause together
- they do not have to move at the same physical pixel speed

The primary synced overlay is normally the notch. It owns advancement and publishes shared progress through `SessionScrollCoordinator`.

Follower synced overlays:

- do not advance the session themselves
- listen to shared content progress
- convert that progress into their own local rendered offset

This lets the notch keep its own configured pacing while pills with different sizes still show the same content position.

In the target architecture:

- synced overlays will not follow another overlay's offset
- they will all project the same shared playhead progress into local geometry
- shared pause/resume will live entirely in the playhead coordinator

## Manual Mode

`Manual` mode means a pill is independent.

That pill:

- does not follow shared sync progress
- does not publish shared sync progress
- uses its own local manual driver state

This is the only mode where overlays are allowed to drift apart.

## Voice-Driven Scroll

Voice-driven behavior still uses `VoiceSyncEngine` for recognition, tokenization, and speech matching.

There are currently two voice-driven styles:

- `classic`
  - jumps forward to the next relevant line when speech reaches the end of a line
- `cinematic`
  - uses `CinematicScrollController` to move more continuously while speaking

Important detail:

- manual scrolling is already on the display-linked path
- cinematic voice motion still lives in its own controller and is not yet fully unified with the manual driver

So the manual path is the cleanest part of the current scroll architecture. Voice-driven motion still has more room to be unified.

In the target architecture:

- `classic` voice mode will update target playhead progress
- `cinematic` voice mode will adjust playhead velocity and anchor correction
- `VoiceSyncEngine` will stop writing view-facing offset state directly

## Progress and Offset Mapping

The difficult part of the system is converting between:

- local rendered offset
- shared content progress

That mapping is currently based on `LineMetric` data from the laid out script.

Current behavior:

- the script is normalized for display before layout metrics are calculated
- line metrics track rendered line positions and their associated word ranges
- `contentProgress(for:)` converts local offset into logical progress
- `localOffset(for:)` converts logical progress back into local offset

These conversions now interpolate continuously between adjacent speakable line anchors. That avoids the earlier bug where progress advanced every frame but the visible offset stayed stuck until the next whole line anchor.

## Script Normalization

Raw editor text is not used directly as scroll input.

The system normalizes script text before layout and pacing so that:

- single line breaks do not create unnecessary teleprompter fragmentation
- paragraph breaks are preserved
- non-spoken metadata should not distort pacing or matching

Recent tokenizer rules also ignore items like:

- email addresses
- raw URLs
- FAQ markers like `Q)` and `A)`

That logic matters because the same tokenization is reused by:

- manual pacing
- shared progress projection
- voice matching

## Known Tradeoffs

The current system is better than the earlier offset-sharing version, but it is not finished.

Open tradeoffs:

- `CinematicScrollController` is still separate from the main display-linked manual driver.
- Progress projection is currently line-anchor based with interpolation, not true word-anchor projection.
- Dense scripts and sparse scripts can still feel different if line metrics are not fine-grained enough.
- Voice sync and manual scroll now share more logic than before, but they are not fully unified under one driver yet.
- Overlay text layout ownership is split across renderer, height measurement, and line-metric extraction instead of one canonical snapshot. That split is now a real source of scroll regressions after readability renderer changes.

If future work is needed, the next likely refinement is moving from line-level anchors to finer word- or segment-level anchors for projection.

## Refactor Boundaries

The following code should be refactored during the playhead-engine migration:

### Must be refactored

- [Aira/Aira/OverlayWindows/Shared/PrompterContentView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/Shared/PrompterContentView.swift)
  - too much scroll authority currently lives here
  - contains local offset math, sync projection, manual driver wiring, and voice path branching
- [Aira/Aira/OverlayWindows/Shared/CinematicScrollController.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/Shared/CinematicScrollController.swift)
  - separate motion system that should be folded into the shared playhead model
- [Aira/Aira/VoiceSync/VoiceSyncEngine.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/VoiceSync/VoiceSyncEngine.swift)
  - should publish matching/anchor information, not directly own scroll-facing offset behavior
- [Aira/Aira/OverlayWindows/OverlayWindowController.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/OverlayWindowController.swift)
  - should own the shared playhead coordinator lifecycle instead of the current lighter session coordinator

### Likely to be refactored

- [Aira/Aira/OverlayWindows/Shared/PrompterTextMetrics.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/Shared/PrompterTextMetrics.swift)
  - line metrics may remain, but the mapping role may shrink if word-anchor LUTs are introduced
- [Aira/Aira/App/OverlayStyledTextView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/App/OverlayStyledTextView.swift)
  - current renderer knows final TextKit layout, but that layout is not yet exported as canonical scroll geometry
- [Aira/Aira/Models/OverlayAppearance.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/Models/OverlayAppearance.swift)
  - text-style helpers currently build measurement inputs in multiple places instead of producing one reusable snapshot
- [Aira/Aira/ManagerWindow/ManagerWindowView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/ManagerWindow/ManagerWindowView.swift)
  - keyboard shortcuts should target playhead actions, not ad hoc session scroll channels

## Layout Snapshot Refactor Plan

The next scroll refactor should not add another timing patch around `contentHeight`.

It should introduce one canonical overlay layout snapshot.

### New source of truth

For any given:

- normalized script body
- `OverlayAppearance`
- available text width

the system should produce one immutable snapshot containing:

- rendered attributed text
- total laid-out text height
- `LineMetric` list
- `pointsPerWord`
- any extra anchor/projection lookup tables needed later

### Why this matters

Current overlay path computes related layout data in separate places:

1. renderer layout in `OverlayStyledTextView`
2. total height in `OverlayTextStyle.measuredHeight(...)`
3. line metrics in `PrompterTextMetrics.calculateLines(...)`

Those paths can drift in timing or implementation detail.

Scroll then consumes stale or partially updated geometry.

That is exactly wrong for a playhead system, which needs geometry to be:

- canonical
- deterministic
- recomputed only on explicit layout inputs

### Target flow

1. Normalize script body once.
2. Build one TextKit-backed layout snapshot.
3. Render overlay from that snapshot.
4. Configure manual driver, playhead projection, and voice anchor math from that same snapshot.
5. Rebind scroll state whenever snapshot changes.

Snapshot recomputes only when:

- script body changes
- readability/alignment appearance changes
- available text width changes

Snapshot does not recompute on:

- per-frame scroll ticks
- pause/resume
- hover state changes
- playhead progress changes

Implementation note:

- `PrompterContentView` no longer relies on a SwiftUI `PreferenceKey` height reported from the AppKit text subtree to know scrollable range.
- Scrollable range is now computed from `OverlayTextLayoutSnapshot.textHeight` plus known start-marker, top inset, and trailing readable padding values.
- Line anchors are shifted by the same leading inset so playhead and voice-sync math use the same coordinate system as rendered content.

### Phase plan

#### Phase 1 — Snapshot type

Introduce dedicated snapshot type for overlay layout.

It should own:

- normalized display string
- attributed text
- height
- line metrics
- points per word

#### Phase 2 — Shared builder

Create one builder path that takes `script.body + appearance + width` and returns snapshot.

This builder should replace separate public calls to:

- `OverlayTextStyle.measuredHeight(...)`
- `PrompterTextMetrics.calculateLines(...)`
- renderer-local ad hoc layout assumptions

#### Phase 3 — Renderer wiring

Make `OverlayStyledTextView` consume snapshot output instead of rebuilding text layout decisions internally from raw string plus appearance.

#### Phase 4 — Scroll wiring

Make `PrompterContentView` consume snapshot as authoritative geometry.

Use snapshot fields for:

- `contentHeight`
- `lineMetrics`
- `pointsPerWord`
- playhead/manual driver configuration
- voice anchor mapping

#### Phase 5 — Cleanup

Delete dead split-measurement paths and any safety logic that only exists because layout ownership is fragmented.

### Success criteria

Refactor is complete when:

- renderer and scroll share same layout geometry
- appearance changes cannot leave scroll range stale
- long scripts still avoid per-frame text rebuilds
- manual and voice scroll both operate from same post-layout snapshot
- notch, synced pill, and manual pill sessions all pass regression coverage
- [Aira/Aira/Models/AppSettings.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/Models/AppSettings.swift)
  - naming may need cleanup if "voice sync mode" expands into a more general session scroll model

### Mostly wrappers, likely minimal refactor

- [Aira/Aira/OverlayWindows/NotchWindow/NotchContentView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/NotchWindow/NotchContentView.swift)
- [Aira/Aira/OverlayWindows/PillWindow/PillContentView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/PillWindow/PillContentView.swift)
- [Aira/Aira/OverlayWindows/PillWindow/PillSetupView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/PillWindow/PillSetupView.swift)
- [Aira/Aira/ManagerWindow/Settings/SettingsView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/ManagerWindow/Settings/SettingsView.swift)

These will mostly need naming and wiring updates, not algorithmic rewrites.

## Refactor Stages

The safe migration path is:

1. Introduce a dedicated session playhead coordinator without changing visible behavior.
2. Move manual auto-scroll to progress/velocity ownership in that coordinator.
3. Make synced overlays pure projections of shared progress.
4. Move keyboard and wheel input to playhead actions.
5. Rewire `classic` and `cinematic` voice behavior to update playhead state instead of local offsets.
6. Remove dead local-offset ownership paths from `PrompterContentView`.

## Data Flow

### Manual path

1. Session starts in `PrompterContentView`.
2. `ManualScrollDriver` starts ticking from the AppKit display link host.
3. Wheel, keyboard, or `WPM` updates change the driver input.
4. The driver computes the next local rendered offset.
5. The primary synced overlay publishes shared content progress if needed.
6. Follower synced overlays reproject shared content progress into their own local offsets.

### Voice path

1. `VoiceSyncEngine` recognizes speech and updates current word state.
2. `PrompterContentView` maps the word index into rendered lines.
3. `classic` mode jumps line targets.
4. `cinematic` mode feeds the cinematic controller.
5. In `Sync` mode, the primary overlay publishes the resulting progress for followers.

## Related Files

### Core scroll view and shared session state

- [Aira/Aira/OverlayWindows/Shared/PrompterContentView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/Shared/PrompterContentView.swift)
  - main scroll view
  - manual driver hookup
  - sync/manual branching
  - content progress projection
  - `SessionScrollCoordinator`
  - `ManualScrollDriver`
  - display-link host
  - scroll wheel interceptor

### Text layout and display normalization

- [Aira/Aira/OverlayWindows/Shared/PrompterTextMetrics.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/Shared/PrompterTextMetrics.swift)
  - rendered line metrics
  - line-to-word mapping
- [Aira/Aira/OverlayWindows/Shared/PrompterContentView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/Shared/PrompterContentView.swift)
  - normalized display text usage
  - offset/progress conversion

### Voice sync and tokenization

- [Aira/Aira/VoiceSync/VoiceSyncEngine.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/VoiceSync/VoiceSyncEngine.swift)
  - speech recognition state
  - pause state
  - manual line nudge signaling
  - tokenization and matching rules

### Cinematic voice movement

- [Aira/Aira/OverlayWindows/Shared/CinematicScrollController.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/Shared/CinematicScrollController.swift)
  - cinematic voice-driven motion controller

### Window/session ownership

- [Aira/Aira/OverlayWindows/OverlayWindowController.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/OverlayWindowController.swift)
  - owns shared `VoiceSyncEngine`
  - owns shared `SessionScrollCoordinator`
  - decides which overlay is primary for synced sessions
- [Aira/Aira/OverlayWindows/NotchWindow/NotchContentView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/NotchWindow/NotchContentView.swift)
  - notch wrapper around `PrompterContentView`
- [Aira/Aira/OverlayWindows/PillWindow/PillContentView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/PillWindow/PillContentView.swift)
  - pill wrapper around `PrompterContentView`
- [Aira/Aira/OverlayWindows/PillWindow/PillSetupView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/PillWindow/PillSetupView.swift)
  - launch-time mode labels and pill configuration

### Settings and app-level session controls

- [Aira/Aira/ManagerWindow/Settings/SettingsView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/ManagerWindow/Settings/SettingsView.swift)
  - `Sync` vs `Manual` settings UI
  - voice mode settings
- [Aira/Aira/ManagerWindow/ManagerWindowView.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/ManagerWindow/ManagerWindowView.swift)
  - session launch
  - keyboard shortcuts for pause and line nudges
- [Aira/Aira/Models/AppSettings.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/Models/AppSettings.swift)
  - persisted scroll mode and voice sync mode settings

### Supporting overlay UI

- [Aira/Aira/OverlayWindows/Shared/ContentModeIndicator.swift](/Users/sankirthkalahasti/Documents/Projects/Aira/Aira/OverlayWindows/Shared/ContentModeIndicator.swift)
  - mode indicator UI

## Short Version

If you only want the mental model:

- notch manual scrolling is the primary reference path
- synced mode shares content position, not one raw offset
- follower pills project shared content position into their own geometry
- manual pills are independent
- manual scroll is display-linked
- voice scroll is partly unified, but not completely yet
- the target architecture is a single shared playhead with `progress + velocity + paused`
