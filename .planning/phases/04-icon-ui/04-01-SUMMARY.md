---
phase: 04-icon-ui
plan: 01
subsystem: ui
tags: [wow-addon, lua, backdrop-template, saved-variables, beast-icon]

# Dependency graph
requires:
  - phase: 03-visibility-gating
    provides: isPackLeaderActive flag and RefreshVisibility() function used as visibility bridge
provides:
  - CreateBeastIcon() frame constructor creating PLBeastFrame at PLAYER_LOGIN
  - ICON_FILE_BY_ID texture map (wyvern=773276, boar=132184, bear=132183)
  - root upvalue forward-declared; assigned in CreateBeastIcon() and consumed by SetNextBeastId/RefreshVisibility
  - 8 new PLBeastDB default keys: offsetX, offsetY, width, height, syncSize, borderThickness, borderColor, locked
  - BackdropTemplate border (black 1px WHITE8X8) on PLBeastFrame
  - borderColor deep-copy guard in ADDON_LOADED preventing defaults table mutation
affects: [04-02, 05-configuration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Eager frame creation at PLAYER_LOGIN — frame exists before first RefreshVisibility call"
    - "Root nil-guard pattern — SetNextBeastId called at ADDON_LOADED before frame; if root and root.tex then guard prevents crash"
    - "BackdropTemplate field-access guard — if f.border.SetBackdrop then (field access, not method call) per 12.x retail requirement"
    - "borderColor deep-copy guard — after flat-merge loop in ADDON_LOADED, replace reference-equal DB.borderColor with a fresh table"

key-files:
  created: []
  modified:
    - PLBeast/PLBeast.lua

key-decisions:
  - "Eager frame creation at PLAYER_LOGIN (D-09): frame is created immediately after slash setup so the initial RefreshVisibility() call sets the correct shown state; avoids a one-frame visibility flicker"
  - "BackdropTemplate field-access guard: checked via if f.border.SetBackdrop then (not f.border:SetBackdrop) — method call on a nil field throws; field access returns nil and the if-guard handles it safely on 12.x retail"
  - "Root nil-guards for SetNextBeastId-before-frame: SetNextBeastId is called from ADDON_LOADED during defaults initialization, before PLAYER_LOGIN creates the frame; if root and root.tex then prevents a nil-index crash (Pitfall 5)"
  - "borderColor deep-copy guard: the flat-merge loop copies the borderColor table by reference; a subsequent DB.borderColor.r write would mutate defaults; the guard replaces with a brand-new {r=0,g=0,b=0,a=1} table immediately after the merge"

patterns-established:
  - "local root forward-declaration: declared near local eventFrame; assigned inside CreateBeastIcon(); consumed by SetNextBeastId and RefreshVisibility without passing as argument"
  - "SetTexCoord(0.08, 0.92, 0.08, 0.92): crops the 8% WoW icon bevel on all four sides; applies to all beast texture icons"
  - "SetDesaturated(false): explicit full-color state on creation; Phase 5 options may add a greyed inactive state"

requirements-completed: [UI-01, UI-02]

# Metrics
duration: ~45min
completed: 2026-06-21
status: complete
---

# Phase 4 Plan 01: Icon UI Summary

**PLBeastFrame icon created eagerly at PLAYER_LOGIN with cropped wyvern/boar/bear texture, BackdropTemplate black 1px border, and visibility driven by isPackLeaderActive — human-verified in-game with correct texture, border, and spec-gated show/hide**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-06-21
- **Completed:** 2026-06-21
- **Tasks:** 3 (2 auto, 1 human-verify checkpoint)
- **Files modified:** 1

## Accomplishments

- Extended defaults table with 8 new DB keys (offsetX, offsetY, width, height, syncSize, borderThickness, borderColor, locked) plus borderColor deep-copy guard in ADDON_LOADED
- Added ICON_FILE_BY_ID constant map (wyvern=773276, boar=132184, bear=132183) and CreateBeastIcon() frame constructor with cropped texture and BackdropTemplate border
- Wired texture-push hook in SetNextBeastId() and visibility bridge in RefreshVisibility(); verified in-game: icon appears with correct beast texture, black 1px border, and shows/hides with Pack Leader spec/talent; no Lua errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend DB defaults and add icon texture/frame data constants** - `6f15372` (feat)
2. **Task 2: Create CreateBeastIcon() with backdrop border, wire texture + visibility hooks, call at PLAYER_LOGIN** - `7bc8b5c` (feat)
3. **Task 3: Human-verify checkpoint** - Approved by user (no code changes; in-game verification confirmed icon, texture, border, and spec-gated visibility with no Lua errors)

## Files Created/Modified

- `PLBeast/PLBeast.lua` — Extended defaults table (8 new keys), added borderColor deep-copy guard in ADDON_LOADED, added ICON_FILE_BY_ID constant map, added local root forward declaration, added CreateBeastIcon() function, added texture-push hook in SetNextBeastId(), added visibility bridge in RefreshVisibility(), added CreateBeastIcon() call in PLAYER_LOGIN handler

## Decisions Made

- **Eager frame creation at PLAYER_LOGIN**: Frame is created immediately after slash setup so the initial RefreshVisibility() call sets the correct shown state without a one-frame flicker.
- **BackdropTemplate field-access guard**: `if f.border.SetBackdrop then` (field access, not method call) — calling a nil method throws on 12.x retail; field access returns nil and the guard handles it safely.
- **Root nil-guards for SetNextBeastId-before-frame**: SetNextBeastId is called from ADDON_LOADED before PLAYER_LOGIN creates the frame; `if root and root.tex then` prevents a nil-index crash.
- **borderColor deep-copy guard**: Flat-merge copies borderColor by reference; the guard replaces DB.borderColor with a fresh `{r=0,g=0,b=0,a=1}` table after the merge so Phase 5 sub-field writes cannot mutate defaults.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 04-02 (drag-to-reposition with combat guard and position/size/border persistence) is unblocked; `root` upvalue and DB defaults (offsetX, offsetY, width, height, borderThickness, borderColor, locked) are in place
- PLBeastFrame is a named WoW frame and can be targeted by drag handlers without changes to CreateBeastIcon()
- No blockers

---
*Phase: 04-icon-ui*
*Completed: 2026-06-21*
