---
phase: 07-text-display-mode
reviewed: 2026-07-09T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - PLBeast/PLBeast.lua
  - PLBeast/Locales/enUS.lua
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
  warning_fixed: 2
  warning_open: 0
status: warnings_fixed
---

# Phase 7: Code Review Report

**Reviewed:** 2026-07-09
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Re-review of Phase 07 (Text Display Mode) after the follow-up quick task 260709-1ir
(mode-conditional options relayout, persisted `textOutline` cycle control, and
`CreateColorSwatch` label-hiding). The two warnings from the prior REVIEW.md
(WR-01 color-picker cancel writing default overrides; WR-02 frame not resizing to text)
are now **fixed** — verified in `CreateColorSwatch` (snapshot/restore of DB override state,
lines 747-794) and in the four text-measure/resize sites.

I traced every path called out in the review brief adversarially: `ApplyDisplayMode`,
`GetBeastColor`, `SetNextBeastId`, `CreateColorSwatch`, `CreateOutlineControl`,
`RelayoutOptions`, `SetControlShown`, the ADDON_LOADED coercion block, and the
`PLBeastTextFont` Font-object lifecycle. The most dangerous suspects turned out sound:

- **SavedVariables load order** — `PLBeastDB = PLBeastDB or {}` at file scope followed by
  `DB = PLBeastDB` reassignment in ADDON_LOADED is correct; all closures share the reassigned
  `DB` upvalue, so they observe the loaded table (not the throwaway file-scope table).
- **Combat lockdown** — `root` is a plain, non-protected `CreateFrame("Frame", ...)`, so the
  `SetSize`/`SetShown`/`SetPoint` calls fired from `PollPackLeader`/`RefreshVisibility` during
  combat are permitted. No taint or protected-action risk.
- **Font object as live reference** — mutating `textFont` via `SetFont` propagates to the label
  bound with `SetFontObject(textFont)`. The font-size setter (`_, _, flags`) and outline setter
  (`file, size`) each preserve the other's field, so they do not clobber each other.
- **`GetStringWidth`** is measured only after `root.label:SetShown(true)`, avoiding the WoW
  hidden-fontstring-returns-0 gotcha.
- **`RelayoutOptions` / `SetControlShown`** — labels are parented to the options frame but
  anchored relative to their widget, so `ClearAllPoints`+`SetPoint` on the widget moves them,
  while `SetControlShown` correctly toggles the separately-parented `.text`/`.valText`/`.label`
  visibility. No orphaned labels.
- **Locale coverage** — every `L[...]` key used by the new controls exists in `enUS.lua`, and
  the `L` metatable falls back to the key on miss regardless.

No blockers found. Two warnings (a robustness gap and a UX-label defect) and four
maintainability info items remain.

## Warnings

### WR-01: `DB.fontSize` is coerced but never range-clamped on load  — FIXED (commit 50e545d)

**Resolution:** Load-time coercion now clamps to the slider's `[8, 32]` range:
`DB.fontSize = math.max(8, math.min(32, tonumber(DB.fontSize) or 16))`. Width/height/
borderThickness clamps were intentionally left out of scope for this fix.

**File:** `PLBeast/PLBeast.lua:1104`
**Issue:** The load-time coercion is `DB.fontSize = tonumber(DB.fontSize) or 16`. Unlike the
slider's `SetMinMaxValues(8, 32)`, this applies no clamp. A corrupt SavedVariables file, a manual
edit, or a future migration can leave `DB.fontSize` at e.g. `999` or `1`. Because the slider's
`setValue` only runs on user interaction, the out-of-range value flows straight into
`textFont:SetFont(fontFile, DB.fontSize or 16, ...)` in `CreateBeastIcon` (line 608), producing a
label that is enormous/invisible with no obvious way to notice the value is illegal until the user
happens to drag the (display-clamped) slider. The same missing-clamp pattern exists for
`width`/`height` (lines 1097-1098, slider range 16-128) and `borderThickness` (line 1101, slider
range 0-8) from earlier phases; `fontSize` is the Phase-7 instance.
**Fix:**
```lua
-- clamp to the same bounds the Font Size slider enforces
DB.fontSize = math.max(8, math.min(32, tonumber(DB.fontSize) or 16))
```
Consider clamping `width`/`height`/`borderThickness` to their slider ranges too.

