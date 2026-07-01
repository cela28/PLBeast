---
created: 2026-06-23T20:59:07.378Z
title: Replace 10Hz poll with event-driven rotation tracking
area: rotation-tracking
files:
  - PLBeast/PLBeast.lua:101-102 (POLL_INTERVAL=0.1)
  - PLBeast/PLBeast.lua:377-439 (CheckAuraState)
  - PLBeast/PLBeast.lua:474-486 (StartPollTicker/StopPollTicker)
  - PLBeast/PLBeast.lua:398-410 (rebuild-on-all-false self-heal)
---

## Problem

PLBeast drives beast detection off a constant `C_Timer.NewTicker(0.1, …)` poll that
runs `CheckAuraState` ~10×/sec (~600 calls/min) the entire time Pack Leader is active —
even when idle, out of combat, with nothing changing. Each tick re-resolves CDM frame
refs and reads 3 ready buffs, allocating 1–3 tables (GC churn). `UNIT_AURA` *also* calls
`CheckAuraState`, so the event path is already there and the poll is redundant overhead.
Surfaced during Phase 2 in-game verification (UAT 8/8 pass — this is performance, not a
correctness bug).

The poll exists because of a "rotation freezes after ~2 beasts" bug: the CDM frame pool
gets rebuilt and cooldownIDs reassigned, invalidating cached `cdmFrame` refs. PLBeast's
current workaround is to rebuild the *entire* cache whenever all three reads come back
false (PLBeast.lua:398-410), which only reliably fires under polling.

## Solution

Adopt AzortharionUI's fully event-driven model (reference impl:
`/home/cela/code_stuff/AddonTest/AzortharionUI - 7.5/AzortharionUI/Modules/BuffTracking/Hunter.lua`):

1. Drive `CheckAuraState` from `UNIT_AURA` (player-only) alone; delete the poll ticker
   (`StartPollTicker`/`StopPollTicker`, `POLL_INTERVAL`, `pollTicker`).
2. Replace the rebuild-whole-cache-on-all-false self-heal with **lazy per-frame
   re-resolve by cooldownID** — when a cached `cdmFrame` ref is nil, look it up on demand
   via `FindCDMFrameByCooldownID` (cf. Azortharion's `CDMFrameHasAura` →
   `FindCDMFrameByCooldownID`). This fixes the freeze without polling.
3. Keep the debounced `CooldownViewerSettings.OnDataChanged` → cache-rebuild hook
   (already present, PLBeast.lua:904-915); optionally also rebuild on
   `COOLDOWN_VIEWER_DATA_LOADED` / `..._SPELL_OVERRIDE_UPDATED` like Azortharion.
4. Optionally debounce `UNIT_AURA` (~0.05s, cf. `AURA_DISPATCH_MIN_GAP`) to cap bursts.

Net: ~0 work when idle vs. ~600 scans/min today.

## Decision (2026-06-24) — promoted to Phase 5.1

User decision: PLBeast should **behaviorally match AzortharionUI exactly**, not just
drop the poll. That means adopting Azor's **self-correcting prediction model** (predict
the beast whose ready buff is actually active — `Hunter.lua:298` — and advance on
consumption — `:308`), which re-syncs to the game continuously. Consequences:
- Resolves a likely off-by-one: PLBeast currently predicts `NEXT_BEAST[spawned]` (the beast
  *after* the ready one); Azor predicts the *ready* beast itself.
- The explicit login/boss-pull reset-to-wyvern (TRACK-03) is **dropped** for parity — the
  self-correcting model makes it largely redundant. Default becomes boar; persist across
  relog; reset-to-boar on spec change (Azor's semantics).
- Verify by **in-game side-by-side**: PLBeast's next beast must match Azor's step-for-step.
- Measure idle cost via AddonProfiler to confirm the perf win.

This todo is now tracked as **Phase 5.1: Event-Driven Rotation Tracking** in ROADMAP.md
(requirement PERF-01). Re-adding the login/boss reset later is a separate todo
([[2026-06-24-reconsider-login-boss-reset]]).

---
## Resolution (2026-07-01)
DONE — Shipped as Phase 5.1 (event-driven CDM poll, self-correcting prediction).
In-game verified 7/7 on the v1.0.1 build (06-UAT.md). Note: the initial 5.1 build had
a per-frame poll bug (GetTime equality guard); fixed to true 1Hz in v1.0.1.
