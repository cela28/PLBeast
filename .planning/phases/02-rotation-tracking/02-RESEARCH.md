# Phase 2: Rotation Tracking - Research

**Researched:** 2026-06-18
**Domain:** WoW Lua addon — aura event detection, snapshot-diff, cyclic index rotation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Event-driven detection via `UNIT_AURA` event — no OnUpdate polling loop. PLBeast registers `UNIT_AURA`, checks the three ready-buff spell IDs on each fire, diffs against previous snapshot, and advances the rotation index on transitions.
- **D-02:** Initial aura scan on `PLAYER_LOGIN` to seed the snapshot, following PLH's init pattern.
- **D-03:** Faithful extract-and-trim from PackLeaderHelper. Copy `NEXT_BEAST` table, `ID_BY_INDEX`/`INDEX_BY_ID` maps, `READY_SPELL_BY_ID`, `SyncNextFromAddedReady` with multi-beast start-time sorting, `SetNextBeastId`, `NormalizeNextIndex`, snapshot-diff logic. Strip CDM polling, wyvern buff tracking, hogstrider, cooldown swipe updates.
- **D-04:** Keep PLH's multi-beast sort-by-start-time logic in `SyncNextFromAddedReady`.
- **D-05:** `/plbeast debug` toggles `DB.debug` on/off persistently. Debug fires on every `UNIT_AURA` event that triggers a state check.
- **D-06:** Debug output format: `next=Boar, wyvern=false, boar=true, bear=false, idx=2`.

### Claude's Discretion

- Spell constants scope: Phase 2 defines only the 3 ready-buff spell IDs (`SPELL_READY_WYVERN`, `SPELL_READY_BOAR`, `SPELL_READY_BEAR`). Phase 3 adds talent-detection constants.
- Snapshot-diff structure: Follow PLH's `readyActiveById` table pattern adapted for event-driven checking.
- DB defaults extension: Phase 2 keeps the existing defaults (`debug`, `nextIndex`); no new DB keys needed.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRACK-01 | Correctly tracks cyclic beast rotation order (wyvern → boar → bear → wyvern) | `NEXT_BEAST` table (PLH line 1494) provides the cyclic map; `ID_BY_INDEX`/`INDEX_BY_ID` provide numeric indexing. Direct copy target. |
| TRACK-02 | Rotation advances when a beast actually spawns, detected via `C_UnitAuras.GetPlayerAuraBySpellID` on ready buff spell IDs | `GetPlayerAuraBySpellID` presence-check pattern confirmed in PLH lines 1993–2002. Returns an aura table or nil; treat non-nil as "active". |
| TRACK-03 | Current next-index persists across sessions via SavedVariablesPerCharacter | `DB.nextIndex` already in Phase 1 defaults; `SetNextBeastId` writes to it; `NormalizeNextIndex` clamps it on load. Round-trip verified via Phase 1 ADDON_LOADED merge. |
| TRACK-04 | Supports both Beast Mastery and Survival hunter specs | Spec detection via `GetSpecialization`/`GetSpecializationInfo`; BM=253, SV=255. Phase 2 only needs `isBeastMastery`/`isSurvival` flags for debug output and future gating — no spec-specific rotation logic differs between specs at this layer. |
| TRACK-05 | Rotation state uses snapshot-diff pattern (only advances on buff transition, not every poll tick) | PLH's `previousReady` → `readyActiveById` diff pattern (lines 2076–2108) is the direct extraction source. `addedBeasts` list is populated only when `readyActiveById[beastId]` transitions from `false` to `true`. |

</phase_requirements>

---

## Summary

Phase 2 is a focused extraction-and-adaptation of PackLeaderHelper's rotation state machine into PLBeast. The source logic is well-defined and tested at lines 1494–1764 of PackLeaderHelper.lua. The core task is transplanting five interlocked functions (`NormalizeNextIndex`, `SetNextBeastId`, `SyncNextFromAddedReady`, `CheckAuraState`, `ResetAuraState`) plus their data tables into PLBeast.lua, switching the trigger from a 20Hz OnUpdate poll to a `UNIT_AURA` event handler, and wiring debug output to the `/plbeast debug` subcommand.

