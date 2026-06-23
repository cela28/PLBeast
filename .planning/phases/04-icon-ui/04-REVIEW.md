---
phase: 04-icon-ui
reviewed: 2026-06-21T00:00:00Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - PLBeast/PLBeast.lua
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-06-21
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed `PLBeast/PLBeast.lua` for the Phase 4 additions: `CreateBeastIcon`, `ICON_FILE_BY_ID`, defaults extension, borderColor deep-copy guard, `SetNextBeastId` texture hook, `RefreshVisibility` visibility bridge, `OnDragStart`/`OnDragStop` drag handlers with combat guard, `SetIconSize`, and `ApplyIconSettings`.

The overall architecture is sound. The frame construction order (frame → texture → border child → drag scripts → assign `root` → `ApplyIconSettings`) correctly avoids the nil-root pitfall documented in the research. The deep-copy guard for `borderColor` is present and fires correctly on first-load. The `SetUserPlaced(false)` and `GetLeft()` nil guard in `OnDragStop` match the spec. The `InCombatLockdown` guard in `OnDragStart` is correct.

Two warnings were found. Both relate to untrusted SavedVariables data, a concern explicitly called out in `CLAUDE.md` ("SavedVariables are player-editable and loaded untrusted") and in the project convention for type-checking before arithmetic. The existing `NormalizeNextIndex` correctly uses `tonumber()` for the `nextIndex` SV field but the Phase 4 numeric fields and the `borderColor` table field lack equivalent guards.

---

## Warnings

### WR-01: `DB.borderColor` not type-validated before field access

**File:** `PLBeast/PLBeast.lua:560-563` (also `643-645`)
**Issue:** `ApplyIconSettings` accesses `DB.borderColor.r`, `.g`, `.b`, `.a` guarded only by a truthiness check (`DB.borderColor and DB.borderColor.r or 0`). If `DB.borderColor` is a non-table truthy value in `PLBeastDB` (e.g., a string `"black"` or boolean `true` from a hand-edited SavedVariables file), Lua 5.1 will raise `"attempt to index a <type> value"` on `.r`. The deep-copy guard at line 643 only fires when `DB.borderColor == defaults.borderColor` (reference equality on first-install), so a corrupted-but-non-nil non-table value bypasses it entirely and persists to `ApplyIconSettings`.

Per `CLAUDE.md`: "SavedVariables are player-editable and loaded untrusted." The pre-existing `NormalizeNextIndex` uses `tonumber()` as the type-safe pattern; `borderColor` needs an equivalent table-type check.

**Fix:** Add a type guard to the `ADDON_LOADED` handler immediately after the existing deep-copy guard:

```lua
-- Existing guard (line 643-645)
if DB.borderColor == defaults.borderColor then
    DB.borderColor = { r = 0, g = 0, b = 0, a = 1 }
end
-- Add: reset non-table values that slipped past the reference check
if type(DB.borderColor) ~= "table" then
    DB.borderColor = { r = 0, g = 0, b = 0, a = 1 }
end
```

---

### WR-02: Phase 4 numeric DB fields not validated with `tonumber()`

**File:** `PLBeast/PLBeast.lua:526-527, 545, 548, 556`
**Issue:** `SetIconSize` and `ApplyIconSettings` consume `DB.width`, `DB.height`, `DB.offsetX`, `DB.offsetY`, and `DB.borderThickness` directly without `tonumber()` coercion. If any of these fields are saved as strings in a hand-edited `PLBeastDB` (e.g., `width = "60"`), `SetIconSize`'s sync comparison `(w >= h)` will attempt a Lua string-vs-number comparison which raises a type error in Lua 5.1. `root:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX, DB.offsetY)` passing a string offset would cause a WoW API error.

The project already applies `tonumber()` in `NormalizeNextIndex` (line 141) for the analogous `DB.nextIndex` field. The Phase 4 fields are inconsistently unprotected.

**Fix:** Either add `tonumber()` coercion at read time in `ApplyIconSettings`/`SetIconSize`:

```lua
local function ApplyIconSettings()
    if not root then return end
    local w = tonumber(DB.width)  or 40
    local h = tonumber(DB.height) or 40
    SetIconSize(w, h)
    local ox = tonumber(DB.offsetX) or 0
    local oy = tonumber(DB.offsetY) or 0
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
    local thickness = tonumber(DB.borderThickness) or 1
    -- ... use thickness in SetBackdrop ...
end
```

Or add a normalization pass in the `ADDON_LOADED` handler alongside `NormalizeNextIndex()`:

```lua
DB.width           = tonumber(DB.width)           or 40
DB.height          = tonumber(DB.height)          or 40
DB.offsetX         = tonumber(DB.offsetX)         or 0
DB.offsetY         = tonumber(DB.offsetY)         or 0
DB.borderThickness = tonumber(DB.borderThickness) or 1
```

---

## Info

### IN-01: Comment inaccuracy — border `SetAllPoints` is set in `CreateBeastIcon`, not deferred

**File:** `PLBeast/PLBeast.lua:590-591`
**Issue:** The comment reads `"BackdropTemplate border child: size/position/color applied later via ApplyIconSettings"`. Size and position are NOT deferred: `border:SetAllPoints(f)` is called on line 593 immediately inside `CreateBeastIcon`. Only the `SetBackdrop` call (edgeSize, edgeFile) and `SetBackdropBorderColor` are deferred. The comment implies more is deferred than actually is.
**Fix:** Change comment to: `"BackdropTemplate border child: backdrop style and color applied later via ApplyIconSettings"`.

---

### IN-02: Redundant `root.border` nil check in `ApplyIconSettings`

**File:** `PLBeast/PLBeast.lua:551`
**Issue:** `if root.border and root.border.SetBackdrop then` — the `root.border` check is unreachable as nil because `f.border = border` (line 594) is always executed before `root = f` (line 618) and `ApplyIconSettings()` (line 619). The extra guard adds noise without providing safety.
**Fix:** Simplify to `if root.border.SetBackdrop then` (matching the old `CreateBeastIcon` inline guard style) or add a comment explaining why the redundant check is intentional (e.g., guarding against a future call path where border might not be set).

---

### IN-03: `SetIconSize` top-level comment phrasing is inverted

**File:** `PLBeast/PLBeast.lua:521-522`
**Issue:** The comment says `"the larger dimension is mirrored to the smaller so the icon stays square"`. This phrase means "the larger dimension is copied onto the smaller dimension", which is correct — but it reads as if the larger value shrinks, when the smaller value grows. The inline comment on line 529 states `"the larger of the two requested dimensions is applied to both"` which is clearer and unambiguous.
**Fix:** Replace the top-level comment with the more precise phrasing already used at line 529: `"When DB.syncSize is true, both dimensions are set to max(width, height) — icon stays square at the larger value."`

---

_Reviewed: 2026-06-21_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
