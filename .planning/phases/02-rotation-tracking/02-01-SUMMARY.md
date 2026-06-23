---
phase: 02-rotation-tracking
plan: "01"
subsystem: rotation-tracking
tags: [lua, wow-addon, unit-aura, state-machine, snapshot-diff, savedvariables]

# Dependency graph
requires:
  - phase: 01-addon-scaffold
    provides: PLBeast addon skeleton (PLBeast.lua, PLBeast.toc, Locales/enUS.lua, two-phase init, DB defaults merge, dprint helper)
provides:
  - Rotation tracking state machine (snapshot-diff via UNIT_AURA events)
  - NEXT_BEAST cyclic rotation table (wyvern -> boar -> bear -> wyvern)
  - SetNextBeastId, SyncNextFromAddedReady with multi-beast start-time sort
  - NormalizeNextIndex with SavedVariables clamping
  - SeedAuraSnapshot (prevents double-advancement on login)
  - IsReadyBuffActive with C_UnitAuras availability guard
  - CheckAuraState with snapshot-diff and BEAST_LABEL_BY_ID debug output
  - RefreshHunterSpecState for BM/SV spec awareness
  - /plbeast debug toggle and /plbeast reset subcommands
  - Session persistence of nextIndex across /reload
affects:
  - 03-icon-display (reads nextBeastId to select icon texture)
  - 04-draggable-icon (no dependency on rotation tracking)

# Tech tracking
tech-stack:
  added:
    - C_UnitAuras.GetPlayerAuraBySpellID (primary aura source, Midnight 12.x)
    - UNIT_AURA WoW event (event-driven aura detection)
    - ACTIVE_PLAYER_SPECIALIZATION_CHANGED WoW event (spec awareness)
  patterns:
    - Snapshot-diff pattern: compare prevReady to current to detect buff additions (not removals)
    - Seed-before-register: SeedAuraSnapshot() called before RegisterEvent("UNIT_AURA") to prevent login race
    - SetNextBeastId as canonical rotation setter (always goes through DB.nextIndex write + NormalizeNextIndex)
    - C_UnitAuras nil-guard pattern: if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false end
    - UNIT_AURA player-unit guard: if unitTarget ~= "player" then return end (T-02-02)

key-files:
  created: []
  modified:
    - PLBeast/PLBeast.lua
    - PLBeast/Locales/enUS.lua

key-decisions:
  - "PLBeast SetNextBeastId defaults to 'wyvern' (PLH uses 'boar'); intentional deviation per PATTERNS.md section 6"
  - "ADDON_LOADED restores saved nextIndex via NormalizeNextIndex + ID_BY_INDEX lookup (not unconditional SetNextBeastId wyvern)"
  - "SeedAuraSnapshot called before RegisterEvent(UNIT_AURA) to prevent double-advancement-on-login bug (Pitfall 1)"
  - "SyncNextFromAddedReady uses flat startTimes table (not PLH nested readySnapshot.start struct)"
  - "Spec flags (isBeastMastery, isSurvival) are debug-output only in Phase 2; they do not gate rotation logic"
  - "ResetAuraState trims all CDM/hogstrider/wyvernBuff state from PLH; only clears prevReady"

patterns-established:
  - "Snapshot-diff: build current table, diff against prevReady, collect addedBeasts, call SyncNextFromAddedReady"
  - "Seed-before-register: always call SeedAuraSnapshot() before RegisterEvent(UNIT_AURA)"
  - "SetNextBeastId is the sole writer of nextBeastId and DB.nextIndex -- never write them directly"
  - "BEAST_LABEL_BY_ID[nextBeastId] for capitalized names in dprint (never raw nextBeastId)"

requirements-completed: [TRACK-01, TRACK-02, TRACK-03, TRACK-04, TRACK-05]

# Metrics
duration: 10min
completed: "2026-06-18"
---

# Phase 02 Plan 01: Rotation Tracking Summary

**Event-driven beast rotation state machine using UNIT_AURA snapshot-diff with C_UnitAuras, NEXT_BEAST cycle table, session-persistent nextIndex, and /plbeast debug/reset slash commands**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-06-18
- **Completed:** 2026-06-18
- **Tasks:** 1 of 2 (Task 2 is a blocking in-game verification checkpoint)
- **Files modified:** 2

