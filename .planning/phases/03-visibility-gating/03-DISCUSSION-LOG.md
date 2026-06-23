# Phase 3: Visibility Gating - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-19
**Phase:** 03-visibility-gating
**Areas discussed:** Output representation, Tracking while hidden, Debug when inactive

---

## Output Representation

| Option | Description | Selected |
|--------|-------------|----------|
| Visibility flag only | Phase 3 sets a module-level `isPackLeaderActive` boolean. No frame created. Phase 4 reads the flag. Verifiable via `/plbeast debug`. | ✓ |
| Minimal placeholder frame | Phase 3 creates a small colored square that shows/hides. Phase 4 replaces it with the real icon. Creates throwaway code. | |
| Root frame created early | Phase 3 creates the actual `PLBeastFrame` with proper anchoring but no texture/border yet. Phase 4 adds icon content. | |

**User's choice:** Visibility flag only (Recommended)
**Notes:** Keeps Phase 3 as pure logic — no frame creation until Phase 4.

---

## Tracking While Hidden

| Option | Description | Selected |
|--------|-------------|----------|
| Pause tracking | Unregister UNIT_AURA when Pack Leader isn't active, re-register + re-seed snapshot on activation. Saves CPU. Rotation resumes from saved DB.nextIndex. | ✓ |
| Keep tracking silently | UNIT_AURA stays registered regardless. Prediction stays live even when hidden. Minimal CPU since check is lightweight. | |

**User's choice:** Pause tracking (Recommended)
**Notes:** None.

---

## Debug When Inactive

| Option | Description | Selected |
|--------|-------------|----------|
| Always available | Debug output works regardless of visibility state. Prints spec and talent info when inactive. Useful for troubleshooting. | ✓ |
| Gate debug too | Debug suppressed when Pack Leader isn't active. Cleaner chat but harder to diagnose visibility issues. | |

**User's choice:** Always available (Recommended)
**Notes:** None.

---

## Claude's Discretion

- Talent detection constants selection and placement
- `IsPackLeaderHeroTalent()` function extraction approach
- Talent change event registration strategy (which events, deferral pattern)
- Spec detection function adaptation (extend existing `RefreshHunterSpecState()`)

## Deferred Ideas

None — discussion stayed within phase scope.
