# Phase 4: Icon UI - Pattern Map

**Mapped:** 2026-06-21
**Files analyzed:** 2 (PLBeast/PLBeast.lua modified; no new files)
**Analogs found:** 5 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `PLBeast/PLBeast.lua` — `CreateBeastIcon()` | UI (frame constructor) | event-driven | `PackLeaderHelper.lua` `CreateIcon()` lines 352–453 | role-match (strip CDM/glow/text) |
| `PLBeast/PLBeast.lua` — drag scripts | UI (input handler) | request-response | `PackLeaderHelper.lua` `OnDragStart/Stop` lines 904–912 | exact |
| `PLBeast/PLBeast.lua` — position persistence | config (SavedVariables) | request-response | `PackLeaderHelper.lua` `RefreshRootTransform()` line 1432–1433 | exact |
| `PLBeast/PLBeast.lua` — backdrop border | UI (frame constructor) | request-response | `PackLeaderHelper.lua` `selectionInfoBox` backdrop lines 1311–1325 | role-match (swap edge texture to WHITE8X8) |
| `PLBeast/PLBeast.lua` — defaults table + texture constants | config / data table | N/A | `PackLeaderHelper.lua` defaults lines 39–54, ICON_FILE_BY_ID lines 57–65 | exact |

---

## Pattern Assignments

### `PLBeast/PLBeast.lua` — `CreateBeastIcon()` (UI frame constructor)

**Analog:** `PackLeaderHelper.lua` `CreateIcon()` lines 352–418

**What to strip vs keep:**
- KEEP: `CreateFrame`, `SetSize`, `SetFrameStrata`, `SetClampedToScreen`, `CreateTexture ARTWORK`, `SetAllPoints`, `SetTexture`, `SetTexCoord(0.08, 0.92, 0.08, 0.92)`, frame name string for global reference
- STRIP: `CooldownFrameTemplate` cd subframe, `FontString` text label, `glow` Frame + 4-edge color texture border (PLBeast uses BackdropTemplate border instead), `SetDesaturated(true)` (PLBeast uses `false`)

**Frame creation pattern** (PLH lines 352–368):
```lua
local function CreateIcon(parent, iconId, fileID)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(40, 40)
	f.iconId = iconId
	f:Show()

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(f)
	bg:SetColorTexture(0, 0, 0, 0.35)
	f.bg = bg

	local tex = f:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(f)
	tex:SetTexture(fileID)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	tex:SetDesaturated(true)   -- PLBeast: change to false (D-05)
	f.tex = tex
```

**PLBeast deviation for frame creation** — combine the analog with these changes:
- Named frame: `CreateFrame("Frame", "PLBeastFrame", UIParent)` (not `nil, parent`)
- `SetSize(DB.width or 40, DB.height or 40)` (not fixed 40)
- `SetMovable(true)` + `EnableMouse(true)` + `RegisterForDrag("LeftButton")` at this level (not in a sub-function)
- `SetPoint("CENTER", UIParent, "CENTER", DB.offsetX or 0, DB.offsetY or 0)` immediately after
- `tex:SetDesaturated(false)` — full color always (D-05)
- No bg dark texture — PLBeast shows the raw icon; border frame provides visual edge

---

### `PLBeast/PLBeast.lua` — Drag scripts (OnDragStart / OnDragStop)

**Analog:** `PackLeaderHelper.lua` lines 904–912 (OnDragStart combat guard) + RESEARCH.md Pattern 2 (OnDragStop position capture)

**OnDragStart combat guard** (PLH lines 904–911):
```lua
button:SetScript("OnDragStart", function(self)
	if InCombatLockdown and InCombatLockdown() then
		Print(L["Cannot edit layout in combat."])
		return
	end
	self:SetFrameStrata("TOOLTIP")
	self:StartMoving()
end)
```

**PLBeast deviation:** Silent no-op (D-08) — no `Print(...)` chat message, no strata change. Exact form:
```lua
f:SetScript("OnDragStart", function(self)
	if DB.locked then return end
	if InCombatLockdown and InCombatLockdown() then return end
	self:StartMoving()
end)
```

