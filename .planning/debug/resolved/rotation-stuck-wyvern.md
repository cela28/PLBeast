---
status: resolved
trigger: "Rotation prediction never advances: nextBeastId is permanently stuck on wyvern. /plbeast debug shows CheckAuraState running on UNIT_AURA but always printing wyvern=false boar=false bear=false idx=1 even while Pack Leader beasts are actually spawning/becoming ready."
created: 2026-06-21
updated: 2026-06-21
---

# Debug Session: rotation-stuck-wyvern

## Symptoms

- **Expected behavior:** As Pack Leader beasts (wyvern/boar/bear) become ready in the rotation, `nextBeastId` should advance through the cycle (wyvern → boar → bear → wyvern) and the Phase 4 icon texture should follow it.
- **Actual behavior:** `nextBeastId` is permanently stuck on "wyvern". The icon faithfully renders wyvern and never changes because the prediction never moves.
- **Error messages:** No Lua errors. `/plbeast debug` chat output consistently shows: `next=Wyvern wyvern=false boar=false bear=false idx=1` — repeated on every UNIT_AURA, all three ready reads always false even while beasts are spawning in-game.
- **Timeline:** Present since rotation tracking was built (Phase 2). Surfaced during Phase 4 (04-01) in-game human verification on 2026-06-21. Phase 3 visibility gating and Phase 4 icon rendering both confirmed working.
- **Reproduction:** On a BM/SV hunter with Pack Leader hero talent, `/plbeast debug` on, then trigger beast spawns in combat. The `next=` value never changes from Wyvern; all three `wyvern=/boar=/bear=` reads stay false.

## Scope guard

- Phase 4 icon UI (CreateBeastIcon, texture push, visibility bridge) is CONFIRMED WORKING and independent of this bug. **Do not modify Phase 4 icon code.** The icon correctly displays whatever `nextBeastId` holds; the defect is purely in the rotation-detection feeding it.

## Current Focus

hypothesis: PLBeast detects beast-ready states ONLY via C_UnitAuras.GetPlayerAuraBySpellID for spell IDs 471878 (wyvern), 472324 (boar), 472325 (bear). Those Pack Leader "ready" states are NOT exposed as player auras under these IDs, so the lookup always returns nil and no beast is ever detected as added — SyncNextFromAddedReady/SetNextBeastId never fire, freezing nextBeastId. The working parent addon PackLeaderHelper.lua detects these PRIMARILY from the Cooldown Manager (CDM) via cdmCache[spellId].cdmFrame.auraInstanceID in BuildReadySnapshot() (PackLeaderHelper.lua:1966-2006), using C_UnitAuras only as a weak fallback. PLBeast has ZERO CDM integration. Root cause traces to Phase 2 design decision D-02 ("seed prevReady directly without CDM dependency").
test: Confirm in-game (user has live WoW access) that C_UnitAuras.GetPlayerAuraBySpellID(471878/472324/472325) returns nil at the moment a beast IS ready; and that the CDM cooldown-viewer entries for those spell IDs are populated. Then verify a CDM-based read detects readiness.
expecting: Aura lookups return nil when a beast is ready (confirming the aura-only path is the wrong source); CDM data is present (confirming the fix direction).
next_action: ROOT CAUSE CONFIRMED by user + scope APPROVED (Option A — full CDM fix). Implement: port parent's CDM cache + auraInstanceID-primary read into PLBeast feeding CheckAuraState, keep C_UnitAuras as fallback, add a C_Timer poll ticker gated on isPackLeaderActive. Do NOT touch Phase 4 icon code. Then verify in-game with user.

