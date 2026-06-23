---
phase: 03-visibility-gating
verified: 2026-06-19T00:00:00Z
status: human_needed
score: 7/7
overrides_applied: 0
human_verification:
  - test: "Load PLBeast on a BM or SV hunter with Pack Leader hero talent active; type /plbeast debug to enable debug output; trigger a spec change; confirm chat shows 'packLeader=true' for BM/SV+PackLeader and 'packLeader=false' for MM or non-Pack-Leader talent"
    expected: "spec=BM packLeader=true when on BM with Pack Leader; spec=other packLeader=false when on MM"
    why_human: "Requires live WoW client to fire ACTIVE_PLAYER_SPECIALIZATION_CHANGED events and read IsPlayerSpell() return values"
  - test: "With Pack Leader active, switch to MM spec — confirm UNIT_AURA debug output stops appearing in chat (no more 'next=... wyvern=...' lines)"
    expected: "After switching to MM, aura tracking output stops because UNIT_AURA is unregistered"
    why_human: "Requires observing event handler suppression in a running WoW session"
  - test: "Switch to a different hero talent (Sentinel or Dark Ranger) while on BM/SV spec — confirm packLeader=false appears in debug and aura tracking stops"
    expected: "IsPackLeaderHeroTalent() returns false when Sentinel or Dark Ranger anchor spell is active; isPackLeaderActive becomes false"
    why_human: "Requires a WoW character with the Sentinel or Dark Ranger hero talent available to select"
  - test: "Switch back from MM to BM/SV with Pack Leader; confirm rotation resumes from the previously saved next-beast index (not reset to wyvern)"
    expected: "DB.nextIndex persists across spec switch; on re-activation the next-beast index is unchanged"
    why_human: "Requires observing DB.nextIndex round-trip across a spec change in a live WoW session"
---

# Phase 3: Visibility Gating — Verification Report

**Phase Goal:** The icon (or its placeholder) is visible only when the player has Pack Leader active on a supported hunter spec, and updates correctly when spec or talents change mid-session
**Verified:** 2026-06-19
**Status:** human_needed (all automated truths VERIFIED; 4 in-game behavioral checks required)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | isPackLeaderActive is true only when BM/SV spec AND Pack Leader hero talent active | VERIFIED | Line 223: `isPackLeaderActive = isHunterSpec and isPackLeader`; isHunterSpec requires specID 253 or 255; isPackLeader requires IsPlayerSpell(SPELL_HOTPL_PARENT) with Sentinel/DarkRanger exclusion |
| 2 | isPackLeaderActive is false on MM spec, non-hunter, or when Sentinel/Dark Ranger is selected | VERIFIED | RefreshHunterSpecState() only sets isBeastMastery=true for specID 253 or isSurvival=true for specID 255 (lines 201-202); IsPackLeaderHeroTalent() returns false if Sentinel anchor (1253599) or Dark Ranger anchor (466930) is present (lines 210-212) |
| 3 | UNIT_AURA is registered only when isPackLeaderActive is true; unregistered when false | VERIFIED | Lines 231-237: RegisterEvent("UNIT_AURA") only inside `if isPackLeaderActive and not wasActive`; UnregisterEvent inside `elseif not isPackLeaderActive and wasActive`; grep -c returns 1 for RegisterEvent.*UNIT_AURA |
| 4 | After switching from inactive to active, SeedAuraSnapshot() runs before UNIT_AURA is re-registered | VERIFIED | Lines 233-234: SeedAuraSnapshot() called on line 233, eventFrame:RegisterEvent("UNIT_AURA") on line 234 — correct order confirmed |
| 5 | On re-activation, rotation resumes from persisted DB.nextIndex — no state reset | VERIFIED | RefreshVisibility() does not modify DB.nextIndex or nextBeastId; ADDON_LOADED handler restores nextBeastId from DB.nextIndex (line 274); ResetAuraState(false) does not reset rotation order |
| 6 | Talent/spec change events trigger deferred visibility refresh via C_Timer.After(0, ...) | VERIFIED | QueueVisibilityRefresh() at lines 244-251: checks pendingVisibilityRefresh guard, then calls C_Timer.After(0, function() ... RefreshVisibility() end); all five talent/spec events route to QueueVisibilityRefresh (line 321) |
| 7 | /plbeast debug prints spec and packLeader flag regardless of visibility state | VERIFIED | dprint("spec=...", "packLeader=...") at lines 226-229 is unconditional inside RefreshVisibility() — executes before the if/elseif registration block; fires on every RefreshVisibility() call regardless of isPackLeaderActive value |

**Score:** 7/7 truths verified

---

### ROADMAP Success Criteria

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| SC-1 | The addon shows its output when Pack Leader is the active hero talent on BM or SV hunter | VERIFIED (automated gate) / NEEDS HUMAN (visual confirmation) | isPackLeaderActive becomes true on BM/SV+PackLeader, enabling UNIT_AURA tracking. Phase 3 goal scopes to "icon (or its placeholder)" — actual icon UI is Phase 4. The gating mechanism is fully implemented. |
| SC-2 | The output hides immediately when the player is not on hunter or switches to Marksmanship | VERIFIED (automated gate) / NEEDS HUMAN (visual confirmation) | isPackLeaderActive becomes false for non-BM/SV specs; UNIT_AURA unregistered on deactivation. |
| SC-3 | After switching specs or changing hero talent loadout (without a reload), visibility updates within one game frame | VERIFIED | C_Timer.After(0, ...) in QueueVisibilityRefresh defers exactly one frame; all five relevant events registered and routed to the queue. |

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `PLBeast/PLBeast.lua` | Visibility gating logic — `local function IsPackLeaderHeroTalent` | VERIFIED | Line 208: `local function IsPackLeaderHeroTalent()` present; substantive 6-line body with IsPlayerSpell checks |
| `PLBeast/PLBeast.lua` | Conditional UNIT_AURA registration — `local function RefreshVisibility` | VERIFIED | Line 218: `local function RefreshVisibility()` present; substantive body with spec eval, flag assignment, conditional register/unregister |
| `PLBeast/PLBeast.lua` | Deferred talent refresh — `local function QueueVisibilityRefresh` | VERIFIED | Line 244: `local function QueueVisibilityRefresh()` present; substantive body with pendingVisibilityRefresh guard and C_Timer.After |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| RefreshVisibility() | IsPackLeaderHeroTalent() | function call | WIRED | Line 221: `local isPackLeader = IsPackLeaderHeroTalent()` |
| RefreshVisibility() | eventFrame:RegisterEvent/UnregisterEvent | conditional UNIT_AURA registration | WIRED | Lines 234, 236: RegisterEvent("UNIT_AURA") and UnregisterEvent("UNIT_AURA") inside if/elseif block |
| QueueVisibilityRefresh() | RefreshVisibility() | C_Timer.After(0, ...) deferral | WIRED | Lines 247-250: C_Timer.After(0, function() ... RefreshVisibility() end); multi-line, grep pattern `C_Timer.After.*RefreshVisibility` fails due to line split but wiring is present and confirmed |
| PLAYER_LOGIN handler | RefreshVisibility() | direct call replacing unconditional UNIT_AURA registration | WIRED | Line 300: `RefreshVisibility()` — unconditional UNIT_AURA registration removed; comment confirms intent |
| Talent/spec event handler | QueueVisibilityRefresh() | unified five-event branch | WIRED | Lines 314-321: all five events (PLAYER_TALENT_UPDATE, ACTIVE_PLAYER_SPECIALIZATION_CHANGED, ACTIVE_COMBAT_CONFIG_CHANGED, TRAIT_CONFIG_UPDATED, TRAIT_SUB_TREE_CHANGED) routed to QueueVisibilityRefresh() |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| RefreshVisibility() | isPackLeaderActive | IsPlayerSpell() WoW API + GetSpecialization() WoW API | Yes — live WoW API calls, not hardcoded | FLOWING |
| IsPackLeaderHeroTalent() | return value | IsPlayerSpell(SPELL_HOTPL_PARENT/SENTINEL/DARK_RANGER) | Yes — reads live talent state | FLOWING |
| QueueVisibilityRefresh() | pendingVisibilityRefresh | module-level flag, reset by C_Timer callback | Yes — coalescing flag, not static | FLOWING |

---

### Behavioral Spot-Checks

Step 7b SKIPPED — requires WoW client runtime. No standalone Lua interpreter available; WoW API calls (IsPlayerSpell, GetSpecialization, C_Timer.After, CreateFrame) cannot be exercised outside the WoW sandbox.

---

### Probe Execution

No probe scripts declared in PLAN frontmatter. No `scripts/*/tests/probe-*.sh` files found for this phase. Step 7c: NOT APPLICABLE.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| VIS-01 | 03-01-PLAN.md | Icon only displays when Pack Leader hero talent is active (IsPlayerSpell with sentinel/dark ranger exclusion) | SATISFIED | IsPackLeaderHeroTalent() at line 208-214: positive gate on SPELL_HOTPL_PARENT (471876), negative gates on SPELL_SENTINEL_ANCHOR (1253599) and SPELL_DARK_RANGER_ANCHOR (466930) |
| VIS-02 | 03-01-PLAN.md | Icon hides when player spec does not support Pack Leader (MM, non-hunter) | SATISFIED | RefreshHunterSpecState() (lines 197-203) sets isBeastMastery=false and isSurvival=false for MM (specID 251) and non-hunter; isHunterSpec becomes false; isPackLeaderActive becomes false; UNIT_AURA unregistered |
| VIS-03 | 03-01-PLAN.md | Icon hides/shows correctly on spec change and talent change events | SATISFIED | Five events registered (lines 301-305); unified handler branch at lines 314-321 routes all five to QueueVisibilityRefresh(); C_Timer.After defers one frame for updated IsPlayerSpell state |

All three Phase 3 requirements accounted for. No orphaned requirements for Phase 3 in REQUIREMENTS.md.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | — | — | No anti-patterns found |

No TBD, FIXME, XXX, TODO, PLACEHOLDER, or empty-implementation patterns detected in PLBeast/PLBeast.lua. All new functions have substantive implementations with live WoW API calls.

---

### Deviations Handled Correctly

The SUMMARY documents one deviation from plan: forward declaration of `eventFrame` was required because `RefreshVisibility()` needs it as an upvalue before the Event Handler section. This was correctly resolved by adding `local eventFrame` at module-level state variables (line 72) and assigning `eventFrame = CreateFrame("Frame")` (without `local`) at line 257. This follows the same forward-declaration pattern used in PackLeaderHelper.lua for mutually recursive functions.

---

### Human Verification Required

#### 1. Pack Leader active on BM/SV shows tracking output

**Test:** Load PLBeast on a BM or SV hunter with Pack Leader hero talent active. Type `/plbeast debug` to enable debug mode. Trigger a talent update (e.g., open the talent UI). Confirm chat shows `spec=BM packLeader=true` (or `spec=SV packLeader=true`).
**Expected:** Debug output confirms isPackLeaderActive=true; subsequent beast ready-buff events produce `next=... wyvern=... boar=... bear=...` lines in chat.
**Why human:** Requires live WoW client with IsPlayerSpell() returning real talent data.

#### 2. UNIT_AURA suppressed on MM / non-Pack-Leader spec

**Test:** With debug mode active, switch to Marksmanship spec (or select Sentinel/Dark Ranger hero talent). Trigger beast abilities. Confirm aura tracking debug lines (`next=... wyvern=...`) no longer appear in chat.
**Expected:** After spec/talent change, UNIT_AURA events are not processed; only the visibility-change dprint (`spec=other packLeader=false`) appears.
**Why human:** Requires observing WoW event suppression behavior in a live session; cannot be tested with file inspection alone.

#### 3. Hero talent switch (Sentinel / Dark Ranger) deactivates gating

**Test:** On a BM/SV hunter with Pack Leader active, switch to Sentinel or Dark Ranger hero talent without changing spec. Confirm debug output transitions to `packLeader=false`.
**Expected:** IsPackLeaderHeroTalent() detects the Sentinel (1253599) or Dark Ranger (466930) anchor and returns false; isPackLeaderActive flips to false.
**Why human:** Requires a character with alternative hero talent trees available and selected in the WoW client.

#### 4. Rotation index persists across spec change re-activation

**Test:** Advance the rotation (let a beast spawn so nextIndex > 1). Switch to MM. Switch back to BM/SV with Pack Leader. Check `/plbeast debug` output to confirm the next-beast matches the pre-switch value and was not reset to wyvern.
**Expected:** DB.nextIndex is preserved because RefreshVisibility() does not modify it; on re-activation SeedAuraSnapshot() seeds prevReady without resetting rotation order.
**Why human:** Requires observing SavedVariablesPerCharacter round-trip across spec transitions in a live session.

---

### Gaps Summary

No gaps. All 7 must-have truths are VERIFIED, all 3 required artifacts exist and are substantive and wired, all 5 key links are wired, all 3 requirement IDs (VIS-01, VIS-02, VIS-03) are satisfied. The 4 human verification items above require in-game testing in the WoW client and do not represent code defects.

---

_Verified: 2026-06-19_
_Verifier: Claude (gsd-verifier)_
