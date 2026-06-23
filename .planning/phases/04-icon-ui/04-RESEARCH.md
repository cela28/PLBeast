# Phase 4: Icon UI - Research

**Researched:** 2026-06-21
**Domain:** WoW Frame API — single draggable icon frame, backdrop border, texture display, position/size persistence
**Confidence:** MEDIUM (WoW API verified via Wowpedia / warcraft.wiki.gg; implementation patterns cross-checked against PLH source)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Resizing uses `frame:SetSize(width, height)` — NOT PLH's uniform `SetScale`. Width and height are independently adjustable per UI-05.
- **D-02:** Width/height sync toggle defaults ON — icon starts square. Default size is 40×40.
- **D-03:** Border thickness is a fixed pixel `edgeSize` in px; does NOT scale with icon. Border defaults: black, 1px. Border uses `BackdropTemplate` with `WHITE8X8` edge texture.
- **D-04:** Beast texture cropped with `SetTexCoord(0.08, 0.92, 0.08, 0.92)`.
- **D-05:** Icon displayed in full color — `SetDesaturated(false)`. No greyed state.
- **D-06:** Beast texture file IDs: wyvern=773276, boar=132184, bear=132183. Drive from existing `nextBeastId`.
- **D-07:** Dragging ON by default this phase, persisted via `DB.locked = false`. Phase 5 adds toggle UI.
- **D-08:** `OnDragStart`/`StartMoving` guarded by `InCombatLockdown()` — silent no-op during combat.
- **D-09:** Position persists as `DB.offsetX` / `DB.offsetY` via `SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)`.

### Claude's Discretion
- Icon creation/lifecycle: create frame eagerly at `PLAYER_LOGIN`; exact frame name (`PLBeastFrame`) and strata (`"MEDIUM"`) are Claude's choice per UI-SPEC.
- Texture-refresh hook: update in `SetNextBeastId()` after advancing `nextBeastId`, and on initial show.
- DB defaults and merge: add new keys to `defaults` table; let existing flat-defaults merge populate them.
- Combat-deferred apply: not needed this phase (options UI is Phase 5 only).

### Deferred Ideas (OUT OF SCOPE)
- Options frame / sliders / color-picker / drag toggle UI (Phase 5)
- Glow effect (v2 VIS-04)
- Release pipeline (Phase 6)
- Cooldown timer, wyvern-buff, hogstrider tracking (stays in PackLeaderHelper)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UI-01 | Single icon displays the next beast's texture (wyvern/boar/bear) | Texture file IDs confirmed in PLH source; SetTexture + SetTexCoord pattern documented |
| UI-02 | Icon has a square border using BackdropTemplate (WHITE8X8 edge texture) with configurable color and thickness; default: black, 1px | BackdropTemplate + SetBackdrop + SetBackdropBorderColor API verified via Wowpedia |
| UI-03 | Icon dragging is toggled on/off; blocked during combat lockdown | SetMovable + RegisterForDrag + InCombatLockdown guard pattern verified |
| UI-04 | Icon position persists across sessions via SavedVariables | CENTER-offset capture pattern documented; SetUserPlaced(false) pitfall identified |
| UI-05 | Icon width and height independently adjustable, with sync toggle | SetSize(w,h) vs SetScale distinction verified |
| UI-06 | Border color and thickness persist across sessions | DB.borderColor + DB.borderThickness in defaults merge; no extra work beyond standard DB pattern |
| UI-07 | Icon width, height, and sync-toggle setting persist across sessions | DB.width + DB.height + DB.syncSize in defaults merge |
</phase_requirements>

---

## Summary

This phase creates a single WoW frame that shows the predicted next Pack Leader beast. The implementation extracts and trims PLH's proven `CreateIcon()` pattern — stripping CDM cooldown swipe, desaturation, glow, and multi-icon concerns — to produce a minimal frame with: (1) a cropped full-color beast texture, (2) a fixed-pixel configurable border via `BackdropTemplate`, (3) drag-to-reposition with combat guard, and (4) persistence of position/size/border in `PLBeastDB`.

