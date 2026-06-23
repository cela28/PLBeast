# Phase 3: Visibility Gating - Research

**Researched:** 2026-06-19
**Domain:** WoW Lua addon — spec detection, hero talent detection, conditional event registration
**Confidence:** HIGH (all critical decisions already locked; source code is available for direct extraction)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Phase 3 produces a module-level boolean flag (`isPackLeaderActive`), not a frame. No UI frames are created — Phase 4 reads the flag to show/hide the icon. Visibility is verifiable via `/plbeast debug` output printing the flag state.
- **D-02:** Pause rotation tracking when Pack Leader isn't active. `RefreshVisibility()` unregisters `UNIT_AURA` when `isPackLeaderActive` is false, and re-registers + re-seeds the aura snapshot (`SeedAuraSnapshot()`) when it becomes true.
- **D-03:** On re-activation (switching back to a Pack Leader spec), the rotation resumes from the persisted `DB.nextIndex` — no state is lost, only live aura tracking pauses.
- **D-04:** Debug output (`dprint()`, `/plbeast debug` toggle) works regardless of visibility state. When inactive, debug prints spec and talent detection status (e.g., `spec=MM packLeader=false`).

### Claude's Discretion

- Talent detection constants: copy `SPELL_HOTPL_PARENT`, `SPELL_SENTINEL_ANCHOR`, `SPELL_DARK_RANGER_ANCHOR` from PackLeaderHelper (lines 11, 21–22)
- `IsPackLeaderHeroTalent()` function: direct copy from PLH line 1574–1580
- Talent change event registration strategy: which WoW events to register for spec/talent changes and whether to use `C_Timer.After(0, ...)` deferral pattern from PLH's `QueueTalentDerivedStateRefresh` (line 1625–1638)
- Spec detection function adaptation: Phase 2's `RefreshHunterSpecState()` already exists — extend or wrap it for visibility gating

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VIS-01 | Icon only displays when Pack Leader hero talent is active (check via `IsPlayerSpell` with sentinel/dark ranger exclusion) | `IsPackLeaderHeroTalent()` copied from PLH line 1574–1580; spell constants at PLH lines 11, 21–22 |
| VIS-02 | Icon hides when player spec does not support Pack Leader (MM, non-hunter) | `RefreshHunterSpecState()` already in PLBeast; `isPackLeaderActive` gates the flag based on isBeastMastery or isSurvival AND pack leader hero talent |
| VIS-03 | Icon hides/shows correctly on spec change and talent change events | PLH registers 5 talent/spec events; PLBeast adds the same set to the eventFrame |
</phase_requirements>

---

## Summary

Phase 3 is a pure logic phase: it adds a module-level boolean flag (`isPackLeaderActive`) that the Phase 4 icon will read. No frames are created. The implementation is a faithful extract-and-trim from PackLeaderHelper: copy three spell constants, copy the six-line `IsPackLeaderHeroTalent()` function, write a `RefreshVisibility()` function that sets the flag and conditionally registers/unregisters `UNIT_AURA`, and wire talent/spec change events to call `RefreshVisibility()`.

The critical correctness concern is the deferral pattern. WoW fires `PLAYER_TALENT_UPDATE` and similar events before `IsPlayerSpell` has been updated to reflect the new state. PackLeaderHelper solves this with `QueueTalentDerivedStateRefresh()`, which uses `C_Timer.After(0, ...)` to push the `IsPlayerSpell` read one frame into the future. PLBeast must replicate this pattern or `RefreshVisibility()` will read stale talent data and produce a wrong flag value.

The source code for every required element exists verbatim in `PackLeaderHelper.lua`. The research task is to document extraction targets precisely, confirm the deferral pattern necessity, and map integration points into the existing Phase 2 PLBeast code.

**Primary recommendation:** Copy `IsPackLeaderHeroTalent()` from PLH verbatim, implement `RefreshVisibility()` with conditional UNIT_AURA registration, and queue all talent event handlers through `C_Timer.After(0, ...)` — exactly as PLH does.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pack Leader talent detection | Addon logic (Lua) | — | `IsPlayerSpell` is a WoW client API, not game state needing server round-trip; evaluated locally in Lua |
| Spec detection | Addon logic (Lua) | — | `GetSpecialization()`/`GetSpecializationInfo()` are local client APIs; already implemented in Phase 2 |
| UNIT_AURA registration control | Event layer (Lua) | — | `eventFrame:RegisterEvent`/`UnregisterEvent` is the standard WoW mechanism; gated by flag |
| Visibility flag (`isPackLeaderActive`) | Module state | — | A module-level boolean; no persistence needed (derived on every login from live talent state) |
| Debug output | Logging utility | — | `dprint()` already implemented; Phase 3 adds new format strings to locale |

