# Phase 1: Addon Scaffold - Research

**Researched:** 2026-06-18
**Domain:** World of Warcraft Lua addon file structure (TOC, SavedVariables, two-phase init, locale)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Minimal skeleton only — TOC + init event frame + DB defaults merge + locale table. No spell ID constants, no NEXT_BEAST rotation table, no tracking function stubs. Phase 2 introduces all tracking data.
- **D-02:** No Media/ directory in scaffold. TOC IconTexture uses a WoW built-in icon. Phase 4 adds custom assets if needed.
- **D-03:** ADDON_LOADED: merge defaults into PLBeastDB, set local DB ref, dprint DB contents for verification.
- **D-04:** PLAYER_LOGIN: register `/plbeast` slash command, print a loaded confirmation message. No pre-wired event stubs or OnUpdate frame — later phases add their own.
- **D-05:** Minimal defaults — Phase 1: `debug = false`, `nextIndex = 1`. Later phases extend the defaults table with their keys (Phase 4 adds position/size, Phase 5 adds UI settings).
- **D-06:** Simple flat merge for DB defaults (3-line `for k,v in pairs` loop), not PLH's recursive CopyDefaults. PLBeast's DB is flat key-value.
- **D-07:** dprint DB contents on ADDON_LOADED for easy SavedVariables round-trip verification during testing.
- **D-08:** Target Midnight (12.x), NOT The War Within (11.x). Current expansion is Midnight, current patch is 12.0.7.
- **D-09:** Broad Interface range in TOC: `120000, 120005, 120007` — covers Midnight launch through current patch.
- **D-10:** ROADMAP reference to "The War Within (11.x)" is outdated and should be corrected to "Midnight (12.x)".

### Claude's Discretion
- Init flow structure (D-03, D-04): Claude chose PLH's two-phase pattern with no pre-wired stubs
- Logging (included Print/dprint): Claude chose to include for scaffold verification
- Media/ (skipped): Claude chose to skip, beast textures are WoW built-in spell icons
- DB merge approach (D-06): Claude chose flat merge over recursive
- DB verification (D-07): Claude chose to include dprint on load

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| STRUCT-01 | Root repo contains a `PLBeast/` folder with the complete addon inside (standard WoW addon packaging) | File layout section: PLBeast/ at repo root, standard AddOns layout |
| STRUCT-02 | Code extracted/adapted from PackLeaderHelper — not written from scratch | Code examples section: exact lines to adapt from PLH source |
| STRUCT-03 | Proper `.toc` file targeting the current expansion with correct Interface version | Standard Stack + Code Examples: TOC structure with 120000, 120005, 120007 |
| STRUCT-04 | SavedVariablesPerCharacter declaration in `.toc` | Code Examples: TOC SavedVariables field; init pattern |
| STRUCT-05 | Localization support (at minimum enUS) | Code Examples: locale table with metatable fallback |
</phase_requirements>

---

## Summary

Phase 1 creates the PLBeast addon directory and its minimal loadable skeleton. Because PLBeast is a WoW Lua addon with no external package manager, there is nothing to install — the deliverables are three text files: `PLBeast.toc`, `Locales/enUS.lua`, and `PLBeast.lua`. The WoW client loads them directly; no build step exists.

The entire domain is well-understood from the PackLeaderHelper source, which is committed to this repo and serves as the authoritative extraction template. Every pattern the planner needs — TOC structure, two-phase init, flat DB merge, locale metatable, Print/dprint helpers, slash command registration — exists verbatim in PLH and requires only mechanical renaming (`PackLeaderHelper` → `PLBeast`, `PLH` → `PLBeast`, `PackLeaderHelperDB` → `PLBeastDB`, etc.).

The only decision that differs from the ROADMAP text is the Interface version target. The ROADMAP says "The War Within (11.x)" but D-08/D-10 lock the target to **Midnight (12.x)**, Interface versions `120000, 120005, 120007`. The planner must also correct the ROADMAP success criterion wording when it creates the PLAN file.