The critical WoW API fact is that `BackdropTemplate` became mandatory in Patch 9.0.1 (retail 2020); calling `SetBackdrop` on a plain frame without the mixin throws a nil-method error. PLBeast targets Interface 120000+ (The War Within) so `BackdropTemplate` must always be included at frame creation — no legacy compatibility check needed. The `SetBackdrop` call must still be guarded (`if frame.SetBackdrop then`) as a defensive nil-check per convention, but on 12.x retail the mixin will always be present if the template was specified.

The phase integrates with three upstream systems: (1) `nextBeastId` / `SetNextBeastId()` from Phase 2 drives texture selection; (2) `isPackLeaderActive` / `RefreshVisibility()` from Phase 3 drives show/hide; (3) the `defaults` merge and `PLBeastDB` pattern from Phase 1 handles all new DB keys. No new events need to be registered; the existing event frame handles everything.

**Primary recommendation:** Create `CreateBeastIcon()` as a local function modelled on PLH `CreateIcon()` (lines 352-453) but stripped to: parent frame + cropped full-color texture + `BackdropTemplate` border. Wire it at `PLAYER_LOGIN` after the existing code, then hook texture push into `SetNextBeastId()` and show/hide into `RefreshVisibility()`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Beast texture display | UI layer (PLBeast.lua) | State machine (nextBeastId) | Frame renders; state machine provides the beast ID |
| Border rendering | UI layer (PLBeast.lua) | — | Pure frame construction; no external data needed |
| Drag repositioning | UI layer (PLBeast.lua) | State machine (InCombatLockdown guard) | Frame handles drag; combat state gates it |
| Position persistence | SavedVariables (PLBeastDB) | UI layer (apply on login) | DB is source of truth; UI applies on PLAYER_LOGIN |
| Size persistence | SavedVariables (PLBeastDB) | UI layer (apply on login) | Same pattern as position |
| Visibility gating | Phase 3 RefreshVisibility() | UI layer (root:SetShown) | Phase 3 owns isPackLeaderActive; Phase 4 calls SetShown |
| Texture refresh trigger | Phase 2 SetNextBeastId() | UI layer (push texture) | Phase 2 advances state; Phase 4 reads it |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WoW Frame API | Built-in (12.x) | Frame creation, texture, backdrop, drag | Only available option in WoW sandbox |
| `BackdropTemplate` | Built-in mixin (9.0+) | Square configurable border | Required since 9.0.1; plain SetBackdrop removed |
| `C_UnitAuras` | Built-in (12.x) | Already used in Phase 2/3 | No new dependency |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `C_Timer.After` | Built-in | Deferred execution | Already used; available for any combat-deferred future work |
| `InCombatLockdown` | Built-in global | Combat state check | Guard OnDragStart |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `BackdropTemplate` border | 4 colored textures as border edges (like PLH's glow border) | More control but more code; BackdropTemplate is simpler for a uniform border |
| CENTER-offset persistence | `SetPoint` saved via `GetPoint()` return values | GetPoint returns anchor + offsets but CENTER approach is simpler and matches PLH exactly |
| `SetSize(w,h)` | `SetScale(factor)` | SetScale is uniform; SetSize is required for independent w/h per D-01 |

**Installation:** None. WoW addons have no package manager. All APIs are built into the WoW client sandbox.

---

## Package Legitimacy Audit

**Not applicable.** This is a World of Warcraft addon. No npm, PyPI, or external packages exist. All dependencies are WoW built-in APIs.

---

## Architecture Patterns

### System Architecture Diagram

```
PLAYER_LOGIN event
       |
       v
CreateBeastIcon()  <-- called once, eagerly
  |   |   |
  |   |   +-- CreateFrame("Frame", "PLBeastFrame", UIParent)
  |   |         :SetSize(DB.width, DB.height)
  |   |         :SetFrameStrata("MEDIUM")
  |   |         :SetClampedToScreen(true)
  |   |         :SetMovable(true), :RegisterForDrag("LeftButton")
  |   |         :SetPoint("CENTER", UIParent, "CENTER", DB.offsetX, DB.offsetY)
  |   |
  |   +-- CreateTexture("ARTWORK")  -- f.tex
  |         :SetAllPoints(f)
  |         :SetTexture(ICON_FILE_BY_ID[nextBeastId])
  |         :SetTexCoord(0.08, 0.92, 0.08, 0.92)
  |         :SetDesaturated(false)
  |
  +-- Border: CreateFrame("Frame", nil, f, "BackdropTemplate")
        :SetAllPoints(f)
        :SetBackdrop({ edgeFile=WHITE8X8, edgeSize=DB.borderThickness, ... })
        :SetBackdropBorderColor(DB.borderColor.r, .g, .b, .a)

       root = f  (module-level upvalue)

       |
       v
RefreshVisibility() called (Phase 3)
       |
       +-- root:SetShown(isPackLeaderActive)   <-- added to existing function

UNIT_AURA / beast spawn event
       |
       v
CheckAuraState() -> SyncNextFromAddedReady() -> SetNextBeastId(id)
       |
       +-- [NEW] push texture: root.tex:SetTexture(ICON_FILE_BY_ID[nextBeastId])

OnDragStart (user drags icon)
       |
       +-- if InCombatLockdown() then return end  -- silent no-op
       +-- self:StartMoving()

OnDragStop (user releases)
       |
       +-- self:StopMovingOrSizing()
       +-- self:SetUserPlaced(false)   -- suppress WoW layout cache
       +-- calculate center offset -> DB.offsetX, DB.offsetY
       +-- ClearAllPoints() + SetPoint("CENTER", UIParent, "CENTER", ...)
```

### Recommended Project Structure

```
PLBeast/
├── PLBeast.toc          -- unchanged
├── PLBeast.lua          -- extend: defaults, CreateBeastIcon(), PLAYER_LOGIN, SetNextBeastId hook, RefreshVisibility hook
└── Locales/
    └── enUS.lua         -- no new strings needed for Phase 4 (icon has no text)
```

### Pattern 1: Minimal Icon Frame (adapted from PLH CreateIcon)

**What:** Create a single frame with cropped full-color texture and backdrop border.
**When to use:** Single-icon display scenarios without cooldown or glow.

```lua
-- Source: adapted from PackLeaderHelper.lua lines 352-453
-- Strips: CooldownFrameTemplate, FontString, glow animation group
-- Deviations: SetDesaturated(false), SetSize(DB.width, DB.height) not SetScale, BackdropTemplate border

local ICON_FILE_BY_ID = {
    wyvern = 773276,  -- ICON_DRAGON_READY (PLH line 29)
    boar   = 132184,  -- ICON_PIG_READY   (PLH line 30)
    bear   = 132183,  -- ICON_BEAR_READY  (PLH line 31)
}

local root  -- module-level frame reference; forward-declared

local function CreateBeastIcon()
    local f = CreateFrame("Frame", "PLBeastFrame", UIParent)
    f:SetSize(DB.width or 40, DB.height or 40)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX or 0, DB.offsetY or 0)

    -- Cropped full-color texture (D-04, D-05)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    local fileID = ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.wyvern
    tex:SetTexture(fileID)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tex:SetDesaturated(false)
    f.tex = tex

    -- Backdrop border (D-03, UI-02)
    -- BackdropTemplate required for SetBackdrop on 9.0+ retail [CITED: wowpedia.fandom.com/wiki/API_Frame_SetBackdrop]
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

    -- Drag handlers (D-07, D-08, D-09)
    f:SetScript("OnDragStart", function(self)
        if DB.locked then return end
        if InCombatLockdown and InCombatLockdown() then return end  -- D-08 silent guard
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)  -- suppress WoW LayoutCache.txt [CITED: wowwiki-archive.fandom.com/wiki/API_Frame_SetUserPlaced]
        -- Capture center offset (D-09)
        local cx = UIParent:GetWidth()  / 2
        local cy = UIParent:GetHeight() / 2
        local fx = self:GetLeft()   + self:GetWidth()  / 2
        local fy = self:GetBottom() + self:GetHeight() / 2
        DB.offsetX = fx - cx
        DB.offsetY = fy - cy
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX, DB.offsetY)
    end)

    root = f
    return f
end
```

### Pattern 2: Texture Refresh Hook in SetNextBeastId

**What:** Push matching texture onto icon immediately after rotation state advances.
**When to use:** Any time `nextBeastId` changes.

```lua
-- Add to existing SetNextBeastId() in PLBeast.lua (~line 102)
local function SetNextBeastId(beastId)
    nextBeastId = beastId or "wyvern"
    DB.nextIndex = INDEX_BY_ID[nextBeastId] or 1
    NormalizeNextIndex()
    -- Phase 4: push texture if icon exists
    if root and root.tex then
        local fileID = ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.wyvern
        root.tex:SetTexture(fileID)
    end
end
```

### Pattern 3: Visibility Bridge in RefreshVisibility

**What:** Add `root:SetShown()` to existing Phase 3 function.
**When to use:** Any time spec/talent state changes.

```lua
-- Add at the end of RefreshVisibility() in PLBeast.lua (~line 218)
-- (after the existing isPackLeaderActive assignment and dprint)
if root then
    root:SetShown(isPackLeaderActive)
end
```

### Pattern 4: DB Defaults for New Phase 4 Keys

**What:** Extend `defaults` table with all new persisted values.
**When to use:** Phase 1's flat-merge loop populates these on first load.

```lua
-- Extend defaults table (~line 14 in PLBeast.lua)
local defaults = {
    debug          = false,
    nextIndex      = 1,
    -- Phase 4 additions:
    offsetX        = 0,
    offsetY        = 0,
    width          = 40,
    height         = 40,
    syncSize       = true,
    borderThickness = 1,
    borderColor    = { r = 0, g = 0, b = 0, a = 1 },
    locked         = false,
}
```

### Anti-Patterns to Avoid

- **Calling SetBackdrop on a plain frame without BackdropTemplate:** Results in a nil method error on 9.0+ retail. Always pass `"BackdropTemplate"` as the fourth arg to `CreateFrame` for any frame that uses `SetBackdrop`. [CITED: wowpedia.fandom.com/wiki/API_Frame_SetBackdrop]
- **Using SetScale for independent width/height:** `SetScale` applies a uniform multiplier to all children — you cannot get different width vs height. Use `SetSize(w, h)` per D-01.
- **Not calling `SetUserPlaced(false)` after `StopMovingOrSizing()`:** `StartMoving()` sets the user-placed flag; WoW will then write the frame's position to `LayoutCache.txt` on logout, creating two sources of truth (LayoutCache AND SavedVariables). Always clear the flag after stopping.
- **Not calling `ClearAllPoints()` before `SetPoint()` on re-anchor:** If a frame has multiple anchor points, adding another with `SetPoint` stacks them and produces undefined layout. Always `ClearAllPoints()` first.
- **Checking `if frame:SetBackdrop then`** (method call): the defensive guard must be `if frame.SetBackdrop then` (field access), not `if frame:SetBackdrop then` (call). The colon form invokes the method and throws if nil.
- **Flat-merging a table-valued default incorrectly:** `defaults.borderColor` is a table `{ r=0, g=0, b=0, a=1 }`. The existing flat-merge loop copies the table reference, not a deep copy. If DB.borderColor is nil, it gets the defaults table reference — which is fine for reading, but Phase 5 slider writes must write to `DB.borderColor.r` etc., not replace `DB.borderColor` with a new table (that would break the defaults reference). The safest approach: on ADDON_LOADED, if `DB.borderColor == nil` then `DB.borderColor = { r=0, g=0, b=0, a=1 }` (new table, not defaults reference). Consider a post-merge deep-copy step for table defaults.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Square configurable border | 4 edge textures + manual sizing math | `BackdropTemplate` + `SetBackdrop` | BackdropTemplate handles all edge rendering, corner joining, and edgeSize scaling automatically |
| Drag-to-move | OnMouseDown delta tracking | `SetMovable` + `StartMoving` + `StopMovingOrSizing` | WoW provides hardware-accelerated drag; manual delta tracking breaks on lag spikes |
| Frame visibility toggle | Writing two separate show/hide functions | `SetShown(bool)` | Single call; avoids Show/Hide duplication |

**Key insight:** WoW's drag system (`StartMoving`/`StopMovingOrSizing`) handles mouse capture, frame clamping, and subpixel movement internally. Any manual implementation misses edge cases (edge clamp, resolution changes, UI scale).

---

## Common Pitfalls

### Pitfall 1: BackdropTemplate nil method on non-mixin frame

**What goes wrong:** `frame:SetBackdrop(...)` throws `attempt to call a nil value (method 'SetBackdrop')`.
**Why it happens:** In 9.0.1+, SetBackdrop was moved to `BackdropTemplateMixin`. Plain frames don't have it.
**How to avoid:** Always pass `"BackdropTemplate"` in CreateFrame: `CreateFrame("Frame", nil, parent, "BackdropTemplate")`.
**Warning signs:** Error on login; icon never appears.

### Pitfall 2: Double position source — LayoutCache + SavedVariables

**What goes wrong:** After a `/reload`, the icon snaps to an unexpected position — sometimes to where it was before a drag, not after.
**Why it happens:** `StartMoving()` sets the user-placed flag. On logout WoW saves the frame's position to `LayoutCache.txt`. On load, WoW applies LayoutCache AFTER your `SetPoint` call, overriding it.
**How to avoid:** Call `frame:SetUserPlaced(false)` immediately after `self:StopMovingOrSizing()`. [CITED: wowwiki-archive.fandom.com/wiki/API_Frame_SetUserPlaced]
**Warning signs:** `/reload` moves icon to a stale position.

### Pitfall 3: GetLeft/GetBottom return nil before frame is shown

**What goes wrong:** Center offset calculation produces nil arithmetic error.
**Why it happens:** `GetLeft()` and `GetBottom()` return nil if the frame has never been rendered (not shown yet).
**How to avoid:** The frame is created at `PLAYER_LOGIN` and `SetShown(isPackLeaderActive)` is called immediately. If isPackLeaderActive is false on login, the frame is hidden and GetLeft may be nil at drag-stop time — but drag can only occur when the frame is shown, so this is safe in practice. Add a nil guard in OnDragStop regardless: `if not self:GetLeft() then return end`.
**Warning signs:** Lua error in OnDragStop nil arithmetic.

### Pitfall 4: borderColor deep-copy vs. reference

**What goes wrong:** Multiple fields of `borderColor` unexpectedly share state with the `defaults` table.
**Why it happens:** Lua table assignment copies the reference; the flat-merge loop does `PLBeastDB.borderColor = defaults.borderColor` (same table). Phase 5 sliders writing `DB.borderColor.r = value` mutate the defaults table.
**How to avoid:** In the `ADDON_LOADED` handler, after the flat-merge loop, add a deep-copy guard: `if DB.borderColor == defaults.borderColor then DB.borderColor = { r=defaults.borderColor.r, g=defaults.borderColor.g, b=defaults.borderColor.b, a=defaults.borderColor.a } end`. Or change the flat-merge to detect table values and deep-copy them.
**Warning signs:** Border color "resets" after every reload even after Phase 5 adds a color picker.

### Pitfall 5: SetTexture called before root is assigned

**What goes wrong:** Texture push in SetNextBeastId fires at file load (before PLAYER_LOGIN), when `root` is nil.
**Why it happens:** Phase 2's event system calls `SetNextBeastId("wyvern")` during `ResetAuraState()` in ADDON_LOADED, before the frame exists.
**How to avoid:** The existing guard `if root and root.tex then` in the texture-push hook is sufficient. Confirm `root` is always nil-checked.
**Warning signs:** Nil index error on `root.tex` at startup.

### Pitfall 6: ClearAllPoints missing before re-anchor after drag

**What goes wrong:** Frame drifts or renders at wrong position after repeated drags.
**Why it happens:** `SetPoint` accumulates anchors; without `ClearAllPoints()` first, the frame has two conflicting anchors.
**How to avoid:** Always call `self:ClearAllPoints()` before `self:SetPoint(...)` in `OnDragStop`.
**Warning signs:** Icon snaps to screen edge or drifts after multiple drag sessions.

---

## Code Examples

Verified patterns from PLH source and WoW API docs:

### SetBackdrop WHITE8X8 border (1px black)

```lua
-- Source: 04-UI-SPEC.md border contract; API verified at wowpedia.fandom.com/wiki/API_Frame_SetBackdrop
-- PLH reference: lines 1314-1324 (different edge texture, same structure)
local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
border:SetAllPoints(f)
if border.SetBackdrop then
    border:SetBackdrop({
        bgFile   = nil,
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    border:SetBackdropBorderColor(0, 0, 0, 1)
end
```

### Drag with combat guard and position capture

```lua
-- Source: PLH lines 904-912 (combat guard pattern), 04-UI-SPEC.md OnDragStop contract
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetClampedToScreen(true)

f:SetScript("OnDragStart", function(self)
    if DB.locked then return end
    if InCombatLockdown and InCombatLockdown() then return end
    self:StartMoving()
end)

f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false)
    if not self:GetLeft() then return end  -- nil guard (Pitfall 3)
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

### Apply persisted position on login

```lua
-- Source: PLH line 1433; 04-CONTEXT.md D-09
f:ClearAllPoints()
f:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX or 0, DB.offsetY or 0)
```

### Apply persisted size on login

```lua
-- Source: PLH line 354 (SetSize pattern); 04-CONTEXT.md D-01
f:SetSize(DB.width or 40, DB.height or 40)
```

### Texture selection from nextBeastId

```lua
-- Source: PLH lines 57-64 (ICON_FILE_BY_ID); 04-CONTEXT.md D-06
local ICON_FILE_BY_ID = {
    wyvern = 773276,
    boar   = 132184,
    bear   = 132183,
}
-- Push texture:
local fileID = ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.wyvern
f.tex:SetTexture(fileID)
f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- crop beveled edge
f.tex:SetDesaturated(false)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `frame:SetBackdrop()` on plain frame | `CreateFrame(..., "BackdropTemplate")` then `frame:SetBackdrop()` | Patch 9.0.1 (2020-10-13) | Plain SetBackdrop removed; BackdropTemplate mixin required |
| `frame:SetScale(n)` for uniform scaling | `frame:SetSize(w, h)` for independent dimensions | N/A — always existed | PLBeast uses SetSize per D-01; PLH uses SetScale for uniform scale |

