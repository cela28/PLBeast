# Phase 2: Rotation Tracking - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-18
**Phase:** 2-Rotation Tracking
**Areas discussed:** Detection mechanism, Extraction fidelity, Debug output design

---

## Detection Mechanism

### How should PLBeast detect beast ready-buff changes?

| Option | Description | Selected |
|--------|-------------|----------|
| Event-driven | Register UNIT_AURA event, check C_UnitAuras.GetPlayerAuraBySpellID only when auras change. No OnUpdate loop needed. | ✓ |
| Polling (PLH-style) | OnUpdate tick loop at ~20Hz, poll C_UnitAuras every 0.05s. Proven pattern from PLH. | |
| Hybrid | UNIT_AURA events as primary trigger, with slow fallback poll as safety net. | |
| You decide | Let Claude pick the best approach. | |

**User's choice:** Event-driven
**Notes:** None

### Initial aura scan on login?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, initial scan on login | PLAYER_LOGIN triggers one full aura check to seed the snapshot. | ✓ |
| No, UNIT_AURA only | Wait for the first UNIT_AURA event. Simpler but snapshot starts empty. | |

**User's choice:** Follow PackLeaderHelper's logic (maps to "Yes, initial scan on login")
**Notes:** User directed to follow PLH's established patterns rather than diverge.

---

## Extraction Fidelity

### How closely should PLBeast's rotation tracking mirror PLH's implementation?

| Option | Description | Selected |
|--------|-------------|----------|
| Faithful extract & trim | Copy PLH's core functions and strip irrelevant parts. Keep edge-case handling. | ✓ |
| Simplified rewrite | Same algorithm rewritten cleaner, single-beast advance only. | |
| You decide | Let Claude judge which parts to keep vs simplify. | |

**User's choice:** Asked "What do you think?" — Claude recommended faithful extract & trim because multi-beast sorting handles real burst-window edge cases.
**Notes:** User accepted Claude's recommendation.

### Spell constants scope

| Option | Description | Selected |
|--------|-------------|----------|
| Only ready-buff IDs now | Phase 2 defines SPELL_READY_WYVERN/BOAR/BEAR only. Phase 3 adds talent constants. | ✓ |
| Include all talent constants | Add SPELL_HOTPL_PARENT, sentinel/dark ranger anchors now for Phase 3. | |
| You decide | Let Claude decide based on extraction cleanliness. | |

**User's choice:** You decide
**Notes:** Claude chose ready-buff IDs only — keeps each phase self-contained.

---

## Debug Output Design

### How should '/plbeast debug' work?

| Option | Description | Selected |
|--------|-------------|----------|
| Toggle mode (PLH-style) | '/plbeast debug' toggles DB.debug on/off. Persistent across sessions. | ✓ |
| One-shot dump | Prints current state once to chat without toggling. | |
| Both | Toggle continuous output + one-shot '/plbeast status'. | |

**User's choice:** Toggle mode (PLH-style)
**Notes:** None

### Debug output content

| Option | Description | Selected |
|--------|-------------|----------|
| Next beast + active buffs | Compact: next=Boar, wyvern=false, boar=true, bear=false, idx=2 | ✓ |
| Full aura readout | Verbose: all buff states, spell IDs, raw aura data. | |
| You decide | Let Claude match PLH's dprint style. | |

**User's choice:** Next beast + active buffs
**Notes:** Matches success criterion 1 requirements.

---

## Claude's Discretion

- Spell constants scope: Only ready-buff spell IDs in Phase 2 (user said "You decide")
- Extraction approach recommendation: Faithful extract & trim (user asked "What do you think?" and accepted recommendation)

## Deferred Ideas

None — discussion stayed within phase scope.
