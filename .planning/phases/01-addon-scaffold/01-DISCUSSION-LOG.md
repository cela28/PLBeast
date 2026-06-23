# Phase 1: Addon Scaffold - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-18
**Phase:** 1-Addon Scaffold
**Areas discussed:** Extraction depth, SavedVariables schema, Interface version

---

## Extraction Depth

### Q1: How much of PackLeaderHelper's code should the scaffold include?

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal skeleton | Just TOC + init event frame + CopyDefaults + empty locale table | ✓ |
| Forward-port constants | Include spell ID constants, NEXT_BEAST table, and beast ID strings now | |
| You decide | Let Claude pick | |

**User's choice:** Minimal skeleton
**Notes:** Phase 2 adds spell constants and tracking logic from scratch.

### Q2: Two-phase init — should PLAYER_LOGIN do anything beyond confirming?

| Option | Description | Selected |
|--------|-------------|----------|
| DB only in ADDON_LOADED | ADDON_LOADED: merge defaults. PLAYER_LOGIN: print loaded message, nothing else. | |
| Stub hooks for later | Create empty event frame with OnUpdate (disabled), register PLAYER_SPECIALIZATION_CHANGED. | |
| You decide | Let Claude pick based on PLH's init pattern. | ✓ |

**User's choice:** You decide
**Notes:** Claude chose PLH's pattern — DB in ADDON_LOADED, slash cmd + confirmation in PLAYER_LOGIN, no pre-wired stubs.

### Q3: Include Print/dprint debug helper in scaffold?

| Option | Description | Selected |
|--------|-------------|----------|
| Include now | Print() with [PLBeast] prefix + dprint() gated by DB.debug | |
| Defer to Phase 2 | No logging until tracking logic needs it | |
| You decide | Let Claude pick | ✓ |

**User's choice:** You decide
**Notes:** Claude chose to include — useful for scaffold load verification.

### Q4: Include Media/ directory with placeholder icon?

| Option | Description | Selected |
|--------|-------------|----------|
| Include placeholder | Media/ with simple .tga for TOC IconTexture | |
| Skip Media/ | No Media/ yet; TOC uses WoW built-in icon | |
| You decide | Let Claude pick | ✓ |

**User's choice:** You decide
**Notes:** Claude chose to skip — beast textures are WoW built-in spell icons, not custom assets.

---

## SavedVariables Schema

### Q1: Full schema up front or minimal + extend?

| Option | Description | Selected |
|--------|-------------|----------|
| Full schema up front | All eventual keys (nextIndex, offsetX, offsetY, width, height, etc.) defined now | |
| Minimal + extend | Phase 1: debug + nextIndex only. Each phase adds its keys. | |
| You decide | Let Claude pick | ✓ |

**User's choice:** You decide
**Notes:** Claude chose minimal + extend — consistent with minimal skeleton choice. CopyDefaults handles missing keys.

### Q2: Recursive CopyDefaults or simple flat merge?

| Option | Description | Selected |
|--------|-------------|----------|
| Copy PLH's recursive | Bring over CopyDefaults verbatim; handles nested tables | |
| Simple flat merge | 3-line loop for flat key-value DB | |
| You decide | Let Claude pick | ✓ |

**User's choice:** You decide
**Notes:** Claude chose flat merge — PLBeast's DB has no nested tables.

### Q3: Debug print DB on load for verification?

| Option | Description | Selected |
|--------|-------------|----------|
| Debug print on load | dprint PLBeastDB contents at ADDON_LOADED | |
| Trust it works | No verification; manual SV file inspection | |
| You decide | Let Claude pick | ✓ |

**User's choice:** You decide
**Notes:** Claude chose to include — leverages dprint already in scaffold.

---

## Interface Version

### Q1: Which WoW version should PLBeast target?

| Option | Description | Selected |
|--------|-------------|----------|
| Match PLH (12.0.x) | 120000, 120001, 120005 | |
| 11.0.x only | TWW base Interface versions | |
| Both 11.x and 12.x | Broad compatibility | |

**User's choice:** Free text — "11 is TWW which is the last expansion. We are in midnight which is 12. Current patch is 12.0.7"
**Notes:** Clarified that TWW (11.x) was the previous expansion. Current expansion is Midnight (12.x), patch 12.0.7. ROADMAP description needs correcting.

### Q2: Interface version range for Midnight?

| Option | Description | Selected |
|--------|-------------|----------|
| Match PLH exactly | 120000, 120001, 120005 | |
| Current patch only | 120007 | |
| Broad 12.x range | 120000, 120005, 120007 | ✓ |

**User's choice:** Broad 12.x range
**Notes:** Covers Midnight launch through current patch 12.0.7.

---

## Claude's Discretion

- Init flow structure: DB in ADDON_LOADED, slash cmd in PLAYER_LOGIN, no stubs
- Logging: Include Print/dprint from the start
- Media/: Skip, use WoW built-in icon
- DB merge: Simple flat merge over recursive
- DB verification: Include dprint on load
- DB schema: Minimal + extend approach

## Deferred Ideas

None — discussion stayed within phase scope.