---

## Standard Stack

No external packages. This phase uses only WoW built-in APIs.

### Core WoW APIs Used

| API | Purpose | Source |
|-----|---------|--------|
| `IsPlayerSpell(spellId)` | Returns true if the player has learned the given spell; used to detect Pack Leader and exclude Sentinel/Dark Ranger | PLH line 1575–1577 [VERIFIED: source code] |
| `GetSpecialization()` | Returns the player's active specialization index | PLH line 1583 [VERIFIED: source code] |
| `GetSpecializationInfo(index)` | Returns spec ID for a given specialization index | PLH line 1584 [VERIFIED: source code] |
| `C_Timer.After(0, callback)` | Defers callback one frame to allow WoW to finish updating talent state before reading | PLH line 1632 [VERIFIED: source code] |
| `eventFrame:RegisterEvent(name)` | Standard WoW event subscription | PLBeast.lua line 243 [VERIFIED: source code] |
| `eventFrame:UnregisterEvent(name)` | Conditional de-subscription; used to pause UNIT_AURA on hidden state | D-02 [VERIFIED: WoW API standard] |

### Spell Constants to Add (copy from PLH)

| Constant | Value | Purpose | PLH Line |
|----------|-------|---------|----------|
| `SPELL_HOTPL_PARENT` | `471876` | Pack Leader parent spell; checked by `IsPlayerSpell` as primary hero-talent gate | 11 |
| `SPELL_SENTINEL_ANCHOR` | `1253599` | Sentinel hero talent anchor; if player has this, they are NOT Pack Leader | 21 |
| `SPELL_DARK_RANGER_ANCHOR` | `466930` | Dark Ranger hero talent anchor; if player has this, they are NOT Pack Leader | 22 |

All values [VERIFIED: `PackLeaderHelper.lua` direct read].

---

## Package Legitimacy Audit

> Not applicable — this phase installs no external packages. All APIs are WoW built-ins.

---

## Architecture Patterns

### System Architecture Diagram

```
Talent/Spec Change Events
  (PLAYER_TALENT_UPDATE, ACTIVE_PLAYER_SPECIALIZATION_CHANGED,
   ACTIVE_COMBAT_CONFIG_CHANGED, TRAIT_CONFIG_UPDATED, TRAIT_SUB_TREE_CHANGED)
           |
           v
  C_Timer.After(0, ...) -- defer one frame so IsPlayerSpell is updated
           |
           v
  RefreshVisibility()
     ├── RefreshHunterSpecState()   -- updates isBeastMastery, isSurvival
     ├── IsPackLeaderHeroTalent()   -- checks HOTPL_PARENT, excludes Sentinel/DarkRanger
     ├── sets isPackLeaderActive = (isBeastMastery or isSurvival) and isPackLeader
     ├── if newly false: eventFrame:UnregisterEvent("UNIT_AURA")
     └── if newly true:  SeedAuraSnapshot() then eventFrame:RegisterEvent("UNIT_AURA")

PLAYER_LOGIN
     ├── RefreshHunterSpecState()
     ├── RefreshVisibility()   ← NEW (determines whether to register UNIT_AURA)
     └── [UNIT_AURA registered only if isPackLeaderActive]

UNIT_AURA (only active when isPackLeaderActive)
     └── CheckAuraState() → rotation advances
```

### Recommended Project Structure

No structural changes. Phase 3 modifies only `PLBeast/PLBeast.lua` and `PLBeast/Locales/enUS.lua`.

```
PLBeast/
├── PLBeast.toc          # unchanged
├── Locales/
│   └── enUS.lua         # add debug format strings for spec/talent state
└── PLBeast.lua          # all Phase 3 changes here
```

### Pattern 1: IsPackLeaderHeroTalent() — Direct Copy from PLH

**What:** Six-line function that checks `IsPlayerSpell(SPELL_HOTPL_PARENT)` as the positive signal, then returns false if the player also has the Sentinel or Dark Ranger anchor spell (mutually exclusive hero trees).

