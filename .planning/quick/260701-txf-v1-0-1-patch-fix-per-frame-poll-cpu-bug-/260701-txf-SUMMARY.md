---
phase: quick-260701-txf
plan: 01
subsystem: rotation-engine
tags: [perf, bug-fix, track-03, wyvern-default, version-bump]
status: complete

dependency_graph:
  requires: []
  provides: [PERF-01, TRACK-03]
  affects: [PLBeast/PLBeast.lua, PLBeast/Locales/enUS.lua, PLBeast/PLBeast.toc]

tech_stack:
  added: []
  patterns: [interval-threshold OnUpdate throttle, debug-gated dprint, event-driven TRACK-03 reset]

key_files:
  modified:
    - PLBeast/PLBeast.lua
    - PLBeast/Locales/enUS.lua
    - PLBeast/PLBeast.toc
    - .planning/phases/05.1-event-driven-rotation-tracking-drop-10hz-poll/05.1-RESEARCH.md

decisions:
  - "POLL_INTERVAL=1.0 elapsed-threshold replaces broken equality guard (now==lastPolledTime was ineffective — GetTime is high-precision, causing PollPackLeader to fire at framerate)"
  - "wyvern is the new default/fallback anchor at all four sites and two reset call sites (TRACK-03 requirement; deliberate divergence from D-08/Azor, removable in v2)"
  - "PLAYER_ENTERING_WORLD (isInitialLogin) and ENCOUNTER_START registered and handled for TRACK-03 reset; event-driven, zero per-frame cost"
  - "locale key and value both updated to Wyvern; L[] reference in reset handler updated to match"
  - "NEXT_BEAST ring order (boar->bear->wyvern->boar) unchanged — only anchor/default sites changed"

metrics:
  duration: ~15min
  completed: 2026-07-01
  tasks: 3
  commits: 3
---

# Phase quick-260701-txf Plan 01: v1.0.1 Patch Summary

**One-liner:** Interval-threshold OnUpdate throttle (POLL_INTERVAL=1.0) fixes per-frame poll CPU bug; wyvern default anchor + TRACK-03 login/boss-pull event resets added; version bumped to 1.0.1.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Fix per-frame poll CPU bug (interval throttle + debug-gated dprint) | 98e8050 | PLBeast/PLBeast.lua |
| 2 | Wyvern default anchor + TRACK-03 login/boss-pull reset + locale | 598e2c3 | PLBeast/PLBeast.lua, PLBeast/Locales/enUS.lua |
| 3 | RESEARCH.md GetTime-resolution correction + version bump to 1.0.1 | d87302f | 05.1-RESEARCH.md, PLBeast/PLBeast.toc |

## What Changed

### Task 1 — PERF-01: OnUpdate throttle fix

- Added `POLL_INTERVAL = 1.0` constant near `lastPolledTime` declaration (line ~120).
- Replaced broken equality guard `if now == lastPolledTime then return end` with elapsed-threshold form `if now - lastPolledTime < POLL_INTERVAL then return end`. GetTime() is high-precision frame time; the equality guard never matched, so PollPackLeader was firing at framerate (~60Hz) instead of ~1Hz.
- Wrapped the `dprint(...)` block inside `PollPackLeader` with `if DB and DB.debug then ... end` to eliminate string concatenation cost when debug is off.

### Task 2 — TRACK-03: Wyvern default + login/boss-pull reset

Four anchor sites changed from `"boar"` to `"wyvern"`:
- `defaults.plNextBeastId` (line ~16)
- Module-level `nextBeastId` init (line ~107)
- `SetNextBeastId` fallback in function body (line ~181)
- PollPackLeader consume-branch error fallback (line ~391)

Two reset call sites updated:
- `/plbeast reset` handler: `SetNextBeastId("wyvern")` + `L["Rotation reset. Next: Wyvern."]`
- `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` handler: `SetNextBeastId("wyvern")`

TRACK-03 events registered in PLAYER_LOGIN branch:
- `PLAYER_ENTERING_WORLD` — handler resets to wyvern only when `isInitialLogin` vararg is true
- `ENCOUNTER_START` — handler always resets to wyvern on boss pull

Both handlers call `ClearPackLeaderState() + SetNextBeastId("wyvern") + SaveState()`.

Locale (`enUS.lua`): key and value updated from `"Rotation reset. Next: Boar."` to `"Rotation reset. Next: Wyvern."`. Code reference in reset handler updated to match new key.

**NEXT_BEAST ring order unchanged:** `boar = "bear"`, `bear = "wyvern"`, `wyvern = "boar"`.

### Task 3 — RESEARCH.md correction + version bump

RESEARCH.md (05.1): surgical `CORRECTION (v1.0.1)` annotations at 6 false-claim sites:
- Core WoW APIs table row for `GetTime()`
- Pattern 1 "once per second via GetTime guard" description
- Pattern 2 paragraph and key-discovery claim
- Pitfall 1 entire block
- Assumption A1
- Tertiary sources entry
- Metadata confidence breakdown

PLBeast.toc: `## Version: 0.2.4` → `## Version: 1.0.1`.

## Verification Results

All grep gates passed:

```
POLL_INTERVAL declared and used in elapsed-threshold guard: PASS
Old equality guard gone: PASS
dprint gated behind DB and DB.debug: PASS
plNextBeastId = "wyvern" in defaults: PASS
nextBeastId module-level = "wyvern": PASS
or "wyvern" fallbacks (2 sites): PASS
ENCOUNTER_START registered and handled: PASS
PLAYER_ENTERING_WORLD registered and handled: PASS
isInitialLogin vararg captured: PASS
boar = "bear" in NEXT_BEAST (ring unchanged): PASS
wyvern = "boar" in NEXT_BEAST (ring unchanged): PASS
Locale Wyvern key/value: PASS (old Boar entry gone: PASS)
RESEARCH.md CORRECTION annotations (19 matches): PASS
PLBeast.toc Version 1.0.1: PASS (0.2.4 gone: PASS)
luac: unavailable — relied on grep gates
```

## Deviations from Plan

None — plan executed exactly as written. All four anchor sites, two reset call sites, TRACK-03 events, locale, RESEARCH.md corrections, and toc version bump are as specified.

## Self-Check: PASSED

- `PLBeast/PLBeast.lua` — modified, committed 98e8050 (task 1) and 598e2c3 (task 2)
- `PLBeast/Locales/enUS.lua` — modified, committed 598e2c3 (task 2)
- `PLBeast/PLBeast.toc` — modified, committed d87302f (task 3)
- `05.1-RESEARCH.md` — modified, committed d87302f (task 3)
- All 3 commits verified in git log
