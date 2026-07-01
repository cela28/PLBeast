---
status: complete
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

[testing complete — 7/7 passed on the v1.0.1 build]

## Tests

### 1. Cold install & load (v1.0.0 release)
expected: Download PLBeast-1.0.0.zip from the v1.0.0 release, extract into AddOns/, log in on a Pack Leader hunter. PLBeast shows enabled in AddOns list; next-beast icon renders; no Lua error on login or /reload.
result: pass

### 2. Default prediction is Wyvern
expected: On fresh state / initial login / after /plbeast reset, the icon shows Wyvern as the next beast; /plbeast reset prints "Rotation reset. Next: Wyvern."
result: pass
note: "Re-tested on v1.0.1 patch (commit 598e2c3). Was 'boar' in v1.0.0; fixed to wyvern anchor + TRACK-03 reset. Confirmed in-game."

### 3. Rotation advance & self-correction
expected: In combat using Pack Leader abilities, as each beast's ready buff appears the icon pins to that beast (boar-ready shows the boar icon). On consume it advances boar → bear → wyvern → boar. Prediction matches the actual next beast every cycle and re-syncs if it ever drifts.
result: pass
observation: "Order tracks correctly. User noted a small delay on the wyvern→boar transition specifically — explicitly flagged as 'not a real issue, just an observation.' Most likely the 1Hz POLL_INTERVAL cadence (up to ~1s to detect a buff change; Azor parity, chosen this patch). Tunable via POLL_INTERVAL (0.25/0.1) if it ever becomes bothersome. Not logged as a gap."

### 4. Persistence across /reload and relog
expected: Note the current prediction, then /reload (and optionally log out/in). The prediction is preserved — it does NOT snap back to the default.
result: pass
note: "/reload preserves prediction (SaveState/RestoreState via DB.plNextBeastId). Full logout/login intentionally resets to wyvern (TRACK-03 isInitialLogin), which is separate and correct."

### 5. /plbeast reset command
expected: Running /plbeast reset prints "Rotation reset. Next: Wyvern." in chat and the icon shows Wyvern.
result: pass
note: "Reset target updated boar->wyvern in v1.0.1 (commit 598e2c3). Confirmed message + icon in-game."

### 6. Idle behavior / no 10Hz poll
expected: With the icon shown but out of combat and idle, there is no constant CPU churn or stutter (the old 10Hz ticker is gone). If you profile via the addon CPU usage tools, PLBeast's idle CPU is negligible.
result: pass
reported: "User measured CPU usage in-game and it is higher than expected."
severity: major
root_cause: |
  The OnUpdate throttle was broken. RESEARCH.md:200 falsely claimed GetTime() has
  1-second resolution, so the guard `if now == lastPolledTime then return end`
  (PLBeast.lua:408) was believed to throttle PollPackLeader to ~1Hz. In reality
  GetTime() advances every frame, so the guard never tripped and PollPackLeader()
  ran EVERY FRAME (60-165+ Hz). Azor throttles via its Scheduler (interval=1);
  PLBeast dropped the Scheduler and relied solely on the ineffective GetTime guard.
resolution: |
  Fixed in v1.0.1 (commit 98e8050): POLL_INTERVAL=1.0 + elapsed-threshold guard
  `now - lastPolledTime < POLL_INTERVAL`; dprint block gated behind DB.debug.
  Re-tested in-game via AddonProfiler on the 1.0.1 build: PLBeast Average 0.001ms,
  Total 8.067ms, 0.03% of app CPU, 0x calls over 1ms, Spike Sum 0ms. Negligible.

### 7. Drag & scale persist (UI regression)
expected: Drag the icon to a new position and change its scale, then /reload. Position and scale are retained.
result: pass
note: "No regression from the 05.1 engine rewrite or the v1.0.1 patch. Position/scale persist across /reload."

## Summary

total: 7
passed: 7
issues: 0
pending: 0
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
