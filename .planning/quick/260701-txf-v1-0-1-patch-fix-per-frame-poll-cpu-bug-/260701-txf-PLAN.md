---
phase: quick-260701-txf
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - PLBeast/PLBeast.lua
  - PLBeast/Locales/enUS.lua
  - PLBeast/PLBeast.toc
  - .planning/phases/05.1-event-driven-rotation-tracking-drop-10hz-poll/05.1-RESEARCH.md
autonomous: true
requirements: [PERF-01, TRACK-03]

must_haves:
  truths:
    - "PollPackLeader runs at most ~1Hz (once per POLL_INTERVAL second), not at framerate."
    - "The dprint block in PollPackLeader does not concatenate strings when DB.debug is false."
    - "Fresh/default next-beast prediction is Wyvern everywhere (default, spec change, /plbeast reset, error fallback)."
    - "Rotation resets to Wyvern on fresh login and boss pull (TRACK-03)."
    - "The NEXT_BEAST ring order remains boar->bear->wyvern->boar (unchanged)."
    - "PLBeast.toc reports version 1.0.1."
  artifacts:
    - path: "PLBeast/PLBeast.lua"
      provides: "Interval-threshold OnUpdate throttle, debug-gated dprint, wyvern default anchor, TRACK-03 login/boss-pull reset"
      contains: "POLL_INTERVAL"
    - path: "PLBeast/Locales/enUS.lua"
      provides: "Reset locale string reflecting Wyvern"
      contains: "Rotation reset. Next: Wyvern."
    - path: "PLBeast/PLBeast.toc"
      provides: "Version 1.0.1"
      contains: "## Version: 1.0.1"
  key_links:
    - from: "PLBeast/PLBeast.lua (OnUpdateHandler)"
      to: "PLBeast/PLBeast.lua (POLL_INTERVAL constant)"
      via: "throttle guard `now - lastPolledTime < POLL_INTERVAL`"
      pattern: "now - lastPolledTime < POLL_INTERVAL"
    - from: "PLBeast/PLBeast.lua (event handler)"
      to: "PLBeast/PLBeast.lua (SaveState)"
      via: "PLAYER_ENTERING_WORLD isInitialLogin + ENCOUNTER_START set nextBeastId=wyvern then SaveState()"
      pattern: "ENCOUNTER_START"
---

<objective>
v1.0.1 patch closing two major UAT defects in the Phase 05.1 event-driven rotation engine (per-frame poll CPU bug PERF-01; wyvern default + TRACK-03 reset), plus a RESEARCH.md doc correction and a version bump.

Purpose: The OnUpdate throttle is ineffective (GetTime() equality guard never trips), so PollPackLeader runs at framerate instead of ~1Hz, burning CPU while Pack Leader is active. Separately, the fresh/default prediction anchor is boar but must be wyvern (start of rotation), and the original TRACK-03 login/boss-pull reset was dropped.

Output: Patched PLBeast.lua (throttle + debug gate + wyvern anchor + TRACK-03 events), updated locale string, corrected RESEARCH.md claims, and PLBeast.toc bumped to 1.0.1.

All fixes are diagnosed and DECIDED in 06-UAT.md (Gaps section). Verification is static only (grep/inspection) — in-game testing is human-only and MUST NOT appear as a task.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/phases/06-release-pipeline/06-UAT.md
@./CLAUDE.md
@PLBeast/PLBeast.lua
@PLBeast/Locales/enUS.lua
@PLBeast/PLBeast.toc
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix per-frame poll CPU bug (interval throttle + debug-gated dprint)</name>
  <files>PLBeast/PLBeast.lua</files>
  <action>
Resolves PERF-01. Two edits, both in PLBeast.lua.

