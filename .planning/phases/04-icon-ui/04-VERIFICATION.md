---
phase: 04-icon-ui
verified: 2026-06-21T17:05:15Z
status: passed
disposition: "passed-with-deferral — user accepted Phase 4 complete on 2026-06-21; the single human-verification item (criterion 5 size/border visual round-trip) is code-complete and statically verified, with hands-on UI confirmation carried forward to Phase 5 (Configuration), where the settings sliders that change these values are built. This is a planned MVP slice boundary, not a code gap."
carried_forward_to_phase: "05"
score: 4/5
behavior_unverified: 1
overrides_applied: 0
human_verification:
  - test: "Verify that border color and thickness can be changed and persist — change DB values (width=64, height=32, borderThickness=3, non-black borderColor), /reload, confirm independent 64x32 rendering and colored 3px border"
    expected: "Icon renders 64 wide × 32 tall with a 3px colored border; after returning to defaults (40x40, 1px, black) and /reload, the icon renders correctly"
    why_human: "ApplyIconSettings() reads DB.borderThickness and DB.borderColor and calls SetBackdrop/SetBackdropBorderColor — the mechanism is fully present and wired. But whether independent width/height renders correctly versus a clamped or aspect-locked result, and whether the color-picker round-trip round-trips without error, can only be confirmed by visual inspection in the WoW client. Explicit user deferral to Phase 5 (when sliders exist) is documented and accepted."
behavior_unverified_items:
  - truth: "Width and height can be adjusted independently; enabling the sync toggle causes changing one to change both; all size and border settings persist across sessions"
    test: "Edit PLBeastDB width=64, height=32, borderThickness=3, non-black borderColor; /reload; observe rendered icon size and border in-game"
    expected: "Icon is 64px wide and 32px tall (not uniformly scaled), border is 3px and colored; reverting and reloading restores defaults"
    why_human: "SetIconSize uses root:SetSize(w, h) — code is present and wired. Whether the WoW client renders independent width/height faithfully versus any unexpected behavior is a runtime visual property only verifiable in-game. User explicitly deferred hands-on UI verification of size/border changes to Phase 5 per documented MVP slice boundary."
---

# Phase 4: Icon UI Verification Report

**Phase Goal:** A single draggable, scalable icon frame displays the correct next-beast texture with a configurable border, and all position/size settings survive session restarts
**Verified:** 2026-06-21T17:05:15Z
**Status:** passed (with one item deferred to Phase 5 — see Disposition)
**Re-verification:** No — initial verification

> **Disposition (2026-06-21):** User accepted Phase 4 as complete. Criteria 1, 3, 4 are fully verified (code + approved in-game checkpoints). Criterion 2 (border) and criterion 5 (independent width/height, sync toggle, size/border persistence) are code-complete and statically verified; the hands-on *visual* round-trip of changing those values is carried forward to **Phase 5 (Configuration)**, where the settings sliders that drive these values are built. Phase 4 has no UI to change them, so this verification can only happen in Phase 5. Tracked as a Phase 5 UAT carry-forward — not a Phase 4 code gap.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | The icon displays the correct wyvern/boar/bear texture matching the predicted next beast | VERIFIED | `ICON_FILE_BY_ID` maps wyvern=773276/boar=132184/bear=132183; `SetNextBeastId()` guards `if root and root.tex then root.tex:SetTexture(ICON_FILE_BY_ID[nextBeastId])` (line 153–155); texture set on creation in `CreateBeastIcon()` (line 585); user-verified in-game (Plan 01 checkpoint approved) |
| 2 | The icon has a visible square border; border color and thickness default to black/1px and can be changed | VERIFIED (code); ⚠️ PRESENT_BEHAVIOR_UNVERIFIED (changed values) | BackdropTemplate border child created at line 592; `ApplyIconSettings()` calls `SetBackdrop` with `edgeSize = DB.borderThickness or 1` and `SetBackdropBorderColor` reading `DB.borderColor`; defaults are `borderThickness=1, borderColor={r=0,g=0,b=0,a=1}`; black 1px border user-verified in-game. The "can be changed" runtime behavior is code-complete but hands-on UI verification deferred to Phase 5 per user decision |
| 3 | Dragging is toggled on/off; the icon cannot be moved during combat lockdown | VERIFIED | `OnDragStart` returns silently when `DB.locked` is true (line 599) OR when `InCombatLockdown and InCombatLockdown()` (line 600) — no chat message in either branch; user verified in-game (combat silently blocks drag, Plan 02 checkpoint approved) |
| 4 | After dragging and /reload, the icon reappears at the same position | VERIFIED | `OnDragStop` computes `DB.offsetX = fx - cx` / `DB.offsetY = fy - cy` (lines 611–612) using center-offset arithmetic; re-anchors via `ClearAllPoints()` + `SetPoint("CENTER", UIParent, "CENTER", DB.offsetX, DB.offsetY)` (lines 613–614); `SetUserPlaced(false)` suppresses LayoutCache double-source (line 605); `ApplyIconSettings()` re-applies persisted offsets on login (line 548); user verified drag persists across /reload and full logout (Plan 02 checkpoint approved) |
| 5 | Width and height can be adjusted independently; sync toggle mirrors them; all size and border settings persist across sessions | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `SetIconSize(w, h)` uses `root:SetSize(DB.width, DB.height)` (line 536) — never SetScale; sync mirror logic present (lines 530–533); border persistence wired through `ApplyIconSettings()`; DB keys `width`, `height`, `syncSize`, `borderThickness`, `borderColor` all in defaults and persisted to PLBeastDB. Runtime visual verification of independent resize deferred to Phase 5 per user decision |