**Deprecated/outdated:**
- `frame:SetBackdrop()` on a plain `CreateFrame("Frame")` without BackdropTemplate: Throws nil error on 9.0+ retail. Must use BackdropTemplate mixin.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `InCombatLockdown()` guard on drag is a safety best-practice but non-protected frames are not technically restricted from StartMoving() during combat | Common Pitfalls | If PLBeast frame is accidentally tainted (e.g. by a secure hook), the guard becomes mandatory. Low risk — follow PLH convention regardless. |
| A2 | `SetUserPlaced(false)` after StopMovingOrSizing() suppresses LayoutCache.txt position save | Common Pitfalls | If WoW writes LayoutCache before SetUserPlaced(false) takes effect, position conflict still occurs. Test in-game; if issue seen, persist position on PLAYER_LOGOUT too. |
| A3 | `GetLeft()` + `GetWidth()/2` center-offset calculation gives correct screen-space offset from UIParent center regardless of UI scale | Code Examples | UI scale changes (1.0 vs non-1.0) could affect GetLeft values if they return values in scaled or unscaled coordinates. PLH uses same pattern; safe to follow. |

**If this table is empty:** N/A — three assumed claims are listed above.

---

## Open Questions

1. **Table default deep-copy for `borderColor`**
   - What we know: Flat-merge loop assigns `DB.borderColor = defaults.borderColor` (reference copy). Phase 4 reads it but never writes sub-fields.
   - What's unclear: Phase 5 will write `DB.borderColor.r/g/b/a` via color picker. If the deep-copy guard is not added in Phase 4, Phase 5 will need to add it.
   - Recommendation: Add the deep-copy guard in Phase 4's ADDON_LOADED handler now to avoid a Phase 5 bug. Simple: `if DB.borderColor == defaults.borderColor then DB.borderColor = {r=0,g=0,b=0,a=1} end`.

