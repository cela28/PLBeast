---
status: partial
phase: 06-release-pipeline
source:
  - .planning/phases/06-release-pipeline/06-01-SUMMARY.md
  - .planning/phases/05.1-event-driven-rotation-tracking-drop-10hz-poll/05.1-01-SUMMARY.md
started: 2026-06-29T17:43:24Z
updated: 2026-06-29T17:43:24Z
note: |
  Combined in-game UAT for the v1.0.0 release build. Tests 1 verifies the
  Phase 06 release-load gate; Tests 2-7 verify the Phase 05.1 event-driven
  rotation rewrite + perf, which ships in the same downloaded build.
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[paused — 2 issues found (wyvern default, perf/throttle). Fixing as v1.0.1;
tests 3, 4, 5, 7 to be run on the patched build.]

## Tests

### 1. Cold install & load (v1.0.0 release)
expected: Download PLBeast-1.0.0.zip from the v1.0.0 release, extract into AddOns/, log in on a Pack Leader hunter. PLBeast shows enabled in AddOns list; next-beast icon renders; no Lua error on login or /reload.
result: pass

### 2. Default prediction is Boar
expected: On fresh state (no prior prediction saved), the icon shows Boar as the next beast.
result: issue
reported: "Icon does show Boar, but the default should be Wyvern — the rotation order is wyvern → boar → bear. Boar-as-default (D-08, Azor parity) is wrong for this player's expectation; original PLBeast reset to wyvern (TRACK-03)."
severity: major
note: "Pre-flagged decision gate — see todo 2026-06-24-reconsider-login-boss-reset. Ring order is correct; only the fresh/default anchor is wrong. Self-corrects on first ready buff, so impact is limited to pre-first-cast (fresh login + boss pull)."

### 3. Rotation advance & self-correction
expected: In combat using Pack Leader abilities, as each beast's ready buff appears the icon pins to that beast (boar-ready shows the boar icon). On consume it advances boar → bear → wyvern → boar. Prediction matches the actual next beast every cycle and re-syncs if it ever drifts.
result: [pending]

### 4. Persistence across /reload and relog
expected: Note the current prediction, then /reload (and optionally log out/in). The prediction is preserved — it does NOT snap back to the default.
result: [pending]

### 5. /plbeast reset command
expected: Running /plbeast reset prints "Rotation reset. Next: Boar." in chat and the icon shows Boar.
result: [pending]

### 6. Idle behavior / no 10Hz poll
expected: With the icon shown but out of combat and idle, there is no constant CPU churn or stutter (the old 10Hz ticker is gone). If you profile via the addon CPU usage tools, PLBeast's idle CPU is negligible.
result: issue
reported: "User measured CPU usage in-game and it is higher than expected."
severity: major
root_cause: |
  The OnUpdate throttle is broken. RESEARCH.md:200 falsely claims GetTime() has
  1-second resolution, so the guard `if now == lastPolledTime then return end`
  (PLBeast.lua:408) was believed to throttle PollPackLeader to ~1Hz. In reality
  GetTime() advances every frame, so the guard never trips and PollPackLeader()
  runs EVERY FRAME (60-165+ Hz) — 60-165x the intended 1Hz and 6-16x the old 10Hz
  ticker it replaced. Azor actually throttles via its Scheduler (C_Timer.After,
  interval=1); PLBeast dropped the Scheduler and relied solely on the ineffective
  GetTime equality guard.
  Compounding: (a) CDMFrameHasAura (PLBeast.lua:288-297) does a full frame-tree DFS
  every call for any unresolved beast frame (the 2 inactive beasts, almost always) —
  now at framerate; (b) dprint args at PLBeast.lua:393-398 concatenate every poll
  even with debug off.
  Only burns CPU while the Pack Leader spec is active (root shown -> OnUpdate fires).

### 7. Drag & scale persist (UI regression)
expected: Drag the icon to a new position and change its scale, then /reload. Position and scale are retained.
result: [pending]

## Summary

total: 7
passed: 1
issues: 2
pending: 4
skipped: 0

## Gaps

- truth: "Fresh/default next-beast prediction reflects the start of the rotation (wyvern), so the icon is correct before the first Pack Leader ability — especially at a boss pull."
  status: failed
  reason: "User reported: default is boar but should be wyvern. D-08 set boar for Azor parity; original PLBeast (TRACK-03) reset to wyvern on login/boss-pull. Ring order is correct; only the anchor/default is wrong. Self-corrects after first ready buff."
  severity: major
  test: 2
  artifacts:
    - "PLBeast/PLBeast.lua:16 (plNextBeastId default = boar)"
    - "PLBeast/PLBeast.lua:107 (nextBeastId default = boar)"
    - "PLBeast/PLBeast.lua:179 (SetNextBeastId fallback boar)"
    - "PLBeast/PLBeast.lua:389 (reset fallback boar)"
  missing:
    - "Decision: default anchor (wyvern vs boar)"
    - "Decision: whether to re-add TRACK-03 login/boss-pull reset-to-wyvern on top of the self-correcting model"
  resolution: |
    DECIDED (user): default anchor -> wyvern everywhere (fresh state, spec change,
    /plbeast reset, error fallback) AND re-add TRACK-03 reset-to-wyvern on fresh
    login (PLAYER_ENTERING_WORLD isInitialLogin) + boss pull (ENCOUNTER_START).
    Event-driven, zero per-frame cost. Diverges from Azor by design; removable later.
    Locale reset string -> "Rotation reset. Next: Wyvern."
  related_todo: ".planning/todos/pending/2026-06-24-reconsider-login-boss-reset.md"

- truth: "Detection is event/poll-driven at Azor's ~1Hz cadence with negligible CPU while the Pack Leader spec is active (PERF-01)."
  status: failed
  reason: "User measured higher-than-expected CPU. OnUpdate throttle is ineffective — GetTime() equality guard never trips (GetTime advances every frame), so PollPackLeader runs at framerate, not 1Hz. Root false premise: RESEARCH.md:200 claims GetTime() has 1-second resolution."
  severity: major
  test: 6
  artifacts:
    - "PLBeast/PLBeast.lua:406-410 (OnUpdateHandler — equality guard should be interval threshold)"
    - "PLBeast/PLBeast.lua:288-297 (CDMFrameHasAura — per-frame DFS for unresolved beasts)"
    - "PLBeast/PLBeast.lua:393-398 (dprint arg concatenation runs even when debug off)"
    - ".planning/phases/05.1-event-driven-rotation-tracking-drop-10hz-poll/05.1-RESEARCH.md:200 (false GetTime resolution claim — source of the bug)"
  missing:
    - "Interval-threshold throttle in OnUpdateHandler (POLL_INTERVAL, e.g. 1.0 to match Azor or 0.1 for 10Hz)"
    - "Gate dprint block behind DB.debug to avoid per-poll string concatenation"
    - "Decision: poll cadence — 1.0s (Azor parity) vs 0.1s (responsiveness)"
  resolution: |
    DECIDED (user): POLL_INTERVAL = 1.0s (Azor parity). Replace the `now == lastPolledTime`
    equality guard with `if now - lastPolledTime < POLL_INTERVAL then return end`.
    Also gate the dprint block at PLBeast.lua:393-398 behind `if DB and DB.debug then`.
    Fix the false GetTime()-resolution claim in RESEARCH.md:200 so it doesn't mislead later.