**Primary recommendation:** Mechanically extract the TOC + init + locale patterns from PLH, rename all identifiers, strip everything beyond the minimal scaffold (no spell constants, no UI, no OnUpdate), and create `PLBeast/` at repo root.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Addon file layout | Repo structure | WoW client loader | WoW reads TOC, loads files in declared order |
| SavedVariables persistence | WoW client | — | Client writes PLBeastDB to disk; addon only reads/writes the global |
| DB defaults merge | PLBeast.lua (init) | — | ADDON_LOADED event fires before PLAYER_LOGIN; merge happens here |
| Locale table | Locales/enUS.lua | PLBeast.lua (metatable) | Locale file sets the global; main file wraps it in a fallback metatable |
| Slash command registration | PLBeast.lua (PLAYER_LOGIN) | WoW SlashCmdList global | SlashCmdList is a WoW global; addon writes into it on login |
| Debug output | PLBeast.lua (dprint) | — | Gated by DB.debug; no external logger |

---

## Standard Stack

### Core

No external packages — WoW Lua sandbox has no package manager. The "stack" is WoW built-in APIs only.

| API / Pattern | Source | Purpose | Notes |
|---------------|--------|---------|-------|
| `CreateFrame("Frame")` | WoW API | Event frame for ADDON_LOADED / PLAYER_LOGIN | PLH line 2554 |
| `RegisterEvent` / `SetScript("OnEvent")` | WoW API | Wire event callbacks | PLH lines 2555–2570 |
| `SavedVariablesPerCharacter` (TOC field) | WoW TOC spec | Per-character persistent storage | D-04 requires PerCharacter, not global |
| Locale metatable (`__index` fallback) | Lua 5.1 | Returns key as fallback when string missing | PLH lines 4–8 |
| `SLASH_<NAME>1` + `SlashCmdList["<NAME>"]` | WoW API | Slash command registration | PLH lines 2479–2481 |

### No Alternatives Considered

This phase has no library choices. The WoW Lua sandbox provides one way to do each operation.

### Installation

None. No `npm install`, `pip install`, or equivalent. Files are loaded directly by the WoW client when placed in the AddOns folder.

---

## Package Legitimacy Audit

**Not applicable.** This phase installs zero external packages. The WoW Lua sandbox has no package manager; all dependencies are WoW built-in APIs.

---

## Architecture Patterns

### System Architecture Diagram

```
WoW Client
  │
  ├─ Reads PLBeast.toc
  │    ├─ Loads Locales/enUS.lua  → sets PLBeastLocale global
  │    └─ Loads PLBeast.lua
  │         ├─ Wraps PLBeastLocale in L metatable
  │         ├─ Creates eventFrame
  │         └─ Registers ADDON_LOADED, PLAYER_LOGIN
  │
  ├─ Fires ADDON_LOADED ("PLBeast")
  │    └─ Merge defaults → PLBeastDB (SavedVariablesPerCharacter)
  │    └─ dprint DB contents
  │
  └─ Fires PLAYER_LOGIN
       └─ Register /plbeast slash command
       └─ Print loaded confirmation
```

### Recommended Project Structure

```
PLBeast/
├── PLBeast.toc          # Addon manifest (Interface, SavedVariables, file list)
├── PLBeast.lua          # Main file: init, Print/dprint, slash stub
└── Locales/
    └── enUS.lua         # English locale table (PLBeastLocale global)
```

This mirrors the PLH structure exactly. The `PLBeast/` folder sits alongside `PackLeaderHelper/` at the repo root — both are independent addons that share only the physical repository.

### Pattern 1: Two-Phase Init (ADDON_LOADED → PLAYER_LOGIN)

**What:** WoW fires `ADDON_LOADED` once per addon file parse, before the world is available. `PLAYER_LOGIN` fires when the character enters the world and all APIs are safe to call.

**When to use:** Always — this is the canonical WoW addon init pattern.

