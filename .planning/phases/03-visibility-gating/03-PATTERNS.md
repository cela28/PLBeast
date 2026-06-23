# Phase 3: Visibility Gating - Pattern Map

**Mapped:** 2026-06-19
**Files analyzed:** 2 (PLBeast/PLBeast.lua modified, PLBeast/Locales/enUS.lua unchanged)
**Analogs found:** 2 / 2

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `PLBeast/PLBeast.lua` | addon-logic (state machine + event handler) | event-driven | `PackLeaderHelper.lua` (lines 1574–1638, 2554–2614) | exact — direct extract-and-trim |
| `PLBeast/Locales/enUS.lua` | localization config | transform | `PLBeast/Locales/enUS.lua` (current) | exact — same file, same pattern |

---

## Pattern Assignments

### `PLBeast/PLBeast.lua` — Spell Constants Block

**Analog:** `PackLeaderHelper.lua` lines 10–22
**Location to insert in PLBeast:** Directly after the existing `-- Spell ID Constants` block (PLBeast.lua line 22–25), before `SPEC_HUNTER_BEAST_MASTERY`.

**Constants pattern** (PLH lines 10–22):
```lua
local SPELL_HOTPL_PARENT        = 471876  -- Pack Leader parent spell; primary hero-talent gate
local SPELL_SENTINEL_ANCHOR     = 1253599 -- Sentinel hero talent anchor; mutually exclusive with Pack Leader
local SPELL_DARK_RANGER_ANCHOR  = 466930  -- Dark Ranger hero talent anchor; mutually exclusive with Pack Leader
```

These three constants are the only additions to the constants block. The three `SPELL_READY_*` constants already present in PLBeast.lua are not duplicated.

---

### `PLBeast/PLBeast.lua` — `isPackLeaderActive` State Variable

**Analog:** PLH module-level state pattern (PLBeast.lua lines 54–62 for existing state variables)
**Location to insert:** After `local isSurvival = false` (PLBeast.lua line 59), inside the `-- Module-Level State Variables` block.

**State variable pattern** (derived from PLH patterns, D-01):
```lua
local isPackLeaderActive = false
```

Single boolean. Not persisted (derived on every login from live talent state). Phase 4 reads this flag via `root:SetShown(isPackLeaderActive)`.

---

### `PLBeast/PLBeast.lua` — `IsPackLeaderHeroTalent()` Function

**Analog:** `PackLeaderHelper.lua` lines 1574–1580
**Location to insert:** In the `-- Core Functions` block (PLBeast.lua line 79), before `RefreshHunterSpecState()`.

**Core function pattern** (PLH lines 1574–1580, verbatim copy):
```lua
-- Source: PackLeaderHelper.lua lines 1574–1580 — direct copy
-- Returns true only when the player has Pack Leader hero talent active,
-- excluding Sentinel and Dark Ranger hero trees (mutually exclusive).
local function IsPackLeaderHeroTalent()
	if not IsPlayerSpell(SPELL_HOTPL_PARENT) then return false end
	if IsPlayerSpell(SPELL_SENTINEL_ANCHOR) or IsPlayerSpell(SPELL_DARK_RANGER_ANCHOR) then
		return false
	end
	return true
end
```

No modifications needed. PLBeast does not have wyvern-duration concern so no further callers of this function need to be adapted.

---

### `PLBeast/PLBeast.lua` — `RefreshVisibility()` Function

**Analog:** `PackLeaderHelper.lua` lines 1605–1620 (`RefreshTalentDerivedState`) + D-01 / D-02 decisions
**Location to insert:** After `IsPackLeaderHeroTalent()`, before the `-- Event Handler` block.