**When to use:** Called inside `RefreshVisibility()`, not called on a timer or OnUpdate loop. Called only when a relevant event fires and after the `C_Timer.After(0, ...)` deferral.

**Example (from PLH lines 1574–1580, VERIFIED: source code):**
```lua
local function IsPackLeaderHeroTalent()
    if not IsPlayerSpell(SPELL_HOTPL_PARENT) then return false end
    if IsPlayerSpell(SPELL_SENTINEL_ANCHOR) or IsPlayerSpell(SPELL_DARK_RANGER_ANCHOR) then
        return false
    end
    return true
end
```

### Pattern 2: RefreshVisibility() — New Function

**What:** Evaluates spec + hero talent state, sets `isPackLeaderActive`, and conditionally registers/unregisters `UNIT_AURA`.

**When to use:** Called from PLAYER_LOGIN and from within the deferred talent/spec event handler.

**Example (derived from PLH patterns, D-01, D-02):**
```lua
local isPackLeaderActive = false

local function RefreshVisibility()
    RefreshHunterSpecState()
    local isHunterSpec = isBeastMastery or isSurvival
    local isPackLeader = IsPackLeaderHeroTalent()
    local wasActive = isPackLeaderActive
    isPackLeaderActive = isHunterSpec and isPackLeader

    dprint(
        "spec=" .. (isBeastMastery and "BM" or (isSurvival and "SV" or "other")),
        "packLeader=" .. tostring(isPackLeaderActive)
    )

    if isPackLeaderActive and not wasActive then
        SeedAuraSnapshot()
        eventFrame:RegisterEvent("UNIT_AURA")
    elseif not isPackLeaderActive and wasActive then
        eventFrame:UnregisterEvent("UNIT_AURA")
    end
end
```

### Pattern 3: QueueTalentRefresh — Defer C_Timer.After(0, ...)

**What:** Talent change events fire before `IsPlayerSpell` is updated. A pending-flag guard plus `C_Timer.After(0, ...)` coalesces multiple rapid talent events into a single deferred call.

**When to use:** Wrap `RefreshVisibility()` for all talent change events (not for `PLAYER_LOGIN`, which is safe to call synchronously because talent data is settled before login).

**Source pattern (PLH lines 1622–1638, VERIFIED: source code):**
```lua
local pendingVisibilityRefresh = false

local function QueueVisibilityRefresh()
    if pendingVisibilityRefresh then return end
    pendingVisibilityRefresh = true
    C_Timer.After(0, function()
        pendingVisibilityRefresh = false
        RefreshVisibility()
    end)
end
```

### Pattern 4: Event Registration for Talent/Spec Changes

**What:** Register all five talent/spec events that PLH uses. These cover: dual spec switch, hero-tree change within a loadout, active combat config switch, trait tree updates, and hero subtree selection change.

**Events to add (from PLH lines 2560–2564, VERIFIED: source code):**
```lua
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("TRAIT_SUB_TREE_CHANGED")
-- ACTIVE_PLAYER_SPECIALIZATION_CHANGED already registered in Phase 2
```

**Event handler branch (from PLH lines 2609–2614, VERIFIED: source code):**
```lua
elseif event == "PLAYER_TALENT_UPDATE"
    or event == "ACTIVE_COMBAT_CONFIG_CHANGED"
    or event == "TRAIT_CONFIG_UPDATED"
    or event == "TRAIT_SUB_TREE_CHANGED"
    or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
    QueueVisibilityRefresh()
```

Note: `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` currently calls only `RefreshHunterSpecState()` in Phase 2. Phase 3 replaces this with `QueueVisibilityRefresh()`, which calls `RefreshHunterSpecState()` internally via `RefreshVisibility()`.

### Anti-Patterns to Avoid

