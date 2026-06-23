# Phase 5: Configuration - Context

**Gathered:** 2026-06-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a lightweight, slash-command-opened options frame for PLBeast that lets the player adjust every existing icon setting from a single UI, with changes applying live to the icon (no `/reload`), and the frame blocked from opening during combat lockdown.

**In scope (CFG-01..04):**
- `/plbeast` opens (toggles) the options frame; combat-blocked open with deferred-open after combat
- Options frame containing: width slider, height slider, border-thickness slider, border **color picker**, a **drag (lock) toggle**, and a **width/height sync toggle**
- Live-apply: every control calls the existing `SetIconSize()` / `ApplyIconSettings()` setters so the icon updates immediately
- Combat guard: the frame cannot be opened while `InCombatLockdown()` is true (CFG-04)

**Also delivers (carried forward from Phase 4 verification):** First hands-on, in-game verification — via these new controls — that independent width/height resize, the sync toggle, and border color/thickness changes render correctly and persist across `/reload`. The underlying setters (`SetIconSize`, `ApplyIconSettings`) and DB persistence are already complete and statically verified; Phase 5 is where they finally have a UI to drive them. See `.planning/phases/04-icon-ui/04-VERIFICATION.md` (Disposition).

**Out of scope:**
- Blizzard Settings (Interface > AddOns) registration — explicitly v2 **CFG-08**
- New persisted settings or new icon behaviors (all DB keys already exist from Phase 4)
- Reset-position subcommand (**CFG-05**, v2), test/demo mode (**CFG-06**, v2)
- Release pipeline (Phase 6)

</domain>

<decisions>
## Implementation Decisions

### Color Picker (CFG-02)
> **DESCOPED (Phase 5, per user, 2026-06-22):** the color picker (D-01, D-02) was removed during in-game verification — the user did not want it and is happy with a fixed black border. Plan 05-02 was deleted; the border is now four solid black edge textures sized by the thickness slider. D-01/D-02 below are retained for history only.

- **D-01:** Use WoW's **native global `ColorPickerFrame`** via `SetupColorPickerAndShow` (the modern table-arg API). The frame shows a color **swatch button**; clicking it opens the native dialog. No custom color UI is built. This is **net-new** — PackLeaderHelper has `CreateSlider`/`CreateCheckbox` but no color picker, so there is no PLH precedent to copy for this widget specifically.
- **D-02:** **Expose alpha/opacity.** `DB.borderColor` already stores `{r,g,b,a}`. Enable the ColorPickerFrame opacity slider (`hasOpacity = true`, seed `opacity` from `a`). Color changes (including alpha) live-apply through `ApplyIconSettings()` via the picker's `swatchFunc`/`opacityFunc` callbacks, and the dialog's `cancelFunc` restores the previous `{r,g,b,a}`.

### Frame Style & Layout (CFG-01, CFG-02, CFG-03)
- **D-03:** Build the options frame with **`BasicFrameTemplateWithInset`** — a Blizzard-standard movable window with a title bar and an X close button (PLH `ToggleOptions` pattern, line 1032). Free close/drag behavior, familiar WoW look, minimal code.
- **D-04:** **Standalone only** — opened solely via the slash command. Do **not** register in Blizzard's AddOns settings list (that is v2 CFG-08).
- **D-05:** Lazy-create the frame on first open (cache the reference), mirroring PLH where the options panel is built inside `ToggleOptions`. Subsequent `/plbeast` calls toggle show/hide.

