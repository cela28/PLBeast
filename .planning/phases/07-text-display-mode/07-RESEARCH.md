# Phase 7: Text Display Mode - Research

**Researched:** 2026-07-07
**Domain:** WoW Lua FontString API — colored text label as an alternative render mode for an existing single-frame addon
**Confidence:** MEDIUM (WoW FontString/escape-sequence API cross-checked via WebSearch against Wowpedia/Warcraft Wiki sources; combat-lockdown specifics and color choice are lower-confidence / design judgment)

> No `07-CONTEXT.md` exists yet for this phase (discuss-phase has not run, or was skipped). No `<user_constraints>` section is included — this research is unconstrained by locked decisions. The planner/discuss-phase should treat every recommendation below as a proposal, not a locked choice.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEXT-01 | Text-based display mode shows each beast as a colored text label instead of an icon texture | FontString creation pattern + `root.label` companion widget on the existing `root` frame (Pattern 1) |
| TEXT-02 | Each beast has a distinct, readable color (wyvern, boar, bear) clearly distinguishable | Okabe-Ito colorblind-safe triad recommended with exact RGB values (Standard Stack / Code Examples) |
| TEXT-03 | Text display updates in real-time as the rotation prediction changes (same state machine) | Single hook point identified: `SetNextBeastId()` already fires on every transition; add `root.label:SetText/SetTextColor` there (Pattern 1) |
| TEXT-04 | User can toggle between icon mode and text mode via the options frame or slash command | Checkbox pattern already established in `ToggleOptions()`; `/plbeast text` subcommand slots into existing slash router (Architecture Patterns) |
| TEXT-05 | Text mode settings (font size, position) persist across sessions via SavedVariables | Reuse existing `DB.offsetX/offsetY` (position already shared since both modes live on the same `root` frame) + new `DB.fontSize`/`DB.textMode` keys via the established flat-defaults merge (Pitfall 3, Code Examples) |
| TEXT-06 | Text display respects the same visibility gating as icon mode (Pack Leader talent, BM/SV spec) | No new gating needed — `RefreshVisibility()` already calls `root:SetShown(isPackLeaderActive)` on the parent frame; both texture and label are children (Architectural Responsibility Map) |
</phase_requirements>

---

## Summary

This is a small, self-contained addition to an 829-line single-file WoW addon. The addon already has exactly one frame (`root`, created in `CreateBeastIcon()`) that carries a texture (`root.tex`), border edge textures, drag handlers, and position/size persistence. The correct shape for text mode is **not** a second frame — it's a second child widget (a `FontString`, `root.label`) on the *same* `root` frame, toggled visible/hidden opposite the existing texture. This means drag, combat-guarded movement, position persistence (`DB.offsetX/offsetY`), and the `RefreshVisibility()` show/hide gating are **all already correct for text mode with zero changes** — they operate on `root`, not on `root.tex` specifically.

