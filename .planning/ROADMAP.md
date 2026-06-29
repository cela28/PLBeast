# Roadmap: PLBeast

## Overview

PLBeast is extracted from PackLeaderHelper as a standalone, minimal WoW addon. Six phases deliver the addon in strict dependency order: scaffold the addon skeleton first, then build the rotation tracking engine (the highest-risk component), then add spec/talent visibility gating, then the draggable icon UI, then the slash-command options panel, and finally the GitHub release pipeline. Each phase produces a verifiable, runnable increment.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Addon Scaffold** - TOC, SavedVariables, two-phase init, locale skeleton (completed 2026-06-18)
- [ ] **Phase 2: Rotation Tracking** - Aura reading, snapshot-diff, cyclic beast advancement
- [x] **Phase 3: Visibility Gating** - Pack Leader talent detection, spec filter, event refresh (completed 2026-06-19)
- [x] **Phase 4: Icon UI** - Draggable/scalable icon, border, position and size persistence (completed 2026-06-21)
- [x] **Phase 5: Configuration** - Slash command, options frame, drag toggle, combat guard (completed 2026-06-21)
- [x] **Phase 5.1: Event-Driven Rotation Tracking** - Drop the 10Hz poll; UNIT_AURA-driven detection + lazy CDM re-resolve (INSERTED) (completed 2026-06-29)
- [ ] **Phase 6: Release Pipeline** - GitHub Actions packaging, tag-triggered release zip

## Phase Details

### Phase 1: Addon Scaffold

**Goal**: A loadable PLBeast addon skeleton exists in the repo with correct TOC, SavedVariables round-trip, and locale stub
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: STRUCT-01, STRUCT-02, STRUCT-03, STRUCT-04, STRUCT-05
**Success Criteria** (what must be TRUE):

  1. A `PLBeast/` folder exists at repo root and WoW loads the addon without Lua errors on `/reload`
  2. `PLBeastDB` is present in SavedVariablesPerCharacter after login and survives a full logout/login cycle with values intact
  3. The `.toc` file declares the correct Interface version for Midnight (12.x) — Interface 120000, 120005, 120007 — and lists all Lua source files
  4. An `enUS` locale table is loadable and referenced by the main Lua file

**Plans:** 1/1 plans complete
Plans:

- [x] 01-01-PLAN.md — Create PLBeast addon skeleton (TOC, locale, main Lua) and correct ROADMAP

### Phase 2: Rotation Tracking

**Goal**: The addon correctly reads beast ready-buff auras and advances the cyclic wyvern → boar → bear rotation index only on real buff transitions
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: TRACK-01, TRACK-02, TRACK-03, TRACK-04, TRACK-05
**Success Criteria** (what must be TRUE):

  1. `/plbeast debug` prints the current next-beast name and raw aura states to chat
  2. The next-beast index advances exactly once each time a beast ready buff appears — never on every poll tick
  3. After a `/reload` the addon resumes from the previously saved next-beast index; a fresh login / full relog and a boss pull (ENCOUNTER_START) each reset the prediction to wyvern; zoning and trash/world-mob combat leave the prediction unchanged
  4. The rotation advances correctly when logged in as both Beast Mastery and Survival hunter specs

**Plans:** 1 plan
Plans:

- [ ] 02-01-PLAN.md — Implement rotation tracking engine with event-driven detection and debug output

### Phase 3: Visibility Gating

**Goal**: The icon (or its placeholder) is visible only when the player has Pack Leader active on a supported hunter spec, and updates correctly when spec or talents change mid-session
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: VIS-01, VIS-02, VIS-03
**Success Criteria** (what must be TRUE):

  1. The addon shows its output when Pack Leader is the active hero talent on BM or SV hunter
  2. The output hides immediately when the player is not on hunter or switches to Marksmanship
  3. After switching specs or changing hero talent loadout (without a reload), visibility updates within one game frame

**Plans:** 1/1 plans complete
Plans:

- [x] 03-01-PLAN.md — Add visibility gating: talent detection, conditional UNIT_AURA registration, deferred spec/talent event handling

### Phase 4: Icon UI

**Goal**: A single draggable, scalable icon frame displays the correct next-beast texture with a configurable border, and all position/size settings survive session restarts
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07
**Success Criteria** (what must be TRUE):

  1. The icon displays the correct wyvern, boar, or bear texture matching the predicted next beast
  2. The icon has a visible square border; border color and thickness default to black/1px and can be changed
  3. Dragging is toggled on/off; the icon cannot be moved during combat lockdown
  4. After dragging the icon to a new position and doing `/reload`, the icon reappears at the same position
  5. Width and height can be adjusted independently; all size and border settings persist across sessions _(the sync toggle was built in Phase 4 and later removed in Phase 5 by user decision)_

**Plans:** 2/2 plans complete
Plans:
**Wave 1**

- [x] 04-01-PLAN.md — Icon frame appears with correct beast texture + visibility bridge + black 1px border

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 04-02-PLAN.md — Drag-to-reposition with combat guard + position/size/border persistence

**UI hint**: yes

