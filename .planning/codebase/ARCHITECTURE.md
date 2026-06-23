<!-- refreshed: 2026-06-18 -->
# Architecture

**Analysis Date:** 2026-06-18

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    WoW Addon Entry Points                    │
│   ADDON_LOADED / PLAYER_LOGIN / slash /plh                  │
│   `PackLeaderHelper.lua` (event handler, line 2570)         │
└──────────────────┬──────────────────┬───────────────────────┘
                   │                  │
         ┌─────────▼──────┐  ┌────────▼────────┐
         │  State Machine │  │   UI Layer       │
         │  (CDM polling, │  │  (frames, icons, │
         │  aura tracker) │  │   options panel) │
         │  lines 1494+   │  │  lines 309+      │
         └────────┬───────┘  └────────┬─────────┘
                  │                   │
                  └─────────┬─────────┘
                            │
         ┌──────────────────▼──────────────────┐
         │         OnUpdate Tick Loop           │
         │   TickUpdate() @ 0.05s intervals     │
         │   `PackLeaderHelper.lua:2418`         │
         └──────────────────┬──────────────────┘
                            │
         ┌──────────────────▼──────────────────┐
         │       Blizzard CDM Integration       │
         │   C_CooldownViewer / C_UnitAuras     │
         │   CDMGroups_Buffs frame tree scan    │
         └──────────────────┬──────────────────┘
                            │
         ┌──────────────────▼──────────────────┐
         │         SavedVariables (DB)          │
         │   PackLeaderHelperDB (persisted)     │
         │   `PackLeaderHelper.lua:36`          │
         └─────────────────────────────────────┘
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

**Overall:** Single-file event-driven WoW addon using a polling update loop

**Key Characteristics:**
- All code lives in one Lua file (`PackLeaderHelper.lua`, 2675 lines); no module boundaries
- Blizzard CDM (Cooldown Manager) is the primary aura source; `C_UnitAuras` is a fallback
- State is held in module-level locals; only position/layout/settings are persisted to SavedVariables
- UI frames are created lazily (options panel on first open) or eagerly (tracker icons on login)
- Combat lockdown: options panel is blocked during combat with a pending-open queue

## Layers

**Event / Bootstrap Layer:**
- Purpose: Initialize DB, build CDM cache, create UI, wire slash commands
- Location: `PackLeaderHelper.lua:2554–2673`
- Contains: `eventFrame`, `OnEvent` handler, `InitSlash`, `PLAYER_LOGIN` bootstrap
- Depends on: All other layers
- Used by: WoW client

**State Machine Layer:**
- Purpose: Maintain authoritative in-memory state for howl CD, beast ready buffs, Wyvern buff, Hogstrider
- Location: `PackLeaderHelper.lua:1494–2136`
- Contains: `PollCDMState`, `BuildCooldownSnapshot`, `BuildReadySnapshot`, `BuildHogstriderSnapshot`, `StartWyvernBuff`, `ExtendWyvernBuff`, `SyncNextFromAddedReady`, `ResetAuraState`
- Depends on: CDM cache, Blizzard APIs (`C_UnitAuras`, `C_CooldownViewer`)
- Used by: TickUpdate, combat events, spell cast events

**CDM Integration Layer:**
- Purpose: Build and maintain a spellID-keyed cache of CDM frame references and cooldown IDs
- Location: `PackLeaderHelper.lua:1805–1949`
- Contains: `BuildCDMCache`, `GatherCooldownsFromFrameTree`, `GatherCooldownsFromViewerCategories`, `RegisterDiscoveredCooldown`, `FindCDMFrameByCooldownID`, `ApplyBlizzardCooldownManagerVisibility`
- Depends on: `_G["CDMGroups_Buffs"]`, `C_CooldownViewer`
- Used by: State machine layer, event handler

**UI Refresh Layer:**
- Purpose: Push current state values onto icon frames (cooldown swipes, desaturation, glow)
- Location: `PackLeaderHelper.lua:2142–2456`
- Contains: `UpdateTimerIcon`, `UpdateReadyIcons`, `UpdateWyvernBuffIcon`, `UpdateWyvernExtendIcon`, `UpdateHogstriderIcon`, `UpdateNextBar`, `ShowTestState`
- Depends on: State machine layer, icon frame table `icons`
- Used by: TickUpdate