**OnDragStop position capture** (derived from PLH `RefreshRootTransform` line 1432 pattern + RESEARCH.md):
```lua
f:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	self:SetUserPlaced(false)   -- suppress LayoutCache.txt
	if not self:GetLeft() then return end  -- nil guard (Pitfall 3 in RESEARCH.md)
	local cx = UIParent:GetWidth()  / 2
	local cy = UIParent:GetHeight() / 2
	local fx = self:GetLeft()   + self:GetWidth()  / 2
	local fy = self:GetBottom() + self:GetHeight() / 2
	DB.offsetX = fx - cx
	DB.offsetY = fy - cy
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX, DB.offsetY)
end)
```

---

### `PLBeast/PLBeast.lua` — Position persistence (apply on login)

**Analog:** `PackLeaderHelper.lua` `RefreshRootTransform()` lines 1429–1434

**Exact analog excerpt** (PLH lines 1432–1433):
```lua
root:ClearAllPoints()
root:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX or 0, DB.offsetY or 0)
```

**PLBeast application:** Call during `CreateBeastIcon()` after frame creation. No `SetScale` — PLBeast uses `SetSize(DB.width, DB.height)` instead (D-01).

---

### `PLBeast/PLBeast.lua` — Backdrop border (BackdropTemplate)

**Analog:** `PackLeaderHelper.lua` `selectionInfoBox` backdrop lines 1311–1325

**PLH excerpt** (lines 1311–1325):
```lua
optionsFrame.selectionInfoBox = CreateFrame("Frame", nil, optionsFrame, "BackdropTemplate")
optionsFrame.selectionInfoBox:SetFrameStrata("TOOLTIP")
optionsFrame.selectionInfoBox:SetSize(210, 54)
if optionsFrame.selectionInfoBox.SetBackdrop then
	optionsFrame.selectionInfoBox:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	optionsFrame.selectionInfoBox:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	optionsFrame.selectionInfoBox:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.9)
end
```

**PLBeast adaptation** (D-03, UI-02) — swap to WHITE8X8 edge, no bgFile, zero insets, 1px default:
```lua
local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
border:SetAllPoints(f)
if border.SetBackdrop then
	border:SetBackdrop({
		bgFile   = nil,
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile     = false,
		edgeSize = DB.borderThickness or 1,
		insets   = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	border:SetBackdropBorderColor(
		DB.borderColor and DB.borderColor.r or 0,
		DB.borderColor and DB.borderColor.g or 0,
		DB.borderColor and DB.borderColor.b or 0,
		DB.borderColor and DB.borderColor.a or 1
	)
end
f.border = border
```

Note: `if border.SetBackdrop then` (field access, NOT `border:SetBackdrop`) — per Anti-Patterns in RESEARCH.md.

---

### `PLBeast/PLBeast.lua` — Texture file ID constants + ICON_FILE_BY_ID

**Analog:** `PackLeaderHelper.lua` lines 29–31 (constants) and lines 57–65 (ICON_FILE_BY_ID map)

**PLH excerpt** (lines 29–31, 57–65):
```lua
local ICON_DRAGON_READY = 773276
local ICON_PIG_READY = 132184
local ICON_BEAR_READY = 132183

local ICON_FILE_BY_ID = {
	timer = ICON_TIMER,
	wyvern = ICON_DRAGON_READY,
	wyvernBuff = ICON_DRAGON_READY,
	wyvernExtend = ICON_WYVERN_EXTEND_AVAILABLE,
	boar = ICON_PIG_READY,
	hogstrider = ICON_HOGSTRIDER,
	bear = ICON_BEAR_READY,
}
```

**PLBeast adaptation** — three-beast subset only:
```lua
local ICON_FILE_BY_ID = {
	wyvern = 773276,   -- ICON_DRAGON_READY
	boar   = 132184,   -- ICON_PIG_READY
	bear   = 132183,   -- ICON_BEAR_READY
}
```

---

### `PLBeast/PLBeast.lua` — defaults table extension

**Analog:** `PackLeaderHelper.lua` defaults table lines 39–54

