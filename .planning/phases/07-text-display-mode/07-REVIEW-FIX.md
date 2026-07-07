---
phase: 07-text-display-mode
fixed_at: 2026-07-07T12:05:00Z
review_path: .planning/phases/07-text-display-mode/07-REVIEW.md
iteration: 1
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 7: Code Review Fix Report

**Fixed at:** 2026-07-07T12:05:00Z
**Source review:** .planning/phases/07-text-display-mode/07-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 2
- Fixed: 2
- Skipped: 0

## Fixed Issues

### WR-01: Color picker cancel writes default colors as explicit DB overrides

**Files modified:** `PLBeast/PLBeast.lua`
**Commit:** b5f5d22
**Applied fix:** The `OnClick` handler now snapshots the DB state (`DB.textColors[beastId]`) before opening the color picker. If the user had an explicit override, a deep copy is saved; if not, `nil` is saved. On cancel, the `OnCancel` callback restores the original DB state -- writing back the saved override if one existed, or clearing the key from `DB.textColors` if there was none. This prevents the cancel action from freezing default palette values as explicit overrides in SavedVariables.

### WR-02: Text mode frame size does not adapt to text content -- drag/click area mismatch

**Files modified:** `PLBeast/PLBeast.lua`
**Commit:** 1724d4a
**Applied fix:** Three changes ensure the root frame dimensions match the visible text label in text mode:
1. `ApplyDisplayMode()` now calls `GetStringWidth()`/`GetStringHeight()` on the label after showing it, and resizes the root frame with 4px padding (minimum 20x16). When switching back to icon mode, `SetIconSize()` is called before `ApplyIconSettings()` to restore the icon dimensions.
2. The font size slider callback now re-measures and resizes the frame when `DB.textMode` is active, since changing font size changes text dimensions.
3. `SetNextBeastId()` now re-measures and resizes the frame when `DB.textMode` is active, since different beast names have different widths.

---

_Fixed: 2026-07-07T12:05:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
