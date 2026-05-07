# Pill Window Launch And Settings Design

## Summary

Use `Pill Window` / `Pill Windows` as the product-facing name for the floating overlay concept.

Core split:
- Settings own Pill Window appearance/readability only.
- Script Editor owns Pill Window launch intent and content assignment.

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
- Pill Window never appears unexpectedly from notch-only action
- Pill Window content choice happens at launch time, not buried in Settings
- no hidden remembered script assignment state
- support 1 or 2 Pill Windows cleanly
- preserve clear split between persistent appearance config and per-session intent

## Non-Goals

- no code rename requirement in this doc; internal `Pill` symbols may stay until migration task
- no new generic `restore prior live setup` flow in this pass
- no auto-launch of manual Pill Window from remembered state
- no Settings-based content mode selector

## Product Language

- User-facing name: `Pill Window`
- Existing code/model names may temporarily keep `Pill` until dedicated rename task
- Docs should use `Pill Window` / `Pill Windows` for normative behavior

## Mental Model

- Settings = how Pill Window looks and reads
- Script Editor = what launches and what content each surface shows

This is intentional separation:
- persistent config lives in Settings
- session intent lives in launch flow

## UX Decisions

### 1. Settings Become Configuration-Only

Remove from Settings:
- enable/disable toggle
- sync/manual mode selector
- collapsed script dropdown that auto-collapses after selection
- generic launch/behavior controls

Keep in Settings:
- Pill Windows tab switcher for `Pill Window 1` / `Pill Window 2`
- Pill Window count selector for how many Pill Windows are enabled during Pill Window launch flow (`1` or `2`)
- live preview
- opacity
- font size
- font
- background color
- text color
- text accessibility controls

Fallback:
- if user never customizes a Pill Window slot, it inherits shared Notch appearance/readability defaults

Reason:
- these values are stable defaults
- they do not answer live question: "what should launch right now?"

### 2. Script Editor Owns Launch Intent

Toolbar control:
- split button: `[ Cast to Notch ] [ chevron ]`

Rules:
- `Cast to Notch` launches only notch
- dropdown path `Cast with Pill Windows` is required for any launch that includes Pill Windows
- launch involving Pill Windows is always explicit user choice

### 3. Launch Dropdown

Chevron dropdown contains:
- `Cast with Pill Windows`

Why:
- primary action stays fastest/safest
- Pill Window launch remains explicit
- cleaner than two equal buttons

### 4. Pill Window Launch Panel
Panel shown only after user selects `Cast with Pill Windows`.

Contents:
- current enabled Pill Window count
- one section per Pill Window
- per-Pill Window choice:
  - `Mirror current script`
  - `Manual`
- script list from library only where `Manual` selected

Examples:
- one Pill Window:
  - `Pill Window 1`
  - `Mirror current script` or `Manual`
- two Pill Windows:
  - `Pill Window 1 -> Mirror`
  - `Pill Window 2 -> Manual`

Behavior:
- each Pill Window is assigned independently
- one Pill Window may mirror while another uses a different script
- no hidden prior script memory
- user confirms before launch

### 5. Invalid / Partial Assignment Handling

If user starts a Pill Window launch but one or more required assignments are missing:
- an unassigned Pill Window must not silently mirror notch
- app may launch valid surfaces only
- app shows lightweight non-blocking feedback describing skipped Pill Window count

Example:
- `1 Pill Window wasn’t opened because no script was assigned`

### 6. Deliberate Exclusions

Not in this pass:
- automatic restore of prior manual Pill Window state
- persistent per-Pill Window script memory
- Settings-based content mode
- implicit Pill Window launch from primary notch action

## User Flows

### Flow A: Notch Only

1. User edits script.
2. User presses `Cast to Notch`.
3. App launches notch with current script.
4. No Pill Window appears.

### Flow B: Mixed Pill Window Launch

1. User edits script.
2. User opens chevron dropdown.
3. User selects `Cast with Pill Windows`.
4. App opens launch panel.
5. User sets `Pill Window 1 -> Mirror current script`.
6. User sets `Pill Window 2 -> Manual` and picks script.
7. App launches notch plus valid Pill Window assignments.
8. If any `Manual` slot is left unassigned, app skips that Pill Window and shows lightweight feedback.

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
- Pill Window-inclusive launch
- per-session content assignment

## Data Ownership

Persistent:
- selected Pill Window count for session launch flow
- Pill Window appearance defaults
- Pill Window readability defaults

Fallback persistent rule:
- absence of Pill Window-specific appearance config means "use Notch defaults"

Session-scoped:
- whether Pill Window launch is requested
- whether launch mode is mirror vs choose-script
- per-Pill Window assigned script IDs for this launch

Must not persist:
- hidden remembered manual script assignment that later relaunches unexpectedly

## Design Consequences

- old `Pill Setup Sheet` no longer matches product model
- Settings copy saying Pill Window content setup lives in Settings becomes wrong
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
- product/UI/docs use `Pill Window`
- internal code rename can be separate, controlled task

## Acceptance Summary

Feature considered aligned when:
- Settings no longer contain Pill Window content behavior
- `Cast to Notch` launches notch only
- Pill Window launch always requires explicit action
- manual Pill Window script choice happens in editor launch flow
- two-Pill Window assignment works independently
- skipped/unassigned Pill Windows never auto-mirror silently

## Recommended Smallest First Implementation Task

Start with docs-only requirement/design/task alignment, then first code task:
- add split button shell `[ Cast to Notch ] [ chevron ]` with dropdown items only

Why first:
- smallest visible seam
- creates correct affordance before deeper launch popup work
- minimal blast radius
