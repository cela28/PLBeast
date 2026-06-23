# Phase 2: Rotation Tracking - Context

**Gathered:** 2026-06-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement the cyclic beast rotation engine: read beast ready-buff aura state from `C_UnitAuras.GetPlayerAuraBySpellID`, detect buff transitions via snapshot-diff, advance the wyvern → boar → bear rotation index, persist the prediction index to SavedVariables, and provide debug output via `/plbeast debug`. No UI frames (Phase 4), no visibility gating (Phase 3), no options panel (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Detection Mechanism
- **D-01:** Event-driven detection via `UNIT_AURA` event — no OnUpdate polling loop. PLBeast registers `UNIT_AURA`, checks the three ready-buff spell IDs on each fire, diffs against previous snapshot, and advances the rotation index on transitions.
- **D-02:** Initial aura scan on `PLAYER_LOGIN` to seed the snapshot, following PLH's init pattern. Without this, logging in with a ready buff already active would produce incorrect first-transition behavior.

### Extraction Fidelity
- **D-03:** Faithful extract-and-trim from PackLeaderHelper. Copy the core rotation functions (`NEXT_BEAST` table, `ID_BY_INDEX`/`INDEX_BY_ID` maps, `READY_SPELL_BY_ID`, `SyncNextFromAddedReady` with multi-beast start-time sorting, `SetNextBeastId`, `NormalizeNextIndex`, snapshot-diff logic) and strip everything irrelevant (CDM polling, wyvern buff tracking, hogstrider, cooldown swipe updates).
- **D-04:** Keep PLH's multi-beast sort-by-start-time logic in `SyncNextFromAddedReady`. During burst windows (rapid Kill Commands), WoW can batch multiple ready-buff aura changes into a single event fire. The sorting ensures correct rotation advancement.

### Debug Output
- **D-05:** `/plbeast debug` toggles `DB.debug` on/off (persistent across sessions), following PLH's toggle pattern. When on, `dprint()` calls fire on every `UNIT_AURA` event that triggers a state check.
- **D-06:** Debug output format: `next=Boar, wyvern=false, boar=true, bear=false, idx=2` — compact line showing the current prediction and which ready buffs are active. Matches success criterion 1 (prints next-beast name and raw aura states).

### Claude's Discretion
- Spell constants scope: Phase 2 defines only the 3 ready-buff spell IDs (`SPELL_READY_WYVERN`, `SPELL_READY_BOAR`, `SPELL_READY_BEAR`). Phase 3 adds talent-detection constants (`SPELL_HOTPL_PARENT`, sentinel/dark ranger anchors) when it needs them.
- Snapshot-diff structure: Follow PLH's `readyActiveById` table pattern adapted for event-driven checking.
- DB defaults extension: Phase 2 keeps the existing defaults (`debug`, `nextIndex`); no new DB keys needed for this phase.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Definition
- `.planning/PROJECT.md` — Core value, constraints, key decisions, extraction context
- `.planning/REQUIREMENTS.md` — Full v1 requirements; Phase 2 maps to TRACK-01 through TRACK-05
- `.planning/ROADMAP.md` — Phase goals and success criteria

### Prior Phase Context
- `.planning/phases/01-addon-scaffold/01-CONTEXT.md` — Phase 1 decisions (init flow, DB merge, interface version); the scaffold that Phase 2 builds on

### Source Addon (extraction reference)
- `PackLeaderHelper.lua` lines 11–15 — Ready-buff spell ID constants (`SPELL_READY_WYVERN`, `SPELL_READY_BOAR`, `SPELL_READY_BEAR`)
- `PackLeaderHelper.lua` lines 1494–1515 — `NEXT_BEAST` rotation table, `ID_BY_INDEX`, `INDEX_BY_ID`, `READY_SPELL_BY_ID`, `ANIMAL_ICON_BY_ID` maps
- `PackLeaderHelper.lua` lines 1526–1530 — `NormalizeNextIndex()` function
- `PackLeaderHelper.lua` lines 1544–1549 — `readyActiveById` snapshot tables
- `PackLeaderHelper.lua` lines 1647–1676 — `SetNextBeastId()` and `SyncNextFromAddedReady()` — core rotation advancement logic
- `PackLeaderHelper.lua` lines 1688–1700 — `ResetAuraState()` — state reset pattern
- `PackLeaderHelper.lua` lines 1752–1764 — `GetAuraTimingBySpellID()` — aura reading via `C_UnitAuras`

### PLBeast Scaffold (Phase 1 output)
- `PLBeast/PLBeast.lua` — Current scaffold: event frame, DB init, slash command, dprint helper
- `PLBeast/PLBeast.toc` — TOC with SavedVariablesPerCharacter declaration
- `PLBeast/Locales/enUS.lua` — Locale table

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PLBeast/PLBeast.lua` event frame: Already registers `ADDON_LOADED` and `PLAYER_LOGIN`. Phase 2 adds `UNIT_AURA` registration.
- `PLBeast/PLBeast.lua` dprint(): Already implemented with `DB.debug` gating. Phase 2 uses it for debug output.
- `PLBeast/PLBeast.lua` slash command handler: Already wired. Phase 2 extends it to handle `debug` subcommand.
- PackLeaderHelper's `NEXT_BEAST`/`ID_BY_INDEX`/`INDEX_BY_ID`/`READY_SPELL_BY_ID` tables: Direct copy targets.
- PackLeaderHelper's `SyncNextFromAddedReady()`: Faithful extract target — keep multi-beast sorting.

### Established Patterns
- PLH's snapshot-diff: Store previous `readyActiveById` state, compare against current on each check, compute `addedBeasts` list, feed to `SyncNextFromAddedReady`. TRACK-05 requires this pattern.
- PLH's `GetAuraTimingBySpellID()`: Uses `C_UnitAuras.GetPlayerAuraBySpellID(spellId)` with nil guards. PLBeast only needs presence check (not timing), so can simplify to boolean.
- PLH's `NormalizeNextIndex()`: Clamps `DB.nextIndex` to 1-3 range. Direct copy.
- Event-driven: `UNIT_AURA` fires with `unitTarget` arg — filter to `"player"` only.

### Integration Points
- `PLBeast.lua` PLAYER_LOGIN handler: Add initial aura scan call after existing init.
- `PLBeast.lua` event handler `OnEvent`: Add `UNIT_AURA` branch.
- `PLBeast.lua` slash command: Add `debug` subcommand routing.
- `DB.nextIndex`: Already in defaults from Phase 1. Phase 2 writes to it on rotation advancement.

</code_context>

<specifics>
## Specific Ideas

- Follow PackLeaderHelper's logic and patterns throughout — user explicitly wants PLBeast's tracking to mirror PLH's established approach, adapted for the event-driven architecture.
- The rotation tracking should be self-contained within this phase — no dependency on Phase 3's visibility gating or Phase 4's UI. The rotation engine runs silently, updating `DB.nextIndex` and `nextBeastId`, observable only via `/plbeast debug` output.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-Rotation Tracking*
*Context gathered: 2026-06-18*