**Core pattern** (PLH lines 1615–1619 for dprint structure; D-01, D-02, D-04 for logic):
```lua
-- Source: PackLeaderHelper.lua lines 1605–1620 (adapted — strips wyvern duration logic)
-- Sets isPackLeaderActive flag; conditionally registers/unregisters UNIT_AURA. (D-01, D-02)
local function RefreshVisibility()
	RefreshHunterSpecState()
	local isHunterSpec = isBeastMastery or isSurvival
	local isPackLeader = IsPackLeaderHeroTalent()
	local wasActive    = isPackLeaderActive
	isPackLeaderActive = isHunterSpec and isPackLeader

	-- D-04: debug output works regardless of visibility state
	dprint(
		"spec=" .. (isBeastMastery and "BM" or (isSurvival and "SV" or "other")),
		"packLeader=" .. tostring(isPackLeaderActive)
	)

	if isPackLeaderActive and not wasActive then
		-- Re-activation: seed snapshot first to prevent spurious rotation advance (Pitfall 2)
		SeedAuraSnapshot()
		eventFrame:RegisterEvent("UNIT_AURA")
	elseif not isPackLeaderActive and wasActive then
		eventFrame:UnregisterEvent("UNIT_AURA")
	end
end
```

Key differences from PLH's `RefreshTalentDerivedState`:
- Strips `ResolveWyvernDurationChoice()`, wyvern buff adjust logic entirely (not in PLBeast scope)
- Adds conditional UNIT_AURA register/unregister (D-02)
- Adds `wasActive` guard to prevent double-registration

---

### `PLBeast/PLBeast.lua` — `QueueVisibilityRefresh()` Function

**Analog:** `PackLeaderHelper.lua` lines 1622–1638 (`QueueTalentDerivedStateRefresh`)
**Location to insert:** Immediately after `RefreshVisibility()`.

**Core pattern** (PLH lines 1622–1638, adapted):
```lua
-- Source: PackLeaderHelper.lua lines 1622–1638 (adapted — single pending flag, no wyvern-buff arg)
-- Defers RefreshVisibility() one frame so IsPlayerSpell reads updated talent state. (Pitfall 1)
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

Key simplification from PLH: PLH's version carries an `adjustActiveWyvernBuff` flag and second pending boolean. PLBeast drops both — `RefreshVisibility()` takes no arguments.

---

### `PLBeast/PLBeast.lua` — Event Registrations (PLAYER_LOGIN block)

**Analog:** `PackLeaderHelper.lua` lines 2554–2564 (event registration block) and PLBeast.lua lines 240–244 (existing PLAYER_LOGIN handler)

**Pattern: new event registrations** (PLH lines 2560–2564):
```lua
-- Add to PLAYER_LOGIN handler in PLBeast.lua after existing eventFrame:RegisterEvent calls
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("TRAIT_SUB_TREE_CHANGED")
-- ACTIVE_PLAYER_SPECIALIZATION_CHANGED already registered (PLBeast.lua line 244)
```

**Pattern: modified PLAYER_LOGIN init sequence** (adapted from PLH lines 2581–2588 and PLBeast.lua lines 240–245):

Replace current block (PLBeast.lua lines 240–245):
```lua
-- BEFORE (Phase 2):
RefreshHunterSpecState()
SeedAuraSnapshot()
eventFrame:RegisterEvent("UNIT_AURA")           -- unconditional
eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
```

With (Phase 3):
```lua
-- AFTER (Phase 3):
-- RefreshHunterSpecState() is now called inside RefreshVisibility()
RefreshVisibility()                             -- sets isPackLeaderActive; owns UNIT_AURA registration
eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("TRAIT_SUB_TREE_CHANGED")
```

`SeedAuraSnapshot()` is no longer called directly here — `RefreshVisibility()` calls it internally on the activation branch. The unconditional `eventFrame:RegisterEvent("UNIT_AURA")` is removed (Pitfall 4).

---

### `PLBeast/PLBeast.lua` — Event Handler Branch Updates

**Analog:** `PackLeaderHelper.lua` lines 2609–2614 (talent/spec event handler branch) and PLBeast.lua lines 253–256 (existing `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` branch)

**Pattern: replace standalone spec handler with unified visibility queue** (PLH lines 2609–2614):

Replace current branch (PLBeast.lua lines 253–256):
```lua
-- BEFORE (Phase 2):
elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
    RefreshHunterSpecState()
