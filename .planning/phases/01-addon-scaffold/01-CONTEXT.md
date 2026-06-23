# Phase 1: Addon Scaffold - Context

**Gathered:** 2026-06-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Create a loadable PLBeast addon skeleton: TOC file, SavedVariablesPerCharacter round-trip, two-phase init (ADDON_LOADED → PLAYER_LOGIN), enUS locale stub, and Print/dprint debug helpers. Code extracted/adapted from PackLeaderHelper's patterns but kept minimal — no tracking logic, no spell constants, no UI.

</domain>

<decisions>
## Implementation Decisions

### Extraction Depth
- **D-01:** Minimal skeleton only — TOC + init event frame + DB defaults merge + locale table. No spell ID constants, no NEXT_BEAST rotation table, no tracking function stubs. Phase 2 introduces all tracking data.
- **D-02:** No Media/ directory in scaffold. TOC IconTexture uses a WoW built-in icon. Phase 4 adds custom assets if needed.

### Init Flow
- **D-03:** ADDON_LOADED: merge defaults into PLBeastDB, set local DB ref, dprint DB contents for verification.
- **D-04:** PLAYER_LOGIN: register `/plbeast` slash command, print a loaded confirmation message. No pre-wired event stubs or OnUpdate frame — later phases add their own.

### SavedVariables Schema
- **D-05:** Minimal defaults — Phase 1: `debug = false`, `nextIndex = 1`. Later phases extend the defaults table with their keys (Phase 4 adds position/size, Phase 5 adds UI settings).
- **D-06:** Simple flat merge for DB defaults (3-line `for k,v in pairs` loop), not PLH's recursive CopyDefaults. PLBeast's DB is flat key-value.
- **D-07:** dprint DB contents on ADDON_LOADED for easy SavedVariables round-trip verification during testing.

### Interface Version
- **D-08:** Target Midnight (12.x), NOT The War Within (11.x). Current expansion is Midnight, current patch is 12.0.7.
- **D-09:** Broad Interface range in TOC: `120000, 120005, 120007` — covers Midnight launch through current patch.
- **D-10:** ROADMAP reference to "The War Within (11.x)" is outdated and should be corrected to "Midnight (12.x)".

### Claude's Discretion
- Init flow structure (D-03, D-04): Claude chose PLH's two-phase pattern with no pre-wired stubs
- Logging (included Print/dprint): Claude chose to include for scaffold verification
- Media/ (skipped): Claude chose to skip, beast textures are WoW built-in spell icons
- DB merge approach (D-06): Claude chose flat merge over recursive
- DB verification (D-07): Claude chose to include dprint on load

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Definition
- `.planning/PROJECT.md` — Core value, constraints, key decisions, extraction context
- `.planning/REQUIREMENTS.md` — Full v1 requirements; Phase 1 maps to STRUCT-01 through STRUCT-05
- `.planning/ROADMAP.md` — Phase goals and success criteria (note: Interface version description needs updating per D-10)

### Source Addon (extraction reference)
- `PackLeaderHelper.toc` — TOC structure to adapt: metadata fields, Interface version declaration, SavedVariables, file load order
- `PackLeaderHelper.lua` lines 1–8 — Addon name capture and locale metatable setup
- `PackLeaderHelper.lua` lines 39–54 — Defaults table and CopyDefaults pattern (adapt to flat merge)
- `PackLeaderHelper.lua` lines 2554–2590 — Event frame creation, ADDON_LOADED/PLAYER_LOGIN init pattern
- `PackLeaderHelper.lua` lines 2479–2530 — Slash command registration pattern
- `Locales/enUS.lua` — Locale table structure to replicate for PLBeast

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PackLeaderHelper.toc`: Direct template for PLBeast's TOC — adapt metadata, rename globals, update file references
- `Locales/enUS.lua`: Direct template for PLBeast's locale file — rename `PackLeaderHelperLocale` to `PLBeastLocale`
- Print/dprint pattern (PLH lines ~10–25): Copy verbatim, change prefix to `[PLBeast]`

### Established Patterns
- Two-phase init: ADDON_LOADED for DB, PLAYER_LOGIN for UI/commands — PLBeast follows this exactly
- SavedVariables: global declared in TOC, aliased to local `DB`, defaults merged at load time
- Locale metatable with `__index` fallback to key string — keeps L["key"] working even without translations
- Hard tab indentation, PascalCase functions, camelCase variables, UPPER_SNAKE_CASE constants

### Integration Points
- `PLBeast/` folder sits alongside `PackLeaderHelper/` at repo root — completely independent addon
- No inter-addon communication; PLBeast reads WoW APIs directly
- SavedVariables: `PLBeastDB` (per-character) — no overlap with `PackLeaderHelperDB`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following PLH's patterns.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Addon Scaffold*
*Context gathered: 2026-06-18*
