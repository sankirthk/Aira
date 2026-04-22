# Satellite Launch And Settings Design

## Summary

Rename product-facing `Pill` concept to `Satellite`.

Core split:
- Settings own Satellite appearance/readability only.
- Script Editor owns Satellite launch intent and content assignment.

This removes hidden remembered session behavior from Settings and makes live launch behavior explicit at point of action.

## Problem

Current model couples two different concerns:
- persistent visual configuration
- live session content/launch behavior

That creates friction:
- `Cast to Notch` can surprise user by also launching extra surfaces
- manual secondary surfaces need script choice, but launch action does not provide that choice
- remembered settings can hide behavior user forgot was enabled

Result: low trust in primary cast action.

## Goals

- `Cast to Notch` always deterministic
- Satellite never appears unexpectedly from notch-only action
- Satellite content choice happens at launch time, not buried in Settings
- no hidden remembered script assignment state
- support 1 or 2 Satellites cleanly
- preserve clear split between persistent appearance config and per-session intent

## Non-Goals

- no code rename requirement in this doc; internal `Pill` symbols may stay until migration task
- no new generic `restore prior live setup` flow in this pass
- no auto-launch of manual Satellite from remembered state
- no Settings-based content mode selector

## Product Language

- User-facing name: `Satellite`
- Existing code/model names may temporarily keep `Pill` until dedicated rename task
- Docs should use `Satellite` for new normative behavior

## Mental Model

- Settings = how Satellite looks and reads
- Script Editor = what launches and what content each surface shows

This is intentional separation:
- persistent config lives in Settings
- session intent lives in launch flow

## UX Decisions

### 1. Settings Become Configuration-Only

Remove from Settings:
- enable/disable toggle
- sync/manual mode selector
- script picker
- generic launch/behavior controls

Keep in Settings:
- Satellite tab switcher for `Satellite 1` / `Satellite 2`
- Satellite count selector for how many Satellites are enabled during Satellite launch flow (`1` or `2`)
- live preview
- opacity
- font size
- font
- background color
- text color
- text accessibility controls

Fallback:
- if user never customizes Satellite slot, it inherits shared Notch appearance/readability defaults

Reason:
- these values are stable defaults
- they do not answer live question: "what should launch right now?"

### 2. Script Editor Owns Launch Intent

Toolbar control:
- split button: `[ Cast to Notch ] [ chevron ]`

Rules:
- `Cast to Notch` launches only notch
- dropdown path `Cast with Satellite…` is required for any launch that includes Satellite
- launch involving Satellite is always explicit user choice

### 3. Launch Dropdown

Chevron dropdown contains:
- `Cast to Notch`
- `Cast with Satellite…`

Why:
- primary action stays fastest/safest
- Satellite remains explicit
- cleaner than two equal buttons

### 4. Satellite Launch Panel

Panel shown only after user selects `Cast with Satellite…`.

Contents:
- current enabled Satellite count
- one section per Satellite
- per-Satellite choice:
  - `Mirror current script`
  - `Choose script…`
- script list from library only where `Choose script…` selected

Examples:
- one Satellite:
  - `Satellite 1`
  - `Mirror current script` or `Choose script…`
- two Satellites:
  - `Satellite 1 -> Mirror`
  - `Satellite 2 -> Choose script…`

Behavior:
- each Satellite assigned independently
- one Satellite may mirror while another uses a different script
- no hidden prior script memory
- user confirms before launch

### 5. Invalid / Partial Assignment Handling

If user starts Satellite launch but one or more required assignments missing:
- unassigned Satellite must not silently mirror notch
- app may launch valid surfaces only
- app shows lightweight non-blocking feedback describing skipped Satellite count

Example:
- `1 Satellite wasn’t opened because no script was assigned`

### 6. Deliberate Exclusions

Not in this pass:
- automatic restore of prior manual Satellite state
- persistent per-Satellite script memory
- Settings-based content mode
- implicit Satellite launch from primary notch action

## User Flows

### Flow A: Notch Only

1. User edits script.
2. User presses `Cast to Notch`.
3. App launches notch with current script.
4. No Satellite window appears.

### Flow B: Mixed Satellite Launch

1. User edits script.
2. User opens chevron dropdown.
3. User selects `Cast with Satellite…`.
4. App opens launch panel.
5. User sets `Satellite 1 -> Mirror current script`.
6. User sets `Satellite 2 -> Choose script…` and picks script.
7. App launches notch plus valid Satellite assignments.
8. If any `Choose script…` slot is left unassigned, app skips that Satellite and shows lightweight feedback.

## Information Architecture Changes

### Settings

Current mixed responsibility:
- appearance
- launch behavior
- content assignment

New responsibility:
- appearance/readability only

### Script Editor

Current responsibility:
- editing
- notch launch

New responsibility:
- editing
- notch-only launch
- Satellite-inclusive launch
- per-session content assignment

## Data Ownership

Persistent:
- selected Satellite count for session launch flow
- Satellite appearance defaults
- Satellite readability defaults

Fallback persistent rule:
- absence of Satellite-specific appearance config means "use Notch defaults"

Session-scoped:
- whether Satellite launch requested
- whether launch mode is mirror vs choose-script
- per-Satellite assigned script IDs for this launch

Must not persist:
- hidden remembered manual script assignment that later relaunches unexpectedly

## Design Consequences

- old `Pill Setup Sheet` no longer matches product model
- Settings copy saying pill setup lives in Settings becomes wrong
- editor toolbar needs split-button launch control
- requirements/test docs must shift from settings-driven content mode to editor-driven launch choice

## Risks

### Risk 1: Too many launch steps

Mitigation:
- keep `Cast to Notch` one click
- keep `Mirror current script` one extra lightweight choice
- only show assignment popup for manual case

### Risk 2: User wants fast repeat manual setup

Mitigation:
- do not solve with hidden persistence
- consider future explicit preset/recent-launch feature only if needed

### Risk 3: Terminology migration confusion

Mitigation:
- product/UI/docs use `Satellite`
- internal code rename can be separate, controlled task

## Acceptance Summary

Feature considered aligned when:
- Settings no longer contain Satellite content behavior
- `Cast to Notch` launches notch only
- Satellite launch always requires explicit action
- manual Satellite script choice happens in editor launch flow
- two-Satellite assignment works independently
- skipped/unassigned Satellites never auto-mirror silently

## Recommended Smallest First Implementation Task

Start with docs-only requirement/design/task alignment, then first code task:
- add split button shell `[ Cast to Notch ] [ chevron ]` with dropdown items only

Why first:
- smallest visible seam
- creates correct affordance before deeper launch popup work
- minimal blast radius