The most important architectural difference from PLH is that PLBeast does not use the Blizzard Cooldown Manager (CDM) as its aura source — it reads ready buffs directly via `C_UnitAuras.GetPlayerAuraBySpellID`, which was PLH's fallback path. This simplifies the extraction substantially: the entire CDM cache machinery (`BuildCDMCache`, `GatherCooldownsFromFrameTree`, `FindCDMFrameByCooldownID`) is out of scope. The `BuildReadySnapshot` path that reads from `C_UnitAuras` directly (PLH lines 1991–2002) is the relevant extraction source, not the CDM-backed path above it.

The snapshot-diff pattern is critical to TRACK-05 correctness. `UNIT_AURA` fires on every aura change, including during multi-buff batch events in burst windows. The diff between a stored `prevReady` table and the freshly-read state produces an `addedBeasts` list — only populated entries cause rotation advancement. The multi-beast sort-by-start-time in `SyncNextFromAddedReady` (D-04) is the defense against incorrect advancement when WoW batches two ready-buff adds into a single `UNIT_AURA` fire.

**Primary recommendation:** Extract the five core functions verbatim from PLH with surgical trimming (remove CDM references, wyvern buff state, hogstrider state). Replace the PLH `BuildReadySnapshot` CDM path with the `C_UnitAuras.GetPlayerAuraBySpellID` path only. Wire `UNIT_AURA` to a new `CheckAuraState()` function that performs the snapshot-diff. Add initial scan in `PLAYER_LOGIN`. Extend the slash handler for `debug` subcommand.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Ready-buff aura reading | Addon Lua (event-driven) | — | `C_UnitAuras.GetPlayerAuraBySpellID` is a client-side WoW API; called in `UNIT_AURA` handler |
| Snapshot-diff state | Addon Lua (module-level locals) | SavedVariables (nextIndex only) | Runtime state is ephemeral; only the rotation index survives sessions |
| Rotation index advancement | Addon Lua function (`SyncNextFromAddedReady`) | — | Pure Lua logic, no WoW API needed beyond the spell ID maps |
| Index persistence | SavedVariablesPerCharacter (`PLBeastDB.nextIndex`) | — | Already declared in PLBeast.toc; Phase 1 established the round-trip |
| Debug output | Chat (via `dprint`) | — | Gate on `DB.debug`; no frame needed |
| Spec state | Addon Lua (module-level locals) | — | `GetSpecialization`/`GetSpecializationInfo` give spec ID; no external dependency |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WoW Lua sandbox (Lua 5.1) | 12.0.x client | All addon logic | The only runtime available in WoW addons |
| `C_UnitAuras` (WoW API) | 12.0+ | Read player aura presence/timing | Confirmed as the primary source in PLH and CONTEXT.md |
| `UNIT_AURA` (WoW event) | 12.0+ | Trigger state checks on buff changes | Event-driven decision (D-01); confirmed in WoW API |

No external packages. This is a WoW Lua environment — no npm, no pip, no build tools.

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `GetSpecialization` / `GetSpecializationInfo` (WoW API) | 12.0+ | Detect BM/SV spec for debug output and future gating (TRACK-04) | Called on `PLAYER_LOGIN` and `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` |
| `C_Timer.After` (WoW API) | 12.0+ | Defer talent state refresh out of event context | Not needed in Phase 2 unless spec change requires deferred detection |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `UNIT_AURA` event | 20Hz OnUpdate poll (PLH approach) | Decision D-01 locks event-driven. OnUpdate adds per-frame overhead; event-driven is cleaner and sufficient since aura transitions are the signal |
| `C_UnitAuras.GetPlayerAuraBySpellID` | CDM frame tree scan (PLH primary path) | CDM path requires `BuildCDMCache` and CDM enabled. `GetPlayerAuraBySpellID` is simpler and is what CONTEXT.md mandates |

**Installation:** None — WoW addons have no package manager.

---

## Package Legitimacy Audit

Not applicable. This phase installs no external packages. All APIs are Blizzard-provided WoW client APIs bundled with the game runtime.

---

## Architecture Patterns

### System Architecture Diagram