**Example (adapted from PLH lines 2554–2601):**

```lua
-- Source: PackLeaderHelper.lua lines 2554-2601 (adapted)
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end
        -- Merge defaults into PLBeastDB
        PLBeastDB = PLBeastDB or {}
        for k, v in pairs(defaults) do
            if PLBeastDB[k] == nil then PLBeastDB[k] = v end
        end
        DB = PLBeastDB
        dprint("DB loaded: debug=" .. tostring(DB.debug) .. " nextIndex=" .. tostring(DB.nextIndex))

    elseif event == "PLAYER_LOGIN" then
        SLASH_PLBEAST1 = "/plbeast"
        SlashCmdList["PLBEAST"] = function(msg)
            msg = (msg or ""):lower():match("^%s*(.-)%s*$")
            Print(L["PLBeast loaded. Type /plbeast for options."])
        end
        Print(L["PLBeast loaded. Type /plbeast for options."])
    end
end)
```

### Pattern 2: Locale Metatable

**What:** A global Lua table for locale strings with a metatable `__index` that returns the key itself when no translation exists. This means `L["any string"]` always returns something — either the translation or the key.

**When to use:** All user-visible strings.

**Example (from PLH lines 1–8):**

```lua
-- Source: PackLeaderHelper.lua lines 1-8 (adapted)
local addonName = ...

local PREFIX = "|cff33ff99[PLBeast]|r "
local L = setmetatable(PLBeastLocale or {}, {
    __index = function(_, key)
        return key
    end,
})
```

The locale file sets the global before PLBeast.lua loads (TOC load order guarantees this):

```lua
-- Source: Locales/enUS.lua pattern
PLBeastLocale = {
    ["PLBeast loaded. Type /plbeast for options."] = "PLBeast loaded. Type /plbeast for options.",
}
```

### Pattern 3: Flat DB Defaults Merge (D-06)

**What:** A simple `for k,v in pairs` loop that fills in missing keys without overwriting existing values. This is simpler than PLH's recursive `CopyDefaults` because PLBeast's DB is flat (no nested tables).

```lua
-- Source: D-06 decision; simplified from PLH CopyDefaults (lines 102-112)
PLBeastDB = PLBeastDB or {}
for k, v in pairs(defaults) do
    if PLBeastDB[k] == nil then PLBeastDB[k] = v end
end
DB = PLBeastDB
```

### Pattern 4: Print / dprint helpers

**What:** `Print` prefixes output with the addon color tag and name. `dprint` gates output behind `DB.debug` and accepts variadic args joined with spaces.

```lua
-- Source: PackLeaderHelper.lua lines 114-122 (adapted)
local function Print(msg)
    print(PREFIX .. tostring(msg))
end

local function dprint(...)
    if DB and DB.debug then
        Print(table.concat({ ... }, " "))
    end
end
```

### Pattern 5: TOC File

**What:** The addon manifest. Field order matches PLH conventions. `SavedVariablesPerCharacter` (not `SavedVariables`) is required per D-04 and STRUCT-04.

```
## Interface: 120000, 120005, 120007
## Title: PLBeast
## Notes: Predicts and displays the next beast in the Pack Leader rotation.
## Author: cela28
## Version: 0.1.0
## SavedVariablesPerCharacter: PLBeastDB
## IconTexture: Interface\Icons\Ability_Hunter_AnimalCompanion

Locales\enUS.lua
PLBeast.lua
```

Key notes:
- `IconTexture` uses a WoW built-in icon path (per D-02, no Media/ folder in Phase 1)
- `Locales\enUS.lua` MUST appear before `PLBeast.lua` so `PLBeastLocale` global exists before the metatable wraps it
- No `## Interface-Retail:` or `## Interface-Classic:` split header needed — PLBeast targets retail only

### Anti-Patterns to Avoid

