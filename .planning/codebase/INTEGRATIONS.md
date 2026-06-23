# External Integrations

**Analysis Date:** 2026-06-18

## APIs & External Services

This is a World of Warcraft addon. All integrations are with in-process WoW client APIs. There are no HTTP requests, external web services, or network calls made by addon code.

**WoW Aura/Buff API:**
- `C_UnitAuras.GetPlayerAuraBySpellID(spellId)` — checks current player buff state for Pack Leader spell IDs
- `C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceID)` — reads specific aura instance data
- `C_UnitAuras.GetAuraDuration("player", auraInstanceID)` — reads remaining duration of a specific aura
- Used in `PackLeaderHelper.lua` at lines ~1753–1799

**WoW Cooldown Viewer API (Blizzard CDM integration):**
- `C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)` — resolves cooldownID to spellID and metadata
- `C_CooldownViewer.GetCooldownViewerCategorySet(categoryIndex)` — retrieves the set of tracked spells for a CDM category
- `EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", ...)` — reacts to user changes in CDM settings
- Events: `COOLDOWN_VIEWER_DATA_LOADED`, `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED`
- Used in `PackLeaderHelper.lua` at lines ~1826–1939, 2567–2668

**WoW Talent/Spec API:**
- `GetSpecialization()` / `GetSpecializationInfo(specIndex)` — detects Hunter spec (Beast Mastery = 253, Survival = 255)
- `IsPlayerSpell(spellID)` — detects which hero talent tree (Pack Leader vs Sentinel vs Dark Ranger) is active; also detects Wyvern's Gaze talent choice
- Events: `PLAYER_TALENT_UPDATE`, `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `ACTIVE_COMBAT_CONFIG_CHANGED`, `TRAIT_CONFIG_UPDATED`, `TRAIT_SUB_TREE_CHANGED`
- Used in `PackLeaderHelper.lua` at lines ~1574–1638

**WoW Spell/Combat Events:**
- `UNIT_SPELLCAST_SUCCEEDED` — tracks Kill Command casts to infer hunter mode and trigger wyvern extend logic
- `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` — combat enter/leave for UI gating
- `CHALLENGE_MODE_START`, `ENCOUNTER_START` — Mythic+ and raid encounter detection
- Used in `PackLeaderHelper.lua` at lines ~2557–2670

## Data Storage

**Databases:**
- None — no external database

**Persistent Storage:**
- WoW `SavedVariables` system via `PackLeaderHelperDB`
  - Declared in `PackLeaderHelper.toc` line 8: `## SavedVariables: PackLeaderHelperDB`
  - WoW writes this to disk as Lua code in the client's SavedVariables folder between sessions
  - Stores: layout config, tracker position/scale, hide flags, next-beast prediction index, debug flag

**File Storage:**
- Media assets bundled in `Media/` directory (read-only textures used by WoW client):
  - `Media/plh.tga` — addon icon (referenced in TOC `IconTexture`)
  - `Media/cdm.png` — usage guide image displayed in options panel
  - `Media/PLH.jpg` — appears to be a promotional/reference image

**Caching:**
- In-memory only: CDM spell cache (`cdmCache` table) built at `PLAYER_LOGIN` and rebuilt on CDM setting changes
- No disk cache beyond SavedVariables

## Authentication & Identity

**Auth Provider:**
- None — WoW addons run inside the authenticated WoW client session; no separate auth mechanism

## Monitoring & Observability

**Error Tracking:**
- None — no external error tracking service
- Debug logging to WoW chat via `dprint()` when `DB.debug == true` (`/plh debug` to toggle)
- `pcall` guards around `C_CooldownViewer` and `C_UnitAuras` API calls to prevent Lua errors from crashing the addon (lines ~1881, ~1771, ~1797)

**Logs:**
- In-game chat output via `print()` wrapper (`PREFIX .. msg`) for status messages and `/plh` command responses

## CI/CD & Deployment

**Hosting:**
- Curseforge / WoWInterface / manual zip distribution (standard WoW addon distribution)
- No CI pipeline detected in the repository

**CI Pipeline:**
- None detected

## Environment Configuration

**Required env vars:**
- None — WoW addons have no environment variables

**Secrets location:**
- Not applicable — no secrets, API keys, or credentials of any kind

## Webhooks & Callbacks

**Incoming:**
- WoW event callbacks via `SetScript("OnEvent", ...)` on `eventFrame` — receives all registered game events
- `EventRegistry` callback for `CooldownViewerSettings.OnDataChanged`

**Outgoing:**
- None — no HTTP webhooks or outbound network calls

## Blizzard Frame System Integration

**Frames referenced/manipulated:**
- `UIParent` — root anchor for all addon frames
- `BuffBarCooldownViewer`, `BuffIconCooldownViewer`, `CDMGroups_Buffs`, `EssentialCooldownViewer` — Blizzard CDM frames hidden/shown via scale/alpha manipulation (not parenting) in `PackLeaderHelper.lua` at lines ~1849–1877
- `PackLeaderHelperFrame` — named root tracker frame anchored to `UIParent`
- `PackLeaderHelperOptionsFrame` — named options panel

---

*Integration audit: 2026-06-18*