### Phase 5: Configuration

**Goal**: The player can open a lightweight options frame via `/plbeast`, adjust all icon settings from it, and the frame is blocked during combat
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: CFG-01, CFG-02, CFG-03, CFG-04
**Success Criteria** (what must be TRUE):

  1. Typing `/plbeast` opens the options frame; the frame does not open during combat lockdown
  2. The options frame contains width slider, height slider, and border thickness slider _(border color picker removed by user decision during Phase 5 — border is a fixed black outline)_
  3. The options frame contains a drag (lock) toggle that matches the current state _(width/height sync toggle removed by user decision during Phase 5)_
  4. Changes made in the options frame take effect immediately on the icon without requiring a reload

**Plans:** 1/1 plans complete
Plans:
**Wave 1**

- [x] 05-01-PLAN.md — Slash command opens combat-guarded options frame; width/height/thickness sliders + lock toggle, all live-applying. Border is a fixed black 4-edge outline (color picker descoped).

**UI hint**: yes

**Carried forward from Phase 4:** Verify in-game (using the new sliders) that independent width/height resize and border thickness changes render and persist correctly across `/reload`. _(sync toggle and border color picker removed by user decision during Phase 5)_ Deferred from Phase 4 because no settings UI existed there to change these values; the underlying code (`SetIconSize`, `ApplyIconSettings`) is already complete and statically verified. See `.planning/phases/04-icon-ui/04-VERIFICATION.md` (Disposition).

### Phase 05.1: Event-Driven Rotation Tracking (INSERTED)

**Goal**: PLBeast's next-beast tracking behaviorally matches AzortharionUI's Pack Leader implementation by adopting its event-driven, self-correcting model — no constant polling — eliminating the idle CPU/GC cost of the 10Hz tick
**Mode:** mvp
**Depends on**: Phase 2 (rotation tracking engine); sequenced after Phase 5, before the Phase 6 release so the optimized build ships
**Requirements**: PERF-01
**Success Criteria** (what must be TRUE):

  1. The recurring `C_Timer` poll ticker is removed; detection is driven by `UNIT_AURA` (player-only), so no timer runs while idle
  2. Prediction uses AzortharionUI's **self-correcting** model — the predicted beast is pinned to whichever ready buff is actually active (advancing on consumption), so it continuously re-syncs to the game rather than dead-reckoning the cycle (this resolves any off-by-one vs the previous `NEXT_BEAST[spawned]` semantic)
  3. Stale CDM frame references are recovered by lazy per-`cooldownID` re-resolve rather than a full cache rebuild; the debounced `CooldownViewerSettings.OnDataChanged` rebuild hook is retained; no freeze after repeated spawns
  4. **In-game side-by-side with AzortharionUI: PLBeast's displayed next beast matches Azor's Pack Leader next-beast step-for-step** through spawns, `/reload`, relog, boss pull, and spec change — i.e. PLBeast adopts Azor's reset semantics too (persists across relog, resets to boar on spec change, **no login/boss-pull reset**)
  5. Performance is measurably event-driven (no constant poll); idle cost is comparable to AzortharionUI — verify via the AddonProfiler addon
  6. NOTE: the explicit login/boss-pull reset-to-wyvern (TRACK-03) is intentionally **dropped** here for parity with AzortharionUI; re-adding it on top of the self-correcting model is captured as a future todo, to be reconsidered after the performance comparison

**Reference**: AzortharionUI `Modules/BuffTracking/Hunter.lua` (`PollPackLeader` lines ~245-326: self-correcting prediction; `:298` predict ready beast, `:308` advance on consumption, `:436` spec-change→boar; persists via `RestoreState`). See `.planning/todos/pending/2026-06-23-event-driven-rotation-tracking.md`

**Plans:** 1/1 plans complete

Plans:

- [x] 05.1-01-PLAN.md — Rewrite detection engine to AzortharionUI's self-correcting model + in-game verification

### Phase 6: Release Pipeline

**Goal**: Pushing a version tag to the `cela28/PLBeast` remote triggers a GitHub Actions workflow that produces a correctly structured release zip
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: REL-01, REL-02, REL-03, REL-04
**Success Criteria** (what must be TRUE):

  1. The repo remote origin is set to `cela28/PLBeast`
  2. Pushing a tag matching `v*` triggers the GitHub Actions release workflow without manual steps
  3. The release zip extracted by a player produces a `PLBeast/` folder at the WoW AddOns installation path (not a nested subfolder)
  4. A GitHub release entry is created automatically with the zip attached

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 5.1 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Addon Scaffold | 1/1 | Complete   | 2026-06-18 |
| 2. Rotation Tracking | 0/1 | Planning complete | - |
| 3. Visibility Gating | 1/1 | Complete   | 2026-06-19 |
| 4. Icon UI | 2/2 | Complete    | 2026-06-21 |
| 5. Configuration | 1/1 | Complete    | 2026-06-21 |
| 5.1. Event-Driven Rotation Tracking | 1/1 | Complete   | 2026-06-29 |
| 6. Release Pipeline | 0/? | Not started | - |
