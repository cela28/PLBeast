# Phase 2: Rotation Tracking - Pattern Map

**Mapped:** 2026-06-18
**Files analyzed:** 2 (1 modified, 1 extended)
**Analogs found:** 2 / 2

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `PLBeast/PLBeast.lua` | addon-module (state machine + event handler) | event-driven | `PackLeaderHelper.lua` (state machine + event handler) | exact — same role, same WoW addon pattern, direct extraction source |
| `PLBeast/Locales/enUS.lua` | locale config | transform (key → string) | `PackLeaderHelper.lua` lines 4–8 + `Locales/enUS.lua` pattern | exact — same locale-table pattern |

---

## Pattern Assignments

### `PLBeast/PLBeast.lua` — Rotation State Machine Extension

Phase 2 adds rotation tracking logic to the existing scaffold. All new code slots into the existing file. The analog is `PackLeaderHelper.lua` — every section below cites exact line ranges in that source.

---

#### 1. Spell ID Constants

**Analog:** `PackLeaderHelper.lua` lines 11–15

```lua
-- Source: PackLeaderHelper.lua lines 13–15
local SPELL_READY_BOAR   = 472324
local SPELL_READY_BEAR   = 472325
local SPELL_READY_WYVERN = 471878
```

**Placement in PLBeast.lua:** After the existing `PREFIX`/`L`/`DB`/`defaults` block, before the eventFrame declaration. Phase 2 scope: only these 3 ready-buff spell IDs. Phase 3 adds `SPELL_HOTPL_PARENT`, `SPELL_SENTINEL_ANCHOR`, `SPELL_DARK_RANGER_ANCHOR`.

---

#### 2. Rotation Data Tables

**Analog:** `PackLeaderHelper.lua` lines 1494–1515

```lua
-- Source: PackLeaderHelper.lua lines 1494–1515
local NEXT_BEAST = {
	boar   = "bear",
	bear   = "wyvern",
	wyvern = "boar",
}
local ID_BY_INDEX = { "wyvern", "boar", "bear" }
local INDEX_BY_ID = { wyvern = 1, boar = 2, bear = 3 }
local READY_SPELL_BY_ID = {
	wyvern = SPELL_READY_WYVERN,
	boar   = SPELL_READY_BOAR,
	bear   = SPELL_READY_BEAR,
}
local BEAST_LABEL_BY_ID = {
	wyvern = "Wyvern",
	boar   = "Boar",
	bear   = "Bear",
}
```

**Note:** `ANIMAL_ICON_BY_ID` (lines 1506–1510) and `TRACKED_SPELL_IDS` (lines 1516–1524) are out of scope for Phase 2 — icon rendering is Phase 4, CDM tracking is stripped entirely.

---

#### 3. Module-Level State Variables

**Analog:** `PackLeaderHelper.lua` lines 1532–1535, 1545

```lua
-- Source: PackLeaderHelper.lua lines 1532–1535, 1545 (trimmed for PLBeast scope)
local nextBeastId = "wyvern"
local isBeastMastery = false
local isSurvival     = false

local prevReady = { wyvern = false, boar = false, bear = false }
```

**Trim notes vs PLH:**
- `inCombat`, `hasCdBuff`, `cdLeft`, `cdStart`, `cdDuration`, `cdUsesDurationObject` — out of scope (no CDM in Phase 2)
- `hasReadyBuff`, `readyBeastId`, `readyActiveById`, `readyLeftById`, `readyStartById`, `readyDurationById`, `readyUsesDurationObjectById` — replaced by the simpler `prevReady` snapshot table
- `cdmCache`, `cdmCacheBuilt`, `testModeUntil` — CDM/test machinery, out of scope
- All wyvern buff state and hogstrider state variables — out of scope

---

#### 4. Spec Constants and Spec State Function

**Analog:** `PackLeaderHelper.lua` lines 24–25, 1582–1587

```lua
-- Source: PackLeaderHelper.lua lines 24–25
local SPEC_HUNTER_BEAST_MASTERY = 253
local SPEC_HUNTER_SURVIVAL      = 255

-- Source: PackLeaderHelper.lua lines 1582–1587
local function RefreshHunterSpecState()
	local specIndex = GetSpecialization and GetSpecialization()
	local specID = specIndex and GetSpecializationInfo
	                and GetSpecializationInfo(specIndex) or nil
	isBeastMastery = specID == SPEC_HUNTER_BEAST_MASTERY
	isSurvival     = specID == SPEC_HUNTER_SURVIVAL
end
```