- **Polling `IsPlayerSpell` in an OnUpdate loop:** This is unnecessary overhead. Event-driven is correct (as established in Phase 2).
- **Calling `RefreshVisibility()` synchronously inside talent events:** `IsPlayerSpell` may return stale data within the same event frame. Always defer via `C_Timer.After(0, ...)`.
- **Registering `UNIT_AURA` unconditionally on PLAYER_LOGIN:** Phase 3 makes this conditional — register only if `isPackLeaderActive` after `RefreshVisibility()` runs.
- **Double-registering UNIT_AURA on re-activation:** The `wasActive` guard in `RefreshVisibility()` prevents re-registering an already-registered event. WoW silently ignores duplicate `RegisterEvent` calls, but the guard makes intent explicit.
- **Unregistering UNIT_AURA without a nil/state guard:** Safe because the flag tracks whether it was registered.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hero talent detection | Custom `C_ClassTalents` tree traversal | `IsPlayerSpell(SPELL_HOTPL_PARENT)` with sentinel/dark ranger exclusion | PLH already established this pattern; `IsPlayerSpell` is the simplest reliable check |
| Event coalescing for rapid talent changes | Sleep loop or OnUpdate polling | `C_Timer.After(0, ...)` with a pending flag | Exactly what PLH does; prevents double-evaluation on burst events |

---

## Common Pitfalls

### Pitfall 1: IsPlayerSpell Returns Stale Data in Talent Event Handlers

**What goes wrong:** `IsPlayerSpell` is called synchronously inside `PLAYER_TALENT_UPDATE` or `TRAIT_SUB_TREE_CHANGED`. It returns the old talent state because WoW hasn't finished propagating the talent change to the spell system yet. `isPackLeaderActive` is set incorrectly.

**Why it happens:** WoW fires talent events as part of updating internal state, but `IsPlayerSpell` reads from a different subsystem that may lag one frame behind.

**How to avoid:** Always wrap the call inside `C_Timer.After(0, ...)`. This is the canonical PLH pattern at lines 1631–1637.

**Warning signs:** `/plbeast debug` shows `packLeader=false` immediately after activating Pack Leader, then corrects itself on the next event.

### Pitfall 2: Forgetting to Re-Seed Aura Snapshot on Re-Activation

**What goes wrong:** Player switches from MM back to BM with Pack Leader. `UNIT_AURA` is re-registered. If `SeedAuraSnapshot()` is NOT called before re-registering, the stale `prevReady` (all false) will treat any currently-active ready buffs as new — causing a spurious rotation advance on the first `UNIT_AURA` fire.

**Why it happens:** `prevReady` was not updated while UNIT_AURA was unregistered.

**How to avoid:** Call `SeedAuraSnapshot()` immediately before `eventFrame:RegisterEvent("UNIT_AURA")` inside the re-activation branch of `RefreshVisibility()`. This mirrors Phase 2's PLAYER_LOGIN sequence. Documented as D-02.

**Warning signs:** Rotation index jumps by one beast immediately on spec-switch-back.

### Pitfall 3: ACTIVE_PLAYER_SPECIALIZATION_CHANGED Handler Conflict

**What goes wrong:** Phase 2's event handler for `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` calls only `RefreshHunterSpecState()`. Phase 3 needs to call `QueueVisibilityRefresh()` instead (which internally calls `RefreshHunterSpecState()`). If the old handler is not replaced, both run and `UNIT_AURA` registration logic conflicts.

**Why it happens:** Phase 3 extends the event handler; the Phase 2 branch must be merged, not appended.

**How to avoid:** In the event handler, replace the standalone `RefreshHunterSpecState()` call under `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` with `QueueVisibilityRefresh()`.

**Warning signs:** Spec changes correctly update `isBeastMastery`/`isSurvival` but `isPackLeaderActive` doesn't update until the next talent event.

### Pitfall 4: UNIT_AURA Registered Before SeedAuraSnapshot on PLAYER_LOGIN

**What goes wrong:** `RefreshVisibility()` is called on PLAYER_LOGIN and determines Pack Leader is active, so it calls `SeedAuraSnapshot()` then registers `UNIT_AURA`. But if Phase 2's unconditional `RegisterEvent("UNIT_AURA")` still exists below `RefreshVisibility()`, the event is registered twice.

**Why it happens:** Phase 2 currently registers `UNIT_AURA` unconditionally at PLAYER_LOGIN (PLBeast.lua line 243). Phase 3 moves this into `RefreshVisibility()`.

**How to avoid:** Remove the unconditional `eventFrame:RegisterEvent("UNIT_AURA")` from the PLAYER_LOGIN handler. `RefreshVisibility()` now owns that call.

**Warning signs:** No functional difference (double-registration is silently safe), but the unconditional register means UNIT_AURA fires even when inactive.

### Pitfall 5: Marksmanship / Non-Hunter Spec Not Gated

