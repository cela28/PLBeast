---
phase: quick-260622-1or
plan: "01"
subsystem: rotation-tracking
tags: [event-handler, reset, login, encounter, WoW-addon, PLBeast]
status: complete

dependency_graph:
  requires: []
  provides: [PLAYER_ENTERING_WORLD-reset, ENCOUNTER_START-reset, ResetRotationToWyvern]
  affects: [PLBeast/PLBeast.lua, .planning/REQUIREMENTS.md, .planning/ROADMAP.md]

tech_stack:
  added: []
  patterns: [isInitialLogin-gate, shared-reset-helper, ENCOUNTER_START-boss-pull-reset]

key_files:
  created: []
  modified:
    - PLBeast/PLBeast.lua
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md

decisions:
  - "Reset-on-fresh-login via PLAYER_ENTERING_WORLD(isInitialLogin=true) — the sole reliable discriminator between relog and /reload"
  - "Boss-pull reset via ENCOUNTER_START unconditional — fires only on raid/dungeon pulls, never on trash or world mobs"
  - "Shared ResetRotationToWyvern() helper deduplicates both reset paths (SetNextBeastId('wyvern') + ResetAuraState(false))"
  - "PLAYER_ENTERING_WORLD + ENCOUNTER_START registered at addon-load time (not inside PLAYER_LOGIN branch) so first PEW firing is caught"
  - "ADDON_LOADED restore unchanged — /reload preservation depends on it"

metrics:
  duration_seconds: 140
  completed_date: "2026-06-21"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 3
---

# Phase quick-260622-1or Plan 01: Default next beast to wyvern on login Summary

**One-liner:** Fresh-login and boss-pull (ENCOUNTER_START) reset prediction to wyvern via shared helper; /reload, zoning, and trash leave prediction unchanged.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Register PLAYER_ENTERING_WORLD + ENCOUNTER_START; add ResetRotationToWyvern helper; add OnEvent branches | 0eea9b8 | PLBeast/PLBeast.lua |
| 2 | Update ADDON_LOADED restore comments to document reload-vs-relog-vs-boss-pull | 9e250b4 | PLBeast/PLBeast.lua |
| 3 | Reword TRACK-03 (REQUIREMENTS.md) and ROADMAP Phase 2 criterion #3 | 7eaf0f3 | .planning/REQUIREMENTS.md, .planning/ROADMAP.md |

## What Was Built

Two new event registrations and two new OnEvent branches in `PLBeast/PLBeast.lua`:

- `eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")` and `eventFrame:RegisterEvent("ENCOUNTER_START")` added immediately after the existing `ADDON_LOADED`/`PLAYER_LOGIN` registrations at addon-load time.
- `local function ResetRotationToWyvern()` added just below `ResetAuraState` — calls `SetNextBeastId("wyvern")` then `ResetAuraState(false)`. The `false` avoids a redundant rotation order reset since `SetNextBeastId` already set wyvern.
- `PLAYER_ENTERING_WORLD` branch reads `isInitialLogin, isReloadingUi = ...`. Calls `ResetRotationToWyvern()` only when `isInitialLogin` is true. `/reload` (`isReloadingUi=true, isInitialLogin=false`) and zoning (both false) are no-ops.
- `ENCOUNTER_START` branch calls `ResetRotationToWyvern()` unconditionally. Only fires on raid/dungeon encounter pulls — not on trash or world mobs.
- `ADDON_LOADED` restore (`NormalizeNextIndex()` + `nextBeastId = ID_BY_INDEX[DB.nextIndex]`) is fully preserved — this is what makes `/reload` carry the prediction forward.

Updated REQUIREMENTS.md TRACK-03 bullet and ROADMAP.md Phase 2 success criterion #3 to document the three-way distinction: /reload preserves, fresh relog + boss pull reset to wyvern, zoning/trash unchanged.

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

All automated checks passed:
- `RegisterEvent("PLAYER_ENTERING_WORLD")` count: 1
- `RegisterEvent("ENCOUNTER_START")` count: 1
- `elseif event == "PLAYER_ENTERING_WORLD"` branch: present, gated on `isInitialLogin`
- `elseif event == "ENCOUNTER_START"` branch: present, unconditional
- `ResetRotationToWyvern` helper: present
- `nextBeastId = ID_BY_INDEX[DB.nextIndex]` restore: intact
- No `PLAYER_REGEN_DISABLED` in executable lines
- TRACK-03 bullet: references /reload, fresh login, boss pull / ENCOUNTER_START
- ROADMAP criterion #3: references fresh relog, boss pull, ENCOUNTER_START, zoning, trash

## Known Stubs

None. The new event branches call existing, fully-wired functions (`SetNextBeastId`, `ResetAuraState`). No data is hardcoded or placeholder.

## Threat Flags

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Event registrations are read-only WoW API calls with no security surface.

## Self-Check: PASSED

- PLBeast/PLBeast.lua: modified (verified via git log and grep checks)
- .planning/REQUIREMENTS.md: modified (verified via grep)
- .planning/ROADMAP.md: modified (verified via grep)
- Commits exist: 0eea9b8, 9e250b4, 7eaf0f3 (verified via git log)