```

With (Phase 3):
```lua
-- AFTER (Phase 3): Source: PackLeaderHelper.lua lines 2609–2614
elseif event == "PLAYER_TALENT_UPDATE"
    or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
    or event == "ACTIVE_COMBAT_CONFIG_CHANGED"
    or event == "TRAIT_CONFIG_UPDATED"
    or event == "TRAIT_SUB_TREE_CHANGED" then
    QueueVisibilityRefresh()
```

`RefreshHunterSpecState()` is no longer called directly in the handler — it runs inside `RefreshVisibility()` via the deferred queue (Pitfall 3).

---

### `PLBeast/Locales/enUS.lua` — No Changes Required

**Analog:** `PLBeast/Locales/enUS.lua` (current, lines 1–7)

Per RESEARCH.md: "The dprint() debug output uses raw string concatenation (no locale key). The existing locale table needs no changes for Phase 3."

No new `Print()` calls are added. The `dprint()` calls in `RefreshVisibility()` use inline string concatenation matching the existing PLBeast dprint pattern (PLBeast.lua lines 166–173).

---

## Shared Patterns

### Guard Pattern: `eventFrame` Reference Safety
**Source:** `PLBeast/PLBeast.lua` lines 199–257
**Apply to:** `RefreshVisibility()` — `eventFrame` is module-level, created before any function that references it. No nil guard needed because it is always initialized at module load before any event fires.

### dprint Debug Pattern
**Source:** `PLBeast/PLBeast.lua` lines 72–76, 166–173
**Apply to:** `RefreshVisibility()` dprint call
```lua
dprint(
    "spec=" .. (isBeastMastery and "BM" or (isSurvival and "SV" or "other")),
    "packLeader=" .. tostring(isPackLeaderActive)
)
```
This exactly mirrors the PLH pattern at lines 1615–1619 (same ternary string format, same `dprint(...)` vararg call). The spec label format `"BM"` / `"SV"` / `"other"` is consistent with PLH.

### C_Timer.After(0, ...) Deferral Pattern
**Source:** `PackLeaderHelper.lua` lines 1631–1637
**Apply to:** `QueueVisibilityRefresh()` — defers one frame to allow `IsPlayerSpell` to settle after talent events.
```lua
C_Timer.After(0, function()
    pendingVisibilityRefresh = false
    RefreshVisibility()
end)
```

### `wasActive` Guard for Idempotent Registration
**Source:** Derived from D-02 and PLH's structural approach (multiple event types can trigger `QueueVisibilityRefresh` rapidly)
**Apply to:** `RefreshVisibility()` — the `wasActive = isPackLeaderActive` capture before setting the new value prevents re-registering UNIT_AURA if the state hasn't changed. WoW silently tolerates duplicate RegisterEvent, but the guard makes intent explicit.

---

## No Analog Found

No files fall into this category. All patterns have direct extraction targets in either `PackLeaderHelper.lua` (primary analog) or existing `PLBeast/PLBeast.lua` (Phase 2 output).

---

## Integration Order (Critical)

The following ordering constraint is required for correctness and must be respected by the planner:

1. Add three spell constants (`SPELL_HOTPL_PARENT`, `SPELL_SENTINEL_ANCHOR`, `SPELL_DARK_RANGER_ANCHOR`) to constants block
2. Add `isPackLeaderActive = false` to state variables block
3. Add `IsPackLeaderHeroTalent()` to core functions block
4. Add `RefreshVisibility()` after `IsPackLeaderHeroTalent()`
5. Add `pendingVisibilityRefresh` flag and `QueueVisibilityRefresh()` after `RefreshVisibility()`
6. Modify PLAYER_LOGIN handler: remove unconditional UNIT_AURA registration; call `RefreshVisibility()` instead; add four new event registrations
7. Replace `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` handler branch with unified five-event branch calling `QueueVisibilityRefresh()`

Steps 3–5 must precede step 6 (forward references are not needed in Lua as long as definitions precede first call, and PLAYER_LOGIN fires after module load completes).

---

## Metadata

**Analog search scope:** `PackLeaderHelper.lua` (lines 1–30, 1574–1638, 2554–2614), `PLBeast/PLBeast.lua` (full file), `PLBeast/Locales/enUS.lua` (full file)
**Files scanned:** 3
**Pattern extraction date:** 2026-06-19