2. **Border frame FrameLevel**
   - What we know: The border frame is a child of the icon frame. WoW sets child FrameLevel = parent + 1 by default.
   - What's unclear: At FrameLevel parent+1, the border will render above the texture (ARTWORK layer). This is correct — the border should be visible above the texture. No issue expected.
   - Recommendation: No explicit FrameLevel needed; default child level is correct.

---

## Environment Availability

Step 2.6: SKIPPED — this phase has no external dependencies. All APIs are WoW client built-ins loaded in the sandbox. No CLI tools, external services, or runtimes are required. Testing is manual in-game via `/reload` and dragging.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual in-game testing only (no automated test framework for WoW Lua) |
| Config file | none |
| Quick run command | Load addon in WoW client; `/reload` |
| Full suite command | Manual verification per success criteria below |

**Note:** WoW addon Lua runs in a protected sandbox. There is no Jest, pytest, or equivalent for in-game frame API calls. All validation is manual, in-game.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UI-01 | Icon displays correct beast texture matching nextBeastId | manual | `/reload` then observe icon; use `/plbeast reset` to cycle | N/A |
| UI-02 | Visible square border, default black 1px | manual | Visually inspect on screen | N/A |
| UI-03 | Dragging toggles on/off; blocked in combat | manual | Drag icon; enter combat and try to drag | N/A |
| UI-04 | Position survives `/reload` | manual | Drag icon; `/reload`; verify position | N/A |
| UI-05 | Width/height adjustable independently | manual | Phase 5 adds sliders; Phase 4 verifies defaults are applied on load | N/A |
| UI-06 | Border settings persist | manual | Phase 5 adds color picker; Phase 4 verifies defaults load correctly | N/A |
| UI-07 | Size settings persist | manual | Phase 5 adds sliders; Phase 4 verifies initial 40×40 | N/A |

