---
phase: 07-text-display-mode
plan: 01
subsystem: ui
tags: [wow-addon, lua, fontstring, colorpicker, savedvariables]

requires:
  - phase: 05-config-ui
    provides: CreateSlider/CreateCheckbox options-frame helpers, ApplyIconSettings border logic
provides:
  - Text-based display mode showing the predicted next beast as colored text instead of an icon texture
  - Per-beast customizable colors (Okabe-Ito colorblind-safe defaults) via in-game ColorPickerFrame
  - Font size slider (8-32) driving a custom Font object live
affects: [options-ui, display-modes]

tech-stack:
  added: []
  patterns:
    - "Dual-widget root frame: root.tex and root.label coexist on the same frame; ApplyDisplayMode() toggles SetShown on exactly one"
    - "Color resolution centralized in GetBeastColor(beastId) — single source of truth read by SetNextBeastId, ApplyDisplayMode, and CreateColorSwatch"
    - "Custom Font object (CreateFont) seeded from a template global font (GameFontNormalLarge:GetFont()) so slider-driven size changes don't lose the locale font file"

key-files:
  created: []
  modified:
    - PLBeast/PLBeast.lua
    - PLBeast/Locales/enUS.lua

key-decisions:
  - "ApplyDisplayMode delegates to ApplyIconSettings() for icon-mode border restoration (never unconditionally SetShown(true) on edges) — this was flagged as a blocking regression in 07-01-CHECK.md and the plan was revised accordingly before this execution; implementation follows the revised, corrected plan"
  - "No slash-command toggle for text mode — options frame checkbox only, per revised plan scope"

requirements-completed: [TEXT-01, TEXT-02, TEXT-03, TEXT-04, TEXT-05, TEXT-06]

coverage:
  - id: D1
    description: "Text mode renders the beast name as colored text (root.label) in place of the icon texture (root.tex), toggled via ApplyDisplayMode"
    requirement: "TEXT-01"
    verification:
      - kind: manual_procedural
        ref: "07-01-PLAN.md <verification> steps 2-4: check/uncheck Text Mode checkbox in options frame"
        status: unknown
    human_judgment: true
    rationale: "WoW addon UI rendering can only be confirmed in a live game client; no test framework exists for this project"
  - id: D2
    description: "Three Okabe-Ito default colors (wyvern sky blue, boar orange, bear bluish green) render distinctly; each is customizable via a color swatch opening ColorPickerFrame"
    requirement: "TEXT-02"
    verification:
      - kind: manual_procedural
        ref: "07-01-PLAN.md <verification> steps 6-7, 11: click swatch, pick color, verify default distinctness"
        status: unknown
    human_judgment: true
    rationale: "Visual color correctness and ColorPickerFrame interaction require in-game observation"
  - id: D3
    description: "Text label updates on every SetNextBeastId call (same state machine driving icon texture updates)"
    requirement: "TEXT-03"
    verification:
      - kind: manual_procedural
        ref: "07-01-PLAN.md <verification> steps 9-10: rotation transitions update text live"
        status: unknown
    human_judgment: true
    rationale: "Requires live Pack Leader rotation state transitions in-game"
  - id: D4
    description: "Text mode toggled exclusively from the options frame checkbox (no slash command)"
    requirement: "TEXT-04"
    verification:
      - kind: manual_procedural
        ref: "07-01-PLAN.md <verification> step 2: options frame shows Text Mode checkbox"
        status: unknown
    human_judgment: true
    rationale: "UI presence/interaction check requires the live options frame"
  - id: D5
    description: "DB.textMode, DB.fontSize, DB.textColors persist across /reload via SavedVariablesPerCharacter, with coercion/validation on ADDON_LOADED"
    requirement: "TEXT-05"
    verification:
      - kind: manual_procedural
        ref: "07-01-PLAN.md <verification> step 8: /reload persists text mode state, font size, and custom colors"
        status: unknown
    human_judgment: true
    rationale: "SavedVariables persistence can only be confirmed via an actual client /reload cycle"
  - id: D6
    description: "Text display inherits root frame visibility gating (hidden when Pack Leader is not active) via existing RefreshVisibility() root:SetShown call, which applies to root.label as a child of root"
    requirement: "TEXT-06"
    verification:
      - kind: manual_procedural
        ref: "07-01-PLAN.md <verification> steps 9-10: spec switch hides/reshows root frame and text label"
        status: unknown
    human_judgment: true
    rationale: "Visibility gating on spec change requires live spec switching in-game"

