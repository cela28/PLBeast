# Plan Check: 07-01-PLAN.md — Text Display Mode

## Verdict: FAIL

One blocker found. Fix required before execution.

## Requirement Coverage

| Req | Task | Status |
|-----|------|--------|
| TEXT-01 | Task 1 (BEAST_COLOR_BY_ID, root.label, ApplyDisplayMode, SetNextBeastId ext.) | Covered |
| TEXT-02 | Task 1 (Okabe-Ito RGB triad, verified against research hex values) | Covered |
| TEXT-03 | Task 1 (SetNextBeastId already the single hook called by PollPackLeader; extension pushes to root.label) | Covered |
| TEXT-04 | Task 2 (checkbox + `/plbeast text`) | Covered |
| TEXT-05 | Task 1 (defaults.textMode/fontSize, ADDON_LOADED coercion) + existing SavedVariablesPerCharacter | Covered |
| TEXT-06 | Implicit — root:SetShown(isPackLeaderActive) in existing RefreshVisibility() already covers children (root.label is a child of root); no new code needed, correctly identified in must_haves truths | Covered |

All 6 requirements are present in the plan's `requirements` frontmatter and have concrete, traceable tasks. No coverage gaps.

## Line-Reference Accuracy (cross-checked against PLBeast/PLBeast.lua, 829 lines)

- `BEAST_LABEL_BY_ID` table: lines 76–80 — plan's "after line 80" insertion point is correct.
- `defaults` table: lines 14–25 — plan's "around line 14" is correct.
- `root` forward declaration: line 132 — plan's "around line 133" for `local textFont` is correct.
- `CreateBeastIcon()`: lines 514–562; tex setup lines 522–528, border edges 530–536 — plan's "after tex setup, before border edge creation" ordering is correct.
- `ApplyIconSettings`/`CreateBeastIcon` boundary: lines 476–511 / 514 — plan's placement of `ApplyDisplayMode()` "between" them is correct.
- `SetNextBeastId`: lines 178–185 — plan's "around line 178" is correct.
- ADDON_LOADED numeric coercion block: lines 738–742 — plan's "around line 738" is correct.
- `ToggleOptions()` frame size line 634 (`SetSize(280, 300)`) — plan's 300→400 change target is correct.
- Lock-position checkbox at yOffset -236 (line 689) — plan's new checkbox at -268 (32px below) is correctly spaced and won't overlap.
- Slash command branches (lines 754–766) — plan's "insert after reset, before empty-string branch" placement is correct and won't disturb existing branches.

All line references and insertion points are accurate. No stale-path or fabricated line-number issues found.

## BLOCKER: ApplyDisplayMode's border-hiding logic will incorrectly re-show a user-configured zero-thickness border on every fresh login

**Location:** Task 1, step 5 (`ApplyDisplayMode` action description).

**The plan's own instruction is self-contradictory and will produce broken behavior:**

> "Hides border edges when text mode is active: iterate root.borderEdges and call SetShown(not textMode) on each edge texture ... When not in text mode, do NOT force-show edges here — let ApplyIconSettings handle border visibility via its thickness logic."

The described code (`edge:SetShown(not textMode)` for every edge, unconditionally) **does** force-show every edge whenever `textMode` is false — directly contradicting the very next sentence's stated intent ("do NOT force-show edges here"). `SetShown(not textMode)` is not conditioned on `DB.borderThickness`; it always sets edges visible in icon mode, regardless of the existing `borderThickness <= 0 → Hide()` behavior established in `ApplyIconSettings()` (PLBeast.lua lines 486–487).

**Concrete failure sequence (regression of existing Phase 4 feature):**