```
WoW Client
    |
    | UNIT_AURA event (unitTarget = "player")
    v
[eventFrame:OnEvent]
    |
    | filter: unitTarget ~= "player" → early return
    v
[CheckAuraState()]
    |
    | C_UnitAuras.GetPlayerAuraBySpellID(SPELL_READY_WYVERN)
    | C_UnitAuras.GetPlayerAuraBySpellID(SPELL_READY_BOAR)
    | C_UnitAuras.GetPlayerAuraBySpellID(SPELL_READY_BEAR)
    |
    | Build currentReady = { wyvern=bool, boar=bool, bear=bool }
    |
    | Diff against prevReady (module-level snapshot)
    |   → compute addedBeasts = beasts in current but not in prev
    |
    +-- addedBeasts empty → update prevReady, return
    |
    | SyncNextFromAddedReady(addedBeasts, startTimes)
    |   → sort addedBeasts by buff start time (asc)
    |   → for each: SetNextBeastId(NEXT_BEAST[beastId])
    |
    | DB.nextIndex updated (persisted to SavedVariablesPerCharacter)
    | nextBeastId updated (module-level local)
    |
    | dprint (if DB.debug): "next=X, wyvern=Y, boar=Z, bear=W, idx=N"
    |
    +→ prevReady = currentReady   (snapshot update)

PLAYER_LOGIN (initial seed)
    |
    | Scan all 3 spell IDs → seed prevReady
    | NormalizeNextIndex() → restore nextBeastId from DB.nextIndex
    |
    +→ State seeded; first UNIT_AURA event will diff correctly
```

### Recommended Project Structure

```
PLBeast/
├── Locales/
│   └── enUS.lua          # Locale strings (Phase 1 output — extend for debug strings)
├── PLBeast.lua           # All rotation logic added here (single file)
└── PLBeast.toc           # Unchanged from Phase 1
```

Phase 2 adds no new files. All logic goes into `PLBeast.lua`.

### Pattern 1: Snapshot-Diff on UNIT_AURA

**What:** Read current aura presence for all 3 spells, compare against stored snapshot, collect newly-appeared beasts into `addedBeasts`.
**When to use:** This is the only detection mechanism for Phase 2 (D-01, TRACK-05).

```lua
-- Source: PackLeaderHelper.lua lines 2076–2111 (adapted for event-driven, C_UnitAuras only)

local prevReady = { wyvern = false, boar = false, bear = false }

local function CheckAuraState()
    local current = {
        wyvern = (C_UnitAuras.GetPlayerAuraBySpellID(SPELL_READY_WYVERN) ~= nil),
        boar   = (C_UnitAuras.GetPlayerAuraBySpellID(SPELL_READY_BOAR)   ~= nil),
        bear   = (C_UnitAuras.GetPlayerAuraBySpellID(SPELL_READY_BEAR)   ~= nil),
    }

    local addedBeasts = {}
    local startTimes = {}
    for _, id in ipairs({ "wyvern", "boar", "bear" }) do
        if current[id] and not prevReady[id] then
            addedBeasts[#addedBeasts + 1] = id
            -- Capture start time for sorting (see Pattern 2)
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(READY_SPELL_BY_ID[id])
            startTimes[id] = (aura and aura.expirationTime and aura.duration)
                             and (aura.expirationTime - aura.duration) or 0
        end
    end

    if #addedBeasts > 0 then
        SyncNextFromAddedReady(addedBeasts, startTimes)
    end

    prevReady = current

    dprint("next=" .. (ID_BY_INDEX[DB.nextIndex] or "?"),
           "wyvern=" .. tostring(current.wyvern),
           "boar="   .. tostring(current.boar),
           "bear="   .. tostring(current.bear),
           "idx="    .. tostring(DB.nextIndex))
end
```

### Pattern 2: Multi-Beast Sort in SyncNextFromAddedReady

**What:** When multiple beasts appear in the same `UNIT_AURA` fire, sort by buff start time (ascending) before processing. Falls back to rotation order index if times are equal or unavailable.
**When to use:** Always — this is a faithful extract from PLH (D-04).