## Accomplishments

- Full rotation tracking engine: 5 data tables (NEXT_BEAST, ID_BY_INDEX, INDEX_BY_ID, READY_SPELL_BY_ID, BEAST_LABEL_BY_ID), 8 functions
- Snapshot-diff detection via UNIT_AURA events — advances rotation exactly once per buff transition, never on every event fire
- Multi-beast sort in SyncNextFromAddedReady by aura start time (expirationTime - duration), INDEX_BY_ID fallback
- Session persistence: ADDON_LOADED clamps saved DB.nextIndex via NormalizeNextIndex and restores nextBeastId
- Login race prevention: SeedAuraSnapshot() seeds prevReady before UNIT_AURA registration (Pitfall 1 fix)
- /plbeast debug toggles DB.debug with formatted output; /plbeast reset returns to wyvern and re-seeds snapshot
- All threat mitigations from T-02-01 through T-02-04 implemented inline

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement rotation tracking engine with event-driven detection and debug output** - `9923456` (feat)

*Task 2 (checkpoint:human-verify) is pending in-game verification — no commit until user confirms.*

## Files Created/Modified

- `PLBeast/PLBeast.lua` - Added 8 core functions (NormalizeNextIndex, SetNextBeastId, SyncNextFromAddedReady, ResetAuraState, IsReadyBuffActive, CheckAuraState, SeedAuraSnapshot, RefreshHunterSpecState), 5 data tables, 3 spell constants, 2 spec constants, module state vars, UNIT_AURA + ACTIVE_PLAYER_SPECIALIZATION_CHANGED event wiring, complete slash command routing
- `PLBeast/Locales/enUS.lua` - Added "Rotation reset. Next: Wyvern." and "PLBeast. /plbeast debug | reset" locale keys

## Decisions Made

- `SetNextBeastId` defaults to "wyvern" (not "boar" as in PackLeaderHelper) — wyvern is the canonical rotation start beast for PLBeast
- ADDON_LOADED uses `NormalizeNextIndex() + ID_BY_INDEX[DB.nextIndex]` to restore saved index, not an unconditional `SetNextBeastId("wyvern")` — saved index is ground truth per RESEARCH.md
- `SyncNextFromAddedReady` receives a flat `startTimes` table (not PLH's nested `readySnapshot.start`) — simpler API for PLBeast's pure C_UnitAuras path
- `ResetAuraState` trims all CDM/hogstrider/wyvern-buff clearing from PLH; only resets `prevReady` — out-of-scope state does not exist in PLBeast

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. All planned functionality is implemented. The slash handler's "reset" subcommand (previously deferred to v2 per STATE.md) is now fully implemented per the plan.

## Threat Surface Scan

No new security-relevant surface beyond the plan's threat model. All STRIDE mitigations in T-02-01 through T-02-04 are implemented:
- T-02-01: NormalizeNextIndex() clamps DB.nextIndex with tonumber fallback
- T-02-02: UNIT_AURA handler guards `unitTarget ~= "player"` immediately
- T-02-03: IsReadyBuffActive guards C_UnitAuras availability before every call
- T-02-04: Slash input normalized via :lower():match("^%s*(.-)%s*$"); only exact "debug"/"reset" route to handlers

## Issues Encountered

None.

## Next Phase Readiness

- Rotation engine complete and observable via /plbeast debug
- Task 2 in-game verification is a blocking checkpoint — Phase 3 should not begin until user confirms rotation advances correctly in WoW client
- Phase 3 (icon display) will read `nextBeastId` directly from module scope to select the beast icon texture

---
*Phase: 02-rotation-tracking*
*Completed: 2026-06-18*

## Self-Check

- [x] PLBeast/PLBeast.lua exists and contains all 8 functions
- [x] PLBeast/Locales/enUS.lua exists with new locale keys
- [x] Commit 9923456 exists (feat(02-01): implement rotation tracking state machine in PLBeast)
- [x] No CDM/hogstrider/wyvernBuff functional code in PLBeast.lua (only in comments)
- [x] BEAST_LABEL_BY_ID used in dprint next= field
- [x] SeedAuraSnapshot called before RegisterEvent("UNIT_AURA") in PLAYER_LOGIN

## Self-Check: PASSED
