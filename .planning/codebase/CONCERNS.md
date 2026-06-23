# Codebase Concerns

**Analysis Date:** 2026-06-18

## Tech Debt

**Locale key mismatch between enUS and usage guide text:**
- Issue: The enUS locale file (`Locales/enUS.lua`, line 41) defines a key `"Cooldown Manager must be enabled. At minimum, track the buffs shown above as icons; order does not matter. Do not disable or hide Cooldown Manager in Blizzard settings. The hide options provided by this addon are good to use."` (ends in "are good to use."), but the main Lua file (`PackLeaderHelper.lua`, line 1089) uses a slightly different string: `"...The hide options provided by this addon are okay."` (ends in "are okay."). These strings won't match, so the localization lookup always falls back to the raw key string as displayed text, defeating the locale system for that one tooltip.
- Files: `PackLeaderHelper.lua:1089`, `Locales/enUS.lua:41`
- Impact: The usage guide tooltip text falls through the metatable fallback and displays the raw key rather than the translated value. For enUS this is cosmetically identical, but it breaks zhCN for that string since the zhCN key also uses the "are good to use." variant and won't match.
- Fix approach: Align the key used in `PackLeaderHelper.lua` line 1089 to exactly match the key defined in both locale files (use the "are good to use." variant), or update both locale files to use the "okay" variant.

**`ApplyBlizzardCooldownManagerVisibility` called before function definition:**
- Issue: In `PackLeaderHelper.lua`, the options frame creation code at lines 1269, 1280, 1291 calls `ApplyBlizzardCooldownManagerVisibility()` inside checkbox callbacks. However, `ApplyBlizzardCooldownManagerVisibility` is defined at line 1849, after the `ToggleOptions` function that creates those checkboxes. Because Lua resolves upvalues/globals at call time (not definition time), this only works because the function is a module-level local resolved at runtime via the closure environment. This is fragile — if someone moves or refactors this code the ordering dependency becomes invisible.
- Files: `PackLeaderHelper.lua:1269`, `PackLeaderHelper.lua:1849`
- Impact: Currently works at runtime, but creates a non-obvious dependency between two distant code blocks. Difficult to reason about during maintenance.
- Fix approach: Move `ApplyBlizzardCooldownManagerVisibility` above `ToggleOptions`, or add a comment at the call site noting the forward reference.

**Duplicate combat-state detection (poll-based and event-based):**
- Issue: The addon tracks `inCombat` both via registered events (`PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED`) and via the `TickUpdate` polling function which also calls `UnitAffectingCombat("player")` every 50ms (`PackLeaderHelper.lua:2433`). When both paths fire, `OnCombatStart` / `OnCombatEnd` can be called twice in sequence.
- Files: `PackLeaderHelper.lua:2416-2457`, `PackLeaderHelper.lua:2616-2629`
- Impact: Double-triggering `OnCombatStart` is harmless now but calls `BuildCDMCache()` and `PollCDMState()` redundantly. If those functions acquire non-idempotent resources in future, this becomes a bug.
- Fix approach: Remove the `UnitAffectingCombat` poll from `TickUpdate` and rely exclusively on the registered events, since `PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED` are authoritative.

**`layoutEditorState` never cleared when options frame is first toggled open after a layout reset:**
- Issue: `layoutEditorState` is initialized on first open of the options panel (`PackLeaderHelper.lua:1412-1415`) and after layout resets in slash commands. The `ADDON_LOADED` handler resets `DB.layout` but does not reset `layoutEditorState`. If a user calls `/plh resetlayout` while the options panel is already open, the in-memory `layoutEditorState` is replaced correctly. However, if the options panel was opened before the reset and closed, reopening it uses the stale `layoutEditorState` from the last session since the `if not layoutEditorState then` guard prevents re-initialization.
- Files: `PackLeaderHelper.lua:1412-1415`, `PackLeaderHelper.lua:2507-2515`
- Impact: After `/plh resetlayout` with the options frame closed, reopening the panel may show stale layout state until the user manually discards.
- Fix approach: After resetting `DB.layout`, also reset `layoutEditorState = nil` so the guard re-initializes it on next open.

**`DB` global alias set during `ADDON_LOADED` but used before that event fires:**
- Issue: `DB` is assigned at the top of the file as `local DB = PackLeaderHelperDB` (line 37). `PackLeaderHelperDB` starts as `PackLeaderHelperDB or {}` (an empty table). `CopyDefaults` to populate it from `defaults` only runs inside `ADDON_LOADED`. Any code that runs before `ADDON_LOADED` and reads `DB.someKey` will get `nil` instead of the default value.
- Files: `PackLeaderHelper.lua:36-37`, `PackLeaderHelper.lua:2574-2575`
- Impact: Low risk in practice because frame creation happens in `PLAYER_LOGIN` after `ADDON_LOADED`, but the alias pattern is confusing — `DB` is a local reference to a table that gets replaced by a new table (`PackLeaderHelperDB = CopyDefaults(...)`) at line 2574. After that reassignment, `PackLeaderHelperDB` points to the merged table, and `DB` is re-pointed at line 2575. If the ordering ever changes this silent double-assignment becomes a bug.
- Fix approach: Document the aliasing sequence with a comment, or restructure to always read from `PackLeaderHelperDB` directly.

**No upper bound on layout grid expansion:**
- Issue: The "+" Column and "+" Row buttons in the layout editor (`PackLeaderHelper.lua:1238-1253`) increment `layoutEditorState.cols/rows` without any upper limit — only `math.max(MIN_LAYOUT_COLS, ...)` is applied. A user can click repeatedly to create an arbitrarily large grid.
- Files: `PackLeaderHelper.lua:1238-1253`
- Impact: An unbounded grid does not cause a crash but renders many empty slot frames and can make the options panel visually unusable. No data loss occurs since saving trims unused edges via `NormalizeLayout(..., true)`.
- Fix approach: Add a maximum constant (e.g., `MAX_LAYOUT_COLS = 10`, `MAX_LAYOUT_ROWS = 10`) and apply it in the button click handlers.

---

## Known Bugs

**Wyvern buff-extend icon uses wrong texture in test mode:**
- Symptoms: During `/plh test`, the `wyvernBuff` icon at line 2382 sets its texture to `ICON_BEAR_READY` instead of `ICON_DRAGON_READY`. This shows the bear icon where the wyvern buff icon should be.
- Files: `PackLeaderHelper.lua:2382`
- Trigger: `/plh test` command
- Workaround: None; purely cosmetic during test mode.

**zhCN locale missing the `"Hogstrider tracker"` description key:**
- Symptoms: `ICON_DESCRIPTION_BY_ID.hogstrider` falls back to the raw key `"Hogstrider tracker"` in English for zhCN users since zhCN (`Locales/zhCN.lua`) provides a translation for `"Hogstrider tracker"` (line 11) as a tooltip name but the description string is identical to the tooltip name and there is no dedicated description translation.
- Files: `Locales/zhCN.lua:11`, `PackLeaderHelper.lua:82`
- Trigger: Opening the layout editor and selecting the Hogstrider icon on a zhCN client.
- Workaround: The displayed text is still readable Chinese for the tooltip name (`猪突猛进监控`); only the description text falls through.

---

## Security Considerations

**Frame hierarchy discovery traverses arbitrary child frames:**
- Risk: `GatherCooldownsFromFrameTree` and `FindCDMFrameByCooldownID` iterate over WoW's live frame tree using `frame:GetChildren()` up to depth 4. Malicious or buggy third-party addons that parent rogue frames under `CDMGroups_Buffs` could be traversed, consuming CPU or, in pathological cases, causing errors if those frames define unexpected `cooldownID` fields.
- Files: `PackLeaderHelper.lua:1805-1823`, `PackLeaderHelper.lua:1901-1923`
- Current mitigation: `pcall` is used around `C_UnitAuras.GetAuraDataByAuraInstanceID` and `C_UnitAuras.GetAuraDuration`. The `seen` table in `GatherCooldownsFromFrameTree` prevents infinite loops. Depth limit of 4 bounds worst-case traversal.
- Recommendations: Already well-mitigated; no critical action needed. Consider adding a frame-count limit (e.g., bail after 200 frames examined) as a defensive measure.

**`ApplyBlizzardCooldownManagerVisibility` uses `frame:SetScale(0.001)`:**
- Risk: Setting scale to 0.001 rather than hiding via `frame:Hide()` is a workaround for frames protected by Blizzard's secure frame system that cannot be hidden directly from addon code. The approach is intentional but noteworthy: if Blizzard changes the protected status of these frames, the workaround may either become unnecessary (breakable with `Hide()`) or stop functioning. The scale approach also leaves the frame technically visible but imperceptibly small, which may affect click hit-testing.
- Files: `PackLeaderHelper.lua:1849-1877`
- Current mitigation: Existing scale/alpha saves and restores are correctly implemented.
- Recommendations: Add a comment explaining WHY `SetScale(0.001)` is used instead of `Hide()` so future maintainers understand this is intentional.

---

## Performance Bottlenecks

**`PollCDMState` runs on every `TickUpdate` (every 50ms) even out of combat:**
- Problem: `TickUpdate` fires every frame but throttles to 50ms. Every 50ms it calls `PollCDMState`, which calls `EnsureCacheFramesResolved`, `BuildReadySnapshot`, `BuildCooldownSnapshot`, and `BuildHogstriderSnapshot`. These each iterate over `cdmCache` (up to 7 entries) and call `C_UnitAuras.GetPlayerAuraBySpellID` up to 7 times per tick. Out of combat, all aura reads return nil immediately, but the calls still occur.
- Files: `PackLeaderHelper.lua:2416-2457`
- Cause: No out-of-combat short-circuit in `TickUpdate` — it polls identically in and out of combat.
- Improvement path: When `not inCombat` and `ShouldShowTracker()` returns false (the common case for non-Pack-Leader specs), skip `PollCDMState` entirely and only call `UpdateNextBar` to ensure correct hide state.

**`FindCDMFrameByCooldownID` performs a full recursive scan on every call:**
- Problem: `EnsureCacheFramesResolved` is called every `PollCDMState` invocation and internally calls `FindCDMFrameByCooldownID` for any cache entry missing a `cdmFrame`. This recursive scan of `CDMGroups_Buffs` children runs each time until all frames are resolved. After initial resolution it becomes a no-op, but during the initial cache-build window (login, spec changes) it fires repeatedly.
- Files: `PackLeaderHelper.lua:1958-1964`, `PackLeaderHelper.lua:1805-1823`
- Cause: Frame references are resolved lazily per-poll rather than eagerly during `BuildCDMCache`.
- Improvement path: Call `EnsureCacheFramesResolved` once immediately after `BuildCDMCache` completes, then remove it from the per-poll path; only retry if a `cdmFrame` is still nil after the initial resolution attempt.

---

## Fragile Areas

**CDM frame discovery depends on undocumented Blizzard frame names:**
- Files: `PackLeaderHelper.lua:1826-1831`
- Why fragile: The strings `"BuffBarCooldownViewer"`, `"BuffIconCooldownViewer"`, `"CDMGroups_Buffs"`, and `"EssentialCooldownViewer"` are undocumented Blizzard internal frame names. Blizzard has renamed or restructured CDM internals in patches before. If any of these names change the CDM cache will fail to build silently (`cdmCacheBuilt` stays false) and the tracker will show no state.
- Safe modification: Any change to `CDM_FRAME_ROOT_NAMES` or `BLIZZARD_CDM_FRAME_GROUPS` should be verified against the current game patch's frame hierarchy using `/framestack` or frame introspection tools.
- Test coverage: None — there are no automated tests for this addon (WoW addon environment; no test runner present).

**`wyvernBuffActive` state is managed entirely in Lua with no server-authoritative source:**
- Files: `PackLeaderHelper.lua:1728-1749`, `PackLeaderHelper.lua:2632-2651`
- Why fragile: The wyvern buff start/end times and extend counts are tracked by intercepting `UNIT_SPELLCAST_SUCCEEDED` events and computing duration manually using `GetTime()`. If the player is disconnected, lags severely, or if a cast event is missed (e.g., due to lag between client and server), the tracked state diverges from reality. There is no reconciliation against server aura state.
- Safe modification: Changes to `WYVERN_BUFF_DURATION_LEFT`, `WYVERN_BUFF_DURATION_RIGHT`, `WYVERN_BUFF_EXTEND_SV`, `WYVERN_BUFF_MAX_EXTENDS_SV`, `WYVERN_BUFF_EXTEND_BM`, or `WYVERN_BUFF_MAX_EXTENDS_BM` constants require in-game verification against the actual spell tuning for the current patch version.
- Test coverage: None.

**Spec detection falls back to `UNIT_SPELLCAST_SUCCEEDED` heuristics:**
- Files: `PackLeaderHelper.lua:1718-1726`, `PackLeaderHelper.lua:1582-1587`
- Why fragile: `RefreshHunterSpecState` uses `GetSpecialization()` + `GetSpecializationInfo()` as the primary method, which is correct. However `UpdateHunterModeFromKillCommand` overrides spec detection based on which Kill Command spell ID is cast. If Blizzard unifies these spell IDs or changes them, the fallback heuristic silently gives wrong answers (wrong wyvern extend count limits).
- Safe modification: Verify `SPELL_KILL_COMMAND` (259489) and `SPELL_KILL_COMMAND_BM` (34026) are still distinct IDs after each major patch.

---

## Scaling Limits

**Grid cell frame pool is never freed:**
- Current capacity: `optionsFrame.editorGridSlots` and `optionsFrame.editorUnusedSlots` are append-only arrays. Frames are created via `EnsureEditorSlot` and hidden but never destroyed.
- Limit: Bounded in practice because `MIN_LAYOUT_COLS/ROWS = 4` and no upper bound exists, but the number of slot frames equals `cols × rows` and grows each time the user adds rows/columns without saving.
- Scaling path: Add `MAX_LAYOUT_COLS`/`MAX_LAYOUT_ROWS` constants to bound frame creation, or pool/recycle slot frames.

---

## Dependencies at Risk

**Dependency on `C_CooldownViewer` API:**
- Risk: `C_CooldownViewer.GetCooldownViewerCooldownInfo` and `C_CooldownViewer.GetCooldownViewerCategorySet` are used in `ReadSpellFromCooldownID` and `GatherCooldownsFromViewerCategories`. These APIs were introduced in 10.x and may be changed or removed in future major versions.
- Impact: If these APIs disappear, `BuildCDMCache` will silently fail (`cdmCacheBuilt` stays false) and the tracker shows no state.
- Migration plan: The addon already guards with `if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo)` at line 1939. If the API is removed, add a fallback that falls back to pure `C_UnitAuras.GetPlayerAuraBySpellID` polling without CDM frame references.

**Dependency on `C_UnitAuras.GetAuraDuration` for DurationObject cooldown frames:**
- Risk: `TrySetCooldownFromDurationObject` uses `C_UnitAuras.GetAuraDuration` and `cd:SetCooldownFromDurationObject`, both relatively new APIs (added in 10.1.x). These are used for smooth cooldown sweep animations.
- Impact: If not available, `TrySetCooldownFromDurationObject` silently returns without setting the cooldown sweep, and the fallback to `SetCooldown(startTime, duration)` handles display.
- Migration plan: Already fully guarded with `if not iconFrame.cd.SetCooldownFromDurationObject then return end` and `pcall`. No action needed.

---

## Missing Critical Features

**No removal of `cellSize` and `cellPadding` from `DB` default config:**
- Problem: `DB.cellSize` and `DB.cellPadding` are read in `RefreshTrackerLayout` (`PackLeaderHelper.lua:1439-1440`) with fallbacks to `defaults.cellSize` (44) and `defaults.cellPadding` (4), but there are no corresponding UI controls in the options panel to expose these settings to users. They are hidden saved variables that users cannot change without directly editing their WTF saved variables file.
- Blocks: Users cannot adjust icon cell size or padding without external file editing.

**No way to shrink the layout grid (only grow):**
- Problem: The layout editor provides `"+ Column"` and `"+ Row"` buttons but no `"- Column"` or `"- Row"` buttons. The only way to reduce grid size is to use `"Reset Layout"` (which resets all positions) or to save the layout (which auto-trims empty trailing rows/columns via `NormalizeLayout(..., true)`).
- Blocks: Users cannot intentionally compact their layout without losing placement work; they must rely on the auto-trim-on-save behavior which is not communicated in the UI.

---

## Test Coverage Gaps

**No test suite exists:**
- What's not tested: All addon logic — CDM cache building, aura state tracking, layout normalization, wyvern buff tracking, next-beast rotation, UI frame creation.
- Files: `PackLeaderHelper.lua` (entire file, 2675 lines), `Locales/enUS.lua`, `Locales/zhCN.lua`
- Risk: Regressions in CDM frame discovery, wyvern extend math, or layout serialization are undetectable without manual in-game testing.
- Priority: Low — WoW addons have no standard automated test infrastructure. Manual testing with `/plh test` covers display paths but not state machine logic.

---

*Concerns audit: 2026-06-18*