- **Loading PLBeast.lua before Locales/enUS.lua:** The main file does `setmetatable(PLBeastLocale or {}, ...)`. If the locale file has not been loaded yet, `PLBeastLocale` is nil and the `or {}` fallback silently swallows all locale strings. TOC load order is the fix.
- **Using `SavedVariables` instead of `SavedVariablesPerCharacter`:** STRUCT-04 and D-04 explicitly require PerCharacter. Using the wrong field means the rotation index is shared across all characters on the account.
- **Registering the slash command in ADDON_LOADED instead of PLAYER_LOGIN:** `SlashCmdList` can be written at any time, but WoW docs and PLH convention place slash registration in PLAYER_LOGIN after the world is ready. There is no functional difference for slash commands, but consistency with PLH is required (STRUCT-02).
- **Pre-wiring OnUpdate in scaffold:** D-04 explicitly prohibits this. Adding `eventFrame:SetScript("OnUpdate", ...)` in Phase 1 would contradict the locked decision.
- **Recursive CopyDefaults:** D-06 requires a flat merge. Using PLH's recursive version introduces unnecessary complexity and a function that Phase 1 has no need for.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Locale string fallback | Custom nil-check wrapper around every `L["..."]` call | Lua metatable `__index` on the locale table | One-time setup; zero per-call overhead |
| SavedVariables persistence | Custom file I/O or serialization | WoW `SavedVariablesPerCharacter` TOC field | WoW client handles read/write automatically on logout/reload |
| Slash command routing | Custom chat event listener parsing | `SLASH_<NAME>1` + `SlashCmdList` | WoW built-in; handles `/` prefix, arg splitting, and tab completion |

**Key insight:** In the WoW Lua sandbox, every system-level concern (persistence, commands, events) has an official built-in mechanism. Hand-rolling any of these is never correct.

---

## Runtime State Inventory

**Trigger condition:** This is a greenfield phase creating a new addon (not a rename/refactor of existing files). However, the PLBeast folder does not yet exist, so there is no pre-existing runtime state to inventory.

**Explicit answers per category:**

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — PLBeastDB does not exist yet; WoW will create it on first login | None |
| Live service config | None — PLBeast has no external service config | None |
| OS-registered state | None — no Task Scheduler, pm2, or system service entries for PLBeast | None |
| Secrets/env vars | None — WoW addons have no env vars or secrets | None |
| Build artifacts | None — WoW addons have no build step; files are loaded directly | None |

---

## Common Pitfalls

### Pitfall 1: TOC file load order — locale before main Lua
**What goes wrong:** If `PLBeast.lua` appears before `Locales\enUS.lua` in the TOC, the `PLBeastLocale` global is nil when the metatable is created. The `or {}` guard means the addon loads silently, but all `L["..."]` calls return the key string rather than a translation. This is invisible until a non-English client loads the addon.
**Why it happens:** Developers list the main file first by habit.
**How to avoid:** Always list locale files before the main Lua file in the TOC. PLH already does this (lines 11–13 of PLH.toc).
**Warning signs:** `L["some string"]` returns the literal key string instead of the localized value.

### Pitfall 2: Wrong SavedVariables field name
**What goes wrong:** Using `## SavedVariables: PLBeastDB` (global, shared across characters) instead of `## SavedVariablesPerCharacter: PLBeastDB`. The rotation tracking index (`nextIndex`) is character-specific — a shared DB would make all characters on the account share the same rotation position.
**Why it happens:** `SavedVariables` is more commonly documented in addon tutorials.
**How to avoid:** STRUCT-04 explicitly says PerCharacter. TOC field name must be `SavedVariablesPerCharacter`.
**Warning signs:** Rotation index changing unexpectedly when switching characters; or nextIndex being 1 on all characters always (if the global resets per-character accidentally).

