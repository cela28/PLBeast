# Phase 1: Addon Scaffold - Pattern Map

**Mapped:** 2026-06-18
**Files analyzed:** 3 new files
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `PLBeast/PLBeast.toc` | config | N/A | `PackLeaderHelper.toc` | exact |
| `PLBeast/Locales/enUS.lua` | config | N/A | `Locales/enUS.lua` | exact |
| `PLBeast/PLBeast.lua` | utility + init | event-driven | `PackLeaderHelper.lua` lines 1–8, 36–122, 2479–2607 | exact (subset) |

---

## Pattern Assignments

### `PLBeast/PLBeast.toc` (config, N/A)

**Analog:** `PackLeaderHelper.toc` (lines 1–14)

**Complete analog** (lines 1–14):
```
## Interface: 120000, 120001, 120005
## Title: PackLeaderHelper
## Title-zhCN: PackLeaderHelper
## Notes: Pack Leader hero talent helper. CDM-driven tracking for howl timer and ready states (wyvern/boar/bear).
## Notes-zhCN: 狗王监控
## Author: Giftia
## Version: 0.8
## SavedVariables: PackLeaderHelperDB
## IconTexture: Interface\AddOns\PackLeaderHelper\Media\plh

Locales\enUS.lua
Locales\zhCN.lua
PackLeaderHelper.lua
```

**Adaptations required (all are mechanical renames or locked decisions):**
- `## Interface:` — change `120000, 120001, 120005` to `120000, 120005, 120007` (D-08, D-09)
- `## Title:` — `PackLeaderHelper` → `PLBeast`
- `## Notes:` — replace with PLBeast description
- Remove `## Title-zhCN:` and `## Notes-zhCN:` (no zhCN locale in Phase 1)
- `## Author:` — `Giftia` → `cela28`
- `## Version:` — `0.8` → `0.1.0`
- `## SavedVariables:` → `## SavedVariablesPerCharacter:` (D-04, STRUCT-04); rename to `PLBeastDB`
- `## IconTexture:` — replace Media/ path with `Interface\Icons\Ability_Hunter_AnimalCompanion` (D-02); or omit entirely
- File list: remove `Locales\zhCN.lua`; rename `PackLeaderHelper.lua` → `PLBeast.lua`
- Load order: `Locales\enUS.lua` MUST appear before `PLBeast.lua` (anti-pattern guard)

---

### `PLBeast/Locales/enUS.lua` (config, N/A)

**Analog:** `Locales/enUS.lua` (lines 1–57)

**Complete analog** (lines 1–57):
```lua
PackLeaderHelperLocale = {
    ["Pack Leader cooldown timer"] = "Pack Leader cooldown timer",
    -- ... 55 more entries ...
    ["Loaded (CDM-driven real aura tracking). Type /plh to open options."] = "Loaded (CDM-driven real aura tracking). Type /plh to open options.",
}
```

**Structure to copy:**
- Single global table assignment: `PLBeastLocale = { ... }` (rename from `PackLeaderHelperLocale`)
- Key-value pairs where key == value (English locale is self-documenting)
- Hard tab indentation inside the table
- No `local` — must be a global so `PLBeast.lua` can reference it via `PLBeastLocale`

**Phase 1 minimal string set (3 strings only):**
```lua
PLBeastLocale = {
    ["PLBeast loaded. Type /plbeast for options."] = "PLBeast loaded. Type /plbeast for options.",
    ["Cannot open options in combat."] = "Cannot open options in combat.",
    ["debug=%s"] = "debug=%s",
}
```

---

### `PLBeast/PLBeast.lua` (utility + init, event-driven)

**Analog:** `PackLeaderHelper.lua` — four non-overlapping sections extracted below.

#### Section 1: File header — addonName capture + locale metatable + PREFIX
**Source lines 1–8:**
```lua
local addonName = ...

local PREFIX = "|cff33ff99[PackLeaderHelper]|r "
local L = setmetatable(PackLeaderHelperLocale or {}, {
	__index = function(_, key)
		return key
	end,
})
```

**Adaptations:**
- `[PackLeaderHelper]` → `[PLBeast]` in PREFIX string
- `PackLeaderHelperLocale` → `PLBeastLocale`

**Critical note:** The `or {}` guard on `PLBeastLocale` is a safety net — if the locale file is listed after `PLBeast.lua` in the TOC, `PLBeastLocale` is nil here and all strings silently fall through to the key. TOC load order (locale first) is the correct fix; the `or {}` is just defensive.

#### Section 2: SavedVariables global + local alias + defaults table
**Source lines 36–54:**
```lua
-- SavedVariables
PackLeaderHelperDB = PackLeaderHelperDB or {}
local DB = PackLeaderHelperDB

local defaults = {
	offsetX = 0,
	offsetY = -120,
	scale = 1.0,
	hideNext = false,
	-- ... (14 keys total in PLH)
	nextIndex = 1, -- 1=wyvern,2=boar,3=bear (which animal will be generated next)
	debug = false,
}
```

**Adaptations for Phase 1 (D-05, D-06):**
- `PackLeaderHelperDB` → `PLBeastDB`
- `local DB = PLBeastDB` — initial alias before ADDON_LOADED; reassigned after merge in handler
- Minimal defaults table: only `debug = false` and `nextIndex = 1`

