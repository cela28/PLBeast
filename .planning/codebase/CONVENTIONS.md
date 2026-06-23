# Coding Conventions

**Analysis Date:** 2026-06-18

## Language

This is a **World of Warcraft addon** written in **Lua** (5.1 dialect as embedded by WoW). There are no JavaScript/TypeScript files. All conventions are Lua-specific.

## Naming Patterns

**Files:**
- PascalCase for primary addon file: `PackLeaderHelper.lua`
- PascalCase directory and locale file names: `Locales/enUS.lua`, `Locales/zhCN.lua`

**Functions (local):**
- PascalCase for all named local functions: `CreateIcon`, `SetCooldown`, `NormalizeLayout`, `RefreshTrackerLayout`, `BuildCDMCache`
- Descriptive verb-first names that clearly state what the function does: `GetGridSlotForIcon`, `FindNearestGridSlot`, `CountReadyActive`
- Short debug/internal utilities are camelCase: `dprint`

**Variables (local):**
- camelCase for local state variables: `inCombat`, `hasCdBuff`, `cdLeft`, `nextBeastId`, `wyvernBuffActive`
- UPPER_SNAKE_CASE for module-level constants: `SPELL_HOTPL_PARENT`, `ICON_TIMER`, `MIN_LAYOUT_COLS`, `LAYOUT_VERSION`
- PascalCase for table/map constants: `TRACKER_ICON_ORDER`, `ICON_FILE_BY_ID`, `READY_SPELL_BY_ID`, `NEXT_BEAST`

**Globals (SavedVariables / addon-wide):**
- PascalCase prefixed with addon name: `PackLeaderHelperDB`, `PackLeaderHelperLocale`

**Frame/widget locals:**
- Single-letter or short names inside constructors (`f`, `bg`, `tex`, `cd`, `ag`) for widget sub-elements
- Descriptive names for top-level frame references: `root`, `optionsFrame`, `nextBar`, `icons`

## Module Design

**Single-file addon:** All code is in `PackLeaderHelper.lua`. No module system or `require`. No barrel files.

**Scoping:**
- All code is wrapped in file-local scope. `local addonName = ...` captures the addon name from varargs at file load.
- The file-module pattern: declare `local` variables at the top, define functions as `local function`, assign forward-declared functions at the bottom if needed (e.g., `SaveLayoutEditor = function(...)` for mutual recursion).

**Forward declarations:**
- Used for mutually recursive functions: `local UpdateNextBar`, `local RefreshLayoutEditor`, `local SaveLayoutEditor` declared before use, assigned later.

## Code Style

**Formatting:**
- No automated formatter detected (no `.editorconfig`, no Lua formatter config).
- 1-tab indentation (hard tabs).
- 60-character separator comments used for section breaks:
  ```lua
  ------------------------------------------------------------
  -- UI
  ------------------------------------------------------------
  ```

**Linting:**
- No linting config detected.

## Import / Dependency Pattern

**Localization:**
```lua
local L = setmetatable(PackLeaderHelperLocale or {}, {
    __index = function(_, key)
        return key  -- fall back to key itself if translation missing
    end,
})
```
All user-facing strings accessed via `L["string key"]`. Keys are English strings used as their own default.

**WoW API access:** Direct global calls (`CreateFrame`, `C_UnitAuras`, `GetTime`, `IsPlayerSpell`, etc.). API availability is checked before use:
```lua
if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
```

**SavedVariables:**
```lua
PackLeaderHelperDB = PackLeaderHelperDB or {}
local DB = PackLeaderHelperDB
local defaults = { ... }
-- Applied at ADDON_LOADED:
PackLeaderHelperDB = CopyDefaults(defaults, PackLeaderHelperDB or {})
DB = PackLeaderHelperDB
```

## Error Handling

**Strategy:** Defensive nil-checks before accessing any frame or API. No Lua `error()` or `assert()` usage. Silent failure is the primary pattern.

**Patterns:**
- Guard returns at top of every function: `if not f or not f.cd then return end`
- WoW API calls that can throw are wrapped in `pcall`:
  ```lua
  local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", auraInstanceID)
  if not ok or not aura then return nil end
  ```
- Numeric operations on aura fields use an inner `pcall` to protect against "secret number" values in restricted content:
  ```lua
  local calcOk, left, start, duration = pcall(function()
      local now = GetTime()
      local remain = aura.expirationTime - now
      ...
  end)
  if not calcOk then return nil end
  ```
- Type checks before arithmetic: `if type(left) ~= "number" then return nil end`
- Ternary-style safe fallbacks: `local scale = DB.scale or defaults.scale`

## Logging

**Framework:** Custom `Print` wrapper over `print`.

```lua
local PREFIX = "|cff33ff99[PackLeaderHelper]|r "

local function Print(msg)
    print(PREFIX .. tostring(msg))
end

local function dprint(...)
    if DB and DB.debug then
        Print(table.concat({ ... }, " "))
    end
end
```

**Patterns:**
- `Print(L["..."])` for user-visible messages (chat output, command feedback).
- `dprint(...)` for debug-only output, gated by `DB.debug` SavedVariable.
- Debug calls include state context: `dprint("spec=" .. ..., "wyvernChoice=" .. ...)`.

## Comments

**When to Comment:**
- Single-line `--` comments explain non-obvious game-mechanic logic inline:
  ```lua
  -- Prefer the direct spell-known check when available.
  -- This avoids depending on hero-tree visual position or entry order.
  ```
- Multi-word comments on constants clarify spell/buff identity:
  ```lua
  local SPELL_HOTPL_PARENT = 471876 -- Howl of the Pack Leader (CDM parent)
  local SPELL_HOTPL_CD_BUFF = 471877 -- 30s countdown buff
  ```
- Section separators use 60-dash block comments.
- No JSDoc/LuaDoc annotations present.

## Function Design

**Size:** Functions range from small guards (3–5 lines) to large constructors (`ToggleOptions` is ~380 lines). Large constructor functions are acceptable since WoW addons lazily build frames.

**Parameters:** Passed by value. Tables passed by reference. Boolean parameters use `true/false` not truthy values.

**Return Values:**
- Functions return `nil` (implicit) on early-guard failure.
- Data-fetching functions return multiple values (`left, start, duration`) following WoW API conventions.
- Boolean predicates return `true`/`false` explicitly.

## WoW-Specific Patterns

**SavedVariables merge:**
```lua
local function CopyDefaults(src, dest)
    -- recursive merge: only sets keys not already present in dest
end
```

**Event registration:**
```lua
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then ... end
end)
```

**Throttled OnUpdate loop:**
```lua
local updateAccumulator = 0
local function TickUpdate(elapsed)
    updateAccumulator = updateAccumulator + elapsed
    if updateAccumulator < 0.05 then return end
    updateAccumulator = 0
    -- actual work here
end
eventFrame:SetScript("OnUpdate", function(_, elapsed) TickUpdate(elapsed) end)
```

**Deferred execution:**
```lua
C_Timer.After(0, function()
    -- runs on next frame
end)
```

---

*Convention analysis: 2026-06-18*