**UI Construction Layer:**
- Purpose: Create and position all WoW frames; never reads game state
- Location: `PackLeaderHelper.lua:309–1488`
- Contains: `CreateIcon`, `CreateNextBar`, `CreateUI`, `ToggleOptions`, `CreateSlider`, `CreateCheckbox`, `CreateLayoutEditorIcon`, layout editor drag-and-drop
- Depends on: WoW Frame API, layout engine
- Used by: Event handler (one-time on PLAYER_LOGIN / first options open)

**Layout Engine:**
- Purpose: Model the grid (cols × rows) and unused-icon list; normalize, serialize, restore
- Location: `PackLeaderHelper.lua:178–307`
- Contains: `CreateDefaultLayout`, `NormalizeLayout`, `EnsureLayoutConfig`, `CountGridIcons`, `GetGridSlotForIcon`, `PlaceIconInGrid`, `MoveIconToUnused`
- Depends on: `DB` SavedVariables table
- Used by: UI construction, options panel, RefreshTrackerLayout

**Localization Layer:**
- Purpose: Provide locale-keyed strings via the `L` metatable
- Location: `PackLeaderHelper.lua:4–8`, `Locales/enUS.lua`, `Locales/zhCN.lua`
- Contains: `PackLeaderHelperLocale` table; fallback is the key itself
- Depends on: Nothing
- Used by: All user-visible strings

## Data Flow

### Primary Tick Path (every ~0.05 s)

1. `TickUpdate(elapsed)` accumulates time (`PackLeaderHelper.lua:2418`)
2. `PollCDMState()` — reads CDM frame cache + `C_UnitAuras`, updates module-level state variables (`PackLeaderHelper.lua:2068`)
3. `UpdateTimerIcon(now)` — applies howl-CD state to `icons.timer` (`PackLeaderHelper.lua:2142`)
4. `UpdateReadyIcons()` — applies per-beast ready state to `icons.wyvern/boar/bear` (`PackLeaderHelper.lua:2170`)
5. `UpdateWyvernBuffIcon()` — applies wyvern buff state to `icons.wyvernBuff` (`PackLeaderHelper.lua:2208`)
6. `UpdateWyvernExtendIcon()` — shows/hides extend reminder for SV (`PackLeaderHelper.lua:2238`)
7. `UpdateHogstriderIcon()` — applies hogstrider aura state (`PackLeaderHelper.lua:2264`)
8. `UpdateNextBar()` — shows/hides root frame + NEXT label (`PackLeaderHelper.lua:2290`)

### Wyvern Buff Tracking

1. `UNIT_SPELLCAST_SUCCEEDED` fires for Kill Command (BM or SV) when `readyActiveById.wyvern` is true
2. `StartWyvernBuff(now)` records `wyvernBuffStartAt`, `wyvernBuffEndsAt` from `wyvernBuffBaseDuration` (`PackLeaderHelper.lua:1728`)
3. Each Wildfire Bomb (SV) or subsequent Kill Command (BM) calls `ExtendWyvernBuff()` with spec-appropriate amount and max-extends cap (`PackLeaderHelper.lua:1735`)
4. `UpdateWyvernBuffIcon()` recomputes time-left every tick and clears the buff when `wyvernBuffEndsAt` is past

### CDM Cache Build

1. On `PLAYER_LOGIN` and `COOLDOWN_VIEWER_DATA_LOADED`: `BuildCDMCache()` called (`PackLeaderHelper.lua:1936`)
2. Scans `_G["CDMGroups_Buffs"]` frame tree (BFS, max depth 4) + queries `C_CooldownViewer.GetCooldownViewerCategorySet` for all category indexes
3. For each discovered cooldownID whose spellID is in `TRACKED_SPELL_IDS`, stores `{ cooldownID, cdmFrame }` keyed by spellID in `cdmCache`
4. `EnsureCacheFramesResolved()` lazily re-resolves `cdmFrame` references that were nil at build time

