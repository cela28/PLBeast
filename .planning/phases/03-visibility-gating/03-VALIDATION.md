---
phase: 3
slug: visibility-gating
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-19
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | WoW in-game manual testing via `/plbeast debug` and `/plbeast test` |
| **Config file** | none — WoW addon sandbox has no external test framework |
| **Quick run command** | `/reload` in WoW client, check `/plbeast debug` output |
| **Full suite command** | `/reload`, switch specs, change talents, verify visibility transitions |
| **Estimated runtime** | ~60 seconds per full manual pass |

---

## Sampling Rate

- **After every task commit:** `/reload` + `/plbeast debug` to verify flag state
- **After every plan wave:** Full spec-switch + talent-change test sequence
- **Before `/gsd:verify-work`:** Full suite must pass (all 3 success criteria verified)
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | VIS-01 | — | N/A | manual | `/plbeast debug` shows `packLeader=true` on BM/SV with Pack Leader | N/A | ⬜ pending |
| 03-01-02 | 01 | 1 | VIS-02 | — | N/A | manual | `/plbeast debug` shows `packLeader=false` on MM or non-hunter | N/A | ⬜ pending |
| 03-01-03 | 01 | 1 | VIS-03 | — | N/A | manual | Switch spec in-game, `/plbeast debug` updates within one frame | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. WoW addon sandbox does not support external test frameworks — all verification is manual in-game via `/plbeast debug` output.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pack Leader talent detection | VIS-01 | Requires live WoW client with `IsPlayerSpell` API | Log in as BM/SV hunter with Pack Leader, run `/plbeast debug`, verify `packLeader=true` |
| MM/non-hunter hiding | VIS-02 | Requires spec switch in live WoW client | Switch to MM spec, run `/plbeast debug`, verify `packLeader=false` |
| Real-time spec/talent change | VIS-03 | Requires talent/spec change events from live WoW client | Change hero talent or spec, verify debug output updates without `/reload` |

---

## Validation Sign-Off

- [ ] All tasks have manual verify instructions
- [ ] Sampling continuity: `/plbeast debug` covers all visibility states
- [ ] Wave 0: N/A (no external test framework applicable)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