The only genuinely new code is: (1) a `FontString` created alongside `root.tex` in `CreateBeastIcon()`, (2) a beast→color lookup table (`BEAST_COLOR_BY_ID`), (3) a small `ApplyDisplayMode()` function that shows exactly one of `root.tex`/`root.label` based on `DB.textMode` and is called from `SetNextBeastId()` and from the mode-toggle control, (4) a font-size control (slider, since fixed `Game*` font templates don't expose arbitrary point sizes) requiring a custom `Font` object rather than a template string, and (5) the checkbox + `/plbeast text` toggle wiring, mirroring the already-established `CreateCheckbox()` / slash-router patterns from Phase 5.

**Primary recommendation:** Add `root.label` as a sibling `FontString` on the existing `root` frame; drive its text and color from `BEAST_LABEL_BY_ID`/`BEAST_COLOR_BY_ID` inside `SetNextBeastId()` via `SetTextColor(r,g,b)` (not `|cff` escape codes — simpler, no `|r` bookkeeping); gate visibility of `root.tex` vs `root.label` on `DB.textMode` inside a single `ApplyDisplayMode()` helper; use the Okabe-Ito colorblind-safe triad for TEXT-02.

## Architectural Responsibility Map

PLBeast has no multi-tier architecture — it is a single Lua file running entirely inside the WoW client sandbox. The standard browser/server/API/CDN/database tiers do not apply. The relevant "tiers" here are the addon's own layers (per `.planning/codebase/ARCHITECTURE.md`-equivalent conventions already established in this project):

| Capability | Primary Layer | Secondary Layer | Rationale |
|------------|---------------|-----------------|-----------|
| Beast label text + color selection | UI layer (`root.label` widget) | State machine (`SetNextBeastId`) | Rendering is a UI concern; the state machine already owns *when* the display value changes — it should also own pushing the new value to whichever widget (texture or label) is active, exactly as it already does for `root.tex` |
| Mode toggle (icon ↔ text) | UI layer (options frame checkbox + slash command) | Persistence (`DB.textMode`) | Toggling is user input; the resulting state is a plain DB flag read by the existing render-push functions |
| Font size control | Options frame (slider) | Persistence (`DB.fontSize`) | Same shape as the existing width/height/border-thickness sliders — no new pattern needed |
| Visibility gating | Event handler / `RefreshVisibility()` | — | Already operates on `root` (the shared parent); no secondary owner needed, no new code |
| Position persistence | Layout/persistence (`DB.offsetX/offsetY`, `ApplyIconSettings()`) | — | Already shared since both display modes are children of the same `root` frame — this is the single biggest simplification available to the planner |

## Standard Stack

There is no package ecosystem for WoW addons (no npm/pip/cargo equivalent — Lua files are loaded directly by the client per the `.toc` manifest). "Standard Stack" here means standard **Blizzard UI API surfaces**, not third-party libraries.

### Core
| API | Source | Purpose | Why Standard |
|-----|--------|---------|---------------|
| `Frame:CreateFontString([name, drawLayer, templateName])` | Blizzard UI API [CITED: wowpedia.fandom.com/wiki/API_Frame_CreateFontString] | Creates the text widget as a child of `root` | The only supported way to render arbitrary text in a WoW frame; no alternative API exists |
| `FontString:SetText(text)` | Blizzard UI API [CITED: wowwiki-archive.fandom.com/wiki/API_FontString_SetText] | Sets the beast label string ("Wyvern"/"Boar"/"Bear") | Standard text-update call |
| `FontString:SetTextColor(r, g, b [, a])` | Blizzard UI API [CITED: addonstudio.org/wiki/WoW:API_FontString_SetTextColor] | Sets the per-beast color without embedding escape codes in the string | Cleaner than `|cff` codes when the color changes independently of the text; avoids `|r` reset bookkeeping |
| `FontInstance:SetFont(fontFile, size, flags)` on a `Font` object created via `CreateFont(name)` | Blizzard UI API [ASSUMED — training knowledge, not directly confirmed via fetch this session] | Enables an arbitrary, slider-controlled point size (fixed `Game*` templates only expose their own baked-in sizes) | Required because TEXT-05 needs a persisted, user-adjustable font size — no fixed template supports that |

### Supporting
| API | Purpose | When to Use |
|-----|---------|-------------|
| `GameFontNormalLarge` (or similar) as the `templateName` arg to `CreateFontString` | Provides a safe, locale-correct default font/size at creation time, before the custom `Font` object is applied | Use as the initial 3rd argument so the FontString always has *some* valid font even before `ApplyIconSettings()`-equivalent code runs (avoids the "Font must be set before SetText" pitfall) |
| `FontInstance:GetFont()` on an existing global font object (e.g., `GameFontNormalLarge:GetFont()`) | Returns `(fontFile, size, flags)` — lets you inherit the client's locale-correct font *file* while only overriding size | Use this to seed the custom `Font` object's `fontFile`/`flags` instead of hardcoding `Fonts\FRIZQT__.TTF`, which is more portable across locales |
| `|cAARRGGBB...|r` UI escape sequences | Inline color markup inside a single `SetText()` string | Only needed if a single label must show multiple colors in one string (not needed here — one label is always exactly one beast, one color) — documented for completeness, not recommended as the primary mechanism |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom `Font` object for size control | Swap between several fixed `Game*Small/Normal/Large/Huge` templates | Simpler code, no `CreateFont`/`SetFont` needed, but only 3-4 discrete sizes instead of a smooth slider — degrades TEXT-05's "font size... persist" into a stepped enum rather than a numeric setting. Recommended only if the planner wants to avoid `CreateFont` entirely. |
| `SetTextColor` per-beast | `|cff` escape codes baked into `BEAST_LABEL_BY_ID` strings (e.g. `BEAST_LABEL_BY_ID.wyvern = "|cff56b4e9Wyvern|r"`) | Works, but couples color to the label string, makes color un-adjustable later (e.g., no future "color intensity" option), and requires care that `|r` doesn't leak into option-frame previews. `SetTextColor` keeps text and color orthogonal. |
| Second frame for text mode | Reuse existing `root` frame, add `root.label` as sibling to `root.tex` | Second frame would duplicate all drag/position/combat-guard/visibility code already on `root` — clear anti-pattern for this codebase's single-frame design intent (see PROJECT.md constraint: "minimal addon... single draggable/scalable icon") |

**Installation:** N/A — no package manager; all APIs are provided globally by the WoW client at runtime.

**Version verification:** N/A — WoW Lua/UI API is versioned by client patch, not by a package registry. This project targets Interface 120000/120005/120007 (The War Within / 12.0.x) per `PLBeast.toc`; all APIs referenced above have been stable across retail client versions since well before 9.0 and are not deprecated in 12.x.

## Package Legitimacy Audit

**Not applicable.** This phase installs no external packages. WoW addons have no package manager (per `.planning/codebase` TECH-STACK notes: "None — WoW addons have no external package manager"). Skip the Package Legitimacy Gate entirely for this phase.

## Architecture Patterns

### System Architecture Diagram

```
                    ┌─────────────────────────────┐
                    │   PollPackLeader() (existing) │
                    │   detects ready-buff / advance │
                    └───────────────┬───────────────┘
                                    │ nowBeast.id / nextId
                                    ▼
                    ┌─────────────────────────────┐
                    │   SetNextBeastId(beastId)     │  <-- single hook point (existing fn, extended)
                    │   - DB.plNextBeastId = id      │
                    │   - push to whichever widget   │
                    │     is currently active         │
                    └───────────────┬───────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                                ▼
        ┌───────────────────────┐        ┌───────────────────────┐
        │ root.tex (texture)     │        │ root.label (FontString)│
        │ SetTexture(ICON_FILE…) │        │ SetText(BEAST_LABEL…)  │
        │ visible iff !DB.textMode│        │ SetTextColor(BEAST_COLOR…)│
        │                        │        │ visible iff DB.textMode │
        └───────────────────────┘        └───────────────────────┘
                    │                                │
                    └───────────────┬───────────────┘
                                    ▼
                    ┌─────────────────────────────┐
                    │   root frame (existing)       │
                    │   - drag / combat guard        │
                    │   - DB.offsetX/offsetY position│
                    │   - shown/hidden by             │
                    │     RefreshVisibility()         │
                    └─────────────────────────────┘

  Mode toggle input:  options-frame checkbox  ──┐
                       /plbeast text command  ──┴──> DB.textMode = not DB.textMode
                                                       ApplyDisplayMode()  (shows/hides tex vs label)
```

### Recommended Project Structure

No new files — this stays inside the existing single-file structure per project convention (see CLAUDE.md constraint: "one or two .lua files"):

```
PLBeast/
├── PLBeast.lua          # add: BEAST_COLOR_BY_ID table, root.label creation,
│                         #      ApplyDisplayMode(), textMode checkbox + slash branch,
│                         #      DB.textMode/DB.fontSize defaults
├── PLBeast.toc           # unchanged
└── Locales/
    └── enUS.lua           # add: "Text Mode" / "Font Size" checkbox+slider labels
```

### Pattern 1: Dual-widget single-frame display mode

**What:** Both display modes (icon, text) live as sibling child widgets on the one existing `root` frame, gated by a single `DB.textMode` boolean. Exactly one is shown at a time.

**When to use:** Whenever an addon needs to switch *what* is rendered without needing to switch *where* it's rendered, positioned, or gated. This is the case here — TEXT-05 and TEXT-06 explicitly require position and visibility gating to be shared with icon mode, which this pattern gets for free.

**Example:**
```lua
-- In CreateBeastIcon(), alongside the existing tex creation:
local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
label:SetPoint("CENTER", f, "CENTER", 0, 0)
label:SetJustifyH("CENTER")
f.label = label

-- One helper, called from SetNextBeastId() and from the mode-toggle control:
local function ApplyDisplayMode()
	if not root then return end
	local textMode = DB.textMode
	root.tex:SetShown(not textMode)
	root.label:SetShown(textMode)
end

-- SetNextBeastId() extended (existing texture line kept, label line added):
local function SetNextBeastId(beastId)
	nextBeastId      = beastId or "boar"
	DB.plNextBeastId = nextBeastId
	if root and root.tex then
		root.tex:SetTexture(ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.boar)
	end
	if root and root.label then
		root.label:SetText(BEAST_LABEL_BY_ID[nextBeastId] or BEAST_LABEL_BY_ID.boar)
		local c = BEAST_COLOR_BY_ID[nextBeastId] or BEAST_COLOR_BY_ID.boar
		root.label:SetTextColor(c[1], c[2], c[3])
	end
end
```

### Pattern 2: Custom-size Font object for a slider-controlled font size

**What:** Create one persistent `Font` object via `CreateFont(name)`, seed it from a stable Blizzard font object's file/flags, then re-apply size via `SetFont` whenever the slider changes.

**When to use:** Any time a font size needs to be a numeric, user-adjustable, persisted value rather than a fixed template pick.

**Example:**
```lua
-- Created once, e.g. in CreateBeastIcon() before label creation:
local textFont = CreateFont("PLBeastTextFont")
local baseFile, _, baseFlags = GameFontNormalLarge:GetFont()  -- inherit locale-correct font file
textFont:SetFont(baseFile, DB.fontSize or 14, baseFlags)
label:SetFontObject(textFont)

-- On slider change:
local function SetTextFontSize(size)
	DB.fontSize = size
	local file, _, flags = textFont:GetFont()
	textFont:SetFont(file, size, flags)
end
```

### Anti-Patterns to Avoid
- **Second frame for text mode:** Creates a duplicate drag/position/combat-guard/visibility surface that must be kept in sync with `root` forever. Use Pattern 1 instead.
- **Baking `|cff` color codes into `BEAST_LABEL_BY_ID` strings:** Couples color to label text, breaks if `BEAST_LABEL_BY_ID` is ever reused for chat/debug output (it already is, in `PollPackLeader()`'s `dprint` call and the `/plbeast reset` chat message) — those call sites would suddenly print raw color codes. Use `SetTextColor` on the FontString instead, keep `BEAST_LABEL_BY_ID` plain-text.
- **Calling `CreateFontString`/`CreateFont` more than once per session:** These allocate a new font/widget object each call. Create both exactly once (at `CreateBeastIcon()` time), store references (`root.label`, module-level `textFont` local), and mutate them thereafter — mirrors the existing `root.tex`/`root.borderEdges` singleton-creation convention already in this file.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Colored text rendering | Manual pixel-color texture-based text, or a custom bitmap font renderer | `FontString` + `SetTextColor` | WoW's built-in text object handles font rendering, locale glyphs (CJK, Cyrillic, etc. for future locale support), and scaling — reimplementing any of this is enormously more complex than the one-line API |
| Distinct/readable color selection | Ad-hoc color guessing | Okabe-Ito colorblind-safe palette values (see Standard Stack alternatives, Code Examples) | TEXT-02 requires colors "clearly distinguishable" — an established, tested colorblind-safe triad satisfies this more reliably than arbitrary picks, and needs no future rework if a colorblind user reports an issue |
| Font-size persistence UI | New slider/text-input widget type | Existing `CreateSlider()` helper already in this file (used for width/height/border-thickness) | Zero new UI code needed — bind a new slider instance to `DB.fontSize` exactly like the existing three sliders |

**Key insight:** Nothing in this phase requires new abstractions — every piece (FontString, custom Font object, slider, checkbox, slash subcommand) is either a one-line Blizzard API call or a direct reuse of a helper already present in `PLBeast.lua`. The main planning risk is scope creep (e.g., building a second frame, or a full theme system) rather than missing capability.

## Common Pitfalls

### Pitfall 1: FontString has no font until one is set
**What goes wrong:** Calling `CreateFontString(nil, "OVERLAY")` with no `templateName` and then immediately `SetText(...)` before any `SetFont`/`SetFontObject` call can render nothing or error, because a FontString has no font object by default.
**Why it happens:** `CreateFontString`'s `templateName` argument is optional; skipping it leaves the widget fontless.
**How to avoid:** Always pass a template (e.g. `"GameFontNormalLarge"`) as the 3rd arg to `CreateFontString`, so a valid font exists immediately — then optionally override with a custom `Font` object afterward (Pattern 2).
**Warning signs:** Blank/invisible label on first login after install, before any options-frame interaction has run `SetFont`.

### Pitfall 2: Reusing `BEAST_LABEL_BY_ID` for both display and debug/chat output
**What goes wrong:** `BEAST_LABEL_BY_ID` is already read in `PollPackLeader()`'s `dprint(...)` line and could be reused for the new label — if it's ever changed to contain embedded color codes for the UI, the debug chat line inherits them.
**Why it happens:** Shared lookup tables silently couple unrelated call sites.
**How to avoid:** Keep `BEAST_LABEL_BY_ID` plain text (as it already is) and apply color exclusively via `SetTextColor` on the FontString, never by mutating the shared label strings.
**Warning signs:** Chat output containing raw `|cff...|r` literal text instead of colored text (chat frames don't always render color codes from `print()` the same way FontStrings do, depending on channel).

### Pitfall 3: `DB.textMode`/`DB.fontSize` missing from `defaults` breaks the existing merge-on-load convention
**What goes wrong:** This addon's `ADDON_LOADED` handler does a flat `for k, v in pairs(defaults) do if PLBeastDB[k] == nil then PLBeastDB[k] = v end end` merge. If the new keys aren't added to the `defaults` table (line ~14), `DB.textMode`/`DB.fontSize` will be `nil` on first load and any code assuming a boolean/number will misbehave (`nil` is falsy, which happens to be an acceptable default for `textMode = false`, but `DB.fontSize` being `nil` will break `SetFont(file, nil, flags)`).
**Why it happens:** Every other DB key in this file follows the same pattern (see `width`, `height`, `borderThickness` in `defaults`) — it's easy to forget one new key.
**How to avoid:** Add `textMode = false` and `fontSize = 14` to the `defaults` table at the top of the file, exactly like every other setting.
**Warning signs:** Lua error referencing `nil` where a number was expected, only on a fresh install / fresh character (before any manual `/reload` re-saves the merged DB).

### Pitfall 4: Root frame's fixed width/height (16–128px, square-biased) doesn't fit variable-length text
**What goes wrong:** The existing `DB.width`/`DB.height` sliders (16–128px) size `root` for a roughly-square icon. "Wyvern" at font size 20+ is wider than 128px would comfortably hold if the FontString is clipped to the frame's bounds.
**Why it happens:** `root.tex:SetAllPoints(f)` clips the texture to the frame box, but a `FontString` anchored via `SetPoint("CENTER", f, "CENTER")` (not `SetAllPoints`) is **not** clipped by the frame's size — text can visually overflow `root`'s box, which is usually fine visually but means the *border* (`f.borderEdges`, sized to `DB.width/height`) will look wrong around text mode (a tight box around a wider label).
**How to avoid:** Either (a) hide the border edges when `DB.textMode` is true (recommended — a border makes little visual sense around free text), or (b) leave `root`'s box as an invisible drag/position anchor only, sized however, and accept the label overflowing it. Flag this as a decision for the planner/discuss-phase — it isn't specified by TEXT-01..06.
**Warning signs:** A visible 1px black square border sitting inside or awkwardly overlapping the beast name text.

## Code Examples

### Beast color table (Okabe-Ito colorblind-safe triad)
```lua
-- Source: Okabe-Ito colorblind-safe palette [CITED: web search — conceptviz.app/blog/okabe-ito-palette-hex-codes-complete-reference; values 0-1 normalized from hex]
local BEAST_COLOR_BY_ID = {
	wyvern = { 0.337, 0.706, 0.914 }, -- #56B4E9 sky blue
	boar   = { 0.902, 0.624, 0.000 }, -- #E69F00 orange
	bear   = { 0.000, 0.620, 0.451 }, -- #009E73 bluish green
}
```

### Color escape sequence (reference only — not the recommended primary mechanism)
```lua
-- Source: [CITED: wowpedia.fandom.com/wiki/UI_escape_sequences via WebSearch]
-- |cAARRGGBB<text>|r — alpha conventionally FF (engine ignores alpha channel here)
fontString:SetText("|cff56b4e9Wyvern|r")
```

### Slash command extension (mirrors existing router in `PLBeast.lua` line ~752)
```lua
-- Add a branch to the existing SlashCmdList["PLBEAST"] handler:
elseif msg == "text" then
	DB.textMode = not DB.textMode
	ApplyDisplayMode()
	Print(string.format(L["Text mode: %s"], tostring(DB.textMode)))
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-------------------|---------------|--------|
| Fixed `Game*` font templates only | `CreateFont(name)` + `SetFont(file, size, flags)` for arbitrary sizes | Long-standing (pre-Classic; not a recent change) | No impact on this phase — both APIs are stable and coexist; recommending the custom-Font approach only because a slider needs continuous values |

**Deprecated/outdated:** None identified — the FontString/escape-sequence APIs referenced here have been stable since well before Legion and are not flagged deprecated anywhere in official documentation as of this research.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | `FontString:SetText`, `SetTextColor`, `CreateFontString`, and `SetShown` are not restricted by `InCombatLockdown()` on a normal (non-secure) addon-owned frame | Pitfalls, Architecture Patterns | If wrong, text updates during combat could silently fail or throw — planner should add the same defensive `InCombatLockdown()` pattern already used for `StartMoving` as a cheap safety net even though research suggests it's unnecessary for text/color/show-hide calls |
| A2 | `CreateFont(name)` + `SetFont` is the correct mechanism for a slider-driven arbitrary font size (vs. only fixed templates) | Standard Stack, Pattern 2 | If wrong (e.g., some subtlety with `CreateFont` re-registration on `/reload`), font-size slider might not visually update — low risk, easy to verify in-game, has a documented fallback (fixed-template alternative in "Alternatives Considered") |
| A3 | Hiding the border edges in text mode is the right UX call (Pitfall 4) | Common Pitfalls | Low risk — purely cosmetic; easy to reverse; flagged explicitly as a planner/discuss-phase decision point, not asserted as locked |

**If this table is empty:** N/A — see entries above; all are moderate-to-low risk and independently verifiable in-game within minutes.

## Open Questions

1. **Does "position" in TEXT-05 mean a *separate* saved position for text mode, or the shared `root` position?**
   - What we know: Both display modes are recommended to live on the same `root` frame (Pattern 1), which means position is automatically shared and already persists via existing `DB.offsetX/offsetY` — no new code needed.
   - What's unclear: The ROADMAP.md phase success criteria (line 184) says settings are "font size, enabled state" while REQUIREMENTS.md (TEXT-05) says "font size, position" — these two source-of-truth docs disagree slightly on what TEXT-05 covers.
   - Recommendation: Treat "position" as already satisfied by the shared-frame design (no new work); treat "enabled state" as `DB.textMode` (new). Confirm with the user during discuss-phase if a *separate* independent position for text mode is actually wanted (would require a second frame, contradicting Pattern 1's simplification) — this is the single highest-leverage question for discuss-phase to resolve before planning.

2. **Should the border (`f.borderEdges`) be shown or hidden in text mode?**
   - What we know: The border was designed for a square icon (Phase 4 D-02/D-03); it doesn't visually suit free-form text (Pitfall 4).
   - What's unclear: No requirement addresses this either way.
   - Recommendation: Hide border when `DB.textMode` is true, inside the same `ApplyDisplayMode()` helper. Cheap to implement, cheap to reverse if the user disagrees during verification.

## Environment Availability

Skipped — this phase is a pure Lua code change inside an already-loaded, already-verified WoW addon (no new external tool, service, or runtime dependency beyond the WoW client itself, which every prior phase already established as a hard requirement in `PLBeast.toc`/PROJECT.md).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None — confirmed via `.planning/codebase/TESTING.md`: "Runner: None detected... Standard Lua testing frameworks (Busted, LuaUnit) require a standalone Lua runtime [and] mocking the WoW API surface" |
| Config file | none |
| Quick run command | `/reload` in-game, then visually inspect the label/icon toggle |
| Full suite command | Manual in-game walk-through (see Phase Requirements → Test Map below) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|---------------|
| TEXT-01 | Text mode shows beast name instead of icon | manual-only (no WoW API mock exists in this repo) | N/A — `/plbeast text`, observe label replaces icon | N/A |
| TEXT-02 | Colors distinct for wyvern/boar/bear | manual-only | N/A — visually compare three colors side by side, or cross-check hex against Okabe-Ito reference | N/A |
| TEXT-03 | Text updates on rotation transition | manual-only | N/A — trigger a beast-ready buff (or use `/plbeast reset` + wait) and observe label text/color change | N/A |
| TEXT-04 | Toggle via options frame checkbox or `/plbeast text` | manual-only | N/A — click checkbox and run slash command, confirm both flip `DB.textMode` | N/A |
| TEXT-05 | Font size + position persist via SavedVariables | manual-only | N/A — set font size, `/reload`, confirm value restored (position already covered by existing Phase 4 tests) | N/A |
| TEXT-06 | Visibility gating shared with icon mode | manual-only | N/A — switch spec away from BM/SV, confirm `root` (and therefore the label) hides | N/A |

*manual-only justification: No standalone Lua test runner exists in this repo and none is planned (per project constraints — "no build step", WoW Lua sandbox); this matches every prior phase's verification approach (`04-VERIFICATION.md`, `06-VERIFICATION.md` both used `human_needed`/manual in-game checks for identical reasons).*

### Sampling Rate
- **Per task commit:** `/reload` + visual spot-check of the specific behavior just implemented
- **Per wave merge:** Full manual walk-through of all six TEXT-0x behaviors above
- **Phase gate:** All six behaviors manually confirmed before `/gsd-verify-work` (expect `human_needed` disposition, consistent with Phases 4 and 6)

### Wave 0 Gaps
None — no test infrastructure exists to gap-fill; this project has never had one and the codebase's own `TESTING.md` documents this as the accepted state.

## Security Domain

Not applicable. This addon has no network access, no external input beyond in-game Blizzard API state, no authentication, no cryptography, and no user-supplied data parsing beyond a fixed slash-command vocabulary already hardened in prior phases. ASVS categories do not map onto a client-side, sandboxed, single-player-scoped WoW addon with no server component. `security_enforcement` should be treated as not meaningfully applicable to this project type — no findings to report.

## Sources

### Primary (HIGH confidence)
- None — no Context7 library or authoritative package registry applies to WoW Lua addon development; all sources are secondary/tertiary by nature of this domain.

### Secondary (MEDIUM confidence)
- [UI escape sequences (Wowpedia)](https://wowpedia.fandom.com/wiki/UI_escape_sequences) — via WebSearch snippet, `|cAARRGGBB...|r` syntax
- [API Frame CreateFontString (Wowpedia)](https://wowpedia.fandom.com/wiki/API_Frame_CreateFontString) — via WebSearch snippet, method signature and draw layers
- [FontString:SetText (WoWWiki archive)](https://wowwiki-archive.fandom.com/wiki/API_FontString_SetText) — via WebSearch snippet, font-must-be-set-first caveat
- [FontString:SetTextColor (AddOn Studio)](https://addonstudio.org/wiki/WoW:API_FontString_SetTextColor) — via WebSearch snippet
- [Okabe-Ito Palette Hex Codes reference (conceptviz.app)](https://conceptviz.app/blog/okabe-ito-palette-hex-codes-complete-reference) — via WebSearch snippet, exact hex values for the recommended color triad
- Prior-phase project artifact: `.planning/phases/05-configuration/05-CONTEXT.md` D-12 — codebase-internal precedent that `SetSize`/`SetBackdrop` on the `root` frame are not combat-lockdown restricted (informs Pitfall/Assumption A1)

### Tertiary (LOW confidence)
- Combat-lockdown behavior for `FontString:SetText`/`SetTextColor`/`CreateFontString` specifically — WebSearch found no source directly confirming or denying protected-function status for these calls; treated as [ASSUMED] per training knowledge and cross-checked only indirectly via the D-12 precedent above (Assumption A1)
- `CreateFont`/`SetFont` mechanics for a slider-driven size — [ASSUMED] per training knowledge, not independently fetched from an official source this session (Assumption A2)

## Metadata

**Confidence breakdown:**
- Standard stack (FontString/color API): MEDIUM — WebSearch cross-checked against Wowpedia/WoWWiki/AddOnStudio snippets, but full page fetches were blocked (self-signed cert / paywall errors) so only search-result summaries were available, not full page text
- Architecture (dual-widget single-frame pattern): HIGH — directly derived from reading the actual current `PLBeast.lua` source in this repo, not from external research
- Pitfalls: MEDIUM — Pitfalls 1-3 are well-established WoW addon conventions; Pitfall 4 (border-vs-text sizing) is original analysis specific to this codebase's existing width/height slider design, not externally sourced

**Research date:** 2026-07-07
**Valid until:** 2026-10-05 (WoW addon UI API surface is very stable; 90-day validity is conservative, not driven by expected churn)
