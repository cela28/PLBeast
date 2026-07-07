---
phase: 07-text-display-mode
reviewed: 2026-07-07T12:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - PLBeast/PLBeast.lua
  - PLBeast/Locales/enUS.lua
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 7: Code Review Report

**Reviewed:** 2026-07-07T12:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Phase 7 adds a text display mode to PLBeast, allowing the predicted beast to be shown as a colored text label instead of an icon texture. The implementation covers: a `DEFAULT_BEAST_COLORS` table with Okabe-Ito palette, a `GetBeastColor` helper with DB-override + default fallback, a `root.label` FontString created in `CreateBeastIcon`, an `ApplyDisplayMode` toggle function, a font-size slider, and per-beast `CreateColorSwatch` color pickers using `ColorPickerFrame`. Locale strings are added to `enUS.lua`. DB validation for the new fields in `ADDON_LOADED` is thorough.

Two issues were found that affect data correctness and usability. One informational item is noted for code clarity.

## Warnings

### WR-01: Color picker cancel writes default colors as explicit DB overrides

**File:** `PLBeast/PLBeast.lua:729-738`
**Issue:** When a user opens a color swatch for a beast that has no custom color (i.e., `DB.textColors` is nil or lacks that beast's entry), the `OnClick` handler captures `origR, origG, origB` from `GetBeastColor(beastId)`, which returns the `DEFAULT_BEAST_COLORS` values. If the user then cancels the color picker, `OnCancel` calls `ApplyColor(origR, origG, origB)`, which unconditionally writes `DB.textColors[beastId] = { r = origR, g = origG, b = origB }` -- creating an explicit override that is identical to the default.

Consequences:
1. SavedVariables accumulates entries that serve no purpose.
2. If a future addon update changes `DEFAULT_BEAST_COLORS` (e.g., palette refinement), users who ever opened-and-cancelled a color picker will not see the updated defaults -- their colors are frozen to the old values despite never having intentionally customized them.

**Fix:** Snapshot the DB state before opening the picker, and restore it on cancel instead of re-applying the resolved color:
```lua
button:SetScript("OnClick", function()
    local origR, origG, origB = GetBeastColor(beastId)
    -- Snapshot DB state: was there an explicit override before opening?
    local origOverride = DB.textColors and DB.textColors[beastId]
    local savedOverride = origOverride
        and { r = origOverride.r, g = origOverride.g, b = origOverride.b }
        or nil

    local function OnColorChanged()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        ApplyColor(r, g, b)
    end

    local function OnCancel()
        -- Restore original DB state, not the resolved color
        if savedOverride then
            DB.textColors = DB.textColors or {}
            DB.textColors[beastId] = savedOverride
        else
            if DB.textColors then
                DB.textColors[beastId] = nil
            end
        end
        swatchTex:SetColorTexture(origR, origG, origB)
        if root and root.label and nextBeastId == beastId then
            root.label:SetTextColor(origR, origG, origB)
        end
    end
    -- ... rest of ColorPickerFrame setup unchanged ...
end)
```

### WR-02: Text mode frame size does not adapt to text content -- drag/click area mismatch

**File:** `PLBeast/PLBeast.lua:545-568, 571-638`
**Issue:** When text mode is activated, `ApplyDisplayMode` hides the icon texture and border edges but does not resize the root frame. The frame retains its icon-mode dimensions (default 40x40 pixels, user-adjustable via width/height sliders). In WoW, `FontString` objects render visually beyond their parent frame's bounds, but mouse events (drag, click) are only received within the frame's actual bounds.

At the default font size 16, the text label "Wyvern" is approximately 55-65 pixels wide -- already wider than the 40px default frame. At the maximum slider value of 32, text width exceeds 100 pixels. Because the root frame is transparent in text mode (texture hidden, borders hidden), the user sees only the text label but can only interact with the invisible 40x40 area in its center. Portions of the text outside this area do not respond to drag or click.

**Fix:** After toggling to text mode, measure the rendered text and resize the frame to fit. Revert to icon dimensions when switching back:
```lua
-- Inside ApplyDisplayMode(), after showing root.label:
if textMode then
    -- ... existing edge-hide logic ...
    if root.label then
        local r, g, b = GetBeastColor(nextBeastId)
        root.label:SetTextColor(r, g, b)
        -- Resize frame to fit text content
        local textWidth = root.label:GetStringWidth() + 4
        local textHeight = root.label:GetStringHeight() + 4
        root:SetSize(math.max(textWidth, 20), math.max(textHeight, 16))
    end
else
    -- Restore icon dimensions before applying icon settings
    SetIconSize(DB.width or 40, DB.height or 40)
    ApplyIconSettings()
end
```

Additionally, the font size slider callback and `SetNextBeastId` should trigger a re-measure when text mode is active, since changing the font size or beast name changes the text dimensions.

## Info

### IN-01: `textColors = nil` in defaults table is a no-op under `pairs()` iteration

**File:** `PLBeast/PLBeast.lua:28`
**Issue:** The `defaults` table contains `textColors = nil`. In Lua, assigning `nil` to a table key is equivalent to the key not existing -- `pairs()` does not iterate over it. The flat defaults merge loop (`for k, v in pairs(defaults) do ... end`) at line 895 will never process this entry. The line serves as documentation only but could mislead a future maintainer into thinking it participates in the merge.
**Fix:** Move to a comment above the defaults table, or add a code comment clarifying it is documentation-only:
```lua
-- textColors: nil by default (use DEFAULT_BEAST_COLORS); set by color pickers.
-- Not listed in defaults table because nil values are invisible to pairs().
```

---

_Reviewed: 2026-07-07T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
