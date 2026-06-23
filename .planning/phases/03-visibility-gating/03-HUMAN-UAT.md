---
status: partial
phase: 03-visibility-gating
source: [03-VERIFICATION.md]
started: "2026-06-19T16:30:00Z"
updated: "2026-06-19T16:30:00Z"
---

## Current Test

[awaiting human testing]

## Tests

### 1. BM/SV + Pack Leader shows tracking
expected: `/plbeast debug` prints `packLeader=true` when on BM or SV spec with Pack Leader hero talent active
result: [pending]

### 2. MM / non-Pack Leader suppresses UNIT_AURA
expected: After switching to MM spec (or non-hunter), aura tracking stops — no aura debug output; `/plbeast debug` shows `packLeader=false`
result: [pending]

### 3. Sentinel or Dark Ranger hero talent deactivates the gate
expected: Selecting Sentinel or Dark Ranger hero tree (instead of Pack Leader) causes `packLeader=false` even on BM/SV spec
result: [pending]

### 4. Rotation index persists across spec change re-activation
expected: After switching to MM then back to BM/SV with Pack Leader, rotation resumes from previously saved next-beast index (not reset to wyvern)
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