### WR-02: Outline cycle button renders the confusing label "Outline: Outline"  — FIXED (commit 5e8b3ab)

**Resolution:** The `OUTLINE` style's `labelKey` was renamed from `"Outline"` to
`"Thin Outline"` (new key added to `Locales/enUS.lua`). The "Outline: " prefix was kept
because the control has no adjacent text label, so the button now reads
"Outline: None" / "Outline: Thin Outline" / "Outline: Thick Outline" — all three distinct.

**File:** `PLBeast/PLBeast.lua:801-805, 826`
**Issue:** `SetOutlineText` builds the button caption as
`L["Outline"] .. ": " .. L[style.labelKey]`. For the middle style the `labelKey` is also
`"Outline"`, so the button reads **"Outline: Outline"** (and "Outline: None" / "Outline: Thick
Outline" for the others). Repeating the category prefix as the value is a UX defect in the very
control this follow-up task shipped, and gives the user no clear name for the thin-outline state.
**Fix:** Rename the middle style's label so the value reads distinctly, or drop the redundant
prefix:
```lua
local OUTLINE_STYLES = {
	{ value = "",             labelKey = "None" },
	{ value = "OUTLINE",      labelKey = "Thin" },   -- add "Thin" to enUS.lua
	{ value = "THICKOUTLINE", labelKey = "Thick Outline" },
}
-- or: button:SetText(L[style.labelKey]) without the "Outline: " prefix
```

## Info

### IN-01: Text-measure/resize block duplicated four times

**File:** `PLBeast/PLBeast.lua:217-221, 576-578, 839-841, 1035-1037`
**Issue:** The identical three-line block
```lua
local textWidth  = root.label:GetStringWidth()  + 4
local textHeight = root.label:GetStringHeight() + 4
root:SetSize(math.max(textWidth, 20), math.max(textHeight, 16))
```
appears in `SetNextBeastId`, `ApplyDisplayMode`, the Font Size slider, and `CreateOutlineControl`.
They are byte-identical today, but four copies invite silent divergence (e.g. someone tweaking the
`+4` padding or the `20/16` floors in one site only).
**Fix:** Extract a single `local function FitFrameToText()` (guarded by
`if DB.textMode and root and root.label then ... end`) and call it from all four sites.

### IN-02: Inconsistent texture fallback (`wyvern` vs `boar`) for an unknown beast id

**File:** `PLBeast/PLBeast.lua:209` vs `599`
**Issue:** `SetNextBeastId` falls back to `ICON_FILE_BY_ID.wyvern` when the beast id is unknown,
while `CreateBeastIcon` falls back to `ICON_FILE_BY_ID.boar`. The label fallbacks
(`BEAST_LABEL_BY_ID.boar`, lines 213/616) and the color fallback (`DEFAULT_BEAST_COLORS.boar`,
line 98) all use boar. This only surfaces under an invalid `nextBeastId`, but the divergence means
the texture and the label/color would disagree in that degraded state.
**Fix:** Use `ICON_FILE_BY_ID.boar` in `SetNextBeastId` for consistency with the rest.

### IN-03: Magic numbers in `RelayoutOptions` and fixed options-frame size

**File:** `PLBeast/PLBeast.lua:874-937, 951`
**Issue:** The relayout uses a scattered set of literal y-deltas (`-40`, `-30`, `-14`, `-48`,
`-24`) and the options frame is hardcoded to `SetSize(280, 460)`. Text-mode controls currently
bottom out around y=-250 so there is no clipping today, but the offsets are hard to reason about
and adding one more control risks manual mis-stacking or overflow of the fixed height.
**Fix:** Name the row-height constants (e.g. `ROW_H`, `SLIDER_ROW_H`, `SWATCH_ROW_H`) and/or
derive the frame height from the final computed `y`.

### IN-04: `defaults.textColors = nil` is a documentation-only default

**File:** `PLBeast/PLBeast.lua:28`
**Issue:** In a Lua table literal, `textColors = nil` stores no key, so `defaults.textColors` does
not exist and the `for k, v in pairs(defaults)` merge (line 1083) never iterates it. The behavior
is correct (nil is the intended default), but the line reads as if it establishes a default it does
not — a footgun for future edits.
**Fix:** Either drop the line in favor of a comment, or annotate that nil defaults are deliberately
not stored by the flat merge.

---

_Reviewed: 2026-07-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
