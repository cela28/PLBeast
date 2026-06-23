---
phase: 01-addon-scaffold
plan: "01"
subsystem: addon-scaffold
tags: [toc, lua, savedvariables, localization, init]
dependency_graph:
  requires: []
  provides:
    - PLBeast addon skeleton (TOC, locale, main Lua)
    - Two-phase init pattern
    - SavedVariablesPerCharacter round-trip
    - /plbeast slash command stub
  affects:
    - .planning/ROADMAP.md (D-10 correction)
    - .planning/REQUIREMENTS.md (STRUCT-03 correction)
tech_stack:
  added:
    - WoW Lua 5.1 addon (PLBeast.lua)
    - WoW TOC manifest (PLBeast.toc)
    - Locale global table (Locales/enUS.lua)
  patterns:
    - Two-phase ADDON_LOADED/PLAYER_LOGIN init
    - Flat DB defaults merge (D-06)
    - Locale metatable with __index fallback
    - dprint gated by DB.debug
key_files:
  created:
    - PLBeast/PLBeast.toc
    - PLBeast/Locales/enUS.lua
    - PLBeast/PLBeast.lua
  modified:
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
decisions:
  - "D-02: No Media/ directory; TOC IconTexture uses WoW built-in icon (Interface\\Icons\\Ability_Hunter_AnimalCompanion)"
  - "D-06: Flat merge loop (for k,v in pairs) instead of recursive CopyDefaults"
  - "D-08/D-09: Interface 120000, 120005, 120007 targets Midnight (12.x), not The War Within (11.x)"
  - "D-10: ROADMAP and REQUIREMENTS corrected from War Within 11.x to Midnight 12.x"
metrics:
  duration_seconds: 96
  completed_date: "2026-06-18"
  tasks_completed: 1
  tasks_total: 2
  files_created: 3
  files_modified: 2
---

# Phase 01 Plan 01: Addon Scaffold Summary

## One-Liner

PLBeast WoW addon skeleton with TOC (Interface 120000-120007, SavedVariablesPerCharacter), three-string enUS locale, and two-phase init with flat DB merge and /plbeast slash stub.

## What Was Built

Created the complete PLBeast addon directory (`PLBeast/`) with three files extracted and adapted from PackLeaderHelper per STRUCT-02:

1. **PLBeast/PLBeast.toc** — Addon manifest declaring `Interface: 120000, 120005, 120007` (Midnight 12.x per D-08/D-09), `SavedVariablesPerCharacter: PLBeastDB` (per STRUCT-04), built-in `IconTexture` (no Media/ folder per D-02), and correct file load order (locale before main Lua).

2. **PLBeast/Locales/enUS.lua** — Global `PLBeastLocale` table with 3 Phase 1 strings: loaded confirmation, combat warning, and debug format string.

3. **PLBeast/PLBeast.lua** — Main file with:
   - `local addonName = ...` capture and `PREFIX` color tag `|cff33ff99[PLBeast]|r`
   - `L` metatable wrapping `PLBeastLocale or {}` with `__index` key-fallback
   - `PLBeastDB = PLBeastDB or {}` global init and `local DB` alias
   - `defaults` table with exactly `debug = false` and `nextIndex = 1` (D-05)
   - `Print` and `dprint` helpers (D-07 verification gated by `DB.debug`)
   - `eventFrame` registering `ADDON_LOADED` and `PLAYER_LOGIN` only
   - ADDON_LOADED: name guard, flat merge loop (D-06), DB reassignment, dprint verification
   - PLAYER_LOGIN: `SLASH_PLBEAST1`/`SlashCmdList["PLBEAST"]` registration, loaded confirmation print
   - No OnUpdate, no spell constants, no tracking stubs (D-01, D-04)

Also corrected ROADMAP.md success criterion #3 and REQUIREMENTS.md STRUCT-03 from "The War Within (11.x)" to "Midnight (12.x)" per D-10.

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create PLBeast addon skeleton and correct ROADMAP | a21d80a | PLBeast/PLBeast.toc, PLBeast/Locales/enUS.lua, PLBeast/PLBeast.lua, .planning/ROADMAP.md, .planning/REQUIREMENTS.md |

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

- `SlashCmdList["PLBEAST"]` handler always prints the loaded confirmation message regardless of sub-command input. This is intentional for Phase 1; sub-command routing (reset, debug, options open) is deferred to Phase 5.

## Threat Surface Scan

No new security-relevant surface introduced beyond what is documented in the plan's threat model (T-01-01 through T-01-05). All three globals are required: `PLBeastDB` (SavedVariables), `PLBeastLocale` (locale file), `SLASH_PLBEAST1` (WoW slash system). The `setmetatable(PLBeastLocale or {}, ...)` guard (T-01-02) and slash input trim/lowercase (T-01-04) are implemented as specified.

## Deferred Human Verification (Task 2)

Task 2 is a `checkpoint:human-verify` gate requiring in-game validation. Deferred on 2026-06-18 — user does not currently have WoW access. Will be verified when WoW access is available.

## Self-Check: PASSED

- [x] PLBeast/PLBeast.toc exists
- [x] PLBeast/Locales/enUS.lua exists
- [x] PLBeast/PLBeast.lua exists
- [x] Commit a21d80a exists
- [x] No PackLeaderHelper identifiers in PLBeast/ files
- [x] ROADMAP.md corrected
- [x] REQUIREMENTS.md STRUCT-03 corrected
