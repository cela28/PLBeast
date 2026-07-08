# PLBeast

## What This Is

PLBeast is a standalone World of Warcraft addon that predicts and displays which beast will spawn next in the Pack Leader hero talent rotation (wyvern → boar → bear → wyvern). It's being extracted from PackLeaderHelper as an independent, minimal addon — just a single draggable/scalable icon showing the next beast.

## Core Value

Accurately predict and display the next beast in the Pack Leader rotation so the player always knows what's coming.

## Requirements

### Validated

- [x] Display a single icon showing the next beast (no label text) — *Validated in Phase 4: Icon UI*
- [x] Icon is draggable — user can reposition by clicking and dragging — *Validated in Phase 4: Icon UI (left-drag with silent combat-lockdown guard)*
- [x] Persist position across sessions (SavedVariables) — *Validated in Phase 4: Icon UI (center-offset persists across /reload and full logout)*
- [x] Only show when Pack Leader hero talent is active — *Validated in Phase 3: Visibility Gating; icon show/hide bridge wired in Phase 4*
- [x] Support both Beast Mastery and Survival hunter specs — *Validated in Phase 3: Visibility Gating*
- ✓ Independently read CDM state to detect beast ready buffs (wyvern, boar, bear) — v1.0 (Phase 2, rebuilt in Phase 5.1 as CDM-frame `auraInstanceID` reads; `C_UnitAuras` fully removed)
- ✓ Track the cyclic beast spawn order (wyvern → boar → bear) — v1.0 (`NEXT_BEAST` ring)
- ✓ Advance the prediction when a beast actually spawns — v1.0 (Phase 5.1 self-correcting model: pin-on-ready, advance-on-consume)
- ✓ Icon is scalable — user can adjust size — v1.0 (Phase 5 sliders; verified in-game)
- ✓ Persist scale/size and border settings across sessions — v1.0 (Phase 5)
- ✓ Options panel / slash command for configuration — v1.0 (Phase 5: `/plbeast` combat-guarded options window)
- ✓ Event-driven detection with negligible idle CPU — v1.0.1 (1Hz `POLL_INTERVAL` throttle; measured 0.001ms avg / 0.03% of app in-game)
- ✓ Start-of-rotation anchor to wyvern + reset on login/boss pull — v1.0.1 (TRACK-03 re-added)
- ✓ Text display mode: colored beast name instead of icon (TEXT-01..06) — Phase 7 (Okabe-Ito default colors, per-beast ColorPickerFrame, font-size slider, mode-conditional options relayout + text-outline cycle control; in-game UAT 9/9)

### Active

(None — v1.0 shipped. Next milestone requirements defined via `/gsd-new-milestone`.)

### Out of Scope

- Modifying PackLeaderHelper — this project is PLBeast only
- Cooldown timer tracking (that stays in PackLeaderHelper)
- Wyvern buff duration/extend tracking (that stays in PackLeaderHelper)
- Hogstrider tracking (that stays in PackLeaderHelper)
- Any dependency on PackLeaderHelper being installed

## Context

- Extracted from PackLeaderHelper, a 2675-line single-file WoW addon that tracks Pack Leader hero talent cooldowns and beast states
- The "next beast" prediction logic lives in PackLeaderHelper around lines 1494–1676: `NEXT_BEAST` rotation table, `SyncNextFromAddedReady()`, `SetNextBeastId()`, `NormalizeNextIndex()`
- The existing NEXT bar UI is at lines 502–520 (`CreateNextBar`) and 2290–2319 (`UpdateNextBar`)
- PLBeast needs its own CDM integration to read beast ready buffs independently — can reference PackLeaderHelper's CDM cache pattern (lines 1805–1949) but must be self-contained
- WoW addon constraints: single-threaded Lua, no file I/O, combat lockdown restrictions on UI manipulation, SavedVariables for persistence
- Target WoW version: The War Within (12.0.x) — CDM (`C_CooldownViewer`) is the sole beast-detection source as of v1.0.1

**Shipped state (v1.0.1, 2026-07-01):**
- Single-file addon: `PLBeast/PLBeast.lua` (~830 lines) + `PLBeast.toc` + `Locales/enUS.lua`
- Detection: CDM-frame `auraInstanceID` reads driven by a 1Hz OnUpdate poll (`POLL_INTERVAL = 1.0`); self-correcting prediction; `C_UnitAuras` removed
- Distribution: GitHub Releases only, tag-triggered (`v*`) Actions workflow; `main` holds only `PLBeast/` + `.github/`
- Released v1.0.0 then v1.0.1; in-game UAT 7/7 on v1.0.1
- Known non-blocking observation: ~1s wyvern→boar visual delay is the 1Hz cadence tradeoff (tunable via `POLL_INTERVAL`)

## Constraints

- **Runtime**: WoW Lua sandbox — no external libraries, no coroutines for async, no file system access
- **Combat lockdown**: Cannot create/move frames during combat; must handle gracefully
- **CDM dependency**: Requires Blizzard Cooldown Manager to be enabled and tracking Pack Leader buff spells
- **Addon size**: Should be minimal — small .toc, one or two .lua files, locale support

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fully independent from PackLeaderHelper | Users may want next-beast prediction without the full PLH tracker | ✓ Good — shipped standalone, no PLH dependency |
| Minimal icon only (no label text) | Clean, unobtrusive UI that blends with other addons | ✓ Good — Phase 4 |
| Draggable + scalable icon | Standard WoW addon UX for movable elements | ✓ Good — drag Phase 4, scale sliders Phase 5 |
| Own CDM/aura reading | No inter-addon communication needed; works standalone | ✓ Good — CDM-frame reads; `C_UnitAuras` removed in 5.1 |
| CDM as sole detection source (5.1) | Match AzortharionUI; CDM is authoritative on 12.x | ✓ Good — verified in-game |
| Event-driven poll, not 10Hz ticker (5.1) | Cut idle CPU | ⚠️ Revisit→Fixed — initial 5.1 build ran every frame (bad GetTime guard); v1.0.1 corrected to true 1Hz (0.03% CPU) |
| Wyvern default anchor + login/boss reset (v1.0.1) | Rotation starts at wyvern; player expectation; validated behavior | ✓ Good — diverges from Azor D-09 by design, removable |
| GitHub Releases only, tag-triggered | Minimal pipeline, no third-party packager | ✓ Good — v1.0.0/v1.0.1 shipped clean |
| Text mode via dual-widget root frame (Phase 7) | `root.tex` + `root.label` coexist; `ApplyDisplayMode()` toggles one, delegating border restore to `ApplyIconSettings()` | ✓ Good — no borderThickness regression; UAT 9/9 |
| Outline as cycle-button, not dropdown (Phase 7) | Least-risk on WoW 12.0.x — no Ace3/menu-API dependency | ✓ Good — None→Outline→Thick, live-applied |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-07-08 after Phase 7 (Text Display Mode) — colored text alternative to the icon shipped with per-beast colors, font-size slider, outline control, and mode-conditional options relayout; in-game UAT 9/9. Detection remains CDM-driven at 1Hz.*
