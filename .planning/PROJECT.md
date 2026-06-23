# PLBeast

## What This Is

PLBeast is a standalone World of Warcraft addon that predicts and displays which beast will spawn next in the Pack Leader hero talent rotation (wyvern → boar → bear → wyvern). It's being extracted from PackLeaderHelper as an independent, minimal addon — just a single draggable/scalable icon showing the next beast.

## Core Value

Accurately predict and display the next beast in the Pack Leader rotation so the player always knows what's coming.

## Requirements

### Validated

- [x] Display a single icon showing the next beast (no label text) — *Validated in Phase 4: Icon UI*
- [x] Icon is draggable — user can reposition by clicking and dragging — *Validated in Phase 4: Icon UI (left-drag with silent combat-lockdown guard)*
- [x] Persist position across sessions (SavedVariables) — *Validated in Phase 4: Icon UI (center-offset persists across /reload and full logout)*
- [x] Only show when Pack Leader hero talent is active — *Validated in Phase 3: Visibility Gating; icon show/hide bridge wired in Phase 4*
- [x] Support both Beast Mastery and Survival hunter specs — *Validated in Phase 3: Visibility Gating*

### Active

- [ ] Independently read CDM/aura state to detect beast ready buffs (wyvern, boar, bear)
- [ ] Track the cyclic beast spawn order (wyvern → boar → bear)
- [ ] Advance the prediction when a beast actually spawns (via ready buff detection)
- [ ] Icon is scalable — user can adjust size *(sizing code complete in Phase 4; user-facing adjustment + visual verification deferred to Phase 5 sliders)*
- [ ] Persist scale/size and border settings across sessions *(persistence code complete in Phase 4; hands-on verification carried forward to Phase 5)*
- [ ] Options panel or slash command for configuration *(Phase 5)*

### Out of Scope

- Modifying PackLeaderHelper — this project is PLBeast only
- Cooldown timer tracking (that stays in PackLeaderHelper)
- Wyvern buff duration/extend tracking (that stays in PackLeaderHelper)
- Hogstrider tracking (that stays in PackLeaderHelper)
- Any dependency on PackLeaderHelper being installed

## Context

- Extracted from PackLeaderHelper, a 2675-line single-file WoW addon that tracks Pack Leader hero talent cooldowns and beast states
- The "next beast" prediction logic lives in PackLeaderHelper around lines 1494–1676: `NEXT_BEAST` rotation table, `SyncNextFromAddedReady()`, `SetNextBeastId()`, `NormalizeNextIndex()`
- The existing NEXT bar UI is at lines 502–520 (`CreateNextBar`) and 2290–2319 (`UpdateNextBar`)
- PLBeast needs its own CDM integration to read beast ready buffs independently — can reference PackLeaderHelper's CDM cache pattern (lines 1805–1949) but must be self-contained
- WoW addon constraints: single-threaded Lua, no file I/O, combat lockdown restrictions on UI manipulation, SavedVariables for persistence
- Target WoW version: The War Within (11.x)

## Constraints

- **Runtime**: WoW Lua sandbox — no external libraries, no coroutines for async, no file system access
- **Combat lockdown**: Cannot create/move frames during combat; must handle gracefully
- **CDM dependency**: Requires Blizzard Cooldown Manager to be enabled and tracking Pack Leader buff spells
- **Addon size**: Should be minimal — small .toc, one or two .lua files, locale support

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fully independent from PackLeaderHelper | Users may want next-beast prediction without the full PLH tracker | — Pending |
| Minimal icon only (no label text) | Clean, unobtrusive UI that blends with other addons | Validated — Phase 4 |
| Draggable + scalable icon | Standard WoW addon UX for movable elements | Drag validated Phase 4; scale UI in Phase 5 |
| Own CDM/aura reading | No inter-addon communication needed; works standalone | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-21 after Phase 4 (Icon UI) completion — draggable bordered beast icon with position persistence shipped; size/border config UI deferred to Phase 5.*