1. Add a module-level constant next to the throttle-state declaration. Near line 118-119 (the `local lastPolledTime = -1` declaration and its "OnUpdate throttle" comment), add a sibling line declaring `POLL_INTERVAL` as the number 1.0. Update the adjacent comment to state the cadence is enforced by an interval threshold of POLL_INTERVAL seconds (Azor parity — Azor's real ~1Hz comes from its Scheduler interval=1, NOT from GetTime resolution). Do NOT restate any prose that a negative grep would key on.

2. Replace the broken equality guard in OnUpdateHandler (near line 407-408). The current line reads the GetTime() equality comparison against lastPolledTime and returns. Change it so the guard returns early when the elapsed time since lastPolledTime is less than POLL_INTERVAL (subtraction-and-compare form). Keep the subsequent `lastPolledTime = now` assignment and the `PollPackLeader()` call unchanged. Because GetTime() advances every frame, the elapsed-threshold form throttles PollPackLeader to at most once per POLL_INTERVAL second.

3. Gate the dprint block inside PollPackLeader (near line 393-398 — the multi-arg dprint with phase/next/ready/beast concatenations) behind a runtime check `if DB and DB.debug then ... end` so its string concatenations do not run every poll when debug is off. Wrap only that dprint call; leave the state-transition logic above it untouched.

Match existing style: hard tabs, guard-return idiom, existing comment conventions.
  </action>
  <verify>
    <automated>grep -n "POLL_INTERVAL" PLBeast/PLBeast.lua && grep -n "now - lastPolledTime < POLL_INTERVAL" PLBeast/PLBeast.lua && ! grep -q "if now == lastPolledTime then return end" PLBeast/PLBeast.lua && grep -n "if DB and DB.debug then" PLBeast/PLBeast.lua && luac -p PLBeast/PLBeast.lua 2>/dev/null || echo "luac unavailable — rely on grep gates"</automated>
  </verify>
  <done>
POLL_INTERVAL constant (1.0) declared near lastPolledTime. OnUpdateHandler guard uses the elapsed-threshold form and the old equality guard is gone. The PollPackLeader dprint block is wrapped in an `if DB and DB.debug then` gate. File remains syntactically valid Lua.
  </done>
</task>

<task type="auto">
  <name>Task 2: Wyvern default anchor + TRACK-03 login/boss-pull reset + locale</name>
  <files>PLBeast/PLBeast.lua, PLBeast/Locales/enUS.lua</files>
  <action>
Resolves TRACK-03 and the wyvern-default gap. Change the default/fallback anchor from boar to wyvern at ALL FOUR sites in PLBeast.lua, add the TRACK-03 event resets, and update the locale string. The NEXT_BEAST ring order (boar->bear->wyvern->boar) MUST stay unchanged — ONLY the anchor/default changes. This deliberately diverges from Azor (D-09), user-approved and removable later.

Four anchor sites in PLBeast.lua (change the string value and update the trailing D-08 comment to say wyvern is the default/start-of-rotation anchor):
- `plNextBeastId` default in the `defaults` table (near line 16): change value from boar to wyvern.
- `nextBeastId` module-level state default (near line 107): change from boar to wyvern.
- `SetNextBeastId` fallback (near line 179): the `beastId or "boar"` fallback becomes `beastId or "wyvern"`; also update the function's header comment (near line 176-177) to reflect the wyvern default.
- PollPackLeader consume-branch reset fallback (near line 389): the `(oldBeast and NEXT_BEAST[oldBeast.id]) or "boar"` fallback becomes the wyvern fallback. Note this is only the error fallback when oldBeast is nil — the NEXT_BEAST lookup itself is unchanged.

Also update the two existing boar-reset call sites that reset the anchor (NOT the ring):
- `/plbeast reset` handler (near line 757-761): change `SetNextBeastId("boar")` to wyvern and update its comment; the printed message uses the locale key (see locale change below).
- `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` handler (near line 808-811): change `SetNextBeastId("boar")` to wyvern and update the D-08 comment.

TRACK-03 event registration and handling (event handler section, near line 706-829):
- In the PLAYER_LOGIN branch where other events are registered (near line 780-790), register two new events: PLAYER_ENTERING_WORLD and ENCOUNTER_START.
- Add handler branches. Replace the current terminal comment block (near line 826-827 stating PLAYER_ENTERING_WORLD/ENCOUNTER_START are not registered per D-09) with real handling: on ENCOUNTER_START, and on PLAYER_ENTERING_WORLD when its `isInitialLogin` argument (the first vararg for that event) is true, call ClearPackLeaderState() then SetNextBeastId("wyvern") then SaveState(). Capture the event varargs via `...` at the point of dispatch. Event-driven, zero per-frame cost.

Locale (PLBeast/Locales/enUS.lua): change the reset string value from "Rotation reset. Next: Boar." to "Rotation reset. Next: Wyvern." Keep the same table key so the code lookup still resolves; if you also rename the key, update the code's `L[...]` lookup in the reset handler to match. Simplest: change only the value, keep the key as-is — but note the key IS the string here, so update BOTH the key and value in the locale table AND the `L["Rotation reset. Next: Boar."]` reference in the reset handler to the new string.

Match existing style: hard tabs, PascalCase functions, guard-return idiom.
  </action>
  <verify>
    <automated>grep -n 'plNextBeastId = "wyvern"' PLBeast/PLBeast.lua && grep -n 'local nextBeastId    = "wyvern"' PLBeast/PLBeast.lua && grep -c 'or "wyvern"' PLBeast/PLBeast.lua && grep -n "ENCOUNTER_START" PLBeast/PLBeast.lua && grep -n "PLAYER_ENTERING_WORLD" PLBeast/PLBeast.lua && grep -n "isInitialLogin" PLBeast/PLBeast.lua && grep -n 'boar   = "bear"' PLBeast/PLBeast.lua && grep -n 'wyvern = "boar"' PLBeast/PLBeast.lua && grep -q "Rotation reset. Next: Wyvern." PLBeast/Locales/enUS.lua && ! grep -q "Rotation reset. Next: Boar." PLBeast/Locales/enUS.lua && ( luac -p PLBeast/PLBeast.lua 2>/dev/null && luac -p PLBeast/Locales/enUS.lua 2>/dev/null || echo "luac unavailable — rely on grep gates" )</automated>
  </verify>
  <done>
All four anchor sites plus the two reset call sites use wyvern. PLAYER_ENTERING_WORLD (isInitialLogin) and ENCOUNTER_START are registered and reset nextBeastId to wyvern via ClearPackLeaderState + SetNextBeastId("wyvern") + SaveState(). The NEXT_BEAST ring (boar->bear, wyvern->boar) is intact. Locale reset string reads Wyvern and the code reference matches. Both files are valid Lua.
  </done>
</task>

<task type="auto">
  <name>Task 3: RESEARCH.md GetTime-resolution correction + version bump to 1.0.1</name>
  <files>.planning/phases/05.1-event-driven-rotation-tracking-drop-10hz-poll/05.1-RESEARCH.md, PLBeast/PLBeast.toc</files>
  <action>
Resolves the doc-hygiene gap and the pending toc-version bump todo. Two independent files.

1. RESEARCH.md doc correction (surgical annotations, do NOT rewrite the doc). Correct the false claim that GetTime() has "1-second resolution" at the sites where it appears: notably lines 89, 154, 198, 200, and Pitfall 1 (lines ~384-390), plus the assumption entries near lines 477, 581, 592. GetTime() returns high-precision frame time (advances every frame); the intended ~1Hz cadence is enforced by the POLL_INTERVAL elapsed-threshold in OnUpdateHandler, NOT by GetTime resolution. For each site, add a concise inline correction annotation (e.g. a `> CORRECTION (v1.0.1):` note or bracketed inline `[CORRECTED: ...]`) explaining that GetTime is high-precision and the 1Hz cadence comes from the POLL_INTERVAL threshold. Keep the original text visible where practical (annotate, don't delete) so the historical record and the fix are both legible. Do NOT touch code-fenced examples in ways that change their meaning beyond the correction note.

2. Version bump in PLBeast/PLBeast.toc (line 5): change `## Version: 0.2.4` to `## Version: 1.0.1`. The release workflow injects the tag version at publish time; bumping the committed value keeps local installs identifiable.
  </action>
  <verify>
    <automated>grep -c -i "CORRECT" .planning/phases/05.1-event-driven-rotation-tracking-drop-10hz-poll/05.1-RESEARCH.md && grep -n "## Version: 1.0.1" PLBeast/PLBeast.toc && ! grep -q "## Version: 0.2.4" PLBeast/PLBeast.toc</automated>
  </verify>
  <done>
RESEARCH.md carries surgical correction annotations at the false-claim sites clarifying GetTime is high-precision and cadence comes from POLL_INTERVAL. PLBeast.toc reports Version 1.0.1 (0.2.4 gone).
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| WoW client -> addon | All input (CDM frame data, aura instance IDs, event varargs) originates from the trusted Blizzard client sandbox. No network, filesystem, or external package boundary crosses in this patch. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-txf-01 | Denial of Service | OnUpdateHandler poll loop | mitigate | Interval-threshold throttle (POLL_INTERVAL=1.0) caps PollPackLeader to ~1Hz; debug-gated dprint removes per-poll allocations — this IS the fix. |
| T-txf-02 | Tampering | event varargs (isInitialLogin) | accept | Varargs come from the trusted WoW event system; type is client-guaranteed. No new package installs — package legitimacy gate N/A. |
</threat_model>

<verification>
- No new external dependencies, no build step (WoW loads .lua/.toc directly).
- Static verification only: grep gates + `luac -p` syntax check where available. NO in-game steps (human-only, out of scope for this plan).
- Task 1 gates prove the throttle constant + elapsed guard exist and the broken equality guard is gone, plus the debug gate.
- Task 2 gates prove all anchor sites are wyvern, the ring order is intact, TRACK-03 events are wired, and the locale is updated.
- Task 3 gates prove the RESEARCH.md annotations and the toc version bump.
</verification>

<success_criteria>
- PollPackLeader is throttled to ~1Hz via POLL_INTERVAL; equality guard removed; dprint gated behind DB.debug.
- Wyvern is the default/fallback anchor at all four sites and the two reset call sites; NEXT_BEAST ring unchanged.
- PLAYER_ENTERING_WORLD (isInitialLogin) and ENCOUNTER_START reset to wyvern (TRACK-03) with SaveState().
- Locale reset string reads "Rotation reset. Next: Wyvern." and the code reference matches.
- RESEARCH.md GetTime-resolution claims annotated as corrected.
- PLBeast.toc version is 1.0.1.
- All edited Lua files remain syntactically valid.
</success_criteria>

<output>
Create `.planning/quick/260701-txf-v1-0-1-patch-fix-per-frame-poll-cpu-bug-/260701-txf-01-SUMMARY.md` when done.
</output>