### Sampling Rate

- **Per task commit:** Load addon in WoW client; `/reload`; observe icon visible on a Pack Leader hunter
- **Per wave merge:** Full visual verification of all 5 success criteria (position, texture, border, drag, persist)
- **Phase gate:** All 5 success criteria pass before `/gsd-verify-work`

### Wave 0 Gaps

None — no automated test infrastructure exists or is needed for WoW addon Lua.

---

## Security Domain

**Not applicable for this phase.** PLBeast is a local WoW addon with no network calls, no user-input parsing, no authentication, and no external data sources. The WoW Lua sandbox enforces its own security model (no filesystem, no network, no OS access). No ASVS categories apply.

---

## Sources

### Primary (MEDIUM confidence — WoW API, official docs)

- [wowpedia.fandom.com/wiki/API_Frame_SetBackdrop](https://wowpedia.fandom.com/wiki/API_Frame_SetBackdrop) — BackdropTemplate + SetBackdrop parameter contract, 9.0.1 change
- [warcraft.wiki.gg/wiki/API_InCombatLockdown](https://warcraft.wiki.gg/wiki/API_InCombatLockdown) — InCombatLockdown return value, lockdown timing, protected vs non-protected frames
- [wowpedia.fandom.com/wiki/Making_draggable_frames](https://wowpedia.fandom.com/wiki/Making_draggable_frames) — SetMovable, RegisterForDrag, StartMoving, StopMovingOrSizing

### Secondary (MEDIUM confidence — cross-checked with PLH source)

- `PackLeaderHelper.lua` lines 309–453 — CreateIcon pattern (extracted directly from codebase)
- `PackLeaderHelper.lua` lines 904–912 — OnDragStart InCombatLockdown guard (extracted from codebase)
- `PackLeaderHelper.lua` lines 1314–1324 — BackdropTemplate SetBackdrop pattern (extracted from codebase)
- `PackLeaderHelper.lua` line 1433 — SetPoint CENTER offset persistence (extracted from codebase)
- `PLBeast/PLBeast.lua` — Current Phase 1–3 implementation; defaults table, SetNextBeastId, RefreshVisibility, event handler structure

### Tertiary (LOW confidence — WebSearch only)

- SetUserPlaced(false) behavior: [wowwiki-archive.fandom.com/wiki/API_Frame_SetUserPlaced](https://wowwiki-archive.fandom.com/wiki/API_Frame_SetUserPlaced) — WebSearch result; flagged LOW

---

## Metadata

**Confidence breakdown:**

- Standard stack: MEDIUM — all APIs are WoW built-ins; no packages; verified against PLH working code and Wowpedia
- Architecture: HIGH — PLH source is ground truth; patterns directly extracted from working 12.x addon
- Pitfalls: MEDIUM — BackdropTemplate pitfall verified; SetUserPlaced pitfall confirmed via search; table ref pitfall is established Lua behavior
- Code examples: MEDIUM — adapted from PLH working code + UI-SPEC.md contracts

**Research date:** 2026-06-21
**Valid until:** 2026-07-21 (WoW frame API is stable; BackdropTemplate has been in place since 9.0.1)