**PLH excerpt** (lines 39–54):
```lua
local defaults = {
	offsetX = 0,
	offsetY = -120,
	scale = 1.0,
	-- ...
	nextIndex = 1,
	debug = false,
}
```

**PLBeast Phase 4 extension** — add to existing defaults at line ~14:
```lua
local defaults = {
	debug           = false,
	nextIndex       = 1,
	-- Phase 4 additions:
	offsetX         = 0,
	offsetY         = 0,
	width           = 40,
	height          = 40,
	syncSize        = true,
	borderThickness = 1,
	borderColor     = { r = 0, g = 0, b = 0, a = 1 },
	locked          = false,
}
```

**Critical:** After the flat-defaults merge in ADDON_LOADED, add a deep-copy guard for `borderColor` to avoid the reference-sharing pitfall (RESEARCH.md Pitfall 4):
```lua
if DB.borderColor == defaults.borderColor then
	DB.borderColor = { r = 0, g = 0, b = 0, a = 1 }
end
```

---

## Shared Patterns

### Texture refresh hook in `SetNextBeastId()`

**Source:** `PLBeast/PLBeast.lua` `SetNextBeastId()` lines 102–106 (existing function to modify)
**Apply to:** Texture push after rotation advance

```lua
-- Add after NormalizeNextIndex() in the existing SetNextBeastId():
if root and root.tex then
	local fileID = ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.wyvern
	root.tex:SetTexture(fileID)
end
```

Guard `if root and root.tex then` is mandatory — `SetNextBeastId` is called during ADDON_LOADED (before PLAYER_LOGIN) when the frame doesn't exist yet (RESEARCH.md Pitfall 5).

### Visibility bridge in `RefreshVisibility()`

**Source:** `PLBeast/PLBeast.lua` `RefreshVisibility()` lines 218–238 (existing function to modify)
**Apply to:** Show/hide icon on Pack Leader spec/talent change

```lua
-- Add at the end of the existing RefreshVisibility(), after the dprint call:
if root then
	root:SetShown(isPackLeaderActive)
end
```

### Combat lockdown guard pattern

**Source:** `PackLeaderHelper.lua` lines 904–908
**Apply to:** `OnDragStart` handler in PLBeast

Pattern: `if InCombatLockdown and InCombatLockdown() then return end`
- PLBeast version is a **silent** no-op (no chat message) per D-08, unlike PLH which prints a warning.

### Frame module-level forward declaration

**Source:** `PLBeast/PLBeast.lua` line 72 (existing `local eventFrame` pattern)
**Apply to:** `local root` — declare before `CreateBeastIcon()`, assigned inside it

```lua
-- At top of UI section (before CreateBeastIcon):
local root
```

This matches the existing `local eventFrame` forward-declaration at line 72 and PLH's `local root` at line 313.

---

## Integration Points Summary

| Where to modify | What to add | Line reference |
|----------------|-------------|----------------|
| `defaults` table (~line 14) | 8 new keys: offsetX/Y, width, height, syncSize, borderThickness, borderColor, locked | PLH lines 39–54 |
| ADDON_LOADED handler | deep-copy guard for `DB.borderColor` after flat-merge | RESEARCH.md Pitfall 4 |
| `SetNextBeastId()` (~line 102) | texture push `root.tex:SetTexture(...)` | PLBeast line 102–106 |
| `RefreshVisibility()` (~line 218) | `root:SetShown(isPackLeaderActive)` | PLBeast line 218–238 |
| PLAYER_LOGIN handler (~line 279) | call `CreateBeastIcon()` after existing slash-command setup | PLBeast line 279–306 |
| New section: UI | `local ICON_FILE_BY_ID`, `local root`, `local function CreateBeastIcon()` | New, after line 255 event handler section or in a new UI section |

---

## No Analog Found

All patterns have close analogs. No files are without a match.

---

## Metadata

**Analog search scope:** `PackLeaderHelper.lua` (lines 29–65, 309–482, 895–919, 1311–1325, 1425–1434), `PLBeast/PLBeast.lua` (full, 324 lines)
**Files scanned:** 2 source files + 3 planning documents
**Pattern extraction date:** 2026-06-21