**Usage:** Call in `PLAYER_LOGIN` and wire to `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` event. Spec flags are for TRACK-04 debug output; they do not gate rotation logic in Phase 2.

---

#### 5. NormalizeNextIndex

**Analog:** `PackLeaderHelper.lua` lines 1526–1530

```lua
-- Source: PackLeaderHelper.lua lines 1526–1530 — direct copy
local function NormalizeNextIndex()
	local idx = tonumber(DB.nextIndex) or 1
	if idx < 1 or idx > 3 then idx = 1 end
	DB.nextIndex = idx
end
```

**No changes needed.** Called in `ADDON_LOADED` after defaults merge to clamp any persisted out-of-range value.

---

#### 6. SetNextBeastId

**Analog:** `PackLeaderHelper.lua` lines 1647–1651

```lua
-- Source: PackLeaderHelper.lua lines 1647–1651
-- Note: PLH defaults to "boar"; PLBeast uses "wyvern" per rotation start convention
local function SetNextBeastId(beastId)
	nextBeastId = beastId or "wyvern"
	DB.nextIndex = INDEX_BY_ID[nextBeastId] or 1
	NormalizeNextIndex()
end
```

**Difference from PLH:** PLH's default fallback is `"boar"` (line 1648). PLBeast uses `"wyvern"` as the canonical rotation-start beast. This is the single intentional deviation from the source — everything else in this function is a direct copy.

---

#### 7. SyncNextFromAddedReady (multi-beast sort)

**Analog:** `PackLeaderHelper.lua` lines 1653–1676

```lua
-- Source: PackLeaderHelper.lua lines 1653–1676 (adapted: readySnapshot arg → startTimes table)
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

**Adaptation note:** PLH passes a `readySnapshot` struct with nested `.start` table (line 1661: `readySnapshot.start[a]`). PLBeast simplifies this to a flat `startTimes` table (`startTimes[a]`). The sort logic and advancement loop are identical.

---

#### 8. ResetAuraState (trimmed)

**Analog:** `PackLeaderHelper.lua` lines 1688–1716

```lua
-- Source: PackLeaderHelper.lua lines 1688–1716 (trimmed — CDM/wyvern/hogstrider state removed)
local function ResetAuraState(resetOrder)
	for beastId in pairs(READY_SPELL_BY_ID) do
		prevReady[beastId] = false
	end
	if resetOrder then
		SetNextBeastId("wyvern")
	end
end
```

**Trim notes:** PLH's `ResetAuraState` also clears `hasCdBuff`, `cdLeft`, `cdStart`, `cdDuration`, `cdUsesDurationObject`, `hasReadyBuff`, `readyBeastId`, `readyLeftById`, `readyStartById`, `readyDurationById`, `readyUsesDurationObjectById`, `wyvernBuffActive`, `wyvernBuffStartAt`, `wyvernBuffEndsAt`, `wyvernBuffExtendsUsed`, `hogstriderActive`, and all hogstrider fields (lines 1689–1715). All of these are out of scope for PLBeast.

---

#### 9. C_UnitAuras Guard Pattern

**Analog:** `PackLeaderHelper.lua` lines 1752–1756, 1993

```lua
-- Source: PackLeaderHelper.lua lines 1753–1756 and line 1993
-- PLH GetAuraTimingBySpellID uses full guard; PLBeast only needs presence (boolean)
local function IsReadyBuffActive(spellId)
	if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
		return false
	end
	return C_UnitAuras.GetPlayerAuraBySpellID(spellId) ~= nil
end
```

**Alternative inline form** (from PLH line 1993) for use inside `CheckAuraState`:
```lua
local aura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
             and C_UnitAuras.GetPlayerAuraBySpellID(spellId)
