# Testing Patterns

**Analysis Date:** 2026-06-18

## Test Framework

**Runner:** None detected.

**Assertion Library:** None detected.

**Run Commands:** No test commands available.

## Test File Organization

**Location:** No test files exist in the repository.

**Named test files found:**
```
(none)
```

## Test Coverage

**Requirements:** None enforced — no coverage tooling present.

**View Coverage:** Not applicable.

## Test Types

**Unit Tests:** Not present.

**Integration Tests:** Not present.

**E2E Tests:** Not present.

## Built-In Test Mechanism

The addon includes a **live in-game test mode** accessed via slash command. This is the only form of functional testing:

```lua
-- /plh test
elseif msg == "test" then
    testModeUntil = GetTime() + 10
    TickUpdate(0.1)
    Print(L["Test mode: forced display for 10 seconds."])
```

`ShowTestState(now)` is invoked by `TickUpdate` when `testModeUntil > GetTime()`. It forces all tracker icons into a representative active state for 10 seconds, bypassing CDM polling and real aura data. This is declared in `PackLeaderHelper.lua` (lines 2321–2407).

**What test mode covers:**
- Visual rendering of all 7 tracker icons (timer, wyvern, wyvernBuff, wyvernExtend, boar, hogstrider, bear)
- NEXT bar display and icon rendering
- Layout positioning and grid visibility
- Glow animation on `wyvernExtend`
- Cooldown swipe animation on timer and boar icons

**What test mode does NOT cover:**
- Correct CDM cache building (`BuildCDMCache`)
- Aura polling logic (`PollCDMState`)
- State machine transitions (beast rotation, `SyncNextFromAddedReady`)
- Wyvern buff extension logic (`ExtendWyvernBuff`)
- Talent detection (`IsPackLeaderHeroTalent`, `ResolveWyvernDurationChoice`)
- Layout normalization edge cases (`NormalizeLayout`)
- SavedVariables persistence

## Debug Mode

A persistent `DB.debug` flag enables verbose chat output via `dprint`:

```lua
-- Toggle with: /plh debug
DB.debug = not DB.debug
```

When enabled, `dprint` calls emit spec detection and wyvern duration resolution results to chat. This is a diagnostic aid, not a test.

## Context for Adding Tests

WoW addon Lua runs inside the WoW client's sandboxed environment. Standard Lua testing frameworks (Busted, LuaUnit) require a standalone Lua runtime. Mocking the WoW API surface (`CreateFrame`, `C_UnitAuras`, `C_CooldownViewer`, `GetTime`, etc.) would be required before any unit tests could run outside the client.

**Pure-logic functions that could be unit-tested with a minimal WoW API mock:**
- `CopyDefaults` — `PackLeaderHelper.lua` line 102
- `NormalizeLayout` — `PackLeaderHelper.lua` line 200
- `FindArrayValueIndex` / `RemoveArrayValue` — lines 151–167
- `AddUnusedIcon` — line 168
- `PlaceIconInGrid` / `MoveIconToUnused` — lines 729–745
- `SyncNextFromAddedReady` — line 1653
- `CountReadyActive` — line 1678
- `FormatTimeLeft` — line 124
- `GetGridDimensions` — line 303

---

*Testing analysis: 2026-06-18*
