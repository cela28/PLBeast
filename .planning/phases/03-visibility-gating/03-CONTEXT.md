# Phase 3: Visibility Gating - Context

**Gathered:** 2026-06-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Gate addon output visibility based on Pack Leader hero talent and hunter spec detection. When Pack Leader is active on a BM or SV hunter, the addon is "on" — otherwise it is "off." This phase adds talent detection constants, the `IsPackLeaderHeroTalent()` function, a `RefreshVisibility()` function that sets a module-level flag, event registration for spec/talent changes, and UNIT_AURA registration/unregistration tied to visibility state. No frames are created (Phase 4), no options panel (Phase 5).

</domain>

<decisions>
## Implementation Decisions

### Output Representation
- **D-01:** Phase 3 produces a module-level boolean flag (`isPackLeaderActive`), not a frame. No UI frames are created — Phase 4 reads the flag to show/hide the icon. Visibility is verifiable via `/plbeast debug` output printing the flag state.

### Tracking While Hidden
- **D-02:** Pause rotation tracking when Pack Leader isn't active. `RefreshVisibility()` unregisters `UNIT_AURA` when `isPackLeaderActive` is false, and re-registers + re-seeds the aura snapshot (`SeedAuraSnapshot()`) when it becomes true. This avoids processing irrelevant aura events on non-hunter specs or alts.
- **D-03:** On re-activation (switching back to a Pack Leader spec), the rotation resumes from the persisted `DB.nextIndex` — no state is lost, only live aura tracking pauses.

### Debug Behavior
- **D-04:** Debug output (`dprint()`, `/plbeast debug` toggle) works regardless of visibility state. When inactive, debug prints spec and talent detection status (e.g., `spec=MM packLeader=false`). This enables troubleshooting visibility issues without requiring the correct spec.

### Claude's Discretion
- Talent detection constants: copy `SPELL_HOTPL_PARENT`, `SPELL_SENTINEL_ANCHOR`, `SPELL_DARK_RANGER_ANCHOR` from PackLeaderHelper (lines 11, 21–22)
- `IsPackLeaderHeroTalent()` function: direct copy from PLH line 1574–1580
- Talent change event registration strategy: which WoW events to register for spec/talent changes and whether to use `C_Timer.After(0, ...)` deferral pattern from PLH's `QueueTalentDerivedStateRefresh` (line 1625–1638)
- Spec detection function adaptation: Phase 2's `RefreshHunterSpecState()` already exists — extend or wrap it for visibility gating

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Definition
- `.planning/PROJECT.md` — Core value, constraints, key decisions, extraction context
- `.planning/REQUIREMENTS.md` — Full v1 requirements; Phase 3 maps to VIS-01, VIS-02, VIS-03
- `.planning/ROADMAP.md` — Phase goals and success criteria

### Prior Phase Context
- `.planning/phases/01-addon-scaffold/01-CONTEXT.md` — Phase 1 decisions (init flow, DB merge, interface version)
- `.planning/phases/02-rotation-tracking/02-CONTEXT.md` — Phase 2 decisions (event-driven detection, extraction fidelity, snapshot-diff)

### Source Addon (extraction reference)
- `PackLeaderHelper.lua` lines 11, 21–22 — Talent detection spell constants (`SPELL_HOTPL_PARENT`, `SPELL_SENTINEL_ANCHOR`, `SPELL_DARK_RANGER_ANCHOR`)
- `PackLeaderHelper.lua` lines 1574–1580 — `IsPackLeaderHeroTalent()` function (sentinel/dark ranger exclusion pattern)
- `PackLeaderHelper.lua` lines 1582–1587 — `RefreshHunterSpecState()` (already copied to PLBeast in Phase 2)
- `PackLeaderHelper.lua` lines 1605–1620 — `RefreshTalentDerivedState()` (talent refresh pattern to adapt)
- `PackLeaderHelper.lua` lines 1622–1638 — `QueueTalentDerivedStateRefresh()` with `C_Timer.After(0, ...)` deferral pattern
- `PackLeaderHelper.lua` lines 2557–2670 — Event registrations including `PLAYER_TALENT_UPDATE`, `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `ACTIVE_COMBAT_CONFIG_CHANGED`, `TRAIT_CONFIG_UPDATED`, `TRAIT_SUB_TREE_CHANGED`

### PLBeast Code (Phase 2 output)
- `PLBeast/PLBeast.lua` — Current code: event frame, rotation engine, spec detection, slash commands
- `PLBeast/PLBeast.toc` — TOC with SavedVariablesPerCharacter declaration
- `PLBeast/Locales/enUS.lua` — Locale table

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PLBeast.lua` `RefreshHunterSpecState()`: Already detects BM/SV spec via `GetSpecialization()` + `GetSpecializationInfo()`. Phase 3 extends this to also check Pack Leader talent.
- `PLBeast.lua` `SeedAuraSnapshot()`: Already seeds `prevReady` state. Phase 3 calls this on re-activation (D-02).
- `PLBeast.lua` event frame: Already registers `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`. Phase 3 adds additional talent change events.
- PLH `IsPackLeaderHeroTalent()`: Direct copy — 6-line function checking `IsPlayerSpell` with sentinel/dark ranger exclusion.

### Established Patterns
- Event-driven architecture (Phase 2 D-01): Phase 3 continues this — visibility refreshes on spec/talent events, not polling.
- Faithful extract-and-trim (Phase 2 D-03): Copy PLH's talent detection, strip wyvern duration logic.
- PLH uses `C_Timer.After(0, ...)` to defer talent state refresh out of the current event to avoid reentrancy — PLBeast may need this if talent events fire before `IsPlayerSpell` returns updated data.

### Integration Points
- `PLAYER_LOGIN` handler: Add `RefreshVisibility()` call after `RefreshHunterSpecState()` and before `SeedAuraSnapshot()` — visibility determines whether to register UNIT_AURA.
- `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` handler: Currently calls `RefreshHunterSpecState()` only — Phase 3 adds `RefreshVisibility()` after it.
- New talent change events: `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`, `TRAIT_SUB_TREE_CHANGED` — wire to visibility refresh.
- `UNIT_AURA` registration: Currently unconditional in PLAYER_LOGIN — Phase 3 makes it conditional on `isPackLeaderActive`.

</code_context>

<specifics>
## Specific Ideas

- Follow PackLeaderHelper's talent detection patterns — user wants PLBeast to mirror PLH's established approach, adapted for the simpler scope (no wyvern duration concerns).
- The visibility flag is the bridge to Phase 4 — keep it simple and reliable so the icon UI can `root:SetShown(isPackLeaderActive)` without additional logic.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 3-Visibility Gating*
*Context gathered: 2026-06-19*
