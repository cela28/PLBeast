---
phase: 1
slug: addon-scaffold
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-18
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — WoW Lua sandbox has no automated test runner |
| **Config file** | N/A |
| **Quick run command** | `/reload` in WoW client |
| **Full suite command** | Manual in-game checklist (see Manual-Only Verifications) |
| **Estimated runtime** | ~60 seconds per manual cycle |

---

## Sampling Rate

- **After every task commit:** Visual code review + Lua syntax check (`luac -p PLBeast/*.lua`)
- **After every plan wave:** Full manual in-game checklist
- **Before `/gsd:verify-work`:** All manual verifications green
- **Max feedback latency:** ~60 seconds (login + `/reload`)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | STRUCT-01 | — | N/A | manual | `/reload` — no Lua errors | N/A | ⬜ pending |
| 01-01-02 | 01 | 1 | STRUCT-02 | — | N/A | manual | Check `PLBeastDB` in SavedVariables file | N/A | ⬜ pending |
| 01-01-03 | 01 | 1 | STRUCT-03 | — | N/A | syntax | `luac -p PLBeast/PLBeast.toc` — valid TOC | N/A | ⬜ pending |
| 01-01-04 | 01 | 1 | STRUCT-04 | — | N/A | manual | Login/logout cycle — DB values persist | N/A | ⬜ pending |
| 01-01-05 | 01 | 1 | STRUCT-05 | — | N/A | manual | `L["key"]` returns key string | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No automated test framework exists for WoW Lua addons — all verification is manual in-game or via file inspection.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Addon loads without errors | STRUCT-01 | WoW client runtime only | 1. Copy PLBeast/ to AddOns folder 2. `/reload` 3. Check no Lua errors in chat |
| SavedVariables round-trip | STRUCT-02, STRUCT-04 | Requires WoW client persistence | 1. Login 2. `/plbeast debug` 3. Logout 4. Login 5. Verify DB values preserved |
| TOC declares correct Interface | STRUCT-03 | File content inspection | Open PLBeast.toc, verify `## Interface: 120000, 120005, 120007` |
| Locale table works | STRUCT-05 | Requires addon runtime | 1. `/reload` 2. Check loaded message uses L[] strings |
| Slash command responds | STRUCT-04 | Requires WoW client | 1. Type `/plbeast` 2. Verify response in chat |

---

## Validation Sign-Off

- [ ] All tasks have manual verify steps documented
- [ ] Sampling continuity: every task has a verification method
- [ ] No automated test infrastructure needed (WoW addon — manual only)
- [ ] Feedback latency < 60s (reload cycle)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
