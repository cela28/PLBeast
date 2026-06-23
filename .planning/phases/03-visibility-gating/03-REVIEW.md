---
phase: 03-visibility-gating
reviewed: 2026-06-19T12:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - PLBeast/PLBeast.lua
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-06-19
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

PLBeast.lua implements visibility gating for the Pack Leader rotation tracker. The phase adds spec detection (BM/SV hunter), hero talent detection (Pack Leader vs Sentinel/Dark Ranger), conditional UNIT_AURA registration, and deferred talent refresh. The implementation correctly follows the plan requirements (D-01 through D-04) and faithfully adapts patterns from the parent PackLeaderHelper addon.

The code is well-structured: forward declaration of `eventFrame` is handled correctly, the `RefreshVisibility` / `QueueVisibilityRefresh` deferral pattern properly prevents stale `IsPlayerSpell` reads, `SeedAuraSnapshot` is correctly called before `RegisterEvent("UNIT_AURA")` to avoid spurious rotation advances, and all five talent/spec events are properly routed through the deferred queue.

Three findings were identified -- two warnings and one informational item. No critical/blocker issues found.

## Warnings

### WR-01: Redundant `C_UnitAuras.GetPlayerAuraBySpellID` call per added beast in `CheckAuraState`

**File:** `PLBeast/PLBeast.lua:152-164`
**Issue:** When a new beast buff is detected, `CheckAuraState` calls `C_UnitAuras.GetPlayerAuraBySpellID` twice for the same spell ID: once via `IsReadyBuffActive` (line 152-154, to build the `current` table) and again directly on line 163-164 (to extract `expirationTime`/`duration` for start time sorting). The second call re-queries the WoW API for data that was already available from the first call. While functionally correct (the aura state is stable within a single Lua frame), the redundant call is wasteful and the two-call pattern creates a latent consistency risk if future WoW API changes introduce frame-crossing aura invalidation.

**Fix:** Refactor `CheckAuraState` to query the aura data once per beast and derive both the boolean and the start time from the same result:
```lua
local function CheckAuraState()
    local current = {}
    local auraData = {}
    for _, id in ipairs({ "wyvern", "boar", "bear" }) do
        local aura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
                     and C_UnitAuras.GetPlayerAuraBySpellID(READY_SPELL_BY_ID[id])
        current[id] = aura ~= nil
        auraData[id] = aura
    end

    local addedBeasts = {}
    local startTimes  = {}
    for _, id in ipairs({ "wyvern", "boar", "bear" }) do
        if current[id] and not prevReady[id] then
            addedBeasts[#addedBeasts + 1] = id
            local aura = auraData[id]
            startTimes[id] = (aura and aura.expirationTime and aura.duration)
                             and (aura.expirationTime - aura.duration) or 0
        end
    end
    -- ... rest unchanged
end
```

### WR-02: `IsPackLeaderHeroTalent` calls `IsPlayerSpell` without nil guard, inconsistent with `RefreshHunterSpecState` pattern

**File:** `PLBeast/PLBeast.lua:209-210`
**Issue:** `RefreshHunterSpecState` (line 198) defensively checks `GetSpecialization and GetSpecialization()` before calling the API. However, `IsPackLeaderHeroTalent` (lines 209-210) calls `IsPlayerSpell(...)` directly without a nil guard. If `IsPlayerSpell` were unavailable (e.g., during very early addon loading or in a future WoW build that changes API availability), this would produce an unprotected Lua error that crashes the event handler.

The parent addon PackLeaderHelper has the same unguarded pattern at line 1575 but also uses the guarded form `IsPlayerSpell and IsPlayerSpell(...)` at line 1599, demonstrating that the guard is recognized as a defensive pattern in this codebase. PLBeast should be consistent with the more defensive form, especially since `IsPackLeaderHeroTalent` is called on every talent/spec change event.

**Fix:** Add a nil guard consistent with the existing defensive coding pattern:
```lua
local function IsPackLeaderHeroTalent()
    if not IsPlayerSpell or not IsPlayerSpell(SPELL_HOTPL_PARENT) then return false end
    if IsPlayerSpell(SPELL_SENTINEL_ANCHOR) or IsPlayerSpell(SPELL_DARK_RANGER_ANCHOR) then
        return false
    end
    return true
end
```

## Info

### IN-01: Unused locale key in `Locales/enUS.lua`

**File:** `PLBeast/Locales/enUS.lua:3`
**Issue:** The locale table defines the key `"Cannot open options in combat."` which is not referenced anywhere in `PLBeast.lua`. This appears to be carried over from PackLeaderHelper. Dead locale entries add minor maintenance burden and could confuse translators adding new locale files.
**Fix:** Remove the unused key from `Locales/enUS.lua`:
```lua
PLBeastLocale = {
    ["PLBeast loaded. Type /plbeast for options."] = "PLBeast loaded. Type /plbeast for options.",
    -- Remove: ["Cannot open options in combat."] = "Cannot open options in combat.",
    ["debug=%s"] = "debug=%s",
    ["Rotation reset. Next: Wyvern."] = "Rotation reset. Next: Wyvern.",
    ["PLBeast. /plbeast debug | reset"] = "PLBeast. /plbeast debug | reset",
}
```

---

_Reviewed: 2026-06-19_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