```lua
-- Source: PackLeaderHelper.lua lines 1653–1676 (trimmed for PLBeast)

local function SyncNextFromAddedReady(addedBeasts, startTimes)
    if not addedBeasts or #addedBeasts == 0 then return end

    table.sort(addedBeasts, function(a, b)
        local sa = (startTimes and startTimes[a]) or 0
        local sb = (startTimes and startTimes[b]) or 0
        if sa > 0 and sb > 0 and sa ~= sb then
            return sa < sb
        end
        return (INDEX_BY_ID[a] or 99) < (INDEX_BY_ID[b] or 99)
    end)

    for _, beastId in ipairs(addedBeasts) do
        SetNextBeastId(NEXT_BEAST[beastId] or "wyvern")
    end
end
```

### Pattern 3: UNIT_AURA Registration and Filtering

**What:** Register `UNIT_AURA` on the existing eventFrame; filter to `"player"` unit only.
**When to use:** Phase 2 adds this registration to the existing eventFrame from Phase 1.

```lua
-- Source: WoW API documented pattern; confirmed in PLH event handler approach

eventFrame:RegisterEvent("UNIT_AURA")

-- In OnEvent handler:
elseif event == "UNIT_AURA" then
    local unitTarget = ...
    if unitTarget ~= "player" then return end
    CheckAuraState()
```

### Pattern 4: Initial Aura Scan on PLAYER_LOGIN (D-02)

**What:** After restoring `DB.nextIndex`, scan all 3 spell IDs to seed `prevReady`. Without this, the first buff that is already active at login time will appear as a "new" addition and incorrectly advance the index.
**When to use:** In `PLAYER_LOGIN` handler, after `NormalizeNextIndex()` and `SetNextBeastIdFromIndex()`.

```lua
-- Source: PLH pattern from PLAYER_LOGIN → PollCDMState() initial call

local function SeedAuraSnapshot()
    prevReady.wyvern = (C_UnitAuras.GetPlayerAuraBySpellID(SPELL_READY_WYVERN) ~= nil)
    prevReady.boar   = (C_UnitAuras.GetPlayerAuraBySpellID(SPELL_READY_BOAR)   ~= nil)
    prevReady.bear   = (C_UnitAuras.GetPlayerAuraBySpellID(SPELL_READY_BEAR)   ~= nil)
end
```

### Pattern 5: Restore nextBeastId from Saved Index

**What:** On load, `DB.nextIndex` (integer 1–3) is restored by the SavedVariables system. `nextBeastId` (string) must be derived from it. `NormalizeNextIndex` clamps the integer. A `SetNextBeastIdFromIndex` call then synchronizes the string.

```lua
-- Source: PackLeaderHelper.lua lines 1526–1530, 1647–1651

local function NormalizeNextIndex()
    local idx = tonumber(DB.nextIndex) or 1
    if idx < 1 or idx > 3 then idx = 1 end
    DB.nextIndex = idx
end

local function SetNextBeastId(beastId)
    nextBeastId = beastId or "wyvern"
    DB.nextIndex = INDEX_BY_ID[nextBeastId] or 1
    NormalizeNextIndex()
end

-- On ADDON_LOADED (after defaults merge):
NormalizeNextIndex()
nextBeastId = ID_BY_INDEX[DB.nextIndex] or "wyvern"
```

### Anti-Patterns to Avoid

