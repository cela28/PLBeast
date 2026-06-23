# Walking Skeleton -- PLBeast

**Phase:** 1
**Generated:** 2026-06-18

## Capability Proven End-to-End

A hunter player can install the PLBeast addon, load into WoW, type /plbeast, see a confirmation message, and have their PLBeastDB settings persist across logout/login cycles.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Runtime | WoW Lua 5.1 sandbox (retail, Midnight 12.x) | Only runtime available for WoW addons; no alternatives exist |
| Persistence | SavedVariablesPerCharacter (PLBeastDB) | Rotation index is character-specific; per-account would share state across characters incorrectly |
| DB structure | Flat key-value table with simple merge | PLBeast has ~5 config keys total; recursive CopyDefaults is unnecessary overhead |
| Localization | Global locale table + metatable __index fallback | Standard WoW addon pattern; PLBeastLocale or {} guard prevents nil if locale file missing |
| Init pattern | Two-phase: ADDON_LOADED (DB merge) then PLAYER_LOGIN (slash command, UI) | PLH-proven pattern; ADDON_LOADED fires before world is ready, PLAYER_LOGIN fires when all APIs are safe |
| Directory layout | PLBeast/ at repo root with PLBeast.toc, PLBeast.lua, Locales/enUS.lua | Standard WoW addon packaging; mirrors PackLeaderHelper structure |
| Interface version | 120000, 120005, 120007 (Midnight 12.x) | Current expansion; broad range covers launch through current patch |
| Code origin | Extracted/adapted from PackLeaderHelper (STRUCT-02) | PLH is the proven reference implementation; mechanical rename, not rewrite |
| Debug output | Print (user-visible) and dprint (debug-gated) helpers | dprint gated by DB.debug for verification; no external logging possible in WoW sandbox |

## Stack Touched in Phase 1

- [x] Project scaffold (PLBeast/ directory, TOC manifest, file load order)
- [x] Event handling -- ADDON_LOADED and PLAYER_LOGIN wired via CreateFrame + SetScript
- [x] Persistence -- SavedVariablesPerCharacter round-trip (write on logout, read on login)
- [x] User interaction -- /plbeast slash command responds with confirmation
- [x] Localization -- enUS locale file loaded and referenced via metatable

## Out of Scope (Deferred to Later Slices)

- Rotation tracking logic (Phase 2: aura reading, snapshot-diff, cyclic advancement)
- Spec/talent detection and visibility gating (Phase 3)
- Icon UI frame, textures, dragging, scaling (Phase 4)
- Options panel with sliders and toggles (Phase 5)
- GitHub Actions release pipeline (Phase 6)
- Spell ID constants and NEXT_BEAST rotation table (Phase 2)
- OnUpdate tick loop (Phase 2)
- Media/ directory and custom icon assets (Phase 4 if needed)
- zhCN localization (v2)
- /plbeast debug, test, reset sub-commands (v2)
- Blizzard Settings panel integration (v2)

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: Rotation tracking -- aura reading via C_UnitAuras, snapshot-diff state machine, cyclic beast advancement persisted via nextIndex
- Phase 3: Visibility gating -- Pack Leader talent detection, spec filter, show/hide based on active hero talent
- Phase 4: Icon UI -- draggable/scalable icon frame displaying next-beast texture with configurable border
- Phase 5: Configuration -- /plbeast opens options frame with sliders, toggles, and color picker
- Phase 6: Release pipeline -- GitHub Actions workflow for tag-triggered release zip packaging
