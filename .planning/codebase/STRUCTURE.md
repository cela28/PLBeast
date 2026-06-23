# Codebase Structure

**Analysis Date:** 2026-06-18

## Directory Layout

```
PackLeaderHelper/             # Addon root — must match folder name for WoW to load it
├── PackLeaderHelper.toc      # Table of Contents — declares WoW interface version, metadata, load order
├── PackLeaderHelper.lua      # Entire addon implementation (2675 lines)
├── Locales/
│   ├── enUS.lua              # English string table (PackLeaderHelperLocale)
│   └── zhCN.lua              # Simplified Chinese string table
└── Media/
    ├── plh.tga               # Addon icon (referenced in .toc as IconTexture)
    ├── PLH.jpg               # Alternate logo asset
    └── cdm.png               # Usage guide screenshot shown in options panel
```

## Directory Purposes

**Root (`PackLeaderHelper/`):**
- Purpose: WoW addon package root; all files in the TOC load order are relative to this directory
- Contains: `.toc` manifest, primary Lua file
- Key files: `PackLeaderHelper.toc`, `PackLeaderHelper.lua`

**`Locales/`:**
- Purpose: Per-locale string tables; loaded before the main addon file (see TOC load order)
- Contains: One Lua file per locale, each defining `PackLeaderHelperLocale = { ... }`
- Key files: `Locales/enUS.lua` (reference locale), `Locales/zhCN.lua`

**`Media/`:**
- Purpose: Static assets referenced at runtime by texture paths in Lua code
- Contains: `.tga` icon for the addon button, `.png` guide image shown in the options panel
- Key files: `Media/plh.tga` (addon icon), `Media/cdm.png` (usage guide image at `PackLeaderHelper.lua:91`)

## Key File Locations

**Entry Points:**
- `PackLeaderHelper.lua:2554`: `eventFrame` creation and all event registrations
- `PackLeaderHelper.lua:2570`: `OnEvent` dispatch — bootstraps on ADDON_LOADED and PLAYER_LOGIN
- `PackLeaderHelper.lua:2479`: Slash command registration (`/plh`)

**Configuration:**
- `PackLeaderHelper.toc`: Interface version targets (`120000, 120001, 120005`), SavedVariables declaration, file load order
- `PackLeaderHelper.lua:39`: `defaults` table — all default values for `PackLeaderHelperDB`

**Core Logic:**
- `PackLeaderHelper.lua:1494–2136`: CDM state machine — spell constants, snapshot builders, `PollCDMState`
- `PackLeaderHelper.lua:1936`: `BuildCDMCache` — scans Blizzard CDM frame tree
- `PackLeaderHelper.lua:2418`: `TickUpdate` — main 20 Hz update loop
- `PackLeaderHelper.lua:178–307`: Layout engine — grid model, normalize, defaults

**UI Construction:**
- `PackLeaderHelper.lua:352`: `CreateIcon` — builds a single tracker icon frame with cooldown, glow, text sub-objects
- `PackLeaderHelper.lua:502`: `CreateNextBar` — builds the NEXT animal indicator
- `PackLeaderHelper.lua:1422`: `CreateUI` — assembles root frame + all tracker icons at login
- `PackLeaderHelper.lua:1021`: `ToggleOptions` — lazily creates and shows/hides the 780×640 options panel

**UI Refresh:**
- `PackLeaderHelper.lua:2142–2406`: Per-icon update functions called each tick

**Testing:**
- `PackLeaderHelper.lua:2321`: `ShowTestState` — `/plh test` forces all icons active for 10 s

## Naming Conventions

**Files:**
- PascalCase for Lua source and directory names: `PackLeaderHelper.lua`, `Locales/`
- Locale files use WoW locale codes: `enUS.lua`, `zhCN.lua`
- Media files use lower-case short names: `plh.tga`, `cdm.png`

**Functions:**
- PascalCase for all functions: `CreateIcon`, `BuildCDMCache`, `PollCDMState`, `ToggleOptions`
- Private helpers not differentiated by naming from "public" functions (all are module-local)

**Variables:**
- Module-level locals: camelCase (`hasCdBuff`, `cdmCacheBuilt`, `nextBeastId`, `inCombat`)
- Constants: SCREAMING_SNAKE_CASE (`SPELL_HOTPL_PARENT`, `ICON_TIMER`, `LAYOUT_VERSION`)
- Per-beast lookup tables: suffixed with `ById` (`readyActiveById`, `readyLeftById`)
- SavedVariables DB key: `PackLeaderHelperDB` (global, PascalCase matching addon name)

**Beast IDs:**
- String identifiers used as keys throughout: `"wyvern"`, `"boar"`, `"bear"`
- Icon IDs extend this with derived states: `"wyvernBuff"`, `"wyvernExtend"`, `"timer"`, `"hogstrider"`

## Where to Add New Code

**New tracked spell / aura:**
1. Add spell ID constant near `PackLeaderHelper.lua:10` (SCREAMING_SNAKE_CASE)
2. Add to `TRACKED_SPELL_IDS` at `PackLeaderHelper.lua:1516`
3. Add state variables (module-level locals) near existing per-beast variables (~line 1535)
4. Add snapshot builder following the pattern of `BuildHogstriderSnapshot` (line 2045)
5. Call snapshot builder inside `PollCDMState` (line 2068) and store results
6. Add update function following `UpdateHogstriderIcon` pattern (line 2264)
7. Call update function inside `TickUpdate` (line 2418)

**New tracker icon:**
1. Add icon ID string to `TRACKER_ICON_ORDER` array (`PackLeaderHelper.lua:56`)
2. Add file ID entry to `ICON_FILE_BY_ID` (`PackLeaderHelper.lua:57`)
3. Add tooltip/description entries to `ICON_TOOLTIP_BY_ID` and `ICON_DESCRIPTION_BY_ID` (`PackLeaderHelper.lua:66–83`)
4. Add default grid slot to `DEFAULT_LAYOUT_SLOTS` (`PackLeaderHelper.lua:92`)
5. The icon frame is automatically created by `CreateUI` iterating `TRACKER_ICON_ORDER`

**New locale:**
- Create `Locales/<localeCode>.lua` defining `PackLeaderHelperLocale = { ... }` with all keys from `Locales/enUS.lua`
- Add file reference to `PackLeaderHelper.toc` before `PackLeaderHelper.lua`

**New option / setting:**
1. Add default value to `defaults` table (`PackLeaderHelper.lua:39`)
2. Add UI control inside `ToggleOptions` following slider/checkbox patterns (line 1021)
3. Store value into `DB.<key>` in the control's `setValue` callback
4. Apply the setting immediately in the callback and in the appropriate update path

**New slash command:**
- Add `elseif msg == "<cmd>"` branch inside `SlashCmdList["PACKLEADERHELPER"]` (`PackLeaderHelper.lua:2481`)

## Special Directories

**`Locales/`:**
- Purpose: Locale string tables loaded before the main file so `L` is populated at module scope
- Generated: No
- Committed: Yes

**`Media/`:**
- Purpose: Static texture assets embedded in the addon package
- Generated: No
- Committed: Yes

**`.planning/`:**
- Purpose: GSD planning documents (architecture maps, phase plans)
- Generated: Yes (by GSD tooling)
- Committed: Optional (per project convention)

---

*Structure analysis: 2026-06-18*
