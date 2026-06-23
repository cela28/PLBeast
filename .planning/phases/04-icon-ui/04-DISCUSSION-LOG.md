# Phase 4: Icon UI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-21
**Phase:** 4-Icon UI
**Areas discussed:** Resize model & defaults, Icon visual treatment, Drag behavior this phase, Position persistence model

---

## Resize Model & Border

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed-px border, sync ON | Border thickness is a literal pixel value (1px at any size); icon starts square 40×40 with sync toggle ON. | ✓ |
| Fixed-px border, sync OFF | Same fixed-pixel border, but width/height independent from the start. | |
| Border scales with icon | Border thickness grows proportionally as the icon grows. | |

**User's choice:** Fixed-px border, sync ON
**Notes:** Confirms deliberate deviation from PLH's uniform `SetScale` — PLBeast uses `SetSize(w,h)` per UI-05. Default 40×40 matches PLH icon size.

---

## Icon Visual Treatment

| Option | Description | Selected |
|--------|-------------|----------|
| Crop edges, full color | `SetTexCoord(0.08–0.92)` trims WoW's built-in border; full color (always-relevant prediction). | ✓ |
| No crop, full color | Raw texture including its built-in beveled border; full color. | |
| Crop edges, desaturated | Trim border but render greyed (mirrors PLH ready-state). | |

**User's choice:** Crop edges, full color
**Notes:** Diverges from PLH's `SetDesaturated(true)` — no "not-ready" greyed state since the icon always shows a live prediction.

---

## Drag Behavior This Phase

| Option | Description | Selected |
|--------|-------------|----------|
| ON by default, silent combat block | Drag enabled now (DB.locked=false); StartMoving is a no-op in combat with no message. | ✓ |
| ON by default, combat notice | Same, but prints a brief chat message on combat-blocked drag. | |
| OFF by default (locked) | Locked until Phase 5 adds the toggle UI. | |

**User's choice:** ON by default, silent combat block
**Notes:** Phase 5 owns the on/off toggle UI. Enabling drag now makes repositioning testable in this phase's MVP slice.

---

## Position Persistence Model

| Option | Description | Selected |
|--------|-------------|----------|
| CENTER + offsetX/offsetY | `SetPoint("CENTER", UIParent, "CENTER", x, y)`; matches PLH line 1433; two persisted numbers. | ✓ |
| Full GetPoint() anchor | Store point/relativePoint/x/y + SetUserPlaced(true); more robust but more state. | |

**User's choice:** CENTER + offsetX/offsetY
**Notes:** Simplest model satisfying the "/reload reappears in place" success criterion; mirrors source addon exactly.

---

## Claude's Discretion

- Icon creation/lifecycle (eager at PLAYER_LOGIN, frame name/strata)
- Texture-refresh hook location (inside `SetNextBeastId()`, event-driven)
- DB defaults representation and merge (offsetX/Y, width/height, syncSize, borderColor/thickness, locked)
- Default border-color RGBA representation (default black 1px)

## Deferred Ideas

None — discussion stayed within phase scope. (Options frame, sliders, color picker, and drag toggle UI are scoped to Phase 5; glow effect is v2 VIS-04.)