- **Calling CheckAuraState on every UNIT_AURA regardless of unit:** The event fires for party members too. Filter `unitTarget == "player"` immediately or the addon processes irrelevant aura changes.
- **Advancing index by 1 instead of using `NEXT_BEAST` map:** `NEXT_BEAST[beastId]` gives the correct successor in the cycle. Incrementing `DB.nextIndex % 3 + 1` produces the same result for single advances but is wrong in the multi-beast sort path and doesn't self-document the cycle mapping.
- **Seeding prevReady as all-false at PLAYER_LOGIN without scanning:** If a ready buff is already active when the player logs in (e.g., they re-logged mid-rotation), the first `UNIT_AURA` won't detect it as "new" and the index won't advance. The initial scan (D-02) must populate `prevReady` with the actual live state.
- **Resetting `nextBeastId` to "wyvern" on ADDON_LOADED:** PLH does this (`SetNextBeastId("wyvern")` at ADDON_LOADED), but it then overwrites with the saved index afterward. For PLBeast, apply `NormalizeNextIndex` + derive `nextBeastId` from `DB.nextIndex` rather than resetting to wyvern unconditionally. The saved index is the ground truth.
- **Calling `dprint` outside the UNIT_AURA handler:** dprint is gated on `DB.debug`, so it's safe, but debug output should only emit when state actually changes or on every `UNIT_AURA` player check per D-05 — not on every event regardless.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cyclic rotation mapping | Manual index math (`idx % 3 + 1`) | `NEXT_BEAST` table lookup | String-keyed table is self-documenting and handles the wyvern→boar→bear→wyvern cycle without modular arithmetic bugs |
| Aura presence detection | Frame scanning, combat log parsing | `C_UnitAuras.GetPlayerAuraBySpellID` | Official WoW API; returns structured data; guaranteed behavior on 12.x |
| Multi-buff ordering | Arbitrary insertion order | Sort by `expirationTime - duration` (start time ascending) | WoW batches aura events; start-time sort is the only reliable ordering during burst Kill Command windows |
| Saved index clamping | Manual range checks scattered throughout | `NormalizeNextIndex()` called once at load | Centralizes range guard; protects against SavedVariables corruption |

**Key insight:** The PLH implementation has already solved every hard edge case in this domain (batched events, seeding on login, index normalization). The correct move is extraction, not reimplementation.

---

## Runtime State Inventory

Not applicable — Phase 2 is greenfield feature addition to a new addon. No rename or refactor of existing runtime state.

---

## Common Pitfalls

### Pitfall 1: Double-Advancement on Login with Active Ready Buff

**What goes wrong:** If a ready buff is already active when the addon loads (player logged out mid-rotation or re-loaded), `prevReady` starts as all-false. The next `UNIT_AURA` event refreshes the existing buff or a new unrelated aura fires, and since `current.wyvern = true` while `prevReady.wyvern = false`, the rotation advances even though no new beast spawned.

**Why it happens:** `prevReady` is initialized to `{ wyvern=false, boar=false, bear=false }` in Lua module scope. Without an initial scan, the diff sees everything as "newly added."

**How to avoid:** Call `SeedAuraSnapshot()` in `PLAYER_LOGIN` before registering `UNIT_AURA` — or immediately after, but before any `UNIT_AURA` event can fire (use `C_Timer.After(0, ...)` if needed to yield after registration). Seeds `prevReady` with current live state so the diff starts from truth.

**Warning signs:** During testing, index jumps immediately after `/reload` when a ready buff was already active.

### Pitfall 2: UNIT_AURA Fires for Non-Player Units

**What goes wrong:** `UNIT_AURA` fires with `unitTarget` for party members, pets, and other units. Without a guard, `CheckAuraState()` runs on every party member's aura change, which is waste and could produce incorrect reads if the APIs ever behave differently for non-player units.

**Why it happens:** `UNIT_AURA` is a general-purpose event. The `unitTarget` argument must be checked.

**How to avoid:** First line of the `UNIT_AURA` branch: `if unitTarget ~= "player" then return end`.

**Warning signs:** Excessive `dprint` output when grouping with other players in `DB.debug` mode.

### Pitfall 3: Index Out of Sync After Manual `/plbeast` Reset (Future)

**What goes wrong:** If a future slash subcommand resets `DB.nextIndex` without also updating `nextBeastId`, the module-level string and the saved integer diverge. Subsequent `SetNextBeastId` calls (which derive `DB.nextIndex` from `nextBeastId`) will overwrite the manual reset.

**Why it happens:** Two representations of the same state (`nextBeastId` string and `DB.nextIndex` integer) must be kept in sync. `SetNextBeastId` is the single write point that does this.

**How to avoid:** Always call `SetNextBeastId(beastId)` rather than writing to `DB.nextIndex` directly. `SetNextBeastId` is the canonical setter for both representations.

**Warning signs:** After a reset, the debug output shows `next=Boar, idx=1` — the string and integer disagree.

### Pitfall 4: `C_UnitAuras.GetPlayerAuraBySpellID` Returns nil vs. Missing API