**State Management:**
- All runtime tracking (CD timers, ready states, Wyvern buff) lives in module-level locals; not persisted
- `PackLeaderHelperDB` (aliased as `DB`) persists: position, scale, layout, hide-flags, nextIndex
- `EnsureLayoutConfig()` migrates legacy `hideBlizzardCooldownManager` flag on load

## Key Abstractions

**`icons` table:**
- Purpose: Holds the 7 tracker icon frames keyed by string ID
- Examples: `icons.timer`, `icons.wyvern`, `icons.boar`, `icons.bear`, `icons.wyvernBuff`, `icons.wyvernExtend`, `icons.hogstrider`
- Pattern: Each frame has `.tex`, `.cd`, `.text`, `.glow`, `.hover` sub-objects; created by `CreateIcon()`

**`cdmCache` table:**
- Purpose: Maps WoW spellID → `{ cooldownID, cdmFrame }` for tracked Pack Leader spells
- Pattern: Built once at login; lazily refreshed; keyed by integer spellID constants defined at file top

**`DB` (SavedVariables alias):**
- Purpose: All persisted player preferences
- Pattern: Module-level `local DB = PackLeaderHelperDB`; defaults applied via `CopyDefaults` on ADDON_LOADED

**Layout model (`DB.layout`):**
- Purpose: Describes which icons are in which grid cells and which are unused
- Pattern: `{ version, cols, rows, gridSlots = { iconId = { col, row } }, unusedOrder = [...] }`; always normalized through `NormalizeLayout()`

## Entry Points

**ADDON_LOADED:**
- Location: `PackLeaderHelper.lua:2571`
- Triggers: WoW client after addon files are parsed
- Responsibilities: Copy defaults into DB, normalize layout/nextIndex, reset aura state

**PLAYER_LOGIN:**
- Location: `PackLeaderHelper.lua:2581`
- Triggers: After character enters world
- Responsibilities: Register slash commands, create all UI frames, build CDM cache, start OnUpdate tick loop

**Slash command `/plh`:**
- Location: `PackLeaderHelper.lua:2480`
- Triggers: Player types command
- Responsibilities: Route to options toggle, state reset, UI reset, layout reset, debug toggle, test mode

**`TickUpdate` (OnUpdate):**
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

**What happens:** All aura/buff tracking variables (`hasCdBuff`, `wyvernBuffActive`, `readyActiveById`, etc.) are module-level locals mutated directly by `PollCDMState` and event handlers.
**Why it's wrong:** State is scattered across ~50 module-level locals; no single "state object" makes it hard to snapshot, diff, or unit-test.
**Do this instead:** Group runtime state into a single local table (e.g., `local state = {}`) and pass or return it explicitly in `PollCDMState`.

### Options panel built entirely inside `ToggleOptions`

**What happens:** The entire 400-line options panel construction is inline in `ToggleOptions` behind a `if not optionsFrame then ... end` guard (`PackLeaderHelper.lua:1031`).
**Why it's wrong:** The function is responsible for both construction and show/hide toggling; difficult to read or extend.
**Do this instead:** Extract a `CreateOptionsFrame()` function called once; `ToggleOptions` only shows/hides.

## Error Handling

**Strategy:** Defensive `pcall` wrapping for all Blizzard API calls that may fail in restricted contexts (e.g., `GetAuraTimingByInstanceID` at `PackLeaderHelper.lua:1771`). Nil-guards on all frame and API references before use.

**Patterns:**
- `pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, ...)` with graceful nil return on failure
- Nil checks on `icons.*`, `root`, `optionsFrame` before every access
- `if not cdmCacheBuilt then return end` guards CDM-dependent code paths

## Cross-Cutting Concerns

**Logging:** `Print(msg)` prefixes with `|cff33ff99[PackLeaderHelper]|r ` and prints to chat. `dprint(...)` only fires when `DB.debug == true`. Defined at `PackLeaderHelper.lua:114`.
**Validation:** `NormalizeLayout()` enforces valid col/row ranges and deduplicates grid slots on every load and save. `CopyDefaults()` ensures all DB keys have values.
**Authentication:** Not applicable (WoW addon; no auth).

---

*Architecture analysis: 2026-06-18*
