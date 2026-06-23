---
phase: 05-configuration
plan: 01
subsystem: ui
tags: [wow-addon, lua, options-frame, slash-command, slider, checkbox, backdrop, combat-lockdown]

# Dependency graph
requires:
  - phase: 04-icon-ui
    provides: SetIconSize / ApplyIconSettings setters, DB schema (width/height/borderThickness/borderColor/locked), PLBeastFrame icon + border
provides:
  - "/plbeast bare command opens/toggles a lightweight options frame (PLBeastOptionsFrame)"
  - "Width, Height, and Border Thickness sliders (live-apply, no /reload)"
  - "Lock position checkbox (writes DB.locked)"
  - "Combat-gated open with deferred-open on PLAYER_REGEN_ENABLED"
  - "4-texture rectangular icon border (fixed black) replacing the BackdropTemplate edge"
affects: [release-pipeline, any future options UI]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Extract-and-trim UI helpers from PackLeaderHelper (CreateSlider without editBox, CreateCheckbox)"
    - "Lazy-create + cache options frame; Hide() at end of build so first toggle opens it"
    - "Four solid OVERLAY edge textures for a scalable rectangular border (avoids BackdropTemplate WHITE8X8 full-fill bug)"

key-files:
  created: []
  modified:
    - PLBeast/PLBeast.lua
    - PLBeast/Locales/enUS.lua
    - PLBeast/PLBeast.toc

key-decisions:
  - "Width/height SYNC feature removed entirely per user during in-game verification (was Phase 4/5 D-09 / UI-05). Width and height are always independent."
  - "Border COLOR PICKER (Plan 05-02 / CFG-02 color portion, D-01/D-02) dropped per user. Border color is fixed black."
  - "Border reimplemented as four solid edge textures — the BackdropTemplate WHITE8X8 edge rendered as a full black fill in-game at small thickness."
  - "First /plbeast must hide the just-created (shown) frame so the toggle opens it."

patterns-established:
  - "Options frame: BasicFrameTemplateWithInset, lazy-create, slash-toggle, combat-deferred open"
  - "Border: 4 edge textures sized by DB.borderThickness, thickness 0 hides it"

requirements-completed: [CFG-01, CFG-02, CFG-03, CFG-04]

# Metrics
duration: ~1 day (iterative in-game verification across builds 0.2.0–0.2.4)
completed: 2026-06-22
status: complete
---

# Phase 5: Configuration Summary

**`/plbeast` now opens a lightweight, combat-guarded options window with live Width / Height / Border-Thickness sliders and a Lock-position toggle — verified in-game across builds 0.2.0–0.2.4.**

## Performance

- **Duration:** iterative (multiple in-game test builds)
- **Completed:** 2026-06-22
- **Tasks:** 2 implementation tasks + 1 human-verify checkpoint (approved)
- **Files modified:** 3 (PLBeast.lua, Locales/enUS.lua, PLBeast.toc)

## Accomplishments
- Bare `/plbeast` opens/toggles `PLBeastOptionsFrame` (`BasicFrameTemplateWithInset`), combat-gated with deferred-open on `PLAYER_REGEN_ENABLED`; `debug`/`reset` subcommands unchanged.
- Width, Height, and Border-Thickness sliders bind live to the existing `SetIconSize` / `ApplyIconSettings` setters — no `/reload`. Width/height are independent.
- Lock-position checkbox writes `DB.locked` (drag scripts already honor it).
- Replaced the buggy BackdropTemplate border with a 4-texture black rectangular outline that scales with the thickness slider (0 = hidden).
- Discharged the Phase 4 carried-forward in-game verification of independent width/height resize and border thickness, plus persistence across `/reload`.

## Task Commits

1. **Task 1: locale strings + combat-deferred open scaffolding** — `942c65f` (feat)
2. **Task 2: ToggleOptions() frame with sliders + checkboxes + slash routing** — `6d7a472` (feat)
3. **Checkpoint: in-game verification** — approved by user

**Fixes during in-game verification:**
- `63cc606` — hide options frame on creation so first `/plbeast` opens it
- `9fd151a` — enlarge frame + space bottom checkboxes (clipping/overlap)
- `75a79f0` — remove width/height sync feature (per user)
- `2ca7d5b` — 4-texture black border (fix black-icon bug) + drop color picker (Plan 05-02)

## Scope changes (user decisions during verification)
- **Sync width/height: REMOVED.** Checkbox, `SetIconSize` mirroring, height-slider dimming, `SetSliderEnabled`, `syncSize` default, and locale string all deleted. (Reconciled: ROADMAP criterion 3, CFG-03, CONTEXT D-09.)
- **Border color picker: REMOVED.** Plan 05-02 deleted; border color fixed black. (Reconciled: ROADMAP criterion 2, CFG-02, CONTEXT D-01/D-02.)
- **Note:** Phase 4 requirements UI-05 / UI-07 still reference the (now-removed) sync toggle — left untouched pending user decision on rewriting completed-phase records.

## Releases
Published to GitHub (author `cela28`): v0.2.0 → v0.2.1 → v0.2.2 → v0.2.3 → v0.2.4 (current). v0.2.4 is the verified, approved build.

## Verification
- Static: both files byte-parse as Lua 5.1 (luaparse; `luac` unavailable locally).
- In-game (human, sole runtime proof): open/close toggle, combat block + deferred open, live width/height resize (independent), live border thickness (clean outline, no black-out), Lock toggle, persistence across `/reload`, subcommands intact. **Approved by user on build 0.2.4.**
