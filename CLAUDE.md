<!-- GSD:project-start source:PROJECT.md -->
## Project

**PLBeast**

PLBeast is a standalone World of Warcraft addon that predicts and displays which beast will spawn next in the Pack Leader hero talent rotation (wyvern → boar → bear → wyvern). It's being extracted from PackLeaderHelper as an independent, minimal addon — just a single draggable/scalable icon showing the next beast.

**Core Value:** Accurately predict and display the next beast in the Pack Leader rotation so the player always knows what's coming.

### Constraints

- **Runtime**: WoW Lua sandbox — no external libraries, no coroutines for async, no file system access
- **Combat lockdown**: Cannot create/move frames during combat; must handle gracefully
- **CDM dependency**: Requires Blizzard Cooldown Manager to be enabled and tracking Pack Leader buff spells
- **Addon size**: Should be minimal — small .toc, one or two .lua files, locale support
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Lua 5.1 (World of Warcraft embedded Lua) - All addon logic in `PackLeaderHelper.lua`
- Lua 5.1 - Locale files in `Locales/enUS.lua` and `Locales/zhCN.lua`
## Runtime
- World of Warcraft client (retail), running the WoW Lua sandbox (Lua 5.1 subset)
- Interface version targets: 120000, 120001, 120005 (The War Within / version 12.0.x)
- No Node.js, Python, or other external runtimes
- None — WoW addons have no external package manager
- Lockfile: Not applicable
## Frameworks
- WoW Addon Framework (built-in) — event registration via `CreateFrame`, `RegisterEvent`, `SetScript`
- No Ace3, LibStub, or any third-party addon library is used
- WoW native frame templates: `BasicFrameTemplateWithInset`, `CooldownFrameTemplate`, `OptionsSliderTemplate`, `InputBoxTemplate`, `UICheckButtonTemplate`, `UIPanelButtonTemplate`, `BackdropTemplate`
- No test framework — manual in-game testing via `/plh test` command which enables a 10-second forced display mode
- No build step — `.lua` and `.toc` files are loaded directly by the WoW client
- TOC file `PackLeaderHelper.toc` specifies load order and metadata
## Key Dependencies
- `C_UnitAuras` (WoW API namespace) — reads player aura/buff states for spell tracking; used in `PackLeaderHelper.lua` at lines ~1753–1799
- `C_CooldownViewer` (WoW API namespace) — reads Blizzard Cooldown Manager data (`GetCooldownViewerCooldownInfo`, `GetCooldownViewerCategorySet`); used at lines ~1879–1939
- `C_Timer.After` (WoW API) — deferred execution for talent refresh, post-combat options, CDM polling; used throughout `PackLeaderHelper.lua`
- `EventRegistry` (WoW API) — callback registration for `CooldownViewerSettings.OnDataChanged`; used at line ~2590
- `SavedVariables: PackLeaderHelperDB` — persistent per-character settings stored by WoW client, declared in `PackLeaderHelper.toc` line 8
## Configuration
- No `.env` files or environment variables — WoW addons are self-contained
- User configuration stored in `PackLeaderHelperDB` (SavedVariables) with defaults defined in `PackLeaderHelper.lua` lines 39–54:
- `PackLeaderHelper.toc` — addon manifest; controls file load order (locales first, then main file), sets interface version compatibility, declares SavedVariables
## Platform Requirements
- Text editor capable of editing Lua
- WoW retail client (version 12.0.x+) for live testing
- No compiler, transpiler, or build tool needed
- WoW retail client AddOns folder: typically `World of Warcraft/_retail_/Interface/AddOns/PackLeaderHelper/`
- Interface compatibility: 120000, 120001, 120005 (declared in TOC)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Language
## Naming Patterns
- PascalCase for primary addon file: `PackLeaderHelper.lua`
- PascalCase directory and locale file names: `Locales/enUS.lua`, `Locales/zhCN.lua`
- PascalCase for all named local functions: `CreateIcon`, `SetCooldown`, `NormalizeLayout`, `RefreshTrackerLayout`, `BuildCDMCache`
- Descriptive verb-first names that clearly state what the function does: `GetGridSlotForIcon`, `FindNearestGridSlot`, `CountReadyActive`
- Short debug/internal utilities are camelCase: `dprint`
- camelCase for local state variables: `inCombat`, `hasCdBuff`, `cdLeft`, `nextBeastId`, `wyvernBuffActive`
- UPPER_SNAKE_CASE for module-level constants: `SPELL_HOTPL_PARENT`, `ICON_TIMER`, `MIN_LAYOUT_COLS`, `LAYOUT_VERSION`
- PascalCase for table/map constants: `TRACKER_ICON_ORDER`, `ICON_FILE_BY_ID`, `READY_SPELL_BY_ID`, `NEXT_BEAST`
- PascalCase prefixed with addon name: `PackLeaderHelperDB`, `PackLeaderHelperLocale`
- Single-letter or short names inside constructors (`f`, `bg`, `tex`, `cd`, `ag`) for widget sub-elements
- Descriptive names for top-level frame references: `root`, `optionsFrame`, `nextBar`, `icons`
## Module Design
- All code is wrapped in file-local scope. `local addonName = ...` captures the addon name from varargs at file load.
- The file-module pattern: declare `local` variables at the top, define functions as `local function`, assign forward-declared functions at the bottom if needed (e.g., `SaveLayoutEditor = function(...)` for mutual recursion).
- Used for mutually recursive functions: `local UpdateNextBar`, `local RefreshLayoutEditor`, `local SaveLayoutEditor` declared before use, assigned later.
## Code Style
- No automated formatter detected (no `.editorconfig`, no Lua formatter config).
- 1-tab indentation (hard tabs).
- 60-character separator comments used for section breaks:
- No linting config detected.
## Import / Dependency Pattern
## Error Handling
- Guard returns at top of every function: `if not f or not f.cd then return end`
- WoW API calls that can throw are wrapped in `pcall`:
- Numeric operations on aura fields use an inner `pcall` to protect against "secret number" values in restricted content:
- Type checks before arithmetic: `if type(left) ~= "number" then return nil end`
- Ternary-style safe fallbacks: `local scale = DB.scale or defaults.scale`
## Logging
- `Print(L["..."])` for user-visible messages (chat output, command feedback).
- `dprint(...)` for debug-only output, gated by `DB.debug` SavedVariable.
- Debug calls include state context: `dprint("spec=" .. ..., "wyvernChoice=" .. ...)`.
## Comments
- Single-line `--` comments explain non-obvious game-mechanic logic inline:
- Multi-word comments on constants clarify spell/buff identity:
- Section separators use 60-dash block comments.
- No JSDoc/LuaDoc annotations present.
## Function Design
- Functions return `nil` (implicit) on early-guard failure.
- Data-fetching functions return multiple values (`left, start, duration`) following WoW API conventions.
- Boolean predicates return `true`/`false` explicitly.
## WoW-Specific Patterns
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## System Overview
```text
```
## Component Responsibilities
| Component | Responsibility | File |
|-----------|----------------|------|
| Event handler | ADDON_LOADED, PLAYER_LOGIN, spell casts, talent changes | `PackLeaderHelper.lua:2554` |
| TickUpdate loop | 20 Hz update pump; drives CDM poll + UI refresh | `PackLeaderHelper.lua:2418` |
| CDM cache | Scans CDMGroups_Buffs frame tree to map spellID → CDM frame | `PackLeaderHelper.lua:1936` |
| State machine | Tracks howl CD, per-beast ready buffs, Wyvern buff, Hogstrider | `PackLeaderHelper.lua:1494` |
| UI layer | Root frame, 7 icon frames, NEXT bar, layout grid rendering | `PackLeaderHelper.lua:309` |
| Options panel | Sliders, checkboxes, drag-and-drop layout editor | `PackLeaderHelper.lua:1021` |
| Layout engine | Grid/unused slot model, normalize, save, render | `PackLeaderHelper.lua:178` |
| Localization | String table loaded at startup from Locales/ | `Locales/enUS.lua`, `Locales/zhCN.lua` |
## Pattern Overview
- All code lives in one Lua file (`PackLeaderHelper.lua`, 2675 lines); no module boundaries
- Blizzard CDM (Cooldown Manager) is the primary aura source; `C_UnitAuras` is a fallback
- State is held in module-level locals; only position/layout/settings are persisted to SavedVariables
- UI frames are created lazily (options panel on first open) or eagerly (tracker icons on login)
- Combat lockdown: options panel is blocked during combat with a pending-open queue
## Layers
- Purpose: Initialize DB, build CDM cache, create UI, wire slash commands
- Location: `PackLeaderHelper.lua:2554–2673`
- Contains: `eventFrame`, `OnEvent` handler, `InitSlash`, `PLAYER_LOGIN` bootstrap
- Depends on: All other layers
- Used by: WoW client
- Purpose: Maintain authoritative in-memory state for howl CD, beast ready buffs, Wyvern buff, Hogstrider
- Location: `PackLeaderHelper.lua:1494–2136`
- Contains: `PollCDMState`, `BuildCooldownSnapshot`, `BuildReadySnapshot`, `BuildHogstriderSnapshot`, `StartWyvernBuff`, `ExtendWyvernBuff`, `SyncNextFromAddedReady`, `ResetAuraState`
- Depends on: CDM cache, Blizzard APIs (`C_UnitAuras`, `C_CooldownViewer`)
- Used by: TickUpdate, combat events, spell cast events
- Purpose: Build and maintain a spellID-keyed cache of CDM frame references and cooldown IDs
- Location: `PackLeaderHelper.lua:1805–1949`
- Contains: `BuildCDMCache`, `GatherCooldownsFromFrameTree`, `GatherCooldownsFromViewerCategories`, `RegisterDiscoveredCooldown`, `FindCDMFrameByCooldownID`, `ApplyBlizzardCooldownManagerVisibility`
- Depends on: `_G["CDMGroups_Buffs"]`, `C_CooldownViewer`
- Used by: State machine layer, event handler
- Purpose: Push current state values onto icon frames (cooldown swipes, desaturation, glow)
- Location: `PackLeaderHelper.lua:2142–2456`
- Contains: `UpdateTimerIcon`, `UpdateReadyIcons`, `UpdateWyvernBuffIcon`, `UpdateWyvernExtendIcon`, `UpdateHogstriderIcon`, `UpdateNextBar`, `ShowTestState`
- Depends on: State machine layer, icon frame table `icons`
- Used by: TickUpdate
- Purpose: Create and position all WoW frames; never reads game state
- Location: `PackLeaderHelper.lua:309–1488`
- Contains: `CreateIcon`, `CreateNextBar`, `CreateUI`, `ToggleOptions`, `CreateSlider`, `CreateCheckbox`, `CreateLayoutEditorIcon`, layout editor drag-and-drop
- Depends on: WoW Frame API, layout engine
- Used by: Event handler (one-time on PLAYER_LOGIN / first options open)
- Purpose: Model the grid (cols × rows) and unused-icon list; normalize, serialize, restore
- Location: `PackLeaderHelper.lua:178–307`
- Contains: `CreateDefaultLayout`, `NormalizeLayout`, `EnsureLayoutConfig`, `CountGridIcons`, `GetGridSlotForIcon`, `PlaceIconInGrid`, `MoveIconToUnused`
- Depends on: `DB` SavedVariables table
- Used by: UI construction, options panel, RefreshTrackerLayout
- Purpose: Provide locale-keyed strings via the `L` metatable
- Location: `PackLeaderHelper.lua:4–8`, `Locales/enUS.lua`, `Locales/zhCN.lua`
- Contains: `PackLeaderHelperLocale` table; fallback is the key itself
- Depends on: Nothing
- Used by: All user-visible strings
## Data Flow
### Primary Tick Path (every ~0.05 s)
### Wyvern Buff Tracking
### CDM Cache Build
- All runtime tracking (CD timers, ready states, Wyvern buff) lives in module-level locals; not persisted
- `PackLeaderHelperDB` (aliased as `DB`) persists: position, scale, layout, hide-flags, nextIndex
- `EnsureLayoutConfig()` migrates legacy `hideBlizzardCooldownManager` flag on load
## Key Abstractions
- Purpose: Holds the 7 tracker icon frames keyed by string ID
- Examples: `icons.timer`, `icons.wyvern`, `icons.boar`, `icons.bear`, `icons.wyvernBuff`, `icons.wyvernExtend`, `icons.hogstrider`
- Pattern: Each frame has `.tex`, `.cd`, `.text`, `.glow`, `.hover` sub-objects; created by `CreateIcon()`
- Purpose: Maps WoW spellID → `{ cooldownID, cdmFrame }` for tracked Pack Leader spells
- Pattern: Built once at login; lazily refreshed; keyed by integer spellID constants defined at file top
- Purpose: All persisted player preferences
- Pattern: Module-level `local DB = PackLeaderHelperDB`; defaults applied via `CopyDefaults` on ADDON_LOADED
- Purpose: Describes which icons are in which grid cells and which are unused
- Pattern: `{ version, cols, rows, gridSlots = { iconId = { col, row } }, unusedOrder = [...] }`; always normalized through `NormalizeLayout()`
## Entry Points
- Location: `PackLeaderHelper.lua:2571`
- Triggers: WoW client after addon files are parsed
- Responsibilities: Copy defaults into DB, normalize layout/nextIndex, reset aura state
- Location: `PackLeaderHelper.lua:2581`
- Triggers: After character enters world
- Responsibilities: Register slash commands, create all UI frames, build CDM cache, start OnUpdate tick loop
- Location: `PackLeaderHelper.lua:2480`
- Triggers: Player types command
- Responsibilities: Route to options toggle, state reset, UI reset, layout reset, debug toggle, test mode
- Location: `PackLeaderHelper.lua:2418`
- Triggers: Every game frame; throttled to 0.05 s
- Responsibilities: Drive CDM polling and all icon UI refresh
## Architectural Constraints
- **Threading:** Single-threaded Lua coroutine model. `C_Timer.After(0, ...)` is used to defer talent refresh out of the current event to avoid reentrancy (`PackLeaderHelper.lua:1632`)
- **Global state:** `PackLeaderHelperDB` (SavedVariables, required global), `PackLeaderHelperLocale` (locale table), `PackLeaderHelperFrame` (named root frame for external reference). All other state is in module-level locals.
- **Circular imports:** Not applicable (single file)
- **Combat lockdown:** Options panel cannot be opened or have layout edits during combat (`InCombatLockdown()` checks at `PackLeaderHelper.lua:905`, `1022`); `pendingOptionsOpenAfterCombat` defers the open to `PLAYER_REGEN_ENABLED`
- **CDM dependency:** The addon requires the Blizzard Cooldown Manager to be enabled and tracking the Pack Leader buff spells; without it the CDM cache is empty and all icons show as inactive
## Anti-Patterns
### Module-level mutable state for runtime tracking
### Options panel built entirely inside `ToggleOptions`
## Error Handling
- `pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, ...)` with graceful nil return on failure
- Nil checks on `icons.*`, `root`, `optionsFrame` before every access
- `if not cdmCacheBuilt then return end` guards CDM-dependent code paths
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