### Pitfall 3: Interface version mismatch
**What goes wrong:** If the TOC declares Interface `110000` (The War Within) rather than `120000+` (Midnight), WoW will show the addon as "out of date" and may refuse to load it without enabling "Load out of date AddOns". The ROADMAP text incorrectly says "11.x" (D-10 flags this).
**Why it happens:** The ROADMAP was written with stale version info; it still says "The War Within (11.x)".
**How to avoid:** Use `120000, 120005, 120007` per D-08/D-09. The planner should note the ROADMAP text needs correction.
**Warning signs:** WoW shows "Interface version mismatch" or addon marked as incompatible in the AddOns list.

### Pitfall 4: addonName match guard missing
**What goes wrong:** ADDON_LOADED fires for every addon that loads. Without `if name ~= addonName then return end`, PLBeast's init code runs multiple times — once for each addon that loads.
**Why it happens:** The guard is easy to forget when adapting a minimal init from tutorials.
**How to avoid:** Always include the name guard. PLH line 2573 shows the exact pattern.
**Warning signs:** DB is initialized multiple times; dprint fires multiple times on load.

### Pitfall 5: PLBeastDB global vs. local DB alias timing
**What goes wrong:** If `dprint` is called before `DB = PLBeastDB` is executed, `dprint` checks `if DB and DB.debug` but DB is still nil. All debug output before the alias assignment is silently swallowed.
**Why it happens:** dprint is defined at file top (using `DB`), but DB is assigned inside the ADDON_LOADED handler.
**How to avoid:** The dprint-for-verification call (D-07) must happen after `DB = PLBeastDB` within the ADDON_LOADED handler. PLH's dprint already handles `if DB and DB.debug` safely (nil-checks DB first).
**Warning signs:** dprint calls before the DB alias produce no output; no obvious error.

---

## Code Examples

Verified patterns from PLH source (all tagged with source line references):

### Complete TOC File
```
-- Source: PackLeaderHelper.toc (adapted per D-08, D-09, D-02)
## Interface: 120000, 120005, 120007
## Title: PLBeast
## Notes: Predicts and displays the next beast in the Pack Leader rotation.
## Author: cela28
## Version: 0.1.0
## SavedVariablesPerCharacter: PLBeastDB
## IconTexture: Interface\Icons\Ability_Hunter_AnimalCompanion

Locales\enUS.lua
PLBeast.lua
```

### Complete enUS Locale File
```lua
-- Source: Locales/enUS.lua (adapted)
PLBeastLocale = {
    ["PLBeast loaded. Type /plbeast for options."] = "PLBeast loaded. Type /plbeast for options.",
    ["Cannot open options in combat."] = "Cannot open options in combat.",
    ["debug=%s"] = "debug=%s",
}
```

### Complete PLBeast.lua Skeleton
```lua
-- Source: PackLeaderHelper.lua lines 1-8, 102-122, 2479-2481, 2554-2607 (adapted, stripped to scaffold)
local addonName = ...

local PREFIX = "|cff33ff99[PLBeast]|r "
local L = setmetatable(PLBeastLocale or {}, {
    __index = function(_, key)
        return key
    end,
})

-- SavedVariablesPerCharacter (declared in PLBeast.toc)
PLBeastDB = PLBeastDB or {}
local DB = PLBeastDB

local defaults = {
    debug   = false,
    nextIndex = 1,  -- 1=wyvern, 2=boar, 3=bear
}

local function Print(msg)
    print(PREFIX .. tostring(msg))
end

local function dprint(...)
    if DB and DB.debug then
        Print(table.concat({ ... }, " "))
    end
end

------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end
        -- Flat defaults merge (D-06)
        PLBeastDB = PLBeastDB or {}
        for k, v in pairs(defaults) do
            if PLBeastDB[k] == nil then PLBeastDB[k] = v end
        end
        DB = PLBeastDB
        -- Verify SavedVariables round-trip (D-07)
        dprint("DB loaded: debug=" .. tostring(DB.debug) .. " nextIndex=" .. tostring(DB.nextIndex))

    elseif event == "PLAYER_LOGIN" then
        SLASH_PLBEAST1 = "/plbeast"
        SlashCmdList["PLBEAST"] = function(msg)
            msg = (msg or ""):lower():match("^%s*(.-)%s*$")
            Print(L["PLBeast loaded. Type /plbeast for options."])
        end
        Print(L["PLBeast loaded. Type /plbeast for options."])
    end
end)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single `## Interface: NNNNN` in TOC | Comma-separated range `## Interface: 120000, 120005, 120007` | Midnight (12.x) multi-patch support | One TOC covers multiple patch versions without needing per-patch updates |
| `SavedVariables` for everything | `SavedVariablesPerCharacter` for per-character state | Always valid; just less used in tutorials | Rotation index is per-character |

