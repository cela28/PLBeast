---
status: partial
phase: 01-addon-scaffold
source: [01-01-PLAN.md]
started: 2026-06-18
updated: 2026-06-18
---

## Current Test

[awaiting human testing — deferred, user lacks WoW access]

## Tests

### 1. Addon appears in AddOns list without version mismatch
expected: PLBeast listed, no "Interface version mismatch" warning
result: [pending]

### 2. No Lua errors on login
expected: No error popup, no errors in chat
result: [pending]

### 3. Loaded message prints on login
expected: [PLBeast] PLBeast loaded. Type /plbeast for options. (green text)
result: [pending]

### 4. /plbeast slash command works
expected: Prints loaded message in chat
result: [pending]

### 5. Clean /reload
expected: No errors, loaded message prints again
result: [pending]

### 6. SavedVariables persist across sessions
expected: WTF/.../SavedVariablesPerCharacter/PLBeast.lua contains PLBeastDB with debug=false, nextIndex=1
result: [pending]

### 7. Debug mode works (optional)
expected: Setting debug=true in SV file and /reload shows dprint output
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps
