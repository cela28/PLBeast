# Phase 5: Configuration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-21
**Phase:** 5-Configuration
**Areas discussed:** Color picker UX, Frame style & layout, Slash command routing, Toggles & slider ranges

---

## Color picker UX

| Option | Description | Selected |
|--------|-------------|----------|
| Blizzard ColorPickerFrame | Swatch button opens WoW's native ColorPickerFrame dialog (SetupColorPickerAndShow). Standard, familiar, live preview, native alpha slider. | ✓ |
| Inline R/G/B sliders | Three extra sliders in the frame. No popup but clutters the panel, clunky for visual picking. | |
| Preset swatches | Small row of fixed colors. Simplest but not freeform. | |

**User's choice:** Blizzard ColorPickerFrame
**Notes:** —

### Alpha/opacity

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include alpha | borderColor already stores 'a'; ColorPickerFrame opacity slider; allows semi-transparent/invisible border. | ✓ |
| No, RGB only | Keep alpha fixed at 1; thickness=0 could hide border instead. | |

**User's choice:** Yes, include alpha

---

## Frame style & layout

| Option | Description | Selected |
|--------|-------------|----------|
| Blizzard windowed frame | BasicFrameTemplateWithInset — titled draggable window with X close button (PLH pattern). Familiar, free close/drag, minimal code. | ✓ |
| Minimal custom panel | Plain backdrop frame, no title bar; write own close/drag. | |

**User's choice:** Blizzard windowed frame

### Blizzard Settings registration

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone only | Slash-opened frame only; CFG-08 (Settings integration) stays v2. Keeps Phase 5 minimal. | ✓ |
| Register in Settings too | Add to Blizzard AddOns settings list — scope creep into v2 CFG-08. | |

**User's choice:** Standalone only

---

## Slash command routing

| Option | Description | Selected |
|--------|-------------|----------|
| Bare opens frame, keep subs | Bare /plbeast opens/toggles frame (CFG-01); debug/reset stay. Discoverable, no lost functionality. | ✓ |
| Bare opens, drop help text | Bare opens frame; debug/reset stay; old help-text branch removed. | |
| Bare toggles, add 'config' | Bare keeps printing help; add /plbeast config to open frame. Less discoverable. | |

**User's choice:** Bare opens frame, keep subs

### Combat-open behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Defer-open after combat | Block open, set pending flag, auto-open on PLAYER_REGEN_ENABLED (PLH pattern). Smoothest UX. | ✓ |
| Refuse with a message | Print 'can't open in combat' and do nothing. | |
| Refuse silently | No-op, no message. | |

**User's choice:** Defer-open after combat

---

## Toggles & slider ranges

### Drag toggle label/polarity

| Option | Description | Selected |
|--------|-------------|----------|
| Lock position | Checked = locked (drag off). Maps directly to DB.locked. Default unchecked. | ✓ |
| Enable dragging | Checked = draggable; inverts DB.locked in getter/setter. Default checked. | |

**User's choice:** Lock position

### Slider ranges

| Option | Description | Selected |
|--------|-------------|----------|
| 16–128 / 0–8 | Width/height 16–128 (step 1, default 40); thickness 0–8 (step 1, default 1; 0 hides border). | ✓ |
| 24–96 / 1–6 | Tighter ranges; thickness min 1 always keeps visible border. | |
| You decide | Claude picks ranges during planning. | |

**User's choice:** 16–128 / 0–8

---

## Claude's Discretion

- Exact frame name, size, strata, anchor, and vertical ordering/spacing of the six controls
- Reuse PLH CreateSlider/CreateCheckbox verbatim (trimmed) vs. slim PLBeast equivalents
- Slider value-readout text format
- New locale string keys in Locales/enUS.lua
- Placement of residual usage/help text now that bare /plbeast opens the frame

## Deferred Ideas

None — discussion stayed within phase scope. (CFG-05 reset cmd, CFG-06 test mode, CFG-08 Settings integration, VIS-06 border presets all remain v2.)