**What goes wrong:** On very early login, `C_UnitAuras` may not yet be populated. The initial scan in `PLAYER_LOGIN` could error without guards.

**Why it happens:** WoW APIs are available after PLAYER_LOGIN, but the PLH guard pattern (`if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end`) exists for a reason.

**How to avoid:** Guard every call: `local aura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(spellId)`. Treat nil return as "buff not present" without erroring. [CITED: PackLeaderHelper.lua line 1753]

**Warning signs:** Lua error on login: `attempt to index global 'C_UnitAuras' (a nil value)`.

### Pitfall 5: Debug Output Format Drift

**What goes wrong:** Success criterion 1 requires the exact format `next=Boar, wyvern=false, boar=true, bear=false, idx=2` (D-06). If the format changes, the in-game verification test for SC-1 fails.

**Why it happens:** `dprint` takes variadic args concatenated with spaces. The format string must capitalize the beast name (not raw ID).

**How to avoid:** Use `BEAST_LABEL_BY_ID[nextBeastId]` (or a local equivalent) for the `next=` field, not raw `nextBeastId` (which is lowercase). Reconstruct from PLH's `BEAST_LABEL_BY_ID` table at line 1511.

**Warning signs:** `/plbeast debug` prints `next=boar` instead of `next=Boar`.

---

## Code Examples

Verified patterns from canonical source:

### Data Tables (direct copy from PLH)

```lua
-- Source: PackLeaderHelper.lua lines 11-15, 1494-1515

local SPELL_READY_BOAR    = 472324
local SPELL_READY_BEAR    = 472325
local SPELL_READY_WYVERN  = 471878

local NEXT_BEAST = {
    boar    = "bear",
    bear    = "wyvern",
    wyvern  = "boar",
}
local ID_BY_INDEX = { "wyvern", "boar", "bear" }
local INDEX_BY_ID = { wyvern = 1, boar = 2, bear = 3 }
local READY_SPELL_BY_ID = {
    wyvern  = SPELL_READY_WYVERN,
    boar    = SPELL_READY_BOAR,
    bear    = SPELL_READY_BEAR,
}
local BEAST_LABEL_BY_ID = {
    wyvern  = "Wyvern",
    boar    = "Boar",
    bear    = "Bear",
}
```

### NormalizeNextIndex (direct copy)

```lua
-- Source: PackLeaderHelper.lua lines 1526–1530

local function NormalizeNextIndex()
    local idx = tonumber(DB.nextIndex) or 1
    if idx < 1 or idx > 3 then idx = 1 end
    DB.nextIndex = idx
end
```

### SetNextBeastId (direct copy)

```lua
-- Source: PackLeaderHelper.lua lines 1647–1651

local function SetNextBeastId(beastId)
    nextBeastId = beastId or "wyvern"
    DB.nextIndex = INDEX_BY_ID[nextBeastId] or 1
    NormalizeNextIndex()
end
```

### SyncNextFromAddedReady (trimmed from PLH)

```lua
-- Source: PackLeaderHelper.lua lines 1653–1676 (CDM snapshot arg simplified to startTimes table)

local function SyncNextFromAddedReady(addedBeasts, startTimes)
    if not addedBeasts or #addedBeasts == 0 then return end

    table.sort(addedBeasts, function(a, b)
        local sa = (startTimes and startTimes[a]) or 0
        local sb = (startTimes and startTimes[b]) or 0
        if sa > 0 and sb > 0 and sa ~= sb then
            return sa < sb
        end
        return (INDEX_BY_ID[a] or 99) < (INDEX_BY_ID[b] or 99)
    end)

    for _, beastId in ipairs(addedBeasts) do
        SetNextBeastId(NEXT_BEAST[beastId] or "wyvern")
    end
end
```

### GetPlayerAuraBySpellID guard pattern

```lua
-- Source: PackLeaderHelper.lua lines 1753–1756, 1993

local function IsReadyBuffActive(spellId)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
        return false
    end
    return C_UnitAuras.GetPlayerAuraBySpellID(spellId) ~= nil
end
```

### ResetAuraState (trimmed — remove CDM/wyvern/hogstrider state)