**What goes wrong:** `IsPackLeaderHeroTalent()` may theoretically return true for a non-hunter spec if the player has the spell cross-spec (edge case). The visibility check should also require `isBeastMastery or isSurvival`.

**Why it happens:** Relying solely on `IsPlayerSpell` without spec check.

**How to avoid:** `isPackLeaderActive = (isBeastMastery or isSurvival) and IsPackLeaderHeroTalent()` — both conditions required. Addresses VIS-02.

---

## Code Examples

### Full RefreshVisibility() Integration Into PLAYER_LOGIN

```lua
-- Source: PLH PLAYER_LOGIN pattern lines 2581–2588, adapted for PLBeast Phase 3
elseif event == "PLAYER_LOGIN" then
    -- ... slash commands ...
    RefreshHunterSpecState()   -- spec flags set before visibility check
    RefreshVisibility()        -- sets isPackLeaderActive; conditionally registers UNIT_AURA
    -- NOTE: eventFrame:RegisterEvent("UNIT_AURA") removed from here (moved into RefreshVisibility)
    eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    -- NEW talent events:
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
    eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    eventFrame:RegisterEvent("TRAIT_SUB_TREE_CHANGED")
    Print(L["PLBeast loaded. Type /plbeast for options."])
```

### Debug dprint Format for Inactive State (D-04)

```lua
-- Inside RefreshVisibility(), emits useful debug regardless of active state:
dprint(
    "spec=" .. (isBeastMastery and "BM" or (isSurvival and "SV" or "other")),
    "packLeader=" .. tostring(isPackLeaderActive)
)
```

Matches D-04: "When inactive, debug prints spec and talent detection status (e.g., `spec=MM packLeader=false`)."

### Locale Strings Needed (enUS.lua additions)

No new user-visible Print() strings are required. The dprint() debug output uses raw string concatenation (no locale key). The existing locale table needs no changes for Phase 3.

---

## Runtime State Inventory

> Not a rename/refactor/migration phase — this section is omitted.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `GetTalentInfo()` for talent detection | `IsPlayerSpell()` for hero talent gates | The War Within (11.0) — Dragonflight talent system overhaul | `IsPlayerSpell` is simpler and spec-tree-agnostic; no tree traversal needed |
| Polling talent state on OnUpdate | Event-driven (`PLAYER_TALENT_UPDATE` + defer) | Dragonflight (10.0) | Events fire reliably; polling is unnecessary CPU cost |

