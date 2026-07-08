---
status: complete
phase: 07-text-display-mode
source: [07-01-SUMMARY.md, 260709-1ir-SUMMARY.md]
started: 2026-07-08T21:58:24Z
updated: 2026-07-08T22:29:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. Toggle to Text Mode
expected: Open options with /plbeast, check "Text Mode". The icon texture is replaced by the next beast's name as colored text.
result: pass

### 2. Distinct Default Colors
expected: In text mode, the three beast names render in distinct, readable colors (Okabe-Ito defaults — Wyvern sky blue, Boar orange, Bear bluish-green). Each is easily distinguishable at a glance.
result: pass

### 3. Customize Beast Color
expected: Click a beast color swatch in the options frame. The ColorPickerFrame opens; pick a new color and confirm. The beast's text label updates to the chosen color.
result: pass

### 4. Font Size Slider
expected: Drag the "Font Size" slider (range 8–32). The text label grows/shrinks live as the slider moves.
result: pass

### 5. Live Update on Rotation
expected: With text mode active in-game, cast through the Pack Leader rotation. The text label updates in real time to the next beast (wyvern → boar → bear), matching what icon mode would show.
result: pass

### 6. Persistence Across /reload
expected: With text mode enabled, a custom font size set, a custom color picked, and an outline style set, run /reload. After reload the addon is still in text mode with the same font size, custom color(s), and outline style retained.
result: pass

### 7. Visibility Gating
expected: Text label follows the same gating as icon mode — when Pack Leader is not active (e.g. switch to a spec/talent build without the Pack Leader hero tree), the text label hides with the frame; switching back reshows it.
result: pass

### 8. Mode-Conditional Options Layout
expected: Open options with /plbeast. Text Mode checkbox is the top control. With Text Mode OFF, the icon-mode controls (Width, Height, Border Thickness) plus Lock position are visible and the text-mode controls (Font Size, Outline, 3 color swatches) are hidden. Check Text Mode → the panel instantly relays out: icon-mode sliders hide, text-mode controls appear. No floating/orphaned labels or vertical gaps in either state.
result: pass

### 9. Text Outline Cycle Control
expected: In text mode, click the "Outline" button repeatedly. Its label cycles None → Outline → Thick Outline → None, and the on-screen beast text outline changes live to match each click (frame re-measures to fit).
result: pass

## Summary

total: 9
passed: 9
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

[none yet]