**Deprecated/outdated:**
- `## Interface-Retail:` / `## Interface-Classic:` split header: Only needed for addons targeting both retail and classic simultaneously. PLBeast is retail-only — use plain `## Interface:`.
- ROADMAP text "The War Within (11.x)": Outdated per D-10. The current expansion is Midnight (12.x). Planner should correct the ROADMAP Phase 1 success criterion text in-place when writing the PLAN.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Interface\Icons\Ability_Hunter_AnimalCompanion` is a valid built-in WoW icon path usable in TOC IconTexture | Standard Stack / TOC example | TOC would load fine; the icon just appears blank in the AddOns list. Low risk — no functional impact |
| A2 | Midnight current patch is 12.0.7 (Interface `120007`) | Standard Stack / TOC | TOC Interface ceiling may be wrong; WoW shows addon as out of date. User can correct from in-game AddOns list |

**All other claims are VERIFIED** against PLH source code committed to this repo (`PackLeaderHelper.toc`, `PackLeaderHelper.lua`, `Locales/enUS.lua`).

---

## Open Questions (RESOLVED)

1. **Built-in icon path for TOC IconTexture** — RESOLVED: Use `Interface\Icons\Ability_Hunter_AnimalCompanion` per D-02. Plan task includes this path in TOC.
   - What we know: D-02 says use a WoW built-in icon; PLH uses a Media/ file path
   - What's unclear: The exact string for a hunter/beast icon that will display in the Addon list
   - Recommendation: Use `Interface\Icons\Ability_Hunter_AnimalCompanion` (a known hunter icon ID) or omit the field entirely — omitting causes no error, just no icon in the AddOns list. The planner can default to omitting and leave it as a low-priority polish task.

2. **ROADMAP text correction (D-10)** — RESOLVED: ROADMAP correction included in plan Task 1 per D-10.
   - What we know: ROADMAP Phase 1 success criterion #3 says "The War Within (11.x)" — this is wrong
   - What's unclear: Whether the planner should patch ROADMAP.md in this phase or defer
   - Recommendation: Include a task to correct the ROADMAP text as part of Phase 1 scaffold work, since D-10 is a locked decision.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Text editor / git | File creation | ✓ | — | — |
| WoW retail client (12.0.x) | Live `/reload` test | unknown | — | Cannot test in-game without the client; manual verification step |
| WoW AddOns folder write access | Addon installation for testing | unknown | — | Symlink or copy PLBeast/ folder |

**Missing dependencies with no fallback:**
- WoW retail client: Required for the success criteria "WoW loads the addon without Lua errors on `/reload`" and the SavedVariables round-trip test. Cannot be automated — these are manual verification steps.

**Missing dependencies with fallback:**
- None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None — WoW Lua sandbox; no automated test runner available |
| Config file | N/A |
| Quick run command | `/reload` in WoW client |
| Full suite command | Manual checklist (see below) |

**Note:** `workflow.nyquist_validation: true` is set in config.json but WoW addon testing is exclusively manual in-game. No automated test runner exists for this environment. The planner must represent verification as manual steps, not automated commands.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| STRUCT-01 | `PLBeast/` folder exists at repo root | manual | `ls PLBeast/` (on disk; not in-game) | ❌ Wave 0 (create folder) |
| STRUCT-02 | Code adapted from PLH (not from scratch) | review | Code diff against PLH source | ❌ Wave 0 (create files) |
| STRUCT-03 | TOC Interface version is 120000+ | manual | `cat PLBeast/PLBeast.toc` | ❌ Wave 0 (create file) |
| STRUCT-04 | SavedVariablesPerCharacter in TOC | manual | `grep SavedVariablesPerCharacter PLBeast/PLBeast.toc` | ❌ Wave 0 (create file) |
| STRUCT-05 | enUS locale loadable and referenced | manual / in-game | `/reload` + check for Lua errors | ❌ Wave 0 (create file) |

### Sampling Rate
- **Per task commit:** `ls PLBeast/ && grep -c "SavedVariablesPerCharacter" PLBeast/PLBeast.toc`
- **Per wave merge:** Full manual checklist below
- **Phase gate:** All 4 success criteria verified manually in WoW client before `/gsd-verify-work`

### Manual Verification Checklist (Phase Gate)

```
1. Copy/symlink PLBeast/ into WoW/_retail_/Interface/AddOns/
2. Launch WoW, enable PLBeast in AddOns list
3. Log in with a hunter character
4. Confirm: no Lua errors in chat or error frame on login
5. Type /plbeast — confirm printed confirmation message appears
6. Type /reload — confirm addon reloads cleanly (no errors)
7. Check SavedVariables file: WoW/WTF/.../SavedVariablesPerCharacter/PLBeast.lua
   - Confirm PLBeastDB = { debug = false, nextIndex = 1 } (or modified values)
