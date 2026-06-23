# Technology Stack

**Analysis Date:** 2026-06-18

## Languages

**Primary:**
- Lua 5.1 (World of Warcraft embedded Lua) - All addon logic in `PackLeaderHelper.lua`

**Secondary:**
- Lua 5.1 - Locale files in `Locales/enUS.lua` and `Locales/zhCN.lua`

## Runtime

**Environment:**
- World of Warcraft client (retail), running the WoW Lua sandbox (Lua 5.1 subset)
- Interface version targets: 120000, 120001, 120005 (The War Within / version 12.0.x)
- No Node.js, Python, or other external runtimes

**Package Manager:**
- None — WoW addons have no external package manager
- Lockfile: Not applicable

## Frameworks

**Core:**
- WoW Addon Framework (built-in) — event registration via `CreateFrame`, `RegisterEvent`, `SetScript`
- No Ace3, LibStub, or any third-party addon library is used

**UI Widgets:**
- WoW native frame templates: `BasicFrameTemplateWithInset`, `CooldownFrameTemplate`, `OptionsSliderTemplate`, `InputBoxTemplate`, `UICheckButtonTemplate`, `UIPanelButtonTemplate`, `BackdropTemplate`

**Testing:**
- No test framework — manual in-game testing via `/plh test` command which enables a 10-second forced display mode

**Build/Dev:**
- No build step — `.lua` and `.toc` files are loaded directly by the WoW client
- TOC file `PackLeaderHelper.toc` specifies load order and metadata

## Key Dependencies

**Critical:**
- `C_UnitAuras` (WoW API namespace) — reads player aura/buff states for spell tracking; used in `PackLeaderHelper.lua` at lines ~1753–1799
- `C_CooldownViewer` (WoW API namespace) — reads Blizzard Cooldown Manager data (`GetCooldownViewerCooldownInfo`, `GetCooldownViewerCategorySet`); used at lines ~1879–1939
- `C_Timer.After` (WoW API) — deferred execution for talent refresh, post-combat options, CDM polling; used throughout `PackLeaderHelper.lua`
- `EventRegistry` (WoW API) — callback registration for `CooldownViewerSettings.OnDataChanged`; used at line ~2590

**Infrastructure:**
- `SavedVariables: PackLeaderHelperDB` — persistent per-character settings stored by WoW client, declared in `PackLeaderHelper.toc` line 8

## Configuration

**Environment:**
- No `.env` files or environment variables — WoW addons are self-contained
- User configuration stored in `PackLeaderHelperDB` (SavedVariables) with defaults defined in `PackLeaderHelper.lua` lines 39–54:
  - `offsetX`, `offsetY`, `scale` — tracker position/scale
  - `cellSize`, `cellPadding` — icon grid dimensions
  - `nextIndex` — which beast (wyvern/boar/bear) is predicted next
  - `hideNext`, `hideBlizzardEssentialCooldowns`, `hideBlizzardTrackedBuffs`, `hideBlizzardTrackedBars` — visibility toggles
  - `debug` — debug logging flag
  - `layout` — full icon grid layout persisted as nested table

**Build:**
- `PackLeaderHelper.toc` — addon manifest; controls file load order (locales first, then main file), sets interface version compatibility, declares SavedVariables

## Platform Requirements

**Development:**
- Text editor capable of editing Lua
- WoW retail client (version 12.0.x+) for live testing
- No compiler, transpiler, or build tool needed

**Production:**
- WoW retail client AddOns folder: typically `World of Warcraft/_retail_/Interface/AddOns/PackLeaderHelper/`
- Interface compatibility: 120000, 120001, 120005 (declared in TOC)

---

*Stack analysis: 2026-06-18*