### Slash Command Routing (CFG-01)
- **D-06:** **Bare `/plbeast` opens/toggles the options frame.** Keep the existing `/plbeast debug` and `/plbeast reset` subcommands working unchanged. The current bare-command help-text branch is replaced by the frame open (a short usage line can move under an unknown-arg fallback if desired — Claude's discretion).
- **D-07:** **Combat-open → defer.** If `/plbeast` is typed during combat, block the open, set a `pendingOptionsOpenAfterCombat`-style flag, and auto-open on `PLAYER_REGEN_ENABLED` (PLH pattern, lines 321 / 1021-1027 / 2623-2626). This satisfies CFG-04 with the smoothest UX. Register `PLAYER_REGEN_ENABLED` if not already.

### Toggles & Slider Ranges (CFG-02, CFG-03)
- **D-08:** **Drag toggle is labeled "Lock position"** — checked = locked (drag off), unchecked = draggable. Maps **directly** to `DB.locked` (checked ⇔ `DB.locked = true`), no inversion. Default **unchecked** (Phase 4 set `locked = false`). Setter just writes `DB.locked`; the existing drag scripts already honor it.
- **D-09:** ~~**Width/height sync toggle** labeled e.g. "Sync width & height" maps directly to `DB.syncSize` (default **checked / true**, per Phase 4 D-02). When on, changing one dimension mirrors to the other — this behavior already lives inside `SetIconSize()`; the toggle just flips `DB.syncSize` and re-applies.~~ **DESCOPED (Phase 5, per user, 2026-06-22):** the sync toggle and all `DB.syncSize` mirroring were removed during in-game verification — the user did not want the feature. Width and height are now always independent. The `SetIconSize` mirror block, the Sync checkbox, height-slider dimming, `SetSliderEnabled`, the `syncSize` default, and the locale string were all removed.
- **D-10:** **Slider ranges:** width & height **16–128**, step **1**, default **40**. Border thickness **0–8**, step **1**, default **1**. Thickness `0` effectively hides the border, complementing the alpha control. Sliders are integer-valued and call `SetIconSize()` (width/height) or `ApplyIconSettings()` (thickness) on change for live-apply.

### Live-Apply & Combat Nuance
- **D-11:** Live-apply uses the **already-built setters** — `SetIconSize(w, h)` for dimensions and `ApplyIconSettings()` for border thickness/color. No new application logic is needed; widgets are thin getter/setter bindings over `DB`.
- **D-12:** Adjusting settings **while in combat** (frame already open, e.g. it was open before combat started) is **allowed** — the PLBeast root is a normal (non-secured) frame, so `SetSize`/`SetBackdrop` are not lockdown-restricted. Only **opening** the frame is combat-gated (D-07). No deferral of value changes is required.

### Claude's Discretion
- Exact options-frame name, size, strata, anchor, and the vertical ordering/spacing of the six controls.
- Whether to reuse PLH's `CreateSlider`/`CreateCheckbox` helpers verbatim (trimmed) or write slim PLBeast equivalents — both fine; keep it minimal and single-file.
- Slider value-readout text (showing the current numeric value next to each slider) — recommended for usability but format is Claude's call.
- New locale strings for all labels go in `Locales/enUS.lua` (CFG labels are net-new).
- Where the residual usage/help text (if any) lands now that bare `/plbeast` opens the frame.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Definition
- `.planning/PROJECT.md` — Core value, constraints (minimal addon, combat lockdown, single-file), key decisions
- `.planning/REQUIREMENTS.md` — Phase 5 maps to **CFG-01, CFG-02, CFG-03, CFG-04**; note v2 deferrals **CFG-05** (reset cmd), **CFG-06** (test mode), **CFG-08** (Blizzard Settings integration) are explicitly out of scope
- `.planning/ROADMAP.md` § "Phase 5: Configuration" — Goal, 4 success criteria, and the "Carried forward from Phase 4" verification note

### Prior Phase Context
- `.planning/phases/04-icon-ui/04-CONTEXT.md` — All settings keys, resize model (`SetSize` not `SetScale`), sync-toggle default-ON (D-02), border model (WHITE8X8, fixed-px thickness), `DB.locked` drag flag, combat-guard pattern (D-08)
- `.planning/phases/04-icon-ui/04-VERIFICATION.md` (Disposition) — The deferred hands-on verification items this phase finally enables

### PLBeast Code (current state — Phase 5 builds directly on this)
- `PLBeast/PLBeast.lua` line ~14 — `defaults` table: `width=40`, `height=40`, `syncSize=true`, `borderThickness=1`, `borderColor={r=0,g=0,b=0,a=1}`, `locked=false`, `offsetX/offsetY` — **all settings keys already exist**
- `PLBeast/PLBeast.lua` lines ~524-536 — `SetIconSize(w, h)`: handles sync mirroring, persists to `DB.width/height`, calls `root:SetSize` (bind width/height sliders here)
- `PLBeast/PLBeast.lua` lines ~542-566 — `ApplyIconSettings()`: applies size, position, and border backdrop/color from `DB` (bind thickness slider + color picker here)
- `PLBeast/PLBeast.lua` lines ~670-686 — current `SLASH_PLBEAST1` handler routing `debug` | `reset` | help (extend so bare cmd opens the frame; keep subcommands)
- `PLBeast/PLBeast.lua` lines ~124 (`Print`), ADDED_LOADED DB-coercion guards (~648-660), event registration block (~713-718)
- `PLBeast/Locales/enUS.lua` — Locale table; add all new CFG UI label strings here
- `PLBeast/PLBeast.toc` — SavedVariablesPerCharacter declaration

### Source Addon (extraction reference for the options UI)
- `PackLeaderHelper.lua` line 552 — `CreateSlider(parent, label, min, max, step, getValue, setValue, yOffset, isInteger, decimals)` helper to reuse/trim
- `PackLeaderHelper.lua` line 629 — `CreateCheckbox(parent, label, getValue, setValue, xOffset, yOffset)` helper to reuse/trim
- `PackLeaderHelper.lua` lines 1021-1032 — `ToggleOptions()` + `BasicFrameTemplateWithInset` frame creation; combat-pending-open guard
- `PackLeaderHelper.lua` line 321 + lines 2623-2626 — `pendingOptionsOpenAfterCombat` flag and `PLAYER_REGEN_ENABLED` deferred-open handling
- **Note:** PackLeaderHelper has **no color picker** — the swatch + `SetupColorPickerAndShow` widget (D-01/D-02) must be written fresh against the WoW global `ColorPickerFrame` API; no in-repo precedent

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SetIconSize()` / `ApplyIconSettings()` in `PLBeast.lua` — the live-apply backbone; every slider/picker is a thin binding over these. No new apply logic needed (D-11).
- All `DB` setting keys already exist with correct defaults (Phase 4) — sliders/toggles read/write existing fields; no new persistence or defaults-merge work.
- PLH `CreateSlider` / `CreateCheckbox` (lines 552, 629) — copy-and-trim source for the widget factories.
- PLH `ToggleOptions` (line 1021) — direct template for lazy frame creation + combat-pending-open.

### Established Patterns
- Faithful extract-and-trim from PackLeaderHelper (Phase 2 D-03) — copy proven UI helpers, strip the multi-icon/layout-editor concerns PLBeast doesn't have.
- Combat lockdown guards (`InCombatLockdown()`) gate frame open; deferred action on `PLAYER_REGEN_ENABLED` (PLH convention).
- Single-file architecture — all options UI lives in `PLBeast.lua`; strings in `Locales/enUS.lua`.
- DB-field type coercion guards already added in ADDON_LOADED (`tonumber`, borderColor table guard) — sliders writing numeric values stay consistent with these.

### Integration Points
- Slash handler (`SLASH_PLBEAST1` / `SlashCmdList["PLBEAST"]`, ~line 672): bare command → open/toggle frame (combat-deferred); `debug`/`reset` unchanged.
- `PLAYER_REGEN_ENABLED` event: add handler to flush a pending options-open (register the event in the PLAYER_LOGIN block alongside existing registrations).
- Color picker callbacks: `swatchFunc`/`opacityFunc` → write `DB.borderColor` then `ApplyIconSettings()`; `cancelFunc` → restore prior `{r,g,b,a}`.

</code_context>

<specifics>
## Specific Ideas

- Mirror PackLeaderHelper's look and helpers wherever they exist (windowed frame, slider/checkbox factories) so PLBeast feels consistent with its parent — but the color picker is deliberately net-new on top of WoW's native dialog.
- Keep the panel minimal: six controls (3 sliders, 1 color swatch, 2 checkboxes) plus title/close. No tabs, no scroll, no extra chrome.
- Show the current numeric value beside each slider for at-a-glance feedback (recommended).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Reset-position subcommand = v2 CFG-05; test/demo mode = v2 CFG-06; Blizzard Settings registration = v2 CFG-08; border style presets = v2 VIS-06.)

</deferred>

---

*Phase: 5-Configuration*
*Context gathered: 2026-06-21*
