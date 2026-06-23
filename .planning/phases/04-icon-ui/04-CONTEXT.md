# Phase 4: Icon UI - Context

**Gathered:** 2026-06-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Create the single next-beast icon frame for PLBeast. This phase delivers a draggable, scalable icon that displays the correct beast texture (wyvern/boar/bear) matching the current rotation prediction, with a configurable square border, and persists its position and size settings across sessions.

The icon is created eagerly (at `PLAYER_LOGIN`) and its visibility is driven by Phase 3's `isPackLeaderActive` flag (`root:SetShown(isPackLeaderActive)`). The icon texture updates as the rotation advances, hooking into the existing event-driven rotation engine — no polling loop is added.

**In scope:** icon frame, beast-texture display, square border (color + thickness), independent width/height with sync toggle, drag-to-reposition (enabled by default this phase), and persistence of position/size/border settings.

**Out of scope (later phases):** the options frame and its sliders/color-picker/toggles (Phase 5 — CFG-01..04), the slash-command-opened config UI, and the release pipeline (Phase 6). No cooldown timer, wyvern-buff, or hogstrider tracking (those stay in PackLeaderHelper, per PROJECT.md).

</domain>

<decisions>
## Implementation Decisions

### Resize Model & Border (UI-02, UI-05, UI-06, UI-07)
- **D-01:** Resizing uses `frame:SetSize(width, height)` — NOT PLH's uniform `SetScale`. Width and height are independently adjustable per UI-05, which is a deliberate deviation from PackLeaderHelper's single-scale model.
- **D-02:** The width/height **sync toggle defaults ON** — the icon starts square, and while sync is on, changing one dimension changes both. Default size is **40×40** (matching PLH's icon size).
- **D-03:** Border thickness is a **fixed pixel value** (a literal `edgeSize` in px) that does NOT scale with the icon — a "1px" border looks 1px at any icon size. Border defaults: **black, 1px** (per UI-02). Border uses `BackdropTemplate` with the `WHITE8X8` edge texture (locked by UI-02/REQUIREMENTS.md).

### Visual Treatment (UI-01)
- **D-04:** The beast texture is cropped with `SetTexCoord(0.08, 0.92, 0.08, 0.92)` to trim WoW's built-in beveled icon border (PLH `CreateIcon` pattern), giving a clean flush look inside the configurable border.
- **D-05:** The icon is displayed in **full color** (NOT desaturated). It represents an always-relevant prediction, so there is no "not-ready"/greyed state — this diverges from PLH's `SetDesaturated(true)` ready-state treatment.
- **D-06:** Beast texture file IDs (from PackLeaderHelper, confirmed): wyvern = `773276` (`ICON_DRAGON_READY`), boar = `132184` (`ICON_PIG_READY`), bear = `132183` (`ICON_BEAR_READY`). Drive texture selection from the existing `nextBeastId` state in `PLBeast.lua`.

### Drag Behavior (UI-03, UI-04)
- **D-07:** Dragging is **ON by default this phase**, persisted via a DB flag (e.g. `DB.locked = false`). Phase 5 adds the on/off toggle UI; enabling drag now makes repositioning testable in this phase's MVP slice.
- **D-08:** During combat lockdown, drag is **silently blocked** — `OnDragStart`/`StartMoving` becomes a no-op guarded by `InCombatLockdown()`, with no error and no chat message (PLH pattern, line ~905).

### Position Persistence (UI-04)
- **D-09:** Position persists as **`DB.offsetX` / `DB.offsetY`** and is applied via `SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)` — exactly the PackLeaderHelper pattern (line 1433). On drag stop, capture the new center offset back into `DB.offsetX/offsetY`. Simplest model; two persisted numbers; survives `/reload`.

### Claude's Discretion
- **Icon creation/lifecycle:** Create the frame eagerly at `PLAYER_LOGIN` (PLH pattern); wire `root:SetShown(isPackLeaderActive)` into the existing visibility refresh from Phase 3. Exact frame name (`PLBeastFrame` or similar) and strata are Claude's choice.
- **Texture-refresh hook:** Update the icon texture wherever `SetNextBeastId()` resolves a new `nextBeastId` (and on show), keeping the event-driven architecture from Phase 2 D-01 — no new poll loop.
- **DB defaults & merge:** Add `offsetX`, `offsetY`, `width`, `height`, `syncSize`, `borderColor`, `borderThickness`, `locked` to the `defaults` table in `PLBeast.lua` (line ~14) and let the existing flat-defaults merge (D-06 from Phase 1) populate them. Exact default border color representation (RGBA table) is Claude's choice; default is black 1px.
- **Combat-deferred apply:** If size/border changes are ever requested during combat (not expected this phase since options UI is Phase 5), defer via `PLAYER_REGEN_ENABLED` — but this phase only needs the drag combat-guard.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Definition
- `.planning/PROJECT.md` — Core value, constraints, extraction context, key decisions (minimal icon, draggable+scalable, own CDM reading)
- `.planning/REQUIREMENTS.md` — Phase 4 maps to UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07 (full text + v2 deferrals like VIS-04 glow)
- `.planning/ROADMAP.md` § "Phase 4: Icon UI" — Goal and 5 success criteria

### Prior Phase Context
- `.planning/phases/03-visibility-gating/03-CONTEXT.md` — `isPackLeaderActive` flag is the show/hide bridge for this phase; event-driven visibility
- `.planning/phases/02-rotation-tracking/02-CONTEXT.md` — Event-driven rotation, snapshot-diff, `nextBeastId` state
- `.planning/phases/01-addon-scaffold/01-CONTEXT.md` — DB init flow, flat-defaults merge, interface version

### Source Addon (extraction reference)
- `PackLeaderHelper.lua` lines 29–35, 57–64 — Beast texture file ID constants and `ICON_FILE_BY_ID` map (`ICON_DRAGON_READY=773276`, `ICON_PIG_READY=132184`, `ICON_BEAR_READY=132183`)
- `PackLeaderHelper.lua` lines 309–420 — `CreateIcon()`: frame/texture creation, `SetTexCoord(0.08, 0.92, ...)` crop, sizing
- `PackLeaderHelper.lua` lines 455–465 — `SetMovable`/`RegisterForDrag` drag wiring pattern
- `PackLeaderHelper.lua` lines ~900–915 — `OnDragStart`/`OnDragStop` with `InCombatLockdown()` combat guard
- `PackLeaderHelper.lua` line 1433 — `SetPoint("CENTER", UIParent, "CENTER", DB.offsetX, DB.offsetY)` position persistence
- `PackLeaderHelper.lua` lines 1316–1324 — `BackdropTemplate`/`SetBackdrop` + `SetBackdropBorderColor` border reference (adapt to WHITE8X8 per UI-02)

### PLBeast Code (current state, Phases 1–3 output)
- `PLBeast/PLBeast.lua` — `defaults` table (~line 14), `SetNextBeastId()`/`nextBeastId` state (~line 103), `ID_BY_INDEX`/`INDEX_BY_ID` maps, visibility flag, event frame, slash commands
- `PLBeast/PLBeast.toc` — TOC with SavedVariablesPerCharacter declaration
- `PLBeast/Locales/enUS.lua` — Locale table (add any new UI strings here)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `PLBeast.lua` `nextBeastId` + `SetNextBeastId()`: the icon reads `nextBeastId` to pick its texture. Hook texture refresh into `SetNextBeastId()`.
- `PLBeast.lua` `defaults` table (~line 14): extend with position/size/border/lock keys; the existing flat-defaults merge populates them on load.
- PLH `CreateIcon()` (lines 309–420): direct reference for frame + cropped texture creation; strip the cooldown swipe / desaturation / glow sub-objects PLBeast doesn't need.
- PLH border + position patterns (lines 1316–1324, 1433): adapt for WHITE8X8 backdrop border and CENTER-offset persistence.

### Established Patterns
- Event-driven architecture (Phase 2 D-01): icon texture updates on rotation-advance events, not via a poll tick.
- Faithful extract-and-trim (Phase 2 D-03): copy PLH's icon/drag/border code, strip the multi-icon/CDM/glow concerns out of scope for a single icon.
- Visibility bridge (Phase 3 D-01): `root:SetShown(isPackLeaderActive)` — no extra logic needed.
- Combat lockdown guards (`InCombatLockdown()`) gate any frame mutation (PLH convention).

### Integration Points
- `PLAYER_LOGIN` handler: create the icon frame after DB load; apply persisted position/size/border; call the Phase 3 visibility refresh to set initial shown state.
- Phase 3 `RefreshVisibility()`: add `root:SetShown(isPackLeaderActive)` so the icon hides/shows with the flag.
- `SetNextBeastId()`: after resolving `nextBeastId`, push the matching texture onto the icon.

</code_context>

<specifics>
## Specific Ideas

- Deviate from PLH where the single-icon scope calls for it: independent width/height (not uniform scale), full-color always-on display (not desaturated ready-state), fixed-pixel border. Everything else mirrors PLH's proven icon/drag/position code.
- Keep the icon minimal — no label text (PROJECT.md key decision), no cooldown swipe, no glow (glow is v2 VIS-04).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Options frame / sliders / color-picker / drag toggle UI are already scoped to Phase 5; glow effect is v2 VIS-04.)

</deferred>

---

*Phase: 4-Icon UI*
*Context gathered: 2026-06-21*
