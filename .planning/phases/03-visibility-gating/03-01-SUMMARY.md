---
phase: 03-visibility-gating
plan: "01"
subsystem: visibility-gating
tags: [lua, wow-addon, visibility, talent-detection, event-handling]
dependency_graph:
  requires: [02-01]
  provides: [isPackLeaderActive flag, RefreshVisibility, QueueVisibilityRefresh, conditional UNIT_AURA registration]
  affects: [PLBeast/PLBeast.lua]
tech_stack:
  added: []
  patterns:
    - IsPlayerSpell() talent detection (PLH lines 1574-1580)
    - C_Timer.After(0, ...) deferred talent refresh (PLH lines 1622-1638)
    - pendingVisibilityRefresh coalescing flag (T-03-02)
    - wasActive guard for idempotent event registration (D-02)
key_files:
  modified:
    - PLBeast/PLBeast.lua
decisions:
  - Forward-declared eventFrame as a module-level local to resolve upvalue scoping issue; RefreshVisibility() needs eventFrame as an upvalue before the Event Handler section creates it
  - Kept SPELL_HOTPL_PARENT constant name with extra spaces alignment matching PLH style
metrics:
  duration: 7m
  completed: "2026-06-19T13:28:39Z"
  tasks_completed: 2
  files_modified: 1
---

# Phase 3 Plan 01: Visibility Gating — Talent Detection and Conditional UNIT_AURA Registration

**One-liner:** Pack Leader hero talent detection and spec-based visibility gating using IsPlayerSpell(), C_Timer.After() deferral, and conditional UNIT_AURA register/unregister.

## What Was Built

Added full visibility gating to PLBeast.lua so that aura event tracking only runs when the player is on BM or SV spec with Pack Leader hero talent active. The `isPackLeaderActive` boolean becomes the single source of truth for Phase 4's icon show/hide logic.

### Task 1: Talent detection constants and visibility gating functions

**Commit:** 7faff5a

Added to `PLBeast/PLBeast.lua`:

- **Constants** (`SPELL_HOTPL_PARENT = 471876`, `SPELL_SENTINEL_ANCHOR = 1253599`, `SPELL_DARK_RANGER_ANCHOR = 466930`) — direct copy from PLH lines 11, 21-22
- **`local isPackLeaderActive = false`** — module-level state flag (D-01); not persisted, derived on every login
- **Forward declaration** of `eventFrame` at module level — required so `RefreshVisibility()` can reference it as an upvalue before the Event Handler section
- **`IsPackLeaderHeroTalent()`** — direct copy from PLH lines 1574-1580; checks `IsPlayerSpell(SPELL_HOTPL_PARENT)` and excludes Sentinel and Dark Ranger via negative guards
- **`RefreshVisibility()`** — calls `RefreshHunterSpecState()`, evaluates `isPackLeaderActive = (BM or SV) and IsPackLeaderHeroTalent()`; on re-activation calls `SeedAuraSnapshot()` before `RegisterEvent("UNIT_AURA")` (Pitfall 2 / D-02); on deactivation calls `UnregisterEvent("UNIT_AURA")`; always emits dprint with spec= and packLeader= (D-04)
- **`local pendingVisibilityRefresh = false`** + **`QueueVisibilityRefresh()`** — coalescing pending flag with `C_Timer.After(0, ...)` deferral so `IsPlayerSpell` reads updated talent state (T-03-05, T-03-02)
- Updated `RefreshHunterSpecState` comment to reflect spec flags now gate visibility (Phase 3)

### Task 2: Rewire event handler and PLAYER_LOGIN

**Commit:** d328266

Modified `PLBeast/PLBeast.lua` event handler:

- **PLAYER_LOGIN init sequence**: replaced `RefreshHunterSpecState() + SeedAuraSnapshot() + RegisterEvent("UNIT_AURA")` with `RefreshVisibility()` — eliminates unconditional UNIT_AURA registration (Pitfall 4)
- **Five new event registrations**: `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_TALENT_UPDATE`, `ACTIVE_COMBAT_CONFIG_CHANGED`, `TRAIT_CONFIG_UPDATED`, `TRAIT_SUB_TREE_CHANGED`
- **Unified five-event handler branch**: replaced standalone `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` → `RefreshHunterSpecState()` with all five events → `QueueVisibilityRefresh()` (Pitfall 3)
- Updated `SeedAuraSnapshot` comment to remove quoted `RegisterEvent("UNIT_AURA")` reference (kept grep count accurate for verification)

## Verification Results

All source code verification checks passed:

```
PASS: HOTPL constant
PASS: Sentinel constant
PASS: DarkRanger constant
PASS: IsPackLeaderHeroTalent
PASS: RefreshVisibility
PASS: QueueVisibilityRefresh
PASS: Single UNIT_AURA registration (count=1)
PASS: PLAYER_TALENT_UPDATE registered
PASS: ACTIVE_COMBAT_CONFIG_CHANGED registered
PASS: TRAIT_CONFIG_UPDATED registered
PASS: TRAIT_SUB_TREE_CHANGED registered
PASS: ACTIVE_PLAYER_SPECIALIZATION_CHANGED registered
PASS: C_Timer deferral
PASS: isPackLeaderActive flag
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Forward reference: eventFrame upvalue unavailable inside RefreshVisibility()**

- **Found during:** Task 1
- **Issue:** `RefreshVisibility()` references `eventFrame` (used to call `RegisterEvent`/`UnregisterEvent`) and `SeedAuraSnapshot()`. The plan places these functions before the Event Handler section where `local eventFrame = CreateFrame("Frame")` was declared. In Lua, a local variable is only visible after its declaration point — `RefreshVisibility()` defined at line ~214 would capture `nil` for `eventFrame` since it was declared at line ~253.
- **Fix:** Added forward declaration `local eventFrame` in the Module-Level State Variables block (after `prevReady`). Changed `local eventFrame = CreateFrame("Frame")` to `eventFrame = CreateFrame("Frame")` (assignment to the already-declared local). This follows the same forward-declaration pattern PLH uses for mutually recursive functions (`local UpdateNextBar`, etc.).
- **Files modified:** `PLBeast/PLBeast.lua`
- **Commit:** 7faff5a (within Task 1 commit)

## Known Stubs

None. All new functions are fully implemented with live WoW API calls.

## Threat Surface Scan

No new network endpoints, auth paths, or trust boundary changes introduced. All new code uses:
- `IsPlayerSpell()` — read-only WoW API, sandboxed
- `C_Timer.After()` — deferred execution, sandboxed
- `eventFrame:RegisterEvent/UnregisterEvent()` — standard addon event API

T-03-04 mitigation confirmed: no new globals. `isPackLeaderActive`, `pendingVisibilityRefresh`, and all new functions are file-local.

## Self-Check

Checking created/modified files and commits exist...

## Self-Check: PASSED

| Item | Status |
|------|--------|
| PLBeast/PLBeast.lua | FOUND |
| .planning/phases/03-visibility-gating/03-01-SUMMARY.md | FOUND |
| Commit 7faff5a (Task 1) | FOUND |
| Commit d328266 (Task 2) | FOUND |
