---
created: 2026-06-24T00:30:00.000Z
title: Reconsider login/boss-pull reset-to-wyvern after Phase 5.1
area: rotation-tracking
files:
  - PLBeast/PLBeast.lua:957-966 (PLAYER_ENTERING_WORLD isInitialLogin → ResetRotationToWyvern)
  - PLBeast/PLBeast.lua:967+ (ENCOUNTER_START reset)
  - .planning/REQUIREMENTS.md (TRACK-03)
---

## Problem

Phase 5.1 adopts AzortharionUI's self-correcting, event-driven prediction model and, for
exact parity with Azor, **drops** PLBeast's explicit reset-to-wyvern on fresh login / full
relog / boss pull (the TRACK-03 behavior shipped in quick task 260622-1or, commit 5d59581,
and validated 8/8 in the Phase 2 UAT on 2026-06-23). Azor instead persists the prediction
across relog and only resets to boar on spec change, relying on continuous re-sync to the
actually-ready beast.

The user wants to ship the exact-match build first, **measure the performance difference**,
and then decide whether the login/boss-pull reset is still worth re-adding on top of the
self-correcting model.

## Solution

After Phase 5.1 ships and the perf comparison is done, evaluate:
1. Does the self-correcting model already make the prediction correct after a login/boss
   pull without an explicit reset? (Likely yes — it snaps to the first ready buff.) If so,
   the reset may be unnecessary.
2. If a deliberate "start-of-encounter anchor to wyvern" is still desired (e.g. the rotation
   genuinely restarts at wyvern on a boss pull and waiting for the first ready buff is too
   slow), re-add the `PLAYER_ENTERING_WORLD (isInitialLogin)` + `ENCOUNTER_START` reset on
   top of the new model, and restore/curate TRACK-03 accordingly.

Decision gate: the measured perf result + in-game observation of whether the prediction is
correct immediately after login/boss pull without the reset. TRACK-03 is currently
superseded-pending by Phase 5.1 (see REQUIREMENTS.md note).

Related: [[2026-06-23-event-driven-rotation-tracking]]

---
## Resolution (2026-07-01)
DECIDED & DONE — After the 5.1 perf fix (1Hz POLL_INTERVAL) and in-game observation,
user chose to RE-ADD the TRACK-03 reset: wyvern default anchor + reset-to-wyvern on
fresh login (PLAYER_ENTERING_WORLD isInitialLogin) + boss pull (ENCOUNTER_START).
Confirmed FPS-free (event-driven). Implemented in v1.0.1 (commit 598e2c3), verified
in-game (06-UAT.md tests 2/4/5). Diverges from Azor D-09 by design; removable later.
