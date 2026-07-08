---
phase: quick-260709-1ir
plan: 01
status: complete
subsystem: options-ui
tags: [text-mode, options-panel, font-outline, ux]
dependency-graph:
  requires: [Phase 07 text-display-mode]
  provides: [RelayoutOptions, DB.textOutline, Outline cycle-control]
  affects: [PLBeast/PLBeast.lua options frame]
tech-stack:
  added: []
  patterns: ["mode-conditional widget SetShown + reposition via a single RelayoutOptions() cursor pass", "custom cycle-button instead of UIDropDownMenu for a 3-value enum"]
key-files:
  created: []
  modified:
    - PLBeast/PLBeast.lua
    - PLBeast/Locales/enUS.lua
decisions:
  - "Implemented Outline as a UIPanelButtonTemplate cycle-button (None -> Outline -> Thick Outline -> None) rather than a dropdown menu, per plan's least-risk WoW 12.0.x guidance (no Ace3/menu-API dependency)."
  - "SetControlShown() centralizes the parent-owned-label gotcha (checkbox .text, slider .valText, swatch/outline .label) so hiding a widget also hides its label instead of leaving a floating orphan."
metrics:
  duration: "~25min"
  completed: 2026-07-09
---

# Phase quick-260709-1ir Plan 01: Text Mode Options UX + Outline Control Summary

Mode-conditional options-panel relayout (Text Mode checkbox on top, icon-mode vs text-mode controls shown/hidden as a group) plus a new persisted text-outline cycle-control (None/Outline/Thick Outline) applied live to the custom `PLBeastTextFont` font object.

## What Was Built

**Task 1 — DB + font plumbing for text outline, plus locale strings**
- Added `textOutline = ""` to the `defaults` table (empty string = no outline; comment documents the three allowed values).
- Added validation in the `ADDON_LOADED` coercion block: an `allowedOutlines` set (`""`, `"OUTLINE"`, `"THICKOUTLINE"`) resets `DB.textOutline` to `""` if it holds any other/corrupt value.
- `CreateBeastIcon`'s initial `textFont:SetFont(...)` call now uses `DB.textOutline or ""` instead of the template-derived `fontFlags`, so the persisted outline applies on login.
- Added `["Outline"]`, `["None"]`, `["Thick Outline"]` locale entries to `PLBeast/Locales/enUS.lua`.
- Commit: `180ce64`

**Task 2 — Options-frame relayout + Text Mode reposition + Outline control**
- Added `optionsFrame.controls` table capturing every `Create*` return value (`textMode`, `lock`, `width`, `height`, `border`, `fontSize`, `outline`, `wyvern`, `boar`, `bear`).
- Fixed the parent-owned-label gotcha: `CreateColorSwatch` now stores `button.label = text` so its label can be hidden alongside the swatch.
- Added `SetControlShown(w, shown)` helper that toggles a widget and any of its known parent-owned label fontstrings (`.valText`, `.text`, `.label`) together.
- Added `RelayoutOptions(frame)`: a single top-down cursor pass that always shows Text Mode + Lock position first, then shows/hides and repositions the icon-mode slider trio (Width/Height/Border Thickness) or the text-mode trio (Font Size/Outline/3 swatches) depending on `DB.textMode`, with no vertical gaps or overlaps.
- Added `CreateOutlineControl(parent, xOffset, yOffset)`: a `UIPanelButtonTemplate` cycle-button labeled `"Outline: <style>"`. Each click advances `DB.textOutline` through None → Outline → Thick Outline → None, applies the flag live via `textFont:GetFont()` / `textFont:SetFont(file, size, DB.textOutline)`, re-measures the root frame when text mode is active (mirroring the Font Size slider's re-measure logic), and refreshes its own label text.
- Wired `RelayoutOptions(optionsFrame)` to run: once after the initial lazy build, immediately after the Text Mode checkbox's `setValue` callback (following `ApplyDisplayMode()`), and every time the options frame is about to be shown.
- `ApplyDisplayMode()` was left completely untouched, preserving its `ApplyIconSettings()` border-restore delegation.
- No slash-command text-mode toggle was added.
- Commit: `5ce8302`

## Deviations from Plan

None — plan executed exactly as written. The plan explicitly permitted either an inline creation or a `CreateOutlineControl` helper; a helper was chosen (matches the existing `CreateSlider`/`CreateCheckbox`/`CreateColorSwatch` factory-function convention already used in this file).

## Verification

- `luac -p PLBeast/PLBeast.lua` equivalent (real `luac` binary is not installed in this sandbox; substituted with a pure-JS Lua parser check using the already-cached `fengari` package, exercised against both valid and intentionally-broken Lua to confirm it correctly catches syntax errors) — passes after both tasks.
- `grep -q 'textOutline' PLBeast/PLBeast.lua` — OK
- `grep -q '"Thick Outline"\|\["Thick Outline"\]' PLBeast/Locales/enUS.lua` — OK
- `grep -q 'RelayoutOptions' PLBeast/PLBeast.lua` — OK
- `grep -q 'controls.outline' PLBeast/PLBeast.lua` — OK
- `grep -q 'textFont:SetFont' PLBeast/PLBeast.lua` — OK

Manual in-game verification (no automated WoW test framework exists) is still required — see the "Manual in-game" checklist in the plan's `<verification>` block. This has NOT been run against a live client in this session; flagging for human UAT:
1. `/plbeast` opens options → Text Mode checkbox is the top control.
2. Text Mode OFF: Width/Height/Border Thickness + Lock position visible; Font Size/Outline/swatches hidden; no floating labels or gaps.
3. Check Text Mode → immediate relayout: Text Mode + Lock position + Font Size + Outline + 3 swatches visible; icon-mode sliders hidden.
4. Cycle the Outline control (None → Outline → Thick Outline → None); on-screen beast text outline changes live; frame re-measures.
5. `/reload` → `DB.textOutline` (and text mode) persist; a corrupted saved value coerces back to `""` (None).

## Known Stubs

None.

## Threat Flags

None — this plan only adds a persisted string enum (`DB.textOutline`) validated against a fixed allow-list, and options-panel layout/visibility logic. No new network, auth, file-access, or schema surface introduced.

## Self-Check: PASSED

- FOUND: PLBeast/PLBeast.lua (modified, both commits present)
- FOUND: PLBeast/Locales/enUS.lua (modified, commit 180ce64 present)
- FOUND commit 180ce64 in `git log --oneline --all`
- FOUND commit 5ce8302 in `git log --oneline --all`