duration: 5min
completed: 2026-07-07
status: complete
---

# Phase 7 Plan 1: Text Display Mode Summary

**Dual-widget root frame (texture + FontString) with Okabe-Ito default colors, per-beast ColorPickerFrame customization, and a live font-size slider — toggled from the options frame only**

## Performance

- **Duration:** ~5 min
- **Completed:** 2026-07-07
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments

- Added `DEFAULT_BEAST_COLORS` (Okabe-Ito colorblind-safe palette) and `GetBeastColor(beastId)` as the single source of truth for beast text color, consumed by `SetNextBeastId`, `ApplyDisplayMode`, and the new color swatches.
- Added `root.label` FontString driven by a custom `PLBeastTextFont` Font object (seeded from `GameFontNormalLarge`), toggled against `root.tex` by `ApplyDisplayMode()`.
- `ApplyDisplayMode()` hides border edges only when text mode is active, and delegates to `ApplyIconSettings()` (not a raw `SetShown(true)`) when returning to icon mode — implementing the fix that `07-01-CHECK.md` flagged as a blocking regression risk in the pre-revision plan.
- Added options frame controls: Text Mode checkbox, Font Size slider (8-32, live-updates the custom Font object), and three per-beast color swatches (`CreateColorSwatch`) that open `ColorPickerFrame` using the 11.0+ `SetupColorPickerAndShow` API with a legacy fallback.
- Extended `defaults` and the `ADDON_LOADED` coercion block to persist and validate `DB.textMode`, `DB.fontSize`, and `DB.textColors` (malformed per-beast entries are nilled out; `GetBeastColor` always falls back safely).
- Added 5 new locale strings to `PLBeast/Locales/enUS.lua`.

## Task Commits

1. **Task 1: Core text display — FontString, color table, ApplyDisplayMode, SetNextBeastId extension** - `6b5ac4f` (feat)
2. **Task 2: Options frame controls — text mode toggle, font size slider, per-beast color pickers, locale strings** - `91d2810` (feat)

_No TDD tasks in this plan; no test framework exists for this project (manual in-game verification only)._

## Files Created/Modified

- `PLBeast/PLBeast.lua` - Added `DEFAULT_BEAST_COLORS`, `GetBeastColor`, `textFont` forward declaration, `root.label` FontString creation in `CreateBeastIcon`, `ApplyDisplayMode` function, `SetNextBeastId` extension, `CreateColorSwatch` helper, options frame Text Mode checkbox / Font Size slider / three color swatches, `ADDON_LOADED` coercion for the three new DB fields.
- `PLBeast/Locales/enUS.lua` - Added "Text Mode", "Font Size", "Wyvern Color", "Boar Color", "Bear Color" locale entries.

## Decisions Made

- Followed the plan exactly as written in its revised form (07-01-PLAN.md, post-CHECK.md fix). `ApplyDisplayMode()` never unconditionally shows border edges — it only hides them in text mode and calls `ApplyIconSettings()` (single source of truth for thickness-aware border visibility) when leaving text mode, preserving the existing `borderThickness = 0` user setting across logins.
- No slash-command toggle was added for text mode, matching the plan's explicit "options frame only" scope (revised from an earlier draft that included `/plbeast text`).

## Deviations from Plan

None — plan executed exactly as written. All 9 numbered actions in Task 1 and all 6 numbered actions in Task 2 were implemented as specified, including exact yOffset/xOffset values, the 280x460 options frame resize, and the 11.0+/legacy ColorPickerFrame API branching.

## Issues Encountered

None. `luac -p` syntax-checked the file successfully after each task; all plan verification greps passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Code changes are complete and syntax-validated (`luac -p PLBeast/PLBeast.lua`), but **all 6 requirements (TEXT-01 through TEXT-06) require in-game manual verification** per the plan's `<verification>` section — this project has no automated test framework. The `coverage` block above marks all deliverables `human_judgment: true` with `status: unknown` pending an actual WoW client `/reload` and options-frame walkthrough. No blockers for proceeding to that manual UAT pass.

---
*Phase: 07-text-display-mode*
*Completed: 2026-07-07*

## Self-Check: PASSED

- FOUND: PLBeast/PLBeast.lua
- FOUND: PLBeast/Locales/enUS.lua
- FOUND: 6b5ac4f
- FOUND: 91d2810