reasoning_checkpoint:
  hypothesis: "PLBeast freezes on wyvern because its ONLY ready-detection source is C_UnitAuras.GetPlayerAuraBySpellID(471878/472324/472325), but Pack Leader beast-ready states are not exposed as player auras under those IDs — they are Cooldown Manager (C_CooldownViewer) tracked entries whose readiness is signaled by cdmFrame.auraInstanceID. So IsReadyBuffActive always returns false, no beast is ever 'added', SyncNextFromAddedReady never fires, nextBeastId never advances."
  confirming_evidence:
    - "PLBeast.lua:164-169 IsReadyBuffActive uses ONLY C_UnitAuras.GetPlayerAuraBySpellID; no CDM path exists anywhere in the file."
    - "Parent PackLeaderHelper.lua:1977-1989 reads beast-ready PRIMARILY from cdmCache[spellId].cdmFrame.auraInstanceID; C_UnitAuras (1991-2003) is only a secondary fallback that, in practice, populates start/duration but the primary 'active' signal comes from the CDM instance ID."
    - "Parent discovers these exact spell IDs via C_CooldownViewer.GetCooldownViewerCooldownInfo / GetCooldownViewerCategorySet (RegisterDiscoveredCooldown L1888-1899) — i.e. they are cooldown-viewer entries, not standalone player auras."
    - "Parent is driven by a PollCDMState polling loop (20Hz tick), not by UNIT_AURA — consistent with the ready state living in CDM frames, not in the aura event stream."
    - "In-game debug output: wyvern=false boar=false bear=false on every UNIT_AURA even while beasts spawn — exactly what an always-nil GetPlayerAuraBySpellID produces."
  falsification_test: "If, the instant a beast is ready in-game, C_UnitAuras.GetPlayerAuraBySpellID(471878/472324/472325) returns a non-nil aura table, the hypothesis is WRONG and the bug lies elsewhere (e.g. prevReady never resetting, UNIT_AURA not registered, or spec-gate suppressing the path)."
  fix_rationale: "Re-introduce a CDM-based read (adapt parent's cdmCache + auraInstanceID primary path) feeding CheckAuraState, keeping C_UnitAuras as fallback. This addresses the root cause (wrong data source) rather than a symptom. Likely also requires a polling drive (C_Timer ticker) since CDM readiness is not delivered via UNIT_AURA."
  blind_spots: "Have not yet confirmed in-game that GetPlayerAuraBySpellID is actually nil for these IDs (static analysis strongly implies it but is not proof). Have not confirmed UNIT_AURA even fires when CDM-only ready state changes. Have not confirmed whether a UNIT_AURA-only drive would still work if a CDM read were added (may need a ticker). These are exactly what the checkpoint snippets resolve."
tdd_checkpoint:

## Likely fix direction (confirm before large rework)

