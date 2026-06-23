---
phase: 02
slug: rotation-tracking
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-18
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — WoW Lua sandbox; no test framework exists |
| **Config file** | none |
| **Quick run command** | `/plbeast debug` in-game (manual) |
| **Full suite command** | `/reload` + manual rotation testing in-game |
| **Estimated runtime** | ~30 seconds per manual test cycle |

---

## Sampling Rate

- **After every task commit:** Visual code inspection + `/plbeast debug` in-game
- **After every plan wave:** Full manual rotation test (trigger beasts, verify index advances)
- **Before `/gsd:verify-work`:** All success criteria manually verified in-game
- **Max feedback latency:** N/A (manual-only validation)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | TRACK-01 | — | N/A | manual | `/plbeast debug` | N/A | ⬜ pending |
| 02-01-02 | 01 | 1 | TRACK-02 | — | N/A | manual | `/plbeast debug` | N/A | ⬜ pending |
| 02-01-03 | 01 | 1 | TRACK-03 | — | N/A | manual | `/reload` + check index | N/A | ⬜ pending |
| 02-01-04 | 01 | 1 | TRACK-04 | — | N/A | manual | spec switch test | N/A | ⬜ pending |
| 02-01-05 | 01 | 1 | TRACK-05 | — | N/A | manual | burst Kill Command test | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test framework to install — WoW addon validation is manual in-game testing via `/plbeast debug` command and observing rotation behavior.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rotation order correct | TRACK-01 | WoW sandbox — no external test runner | Use Kill Command to trigger beasts. `/plbeast debug` should show wyvern→boar→bear→wyvern cycle |
| Advances on buff transition only | TRACK-02, TRACK-05 | Requires real WoW aura events | Watch debug output: index should change exactly once per beast spawn, never on repeated poll |
| Persistence across reload | TRACK-03 | Requires SavedVariables round-trip | Note current next-beast, `/reload`, `/plbeast debug` — should match |
| Works on BM and SV specs | TRACK-04 | Requires spec switching in-game | Test rotation on BM hunter, switch to SV, verify still works |
| Multi-beast burst handling | TRACK-05 | Requires rapid Kill Command in combat | Fire rapid Kill Commands, verify index doesn't skip or double-count |

---

*Phase: 02-rotation-tracking*
*Validation strategy created: 2026-06-18*