**Important:** The initial `PLBeastDB = PLBeastDB or {}` / `local DB = PLBeastDB` at file top is a pre-load alias. The real merge and re-alias happens inside ADDON_LOADED. `dprint` uses `if DB and DB.debug` so nil-checking DB is safe before the handler fires.

#### Section 3: Print + dprint helpers
**Source lines 114–122:**
```lua
local function Print(msg)
	print(PREFIX .. tostring(msg))
end

local function dprint(...)
	if DB and DB.debug then
		Print(table.concat({ ... }, " "))
	end
end
```

**Copy verbatim** — no renames needed (PREFIX is already adapted in Section 1; DB is the local alias).

#### Section 4: Event frame + ADDON_LOADED + PLAYER_LOGIN + slash registration
**Source lines 2479–2481 (slash registration pattern):**
```lua
local function InitSlash()
	SLASH_PACKLEADERHELPER1 = "/plh"
	SlashCmdList["PACKLEADERHELPER"] = function(msg)
		msg = (msg or ""):lower():match("^%s*(.-)%s*$")
		-- ... route to handlers ...
	end
end
```

**Source lines 2554–2607 (event frame + OnEvent handler):**
```lua
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
-- (PLH also registers 12 more events here — PLBeast Phase 1 registers ONLY these two)

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= addonName then return end
		PackLeaderHelperDB = CopyDefaults(defaults, PackLeaderHelperDB or {})
		DB = PackLeaderHelperDB
		EnsureLayoutConfig()
		NormalizeNextIndex()
		-- ...

	elseif event == "PLAYER_LOGIN" then
		InitSlash()
		CreateUI()
		-- ... many calls ...
		Print(L["Loaded (CDM-driven real aura tracking). Type /plh to open options."])
		eventFrame:SetScript("OnUpdate", function(_, elapsed)
			TickUpdate(elapsed)
		end)
	end
end)
```

**Adaptations for Phase 1 (D-03, D-04, D-06, D-07):**

ADDON_LOADED handler:
- Replace `CopyDefaults(defaults, PackLeaderHelperDB or {})` with the flat merge loop (D-06):
  ```lua
  PLBeastDB = PLBeastDB or {}
  for k, v in pairs(defaults) do
      if PLBeastDB[k] == nil then PLBeastDB[k] = v end
  end
  DB = PLBeastDB
  ```
- Add dprint for DB verification after `DB = PLBeastDB` (D-07)
- Remove `EnsureLayoutConfig()`, `NormalizeNextIndex()`, `SetNextBeastId()`, `ResetAuraState()` — those functions don't exist in Phase 1

PLAYER_LOGIN handler:
- Inline the slash command registration directly (no `InitSlash()` helper needed at this scale)
- Slash key: `SLASH_PLBEAST1 = "/plbeast"`, table key: `SlashCmdList["PLBEAST"]`
- Strip all calls after slash registration (`CreateUI`, `BuildCDMCache`, etc.) — no UI in Phase 1 (D-04)
- Do NOT add `eventFrame:SetScript("OnUpdate", ...)` — D-04 explicitly prohibits OnUpdate in scaffold
- Print loaded confirmation: `Print(L["PLBeast loaded. Type /plbeast for options."])`

**addonName guard — must not be omitted:**
```lua
local name = ...
if name ~= addonName then return end
```
Source: PLH line 2573. ADDON_LOADED fires for every addon that loads; without this guard PLBeast's init runs once per addon.

---

## Shared Patterns

### Locale metatable fallback
**Source:** `PackLeaderHelper.lua` lines 4–7
**Apply to:** `PLBeast/PLBeast.lua` (file header)
```lua
local L = setmetatable(PLBeastLocale or {}, {
	__index = function(_, key)
		return key
	end,
})
```
Ensures `L["any string"]` always returns a non-nil value — the translation if present, otherwise the key itself.

### dprint nil-safety pattern
**Source:** `PackLeaderHelper.lua` lines 118–122
**Apply to:** `PLBeast/PLBeast.lua`
```lua
local function dprint(...)
	if DB and DB.debug then
		Print(table.concat({ ... }, " "))
	end
end
```
`DB` is checked for nil before `DB.debug` — safe to call before ADDON_LOADED fires.

### ADDON_LOADED name guard
**Source:** `PackLeaderHelper.lua` lines 2572–2573
**Apply to:** `PLBeast/PLBeast.lua` ADDON_LOADED branch
```lua
local name = ...
if name ~= addonName then return end
```
Without this, the handler runs once per loaded addon, not once for PLBeast.

### Hard tab indentation
**Source:** All PLH Lua files
**Apply to:** All new Lua files
Use hard tabs (`\t`), not spaces. PLH has no formatter config; convention is enforced by reading existing code.

---

## No Analog Found

None — all three Phase 1 files have exact analogs in the PLH source.

---

## Metadata

**Analog search scope:** Repo root — `PackLeaderHelper.toc`, `PackLeaderHelper.lua`, `Locales/enUS.lua`
**Files scanned:** 3 (all files in the repo that contain extractable patterns)
**Pattern extraction date:** 2026-06-18