**Score:** 4/5 truths verified (1 present, behavior-unverified — code wired, runtime visual confirmation deferred to Phase 5)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `PLBeast/PLBeast.lua` | CreateBeastIcon() frame constructor, ICON_FILE_BY_ID map, root upvalue, defaults extension, texture hook, visibility bridge | VERIFIED | All symbols present and substantive; CreateBeastIcon at line 573, ICON_FILE_BY_ID at line 74, local root forward-declared at line 118, defaults extended at lines 17–25, texture hook in SetNextBeastId lines 152–155, visibility bridge in RefreshVisibility lines 497–500 |
| `PLBeast/PLBeast.lua` | OnDragStart/OnDragStop handlers with combat guard + center-offset persistence, ApplyIconSettings() for size/position/border, sync-aware SetIconSize | VERIFIED | OnDragStart lines 598–602, OnDragStop lines 603–615, ApplyIconSettings lines 542–566, SetIconSize lines 524–537; git commits 7bc8b5c and a5349df confirmed |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `SetNextBeastId()` | `root.tex` | `root.tex:SetTexture(ICON_FILE_BY_ID[nextBeastId])` guarded by `if root and root.tex then` | WIRED | Lines 152–155; guard prevents crash before frame exists at ADDON_LOADED (Pitfall 5 addressed) |
| `RefreshVisibility()` | `root` | `if root then root:SetShown(isPackLeaderActive) end` | WIRED | Lines 497–500; bridge at end of function after UNIT_AURA branch |
| `PLAYER_LOGIN handler` | `CreateBeastIcon()` | `CreateBeastIcon()` called at line 675, before `RefreshVisibility()` at line 678 | WIRED | Ordering confirmed: CreateBeastIcon() → RefreshVisibility(); initial SetShown fires on an existing root |
| `OnDragStop` | `DB.offsetX/DB.offsetY` | Center-offset capture with `SetUserPlaced(false)` suppression | WIRED | Lines 605–614; arithmetic correct, LayoutCache suppression present, GetLeft nil-guard present |
| `OnDragStart` | `InCombatLockdown` | Silent return when `InCombatLockdown()` is true; no chat message | WIRED | Line 600; confirmed no Print/chat call inside combat branch |
| `CreateBeastIcon/PLAYER_LOGIN` | `ApplyIconSettings()` | `ApplyIconSettings()` called at end of CreateBeastIcon (line 619) | WIRED | Delegation order: frame + texture + border child + drag scripts → `root = f` → `ApplyIconSettings()` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `CreateBeastIcon()` — icon texture | `nextBeastId` | Module-level state set by `SetNextBeastId()`; seeded from `ID_BY_INDEX[DB.nextIndex]` in ADDON_LOADED | Yes — driven by CDM aura polling | FLOWING |
| `ApplyIconSettings()` — border | `DB.borderThickness`, `DB.borderColor` | PLBeastDB SavedVariables; defaults `1` and `{r=0,g=0,b=0,a=1}` | Yes — read directly from persisted DB | FLOWING |
| `ApplyIconSettings()` — position | `DB.offsetX`, `DB.offsetY` | PLBeastDB SavedVariables; defaults `0,0`; written by OnDragStop | Yes — persisted center-offset | FLOWING |
| `ApplyIconSettings()` — size | `DB.width`, `DB.height` | PLBeastDB SavedVariables; defaults `40,40` | Yes — persisted dimensions | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — WoW Lua addon; no runnable entry points outside the WoW client. There is no test runner and no CLI. Behavioral verification is handled by the in-game human checkpoints (both approved by user).

### Probe Execution