**Deprecated/outdated:**
- `GetTalentInfo()`: Outdated for hero talent detection; the Dragonflight/TWW trait system does not surface hero tree selections through this API. [ASSUMED — training knowledge, not verified against current API docs, but consistent with PLH's use of `IsPlayerSpell`]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `IsPlayerSpell` returns stale data within the same event frame as `PLAYER_TALENT_UPDATE` / `TRAIT_SUB_TREE_CHANGED` | Common Pitfalls, Pattern 3 | If wrong: `C_Timer.After(0, ...)` deferral is unnecessary but harmless — the deferred call still produces the correct answer |
| A2 | `GetTalentInfo()` does not reliably detect hero talent selection in 12.x | State of the Art | If wrong: alternative detection method exists, but PLH's `IsPlayerSpell` approach is still valid and simpler |
| A3 | `TRAIT_SUB_TREE_CHANGED` fires with `subTreeID` as its argument (no unit filter needed) | Pattern 4 / Code Examples | If wrong: event handler may need an arg guard; but handler only calls `QueueVisibilityRefresh()` with no arg dependency, so the risk is zero in practice |

**Verified claims have zero assumptions about correctness:** Spell constants, function implementations, and event names are all read directly from `PackLeaderHelper.lua` source code.

---

## Open Questions (RESOLVED)

1. **Is `ACTIVE_COMBAT_CONFIG_CHANGED` required for PLBeast's scope?**
   - What we know: PLH registers it alongside other talent events and routes it to `QueueTalentDerivedStateRefresh`. It fires when the player's active combat config changes (loadout switch).
   - What's unclear: Whether hero talent selection can change via a combat config switch without also firing `TRAIT_SUB_TREE_CHANGED` or `PLAYER_TALENT_UPDATE`.
   - Recommendation: Include it — following PLH's established event set is safer than omitting events. Cost is negligible (one extra event registration and one extra `QueueVisibilityRefresh` call per loadout switch).

---

## Environment Availability

> Step 2.6: SKIPPED — this phase is code-only changes. No external tools, runtimes, databases, or CLI utilities are required. All APIs are WoW built-ins available in the retail client.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — WoW addon; no automated test framework available |
| Config file | n/a |
| Quick run command | `/plbeast debug` in-game (toggle debug on, observe chat output) |
| Full suite command | Manual in-game spec-switching session (see Phase Requirements → Test Map) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VIS-01 | Flag `isPackLeaderActive` is true when on BM/SV with Pack Leader talent active | manual | `/plbeast debug` shows `packLeader=true` | n/a |
| VIS-02 | Flag is false on MM or non-hunter; icon hidden | manual | Switch to MM in-game, `/plbeast debug` shows `packLeader=false` | n/a |
| VIS-03 | Visibility updates within one game frame after spec or hero talent change | manual | Switch spec, observe debug output before next UNIT_AURA event | n/a |

No automated test infrastructure exists or is feasible for WoW addons. All validation is manual in-game testing.

### Sampling Rate

- **Per task commit:** Load addon in WoW client via `/reload`, execute `/plbeast debug`, verify no Lua errors in chat
- **Per wave merge:** Full spec-switch sequence: BM+PackLeader (active), switch to MM (inactive), switch to SV+PackLeader (active with re-seeded snapshot)
- **Phase gate:** All three VIS requirements confirmed via in-game testing before proceeding to Phase 4

### Wave 0 Gaps

None — no test files to create. Manual in-game testing is the sole validation path for WoW addons in this project.

---

## Security Domain

> This phase introduces no authentication, session management, access control, cryptography, or network calls. WoW addon security model is enforced by the WoW client sandbox (no file system, no network, no eval). No ASVS categories apply.

---

## Sources

### Primary (HIGH confidence)

- `PackLeaderHelper.lua` lines 11, 21–22 — Talent spell constants (SPELL_HOTPL_PARENT, SPELL_SENTINEL_ANCHOR, SPELL_DARK_RANGER_ANCHOR) — read directly from source
- `PackLeaderHelper.lua` lines 1574–1580 — `IsPackLeaderHeroTalent()` function body — read directly from source
- `PackLeaderHelper.lua` lines 1622–1638 — `QueueTalentDerivedStateRefresh()` deferral pattern — read directly from source
- `PackLeaderHelper.lua` lines 2560–2614 — Event registrations and talent event handler — read directly from source
- `PLBeast/PLBeast.lua` lines 179–257 — Current Phase 2 state: `SeedAuraSnapshot()`, `RefreshHunterSpecState()`, PLAYER_LOGIN sequence — read directly from source

### Secondary (MEDIUM confidence)

- [Dragonflight Talent System — Warcraft Wiki](https://warcraft.wiki.gg/wiki/Dragonflight_Talent_System) — Background on trait/hero tree system; TRAIT_SUB_TREE_CHANGED fires when hero subtree selection changes
- [TRAIT_CONFIG_UPDATED — Warcraft Wiki](https://warcraft.wiki.gg/wiki/TRAIT_CONFIG_UPDATED) — Event documented as firing when active talent config changes
- Sentinel Hunter Tools CurseForge page — Third-party corroboration that `IsPlayerSpell(471876)` without sentinel/dark ranger exclusion is insufficient; the exclusion pattern is established practice in the ecosystem [MEDIUM]

### Tertiary (LOW confidence)

- WebSearch results for `TRAIT_SUB_TREE_CHANGED` arguments: fires with `subTreeID` as arg1 — [ASSUMED based on search summary; not verified via official docs]

---

## Metadata

**Confidence breakdown:**

- Standard stack / APIs: HIGH — all APIs read from existing PLH source code that runs successfully in production
- Architecture: HIGH — direct extraction pattern with well-understood integration points in existing PLBeast code
- Deferral requirement: MEDIUM — `C_Timer.After(0, ...)` necessity is pattern-inherited from PLH; the underlying WoW engine behavior was not independently verified, but the pattern is universally applied and harmless even if unnecessary
- Event set completeness: MEDIUM — five events copied from PLH; whether all five are required for PLBeast's simpler scope is unverified but conservative

**Research date:** 2026-06-19
**Valid until:** 2026-08-01 (stable WoW API domain; only invalid if Blizzard changes hero talent API in a major patch)