```

Use `IsReadyBuffActive` for the simple presence check in `prevReady` seeding. For `CheckAuraState`'s start-time capture path, use the inline form so the aura table is available for `expirationTime - duration` calculation.

---

#### 10. CheckAuraState (snapshot-diff — new function)

**Analog:** `PackLeaderHelper.lua` lines 2068–2111 (the `PollCDMState` snapshot-diff block, adapted)

The PLH analog for the diff block is lines 2076–2111. The PLBeast version replaces the CDM-backed `BuildReadySnapshot` call with direct `C_UnitAuras.GetPlayerAuraBySpellID` reads per the `BuildReadySnapshot` C_UnitAuras fallback path (PLH lines 1991–2003).

```lua
-- Pattern derived from: PackLeaderHelper.lua lines 2076–2111 (snapshot-diff structure)
-- and lines 1991–2003 (C_UnitAuras direct read path)
local function CheckAuraState()
	local current = {
		wyvern = IsReadyBuffActive(SPELL_READY_WYVERN),
		boar   = IsReadyBuffActive(SPELL_READY_BOAR),
		bear   = IsReadyBuffActive(SPELL_READY_BEAR),
	}

	local addedBeasts = {}
	local startTimes  = {}
	for _, id in ipairs({ "wyvern", "boar", "bear" }) do
		if current[id] and not prevReady[id] then
			addedBeasts[#addedBeasts + 1] = id
			-- Capture start time for multi-beast sort (D-04)
			local aura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
			             and C_UnitAuras.GetPlayerAuraBySpellID(READY_SPELL_BY_ID[id])
			startTimes[id] = (aura and aura.expirationTime and aura.duration)
			                 and (aura.expirationTime - aura.duration) or 0
		end
	end

	if #addedBeasts > 0 then
		SyncNextFromAddedReady(addedBeasts, startTimes)
	end

	prevReady = current

	dprint(
		"next="   .. (BEAST_LABEL_BY_ID[nextBeastId] or "?"),
		"wyvern=" .. tostring(current.wyvern),
		"boar="   .. tostring(current.boar),
		"bear="   .. tostring(current.bear),
		"idx="    .. tostring(DB.nextIndex)
	)
end
```

**Format note (D-06, Pitfall 5):** The `next=` field must use `BEAST_LABEL_BY_ID[nextBeastId]` (capitalized) not raw `nextBeastId` (lowercase). The PLH equivalent is `BEAST_LABEL_BY_ID` at lines 1511–1515.

---

#### 11. SeedAuraSnapshot (initial scan — new function)

**Analog:** `PackLeaderHelper.lua` line 2588 (`PollCDMState()` call in PLAYER_LOGIN), adapted to event-driven seeding

```lua
-- Pattern: PLH calls PollCDMState() in PLAYER_LOGIN (line 2588) to seed state.
-- PLBeast equivalent seeds prevReady directly without CDM dependency.
local function SeedAuraSnapshot()
	prevReady.wyvern = IsReadyBuffActive(SPELL_READY_WYVERN)
	prevReady.boar   = IsReadyBuffActive(SPELL_READY_BOAR)
	prevReady.bear   = IsReadyBuffActive(SPELL_READY_BEAR)
end
```

**Placement:** Called in `PLAYER_LOGIN` handler after `NormalizeNextIndex()` + `SetNextBeastId` restore, before `eventFrame:RegisterEvent("UNIT_AURA")`. Registering UNIT_AURA after seeding prevents any race with queued events (RESEARCH.md Open Question 1).

---

#### 12. ADDON_LOADED Handler Extension

**Analog:** `PackLeaderHelper.lua` lines 2571–2579 and existing `PLBeast/PLBeast.lua` lines 36–47

```lua
-- Source: PackLeaderHelper.lua lines 2577–2579
-- Add to existing ADDON_LOADED branch in PLBeast.lua after DB merge:
NormalizeNextIndex()
nextBeastId = ID_BY_INDEX[DB.nextIndex] or "wyvern"
ResetAuraState(false)
```

**Do not** call `SetNextBeastId("wyvern")` unconditionally as PLH does (PLH line 2578) — that discards the saved index. Instead, apply `NormalizeNextIndex()` then derive `nextBeastId` from `DB.nextIndex`. The saved index is ground truth (RESEARCH.md anti-pattern note).

---

#### 13. PLAYER_LOGIN Handler Extension

**Analog:** `PackLeaderHelper.lua` lines 2581–2608 (trimmed for PLBeast scope)

```lua
-- Source: PackLeaderHelper.lua lines 2581–2608 (trimmed)
-- Add to existing PLAYER_LOGIN branch in PLBeast.lua:
SLASH_PLBEAST1 = "/plbeast"
SlashCmdList["PLBEAST"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "debug" then
		DB.debug = not DB.debug
		Print(string.format(L["debug=%s"], tostring(DB.debug)))
	elseif msg == "reset" then
		SetNextBeastId("wyvern")
		ResetAuraState(false)
		SeedAuraSnapshot()
		Print("Rotation reset. Next: Wyvern.")
	else
		Print("PLBeast. /plbeast debug | reset")
	end
end

RefreshHunterSpecState()
SeedAuraSnapshot()
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
Print(L["PLBeast loaded. Type /plbeast for options."])
```

**PLH analog for `debug` subcommand:** lines 2541–2543 (exact pattern).
**PLH analog for slash registration:** lines 2479–2482 (exact pattern for msg normalization trim).

---

#### 14. UNIT_AURA Event Branch

**Analog:** `PackLeaderHelper.lua` event handler structure (lines 2570–2673), adapted to UNIT_AURA

```lua
-- Source: WoW standard UNIT_AURA filter pattern (confirmed in RESEARCH.md Pattern 3)
-- Add new branch to eventFrame:SetScript("OnEvent", ...) in PLBeast.lua:
elseif event == "UNIT_AURA" then
	local unitTarget = ...
	if unitTarget ~= "player" then return end
	CheckAuraState()

elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
	RefreshHunterSpecState()
```

**PLH analog for unit filter:** `UNIT_SPELLCAST_SUCCEEDED` branch at line 2633: `if unit ~= "player" then return end` — same guard pattern applied to UNIT_AURA.

---

### `PLBeast/Locales/enUS.lua` — Locale String Addition

**Analog:** `PLBeast/Locales/enUS.lua` lines 1–5 (existing file, extend in place)

The existing file already has `"debug=%s"`. No new locale keys are strictly required for Phase 2's debug output — `dprint` calls use `string.format` with `"debug=%s"` which already exists. If a reset confirmation string is desired, add it here using the same `["key"] = "value"` pattern.

---

## Shared Patterns

### Guard Returns (every function)

**Source:** `PackLeaderHelper.lua` — pervasive pattern (e.g., lines 1753, 1993, 2069–2072)
**Apply to:** `IsReadyBuffActive`, `CheckAuraState`, `SeedAuraSnapshot`, `SyncNextFromAddedReady`

```lua
-- Pattern: nil-guard at top of every function that depends on external state
if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false end
```

### Debug Toggle (slash command)

**Source:** `PackLeaderHelper.lua` lines 2541–2543
**Apply to:** PLBeast slash command handler `debug` branch

```lua
-- Source: PackLeaderHelper.lua lines 2541–2543 — direct copy, name change only
DB.debug = not DB.debug
Print(string.format(L["debug=%s"], tostring(DB.debug)))
```

### dprint Variadic Pattern

**Source:** `PLBeast/PLBeast.lua` lines 23–27 (already implemented)
**Apply to:** `CheckAuraState` debug output line

```lua
-- Source: PLBeast/PLBeast.lua lines 23–27
-- dprint takes variadic args joined by spaces — pass each key=value as a separate arg
dprint("next=X", "wyvern=Y", "boar=Z", "bear=W", "idx=N")
```

### WoW API Availability Guard

**Source:** `PackLeaderHelper.lua` lines 1753–1756
**Apply to:** Every `C_UnitAuras` call

```lua
-- Source: PackLeaderHelper.lua lines 1753–1756
if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false end
```

---

## No Analog Found

None. All patterns for Phase 2 have direct analogs in `PackLeaderHelper.lua`.

---

## Metadata

**Analog search scope:** `PackLeaderHelper.lua` (primary source), `PLBeast/PLBeast.lua` (scaffold), `PLBeast/Locales/enUS.lua`
**Files scanned:** 3
**Pattern extraction date:** 2026-06-18

### Key Source Ranges Summary (for planner quick reference)

| Pattern | PLH Source Lines |
|---------|-----------------|
| Spell ID constants | 13–15 |
| Rotation tables (NEXT_BEAST, ID_BY_INDEX, INDEX_BY_ID, READY_SPELL_BY_ID, BEAST_LABEL_BY_ID) | 1494–1515 |
| NormalizeNextIndex | 1526–1530 |
| Module-level state vars (trimmed) | 1532–1535, 1545 |
| Spec constants + RefreshHunterSpecState | 24–25, 1582–1587 |
| SetNextBeastId | 1647–1651 |
| SyncNextFromAddedReady | 1653–1676 |
| ResetAuraState (trim to prevReady only) | 1688–1716 |
| C_UnitAuras guard pattern | 1752–1756, 1993 |
| Snapshot-diff loop (PollCDMState adapted) | 2076–2111 |
| PLAYER_LOGIN init sequence | 2581–2608 |
| debug slash subcommand | 2541–2543 |
| Slash msg normalization | 2479–2482 |