1. User sets `DB.borderThickness = 0` via the existing slider (valid range is 0–8, per `CreateSlider(..., 0, 8, 1, ...)` at line 673) — this is a supported, already-shipped configuration that hides the border (`ApplyIconSettings` line 486-487: `if thick <= 0 then edges.*:Hide() ... end`).
2. On next `/reload` or login, `CreateBeastIcon()` runs `ApplyIconSettings()` first (line 560, correctly hides the 4 edge textures because thickness is 0), then — per this plan's Task 1 step 7 — calls the new `ApplyDisplayMode()` immediately after.
3. `ApplyDisplayMode()`, with `DB.textMode` false (the default), executes `edge:SetShown(not textMode)` = `edge:SetShown(true)` on all four edges, **re-showing the border that `ApplyIconSettings()` just correctly hid.**
4. The user now sees an unwanted border around their icon, with no direct action having caused it — a regression of a previously working, user-configured setting (borderThickness=0 → no border).
5. This is not self-correcting: the checkbox/slash-command paths do re-run `ApplyIconSettings()` when switching *out of* text mode (Task 2 steps 3 & 5), but there is no such call on ordinary startup/login while already in icon mode — the bug persists until the user manually touches the border-thickness slider again.

**Why this matters:** This is a genuine functional regression on a previously delivered and tested capability (Phase 4 border thickness = 0 hides the border), triggered on every normal login for any user who has set thickness to 0 — not an edge case that requires unusual input, just a supported slider value at its minimum.

**Fix hint:** `ApplyDisplayMode()` should not unconditionally `SetShown(true)` the border edges when leaving text mode. Either:
- (a) Only ever hide edges in text mode (`if textMode then hide all edges end`) and leave icon-mode edge visibility entirely to `ApplyIconSettings()` (call it, don't duplicate its logic), or
- (b) Have `ApplyDisplayMode()` call `ApplyIconSettings()` itself when `not textMode`, so the thickness-aware logic is the single source of truth for icon-mode border visibility, instead of an independent unconditional `SetShown`.

This must be corrected in the plan's Task 1 step 5 action text before execution; as written, the executor will faithfully implement a border-visibility regression.

## Other Dimensions Checked (no issues)

- **Task completeness:** Both tasks have files/action/verify/done. Actions are specific (line-anchored, named functions, exact API calls) rather than vague.
- **Dependency correctness:** Single plan, `depends_on: []`, wave 1. No graph issues.
- **Key links:** `SetNextBeastId → root.tex + root.label` wiring explicitly described; `ApplyDisplayMode` toggle wiring explicitly described; font slider → `textFont:SetFont` wiring explicitly described. All three `key_links` in frontmatter are addressed by concrete action steps.
- **Scope sanity:** 2 tasks, ~2 files modified (PLBeast.lua, enUS.lua). Well within budget.
- **must_haves derivation:** Truths are user-observable ("beast name appears as colored text", "player can toggle... via checkbox or slash command"), not implementation-only. Artifacts map 1:1 to truths.
- **WoW API correctness:** `CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")`, `CreateFont(name)`, `FontInstance:GetFont()/SetFont()`, `FontString:SetFontObject()`, `SetTextColor(r,g,b)`, `Texture:SetShown()` are all valid, correctly-signatured Blizzard UI API calls consistent with the RESEARCH.md findings.
- **CLAUDE.md compliance:** Naming conventions (PascalCase functions `ApplyDisplayMode`, UPPER_SNAKE table `BEAST_COLOR_BY_ID`, camelCase locals `textFont`/`textMode`) match project conventions. No new files created (single-file constraint respected). No third-party libraries introduced.
- **Research resolution:** RESEARCH.md's two Open Questions are both resolved with explicit recommendations that the plan follows (shared-frame position, border hidden in text mode) — no unresolved research blockers.
- **Threat model:** Adequate for this trust-boundary-free, sandboxed, no-network addon; T-07-01/T-07-02 dispositions are reasonable.

## Recommendation

Return to planner: fix Task 1 step 5's `ApplyDisplayMode` border-hiding logic per the fix hint above, then re-submit for verification.