Re-introduce a CDM-based ready-detection path into PLBeast (adapt PackLeaderHelper's cdmCache + BuildReadySnapshot / auraInstanceID approach) feeding CheckAuraState, keeping the C_UnitAuras path as fallback. This reverses Phase 2 decision D-02 and adds a CDM dependency, so confirm scope with the user before implementing.

## Evidence

- timestamp: 2026-06-21 — In-game `/plbeast debug` output shows `next=Wyvern wyvern=false boar=false bear=false idx=1` repeatedly on UNIT_AURA; rotation never advances.
- timestamp: 2026-06-21 — Code review: PLBeast/PLBeast.lua has no C_CooldownViewer/cdmCache references (grep returned NONE). Only detection path is C_UnitAuras.GetPlayerAuraBySpellID in IsReadyBuffActive (~L164) and CheckAuraState (~L174).
- timestamp: 2026-06-21 — PackLeaderHelper.lua:1966-2006 BuildReadySnapshot reads cdmCache[spellId].cdmFrame.auraInstanceID as primary source, C_UnitAuras as secondary. Same spell IDs (471878/472324/472325) used in both.
- timestamp: 2026-06-21 — VERIFICATION: confirmed parent discovers these spell IDs exclusively through C_CooldownViewer (RegisterDiscoveredCooldown L1888-1899 maps cooldownID→spellID via GetCooldownViewerCooldownInfo). The "active" signal in BuildReadySnapshot's primary branch (L1980-1982) is `type(inst)=="number" and inst>0` where inst = cdmFrame.auraInstanceID — i.e. readiness lives in CDM frame state, not in a player-aura lookup. Implication: PLBeast's aura-only IsReadyBuffActive is reading the wrong source.
- timestamp: 2026-06-21 — VERIFICATION: confirmed parent is driven by PollCDMState (L2068) on a 20Hz tick, NOT by UNIT_AURA. PLBeast drives detection solely off UNIT_AURA (PLBeast.lua:418-422). Implication: even if a CDM read is added, PLBeast may need a polling/ticker drive because CDM readiness changes are not guaranteed to emit UNIT_AURA for the player unit.
- timestamp: 2026-06-21 — USER CONFIRMED in-game: Part 1 hypothesis correct (C_UnitAuras.GetPlayerAuraBySpellID returns nil for 471878/472324/472325 while a beast is ready; CDM cooldown-viewer entries are populated). Root cause is confirmed, not just inferred.
- timestamp: 2026-06-21 — USER APPROVED scope Option A (full CDM fix): re-introduce CDM dependency reversing Phase 2 D-02. Proceed to implementation without a further scope checkpoint.

## Round 2 — partial fix, new symptom (stale CDM cache)

After the CDM fix (047df26) the rotation NOW advances — but only for ~2 beasts, then freezes.

- timestamp: 2026-06-21 — USER in-game with v0.1.1: rotation advanced wyvern→boar→bear then froze at `next=Bear ... wyvern=false boar=false bear=false idx=3`.
- timestamp: 2026-06-21 — Debug lines KEEP printing while stuck (poll ticker is alive — NOT a ticker-death bug). All three reads are stuck FALSE.
- timestamp: 2026-06-21 — `/reload` temporarily restores rotation, then it stops again after ~2 beasts. Repeatable.
- INTERPRETATION (high confidence): stale CDM cache. cdmCache is built once and its cdmFrame references (or cooldownID→frame mapping) go invalid after the Blizzard Cooldown Manager recycles/rebuilds its frame pool, so auraInstanceID reads return nil for all beasts. A reload rebuilds the cache (works ~2 beasts) until it goes stale again.
- FIX DIRECTION: rebuild/refresh the CDM cache on CDM data-change events as the parent addon does — PackLeaderHelper.lua registers `EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", ...)` (~L2590) and rebuilds via BuildCDMCache; it also re-resolves cdmFrame lazily (FindCDMFrameByCooldownID) rather than caching a frame ref that can go stale. Prefer re-resolving the frame each poll by cooldownID, or invalidate+rebuild on OnDataChanged, instead of holding a one-time frame reference.

next_action_round2: investigate why reads go all-false after ~2 beasts (confirm stale cdmFrame ref vs. cache never refreshed); implement cache refresh/re-resolve per parent addon; do NOT touch Phase 4 icon code.

- timestamp: 2026-06-21 (R2 investigation) — CONFIRMED stale-cache root cause by static analysis. PLBeast built cdmCache ONCE (at activation in RefreshVisibility, and lazily in CheckAuraState) and NEVER rebuilt it. grep confirmed ZERO `OnDataChanged`/`EventRegistry` references in PLBeast.lua (only 3 BuildCDMCache call sites, all one-shot). The parent (PackLeaderHelper.lua:2590-2599) registers `CooldownViewerSettings.OnDataChanged` → rebuilds cache; PLBeast did not. CRITICAL: PLBeast's old EnsureCacheFramesResolved only re-resolved a cdmFrame when it was NIL — a stale-but-non-nil frame (CDM recycled the pooled frame and reassigned it to a different cooldown) was NEVER re-resolved, so auraInstanceID read nil for all three beasts → current all-false → no "added" beast → frozen. /reload rebuilt the cache → worked ~2 beasts → went stale again. Matches the exact symptom (stuck idx=3, all three false, ticker alive).
- timestamp: 2026-06-21 (R2 fix) — Implemented three complementary, parent-proven, pcall/availability-guarded defenses in PLBeast/PLBeast.lua: (1) EnsureCacheFramesResolved now re-resolves a cdmFrame whenever it is nil OR no longer owns its cooldownID (new FrameStillOwnsCooldown helper); (2) rebuild-on-miss in CheckAuraState — when CDM yields readiness for NO beast, rebuild the whole cache and re-read, rate-limited to once/1.0s (CDM_REBUILD_COOLDOWN) so legitimate downtime does not trigger a 10Hz rebuild storm; (3) registered CooldownViewerSettings.OnDataChanged at PLAYER_LOGIN to BuildCDMCache (deferred 0.5s) exactly as the parent does. Bumped TOC version 0.1.1 → 0.1.2. Phase 4 icon code untouched.

## Eliminated

- hypothesis: Phase 4 icon texture-push bug — ELIMINATED. Debug output proves `nextBeastId`/`next=` itself never advances; the icon is downstream of a frozen prediction.
- hypothesis: Sentinel/Dark-ranger hero-talent detection bug — ELIMINATED. User confirmed visibility gating (Sentinel SV correctly hides) works fine.

## Resolution

root_cause: |
  PLBeast detected beast-ready states ONLY via C_UnitAuras.GetPlayerAuraBySpellID for spell IDs
  471878 (wyvern), 472324 (boar), 472325 (bear). These Pack Leader "ready" states are NOT exposed
  as player auras under those IDs — the readiness lives in the Blizzard Cooldown Manager
  (C_CooldownViewer), signaled by the tracked CDM frame's auraInstanceID being a positive number.
  USER CONFIRMED in-game that GetPlayerAuraBySpellID returns nil while a beast IS ready, while the
  CDM cooldown-viewer entries are populated. Because PLBeast had ZERO CDM integration, IsReadyBuffActive
  always returned false, no beast was ever detected as "added", SyncNextFromAddedReady/SetNextBeastId
  never fired, and nextBeastId stayed frozen on wyvern. Traces to Phase 2 design decision D-02
  ("seed prevReady directly without CDM dependency").
fix: |
  Option A (full CDM fix) — adapted the proven CDM approach from PackLeaderHelper.lua into PLBeast,
  kept minimal:
  - Added TRACKED_SPELL_IDS (three beast-ready spells) and module state cdmCache / cdmCacheBuilt.
  - Added a CDM discovery path: FindCDMFrameByCooldownID, ReadSpellFromCooldownID,
    RegisterDiscoveredCooldown, GatherCooldownsFromFrameTree, GatherCooldownsFromViewerCategories,
    BuildCDMCache, EnsureCacheFramesResolved (all pcall/availability-guarded per CLAUDE.md).
  - Added IsReadyViaCDM (primary: cdmFrame.auraInstanceID > 0) and IsReadyViaAura (the original
    C_UnitAuras path, now a SECONDARY fallback). IsReadyBuffActive prefers CDM, falls back to aura.
  - CheckAuraState now lazily builds + resolves the CDM cache before reading.
  - Added a C_Timer.NewTicker poll ticker (POLL_INTERVAL 0.1s) driven by StartPollTicker/StopPollTicker,
    started/stopped in RefreshVisibility alongside UNIT_AURA register/unregister, gated on
    isPackLeaderActive (CDM readiness is not reliably delivered via UNIT_AURA).
  - On (re)activation RefreshVisibility now calls BuildCDMCache() then SeedAuraSnapshot() before
    registering UNIT_AURA / starting the ticker, preventing spurious advance on activation.
  Phase 4 icon code (CreateBeastIcon, SetNextBeastId texture push, root:SetShown bridge) untouched.
verification: |
  ROUND 1: rotation began advancing in-game (CDM-primary read worked) but froze after ~2 beasts —
  superseded by Round 2.
  ROUND 2 (stale-cache fix): CONFIRMED FIXED by user in-game on 2026-06-21 with v0.1.2 — "It seems to be
  working fine"; rotation now advances across multiple cycles without /reload. Session RESOLVED.
  Note (separate, deferred): user observed the icon positioned top-right rather than screen center.
  Out of scope for this rotation-detection bug; to be investigated when Phase 4 Wave 2 (04-02
  ApplyIconSettings / drag / position persistence) is executed — 04-02 re-asserts the CENTER anchor on
  login and is the natural place to confirm or fix this.
  Original ROUND 2 detail: The fix targets the stale cdmCache:
  cdmFrame references went invalid after the Blizzard CDM recycled its frame pool, and the old
  EnsureCacheFramesResolved only re-resolved NIL frames, never stale-non-nil ones. Three defenses
  now keep reads working across many cycles: (1) re-resolve a cdmFrame when it no longer owns its
  cooldownID, (2) rate-limited rebuild-on-miss (≤1/s) when CDM yields no readiness, (3) rebuild on
  CooldownViewerSettings.OnDataChanged (parent-proven). No Lua interpreter in this env for a syntax
  pass; structural review confirms balanced scope and correct upvalue ordering (FrameStillOwnsCooldown,
  EnsureCacheFramesResolved, BuildCDMCache all defined before their PLAYER_LOGIN-runtime closures).
  The orchestrator will collect the user's in-game verdict (see CHECKPOINT REACHED). Must NOT be
  marked resolved until the user confirms sustained multi-cycle rotation with no /reload.
files_changed:
  - PLBeast/PLBeast.lua: (R1) added CDM ready-detection path (cache + auraInstanceID primary read), poll ticker, kept C_UnitAuras as fallback. (R2) stale-frame re-resolution (FrameStillOwnsCooldown), rate-limited rebuild-on-miss in CheckAuraState, CooldownViewerSettings.OnDataChanged cache rebuild at PLAYER_LOGIN.
  - PLBeast/PLBeast.toc: version 0.1.1 → 0.1.2 (so the user can confirm they are running the round-2 build)
