# Milestones

## v1.0 MVP (Shipped: 2026-07-01)

**Phases completed:** 7 phases, 8 plans, 14 tasks

**Key accomplishments:**

- Event-driven beast rotation state machine using UNIT_AURA snapshot-diff with C_UnitAuras, NEXT_BEAST cycle table, session-persistent nextIndex, and /plbeast debug/reset slash commands
- Pack Leader hero talent detection and spec-based visibility gating using IsPlayerSpell(), C_Timer.After() deferral, and conditional UNIT_AURA register/unregister.
- PLBeastFrame icon created eagerly at PLAYER_LOGIN with cropped wyvern/boar/bear texture, BackdropTemplate black 1px border, and visibility driven by isPackLeaderActive — human-verified in-game with correct texture, border, and spec-gated show/hide
- Drag-to-reposition (left button) with silent combat-lockdown guard and center-offset DB persistence, plus ApplyIconSettings() applying independent SetSize width/height and BackdropTemplate border from PLBeastDB on login — human-verified in-game
- `/plbeast` now opens a lightweight, combat-guarded options window with live Width / Height / Border-Thickness sliders and a Lock-position toggle — verified in-game across builds 0.2.0–0.2.4.
- Replaced 10Hz C_Timer.NewTicker poll with AzortharionUI's self-correcting CDM model — per-frame OnUpdate detection, lazy frame re-resolve, debounced rebuild, and string-based SavedVariables persistence.
- PLBeast v1.0.0 shipped via tag-triggered GitHub Actions — zip verified correct for WoW addon install
- v1.0.1 patch: fixed the per-frame poll CPU bug (1Hz POLL_INTERVAL throttle; was running every frame due to an ineffective GetTime equality guard) and restored the wyvern default anchor + login/boss-pull reset (TRACK-03). In-game UAT 7/7 on the v1.0.1 build; PLBeast idle CPU measured at 0.001ms avg / 0.03% of app.

**Released:** v1.0.0 (2026-06-29), v1.0.1 (2026-07-01) — both via tag-triggered GitHub Actions to GitHub Releases.

**Known deferred items at close:** 3 (see STATE.md Deferred Items) — legacy Phase 01/03 HUMAN-UAT scenarios + Phase 03 verification, superseded by the v1.0.1 comprehensive in-game UAT.

---