Step 7c: SKIPPED — No `scripts/*/tests/probe-*.sh` files exist; phase is a WoW addon with no probe infrastructure.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| UI-01 | 04-01-PLAN.md | Single icon displays the next beast's texture (wyvern/boar/bear) | SATISFIED | `ICON_FILE_BY_ID` + `SetNextBeastId()` texture hook + `CreateBeastIcon()` texture creation; user-verified in-game |
| UI-02 | 04-01-PLAN.md | Icon has a square border using BackdropTemplate (WHITE8X8 edge texture) with configurable color and thickness; default: black, 1px | SATISFIED (default); DEFERRED (UI config to Phase 5) | BackdropTemplate border child created; `ApplyIconSettings()` applies `DB.borderThickness` and `DB.borderColor`; defaults black/1px user-verified in-game; UI for changing these is Phase 5 |
| UI-03 | 04-02-PLAN.md | Icon dragging is toggled on/off (not always draggable); blocked during combat lockdown | SATISFIED | `OnDragStart` guards `DB.locked` and `InCombatLockdown()`; silent no-op confirmed; user-verified in-game |
| UI-04 | 04-02-PLAN.md | Icon position persists across sessions via SavedVariables | SATISFIED | `OnDragStop` writes `DB.offsetX/offsetY` to PLBeastDB; `ApplyIconSettings()` re-applies on login; user-verified across /reload and full logout |
| UI-05 | 04-02-PLAN.md | Icon width and height are independently adjustable, with a toggle to sync them | SATISFIED (code); UI deferred to Phase 5 | `SetIconSize` uses `root:SetSize(w, h)`, never SetScale; `DB.syncSize` mirror logic present |
| UI-06 | 04-02-PLAN.md | Border color and thickness persist across sessions | SATISFIED | `DB.borderThickness` and `DB.borderColor` in defaults; `ApplyIconSettings()` applies on login |
| UI-07 | 04-02-PLAN.md | Icon width, height, and sync-toggle setting persist across sessions | SATISFIED | `DB.width`, `DB.height`, `DB.syncSize` in defaults; written by `SetIconSize`; applied via `ApplyIconSettings()` on login |

All 7 phase requirements (UI-01 through UI-07) are accounted for. No orphaned requirements.

### Anti-Patterns Found

No TBD/FIXME/XXX markers found. No placeholder patterns found. No return-null stubs found. No SetScale usage found (prohibited — anti-pattern avoided). The BackdropTemplate field-access guard `if root.border and root.border.SetBackdrop then` correctly avoids colon-call nil-method crash.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | — |

### Human Verification Required

#### 1. Independent resize and border color/thickness change via SavedVariables

**Test:** Edit `PLBeastDB` in the SavedVariables file to set `width=64, height=32, borderThickness=3` and a non-black `borderColor` (e.g. `{r=1, g=0.5, b=0, a=1}`). Do `/reload`. Observe the rendered icon.

**Expected:** Icon renders 64px wide by 32px tall (not uniformly scaled square) with a 3px orange border. Return values to `width=40, height=40, borderThickness=1, borderColor={r=0,g=0,b=0,a=1}` and `/reload`; icon returns to clean 40x40 black-1px state.

**Why human:** `ApplyIconSettings()` reads `DB.borderThickness`/`DB.borderColor` and calls `SetBackdrop`/`SetBackdropBorderColor`; `SetIconSize` calls `root:SetSize(DB.width, DB.height)`. The mechanism is fully wired. Whether the WoW client renders independent non-square dimensions faithfully and whether a non-default borderColor applies without Lua error can only be confirmed visually in-game. This verification was explicitly deferred by the user to Phase 5 (when sliders exist as the control surface), per the documented Phase 4 MVP slice boundary.

### Gaps Summary

No gaps. All implementation is code-complete and structurally correct. The single item routed to human verification (criterion 5's runtime visual confirmation, and criterion 2's "can be changed" path) is a planned deferral to Phase 5, not a missing implementation. The mechanism is present and wired:

- `SetIconSize(w, h)` uses `root:SetSize(DB.width, DB.height)` (never SetScale)
- `DB.syncSize` mirror logic: `if DB.syncSize then local s = max(w,h); w = s; h = s end`
- `ApplyIconSettings()` reads `DB.borderThickness` and `DB.borderColor.r/g/b/a` with fallbacks
- All 8 DB keys are in `defaults` and persisted to PLBeastDB

The user approved both in-game human checkpoints (Plan 01: icon/texture/border/visibility; Plan 02: drag persists across reload and logout, combat guard is silent). The hands-on UI path for size/border changes is deferred to Phase 5 sliders.

---

_Verified: 2026-06-21T17:05:15Z_
_Verifier: Claude (gsd-verifier)_