8. Log out fully, log back in
   - Confirm PLBeastDB values survive the cycle
9. Enable debug: /plbeast debug (v2 feature — skip in Phase 1; dprint fires only if DB.debug=true)
   - For Phase 1 verification: manually set DB.debug=true in the SavedVariables file and reload
   - Confirm dprint output appears on ADDON_LOADED
```

### Wave 0 Gaps
- [ ] `PLBeast/PLBeast.toc` — covers STRUCT-01, STRUCT-03, STRUCT-04
- [ ] `PLBeast/PLBeast.lua` — covers STRUCT-01, STRUCT-02, STRUCT-05 (locale reference)
- [ ] `PLBeast/Locales/enUS.lua` — covers STRUCT-05

*(All three files are Wave 0 creation tasks — none exist yet)*

---

## Security Domain

**Not applicable.** WoW addons run inside the WoW Lua sandbox with no network access, no file system access outside SavedVariables, and no user-supplied input execution paths beyond slash commands (which execute only pre-defined Lua branches). ASVS categories V2–V6 do not apply to this domain.

---

## Sources

### Primary (HIGH confidence)
- `PackLeaderHelper.toc` (this repo) — TOC field names, Interface versions, file load order, SavedVariables declaration
- `PackLeaderHelper.lua` lines 1–8 (this repo) — addonName capture, locale metatable, PREFIX pattern
- `PackLeaderHelper.lua` lines 102–122 (this repo) — CopyDefaults, Print, dprint
- `PackLeaderHelper.lua` lines 2479–2481 (this repo) — slash command registration pattern
- `PackLeaderHelper.lua` lines 2554–2607 (this repo) — event frame creation, ADDON_LOADED/PLAYER_LOGIN handlers
- `Locales/enUS.lua` (this repo) — locale table structure

### Secondary (MEDIUM confidence)
- CONTEXT.md decisions D-01 through D-10 — locked implementation choices from discuss-phase

### Tertiary (LOW confidence)
- None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — entire domain is WoW built-in APIs; no external packages
- Architecture: HIGH — exact patterns verified from PLH source committed to repo
- Pitfalls: HIGH — verified from PLH source and WoW addon development conventions
- Interface version: HIGH — D-08/D-09 lock this; 120000/120005/120007 match PLH.toc pattern

**Research date:** 2026-06-18
**Valid until:** Stable — WoW Lua addon file structure has been stable for 10+ years; no external dependency drift risk