```lua
-- Source: PackLeaderHelper.lua lines 1688–1716 (trimmed for PLBeast scope)

local function ResetAuraState(resetOrder)
    for beastId in pairs(READY_SPELL_BY_ID) do
        prevReady[beastId] = false
    end
    if resetOrder then
        SetNextBeastId("wyvern")
    end
end
```

### Spec detection (for TRACK-04 debug output)

```lua
-- Source: PackLeaderHelper.lua lines 1582–1587

local SPEC_HUNTER_BEAST_MASTERY = 253
local SPEC_HUNTER_SURVIVAL      = 255
local isBeastMastery = false
local isSurvival     = false

local function RefreshHunterSpecState()
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo
                   and GetSpecializationInfo(specIndex) or nil
    isBeastMastery = (specID == SPEC_HUNTER_BEAST_MASTERY)
    isSurvival     = (specID == SPEC_HUNTER_SURVIVAL)
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 20Hz OnUpdate polling (PLH) | `UNIT_AURA` event-driven (PLBeast D-01) | Phase 2 decision | Eliminates per-frame work; aura transitions are the natural trigger |
| CDM-backed aura reads (PLH primary) | `C_UnitAuras.GetPlayerAuraBySpellID` direct | Phase 2 scope decision | No CDM dependency; simpler init; works even if CDM is disabled |

**Deprecated/outdated for PLBeast:**
- CDM cache machinery (`BuildCDMCache`, `GatherCooldownsFromFrameTree`, etc.) — stays in PLH, not needed in PLBeast
- `readyLeftById`, `readyDurationById`, `readyUsesDurationObjectById` — timing data not needed for detection-only use case in Phase 2; Phase 4 may need start time for icon animation but that's out of scope here

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `UNIT_AURA` fires when `C_UnitAuras.GetPlayerAuraBySpellID` transitions from nil → non-nil | Architecture Patterns | If the event fires before the API is updated, `prevReady` diff will be wrong. Mitigation: tested pattern from PLH D-02 initial scan covers the seeding case; aura add events typically update the API before the event fires. | [ASSUMED] |
| A2 | Phase 2 does not need `isBeastMastery`/`isSurvival` for rotation correctness — the rotation cycle is identical for both specs | Architecture Patterns | If WoW 12.x introduces a spec-specific rotation variant, the rotation logic is insufficient. Current design: spec flags captured for debug output (TRACK-04 verifiable) but don't gate rotation logic. | [ASSUMED] |
| A3 | `C_UnitAuras.GetPlayerAuraBySpellID` is available at `PLAYER_LOGIN` time (not only after first combat) | Code Examples | If API unavailable at login, initial scan silently seeds prevReady as all-false — same as the buggy case in Pitfall 1. Mitigation: API guard returns false rather than erroring. | [ASSUMED] |

**If this table is empty:** N/A — three assumed claims documented above.

---

## Open Questions

1. **Does `UNIT_AURA` fire during the initial login scan window, before `SeedAuraSnapshot` completes?**
   - What we know: `PLAYER_LOGIN` fires after character load. `UNIT_AURA` requires a subscription via `RegisterEvent`. Registration happens in the same `PLAYER_LOGIN` block as seeding.
   - What's unclear: Whether WoW can queue a `UNIT_AURA` event to fire in the same frame as `PLAYER_LOGIN` if a ready buff is active.
   - Recommendation: Register `UNIT_AURA` after calling `SeedAuraSnapshot()` within the `PLAYER_LOGIN` handler. This prevents any race. If the seed and registration are in the same handler function, WoW processes them sequentially before dispatching queued events.

2. **Are spec flags (`isBeastMastery`/`isSurvival`) needed for any Phase 2 logic beyond TRACK-04 debug output?**
   - What we know: The rotation cycle (wyvern→boar→bear) is documented as identical for BM and SV in PLH. PLH uses spec flags for wyvern buff duration and wyvern extend logic, both of which are out of scope for Phase 2.
   - What's unclear: Whether Blizzard has changed or plans to change the rotation per-spec in 12.x.
   - Recommendation: Capture spec state via `RefreshHunterSpecState()` on `PLAYER_LOGIN` and `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` for TRACK-04 compliance. Don't gate rotation logic on spec in Phase 2. Phase 3 will need spec for visibility gating anyway.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| WoW retail client (12.0.x) | All runtime testing | ✓ (user environment) | 12.0.x | — |
| `C_UnitAuras.GetPlayerAuraBySpellID` | TRACK-02 detection | ✓ (12.0+ API) | 12.0+ | — |
| `UNIT_AURA` event | D-01 detection | ✓ (standard WoW event) | All versions | — |
| `GetSpecialization` / `GetSpecializationInfo` | TRACK-04 | ✓ (standard WoW API) | All versions | Guard with `and` check |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — WoW Lua sandbox; no unit test framework available |
| Config file | None |
| Quick run command | `/reload` in WoW client + observe chat |
| Full suite command | `/plbeast debug` + manual buff cycling via `/use` or arena dummy |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRACK-01 | Rotation order is wyvern→boar→bear→wyvern | manual | `/plbeast debug` observe idx sequence | N/A |
| TRACK-02 | Index advances on beast spawn (ready buff appears) | manual | Observe in-game: ready buff triggers → debug output shows advancement | N/A |
| TRACK-03 | nextIndex persists across `/reload` | manual | Note idx, `/reload`, confirm same idx in debug output | N/A |
| TRACK-04 | Works on both BM and SV spec | manual | Test on both specs; debug output shows correct `next=` | N/A |
| TRACK-05 | Advances only on transition, not every check | manual | `/plbeast debug` active: confirm no repeat advancement on same buff presence | N/A |

### Sampling Rate

- **Per task commit:** `/reload` in WoW client; check for Lua errors in chat
- **Per wave merge:** Full manual test: buff cycle through all 3 beasts, confirm index advances correctly, confirm persistence via `/reload`
- **Phase gate:** All 4 success criteria verified manually in-game before `/gsd-verify-work`

### Wave 0 Gaps

None — no automated test framework exists or is planned for WoW Lua addon phases. All validation is manual in-game.

---

## Security Domain

Not applicable. This addon runs entirely in the WoW Lua sandbox, has no network calls, no user-provided input beyond slash commands, and no external services. The WoW sandbox enforces its own security model. No ASVS categories apply.

---

## Sources

### Primary (HIGH confidence)

- `PackLeaderHelper.lua` lines 1494–1764 — Canonical source for all rotation logic tables and functions; direct extraction target. [VERIFIED: codebase read]
- `PackLeaderHelper.lua` lines 2068–2136 — `PollCDMState()` — snapshot-diff pattern reference (CDM path excluded for PLBeast). [VERIFIED: codebase read]
- `PackLeaderHelper.lua` lines 2554–2673 — Event handler structure, PLAYER_LOGIN init pattern. [VERIFIED: codebase read]
- `PLBeast/PLBeast.lua` — Phase 1 scaffold; integration points confirmed. [VERIFIED: codebase read]
- `.planning/phases/02-rotation-tracking/02-CONTEXT.md` — All decisions D-01 through D-06. [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)

- WoW API `C_UnitAuras.GetPlayerAuraBySpellID` behavior — confirmed available and used in PLH at lines 1753, 1993. Spec compatibility confirmed by CONTEXT.md D-02 reference to PLH init pattern. [CITED: PackLeaderHelper.lua]
- `UNIT_AURA` event `unitTarget` filtering — confirmed as standard pattern from WoW event system; PLH does not use UNIT_AURA but the pattern is standard WoW addon practice. [ASSUMED]

### Tertiary (LOW confidence)

- `UNIT_AURA` timing relative to `C_UnitAuras` API update — assumed fires after API update; standard documented behavior but not verified for 12.0.x specifically. [ASSUMED — A1]

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — WoW APIs confirmed via direct code inspection of working PLH source
- Architecture: HIGH — All functions are direct extractions from proven PLH code
- Pitfalls: HIGH — Derived from PLH guard patterns and CONTEXT.md discussion; D-02 and D-04 directly address the two most common failure modes
- Validation: HIGH — WoW Lua sandbox has no automated test framework; manual testing is the only path

**Research date:** 2026-06-18
**Valid until:** Stable (WoW 12.0.x API surface is locked for this patch cycle; re-verify if Interface version changes to 13.x)
