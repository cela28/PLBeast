---
phase: 04-icon-ui
plan: 02
subsystem: ui
tags: [wow-addon, lua, drag-handler, saved-variables, backdrop-template, combat-lockdown, position-persistence]

# Dependency graph
requires:
  - phase: 04-icon-ui (plan 01)
    provides: PLBeastFrame root upvalue, CreateBeastIcon() frame constructor, BackdropTemplate border child, 8 DB default keys (offsetX, offsetY, width, height, syncSize, borderThickness, borderColor, locked)
provides:
  - OnDragStart/OnDragStop scripts on PLBeastFrame with silent combat-lockdown guard and center-offset persistence
  - SetIconSize(w, h) sync-aware sizing helper honoring DB.syncSize
  - ApplyIconSettings() single re-apply entry point for size, position, and border (Phase 5 sliders will call this)
  - CreateBeastIcon() refactored to delegate size/position/border application to ApplyIconSettings()
affects: [05-configuration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Silent combat-lockdown drag guard: OnDragStart returns early when InCombatLockdown() — no Print, no chat message (D-08)"
    - "Center-offset persistence: OnDragStop captures center-relative offset (GetLeft+Width/2 - UIParent.width/2) to DB.offsetX/offsetY; SetUserPlaced(false) suppresses LayoutCache.txt double-source (D-09, Pitfall 2)"
    - "GetLeft nil-guard before offset arithmetic: if not self:GetLeft() then return end (Pitfall 3)"
    - "ApplyIconSettings as single re-apply entry point: called from CreateBeastIcon() and available for Phase 5 slider callbacks"
    - "SetSize for independent width/height: root:SetSize(DB.width, DB.height) — never SetScale which is uniform-only (D-01 anti-pattern avoided)"
    - "Sync-aware sizing: SetIconSize mirrors width↔height when DB.syncSize is true (D-02)"

key-files:
  created: []
  modified:
    - PLBeast/PLBeast.lua

key-decisions:
  - "SetSize not SetScale for independent width/height (D-01): SetScale applies a uniform multiplier to both dimensions; SetSize(w, h) allows the independent width and height that Phase 5 sliders require"
  - "Sync-aware SetIconSize honors DB.syncSize (D-02): the helper mirrors the wider of the two dimensions when sync is on, so Phase 5 sliders get correct mirroring behavior without re-implementing the logic"
  - "ApplyIconSettings as single re-apply entry point: Phase 5 sliders call one function after any DB change rather than scattering SetSize/SetPoint/SetBackdrop calls across slider callbacks"
  - "Silent combat drag guard — no chat message (D-08): OnDragStart returns bare when InCombatLockdown(); unlike PackLeaderHelper which prints a warning, PLBeast is a minimal overlay and any combat-phase chat output would be intrusive"
  - "Task 1 work front-loaded into 04-01 Task 2: CreateBeastIcon() already included SetMovable/EnableMouse/RegisterForDrag/SetClampedToScreen and OnDragStart/OnDragStop scripts in commit 7bc8b5c; no duplicate work was needed in 04-02"

patterns-established:
  - "ApplyIconSettings() call pattern: always guard `if not root then return end`, then call SetIconSize → ClearAllPoints/SetPoint → SetBackdrop/SetBackdropBorderColor in that order"
  - "DB.syncSize mirroring: when sync is true, SetIconSize takes max(w,h) and applies to both dimensions"

requirements-completed: [UI-03, UI-04, UI-05, UI-06, UI-07]

# Metrics
duration: ~30min (code) + human-verify session
completed: 2026-06-21
status: complete
---

# Phase 4 Plan 02: Icon UI Summary

**Drag-to-reposition (left button) with silent combat-lockdown guard and center-offset DB persistence, plus ApplyIconSettings() applying independent SetSize width/height and BackdropTemplate border from PLBeastDB on login — human-verified in-game**

## Performance

- **Duration:** ~30 min (code) + in-game human verification session
- **Started:** 2026-06-21
- **Completed:** 2026-06-21
- **Tasks:** 3 (1 auto — absorbed from 04-01, 1 auto with new code, 1 human-verify checkpoint)
- **Files modified:** 1

## Accomplishments

- Added `SetIconSize(w, h)` sync-aware sizing helper: persists resolved values to DB.width/DB.height, calls `root:SetSize` (never SetScale), mirrors width↔height when DB.syncSize is true
- Added `ApplyIconSettings()` single re-apply entry point: applies persisted size via SetIconSize, position via ClearAllPoints+SetPoint CENTER, and border via SetBackdrop+SetBackdropBorderColor reading DB.borderThickness/borderColor — callable from Phase 5 sliders/color-picker
- Refactored CreateBeastIcon() to delegate all size/position/border application to ApplyIconSettings() at end of frame creation; verified in-game: drag persists across /reload and full logout, combat guard silently blocks drag with no Lua errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Drag handlers with combat guard and center-offset persistence** — covered by `7bc8b5c` (feat, 04-01 Task 2; front-loaded — see Deviations)
2. **Task 2: ApplyIconSettings(), sync-aware SetIconSize(), refactor CreateBeastIcon()** — `a5349df` (feat)
3. **Task 3: Human-verify checkpoint** — Approved by user (no code changes; in-game verification confirmed drag persists across reload and full logout, combat silently blocks drag, no Lua errors)

## Files Created/Modified

- `PLBeast/PLBeast.lua` — Added `SetIconSize(w, h)` sync-aware sizing helper, added `ApplyIconSettings()` single re-apply entry point (size via SetSize, position via ClearAllPoints/SetPoint, border via SetBackdrop/SetBackdropBorderColor), refactored CreateBeastIcon() to call ApplyIconSettings() at end; OnDragStart/OnDragStop and combat guard already present from 04-01 Task 2

## Decisions Made

- **SetSize not SetScale (D-01):** `root:SetSize(DB.width, DB.height)` allows independent width and height; `SetScale` applies a uniform multiplier and cannot produce the asymmetric resize Phase 5 sliders require.
- **Sync-aware SetIconSize helper (D-02):** A dedicated helper owns the sync-mirroring logic so Phase 5 sliders call one function and get correct behavior without re-implementing the mirror.
- **ApplyIconSettings as single entry point:** Phase 5 sliders call one function after updating any DB value rather than scattering SetSize/SetPoint/SetBackdrop calls across callbacks.
- **Silent combat drag guard (D-08):** `OnDragStart` returns bare when `InCombatLockdown()` — no Print, no chat message. PLBeast is a minimal HUD overlay; combat-phase chat output would be intrusive.

## Deviations from Plan

### Front-loaded Task 1 Work

**[Structural deviation — no bug, no missing functionality]**
- **Found during:** Plan review before execution
- **Issue:** Task 1 required adding `SetMovable(true)`, `EnableMouse(true)`, `RegisterForDrag("LeftButton")`, `SetClampedToScreen(true)`, and `OnDragStart`/`OnDragStop` scripts to CreateBeastIcon(). Inspection of PLBeast/PLBeast.lua confirmed all of these were already present in commit `7bc8b5c` (04-01 Task 2) — they were implemented as part of the Plan 01 frame constructor rather than deferred to Plan 02.
- **Impact:** All four automated checks from Task 1's `<verify>` block pass against the current code. No re-implementation was needed.
- **Committed in:** `7bc8b5c` (04-01 Task 2 commit; this is the authoritative Task 1 commit for 04-02 tracking purposes)

---

**Total deviations:** 1 structural (Task 1 front-loaded into 04-01; zero bugs, zero missing functionality)
**Impact on plan:** No scope creep. All acceptance criteria satisfied. Plan goals fully met.

## Issues Encountered

None — code-complete without errors; in-game verification straightforward.

## Phase-5 Deferral Note

The in-game human verification confirmed drag persistence, combat guard, and no Lua errors (checkpoint steps 1–3 and 6). Steps 4 and 5 of the checkpoint — verifying independent width/height resize and border thickness/color via SavedVariables edits — were **explicitly deferred by the user to Phase 5**, when the options frame (sliders + color picker) will expose these controls without requiring manual SavedVariables file editing. `ApplyIconSettings()` is verified correct by code inspection and the size/border DB keys are in place; the end-to-end UI path will be fully exercised when Phase 5 sliders are wired.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 4 is complete: PLBeastFrame is draggable, position survives reload and logout, combat guard is silent, and `ApplyIconSettings()` is the documented entry point for Phase 5 slider callbacks
- Phase 5 (Configuration) is unblocked: `ApplyIconSettings()` is in place and awaiting slider/color-picker wiring; all DB keys (width, height, syncSize, borderThickness, borderColor, locked, offsetX, offsetY) exist with defaults
- No blockers

---
*Phase: 04-icon-ui*
*Completed: 2026-06-21*
