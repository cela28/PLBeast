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
	debug    = false,
	nextIndex = 1,  -- 1=wyvern, 2=boar, 3=bear
	-- Phase 4: icon position, size, border, and drag-lock settings
	offsetX         = 0,
	offsetY         = 0,
	width           = 40,
	height          = 40,
	borderThickness = 1,
	borderColor     = { r = 0, g = 0, b = 0, a = 1 },
	locked          = false,
}

------------------------------------------------------------
-- Spell ID Constants
------------------------------------------------------------
-- Source: PackLeaderHelper.lua lines 13–15, 24–25
local SPELL_READY_WYVERN = 471878
local SPELL_READY_BOAR   = 472324
local SPELL_READY_BEAR   = 472325

-- Source: PackLeaderHelper.lua lines 11, 21-22 — direct copy
local SPELL_HOTPL_PARENT       = 471876  -- Pack Leader parent spell; primary hero-talent gate
local SPELL_SENTINEL_ANCHOR    = 1253599 -- Sentinel hero talent anchor; mutually exclusive with Pack Leader
local SPELL_DARK_RANGER_ANCHOR = 466930  -- Dark Ranger hero talent anchor; mutually exclusive with Pack Leader

local SPEC_HUNTER_BEAST_MASTERY = 253
local SPEC_HUNTER_SURVIVAL      = 255

------------------------------------------------------------
-- Rotation Data Tables
------------------------------------------------------------
-- Source: PackLeaderHelper.lua lines 1494–1515
local NEXT_BEAST = {
	boar   = "bear",
	bear   = "wyvern",
	wyvern = "boar",
}
local ID_BY_INDEX = { "wyvern", "boar", "bear" }
local INDEX_BY_ID = { wyvern = 1, boar = 2, bear = 3 }
local READY_SPELL_BY_ID = {
	wyvern = SPELL_READY_WYVERN,
	boar   = SPELL_READY_BOAR,
	bear   = SPELL_READY_BEAR,
}
-- Source: PackLeaderHelper.lua lines 1516–1524 (trimmed to the three beast-ready spells)
-- Used by RegisterDiscoveredCooldown to filter the CDM scan to only tracked spells.
local TRACKED_SPELL_IDS = {
	[SPELL_READY_WYVERN] = true,
	[SPELL_READY_BOAR]   = true,
	[SPELL_READY_BEAR]   = true,
}
local BEAST_LABEL_BY_ID = {
	wyvern = "Wyvern",
	boar   = "Boar",
	bear   = "Bear",
}
-- Source: PackLeaderHelper.lua lines 29–31 (ICON_DRAGON_READY, ICON_PIG_READY, ICON_BEAR_READY)
-- Three-beast subset; drives texture selection from nextBeastId. (D-06)
local ICON_FILE_BY_ID = {
	wyvern = 773276,  -- ICON_DRAGON_READY
	boar   = 132184,  -- ICON_PIG_READY
	bear   = 132183,  -- ICON_BEAR_READY
}

------------------------------------------------------------
-- Module-Level State Variables
------------------------------------------------------------
-- Source: PackLeaderHelper.lua lines 1532–1535, 1545 (trimmed for PLBeast scope)
-- Note: PLBeast uses "wyvern" as default, not "boar" (PLH convention)
local nextBeastId    = "wyvern"
local isBeastMastery = false
local isSurvival     = false
local isPackLeaderActive = false  -- D-01: true only when BM/SV spec and Pack Leader hero talent active

-- Snapshot for diff: tracks which ready buffs were active at last check (D-01, TRACK-05)
local prevReady = { wyvern = false, boar = false, bear = false }

-- CDM (Cooldown Manager) integration state. Beast-ready states are NOT exposed as
-- player auras; they live in C_CooldownViewer frames signaled by cdmFrame.auraInstanceID.
-- Source: PackLeaderHelper.lua lines 1551–1552.
local cdmCache = {}          -- spellID -> { cooldownID, cdmFrame }
local cdmCacheBuilt = false

-- Poll ticker handle: CDM readiness is not reliably delivered via UNIT_AURA, so a
-- C_Timer ticker drives CheckAuraState while isPackLeaderActive. Started/stopped in
-- RefreshVisibility alongside UNIT_AURA register/unregister.
local pollTicker = nil
local POLL_INTERVAL = 0.1

-- Round-2 throttle: when CDM reads come back all-false the cache MAY be stale, but it is
-- also legitimately all-false during rotation downtime. Rebuilding on every 10Hz poll
-- during downtime would re-scan the CDM frame tree needlessly, so the rebuild-on-miss
-- self-heal is rate-limited to at most once per CDM_REBUILD_COOLDOWN seconds.
local CDM_REBUILD_COOLDOWN = 1.0
local lastCDMRebuildAt = 0

-- Forward declaration: eventFrame is created in the Event Handler section below.
-- Declared here so Core Functions (RefreshVisibility) can reference it as an upvalue.
local eventFrame

-- Forward declaration: root is assigned inside CreateBeastIcon() at PLAYER_LOGIN.
-- Declared here so SetNextBeastId() and RefreshVisibility() can guard against nil. (Pitfall 5)
local root

-- Phase 5 forward declarations: options frame and combat-deferred open flag.
-- optionsFrame is lazy-created inside ToggleOptions() on first /plbeast invocation.
-- pendingOptionsOpenAfterCombat is set when /plbeast is typed during combat; cleared and
-- acted on by the PLAYER_REGEN_ENABLED handler (D-07, CFG-04).
local optionsFrame
local pendingOptionsOpenAfterCombat = false

-- ToggleOptions is defined in the Options Frame Helpers section (before the event handler).
-- No forward declaration is needed because ToggleOptions() is defined before eventFrame's
-- OnEvent script captures it in closures (PLAYER_LOGIN slash handler, PLAYER_REGEN_ENABLED branch).

------------------------------------------------------------
-- Utility
------------------------------------------------------------

local function Print(msg)
	print(PREFIX .. tostring(msg))
end

local function dprint(...)
	if DB and DB.debug then
		Print(table.concat({ ... }, " "))
	end
end

------------------------------------------------------------
-- Core Functions
------------------------------------------------------------

-- Source: PackLeaderHelper.lua lines 1526–1530 — direct copy
-- Clamps DB.nextIndex to 1–3; corrupted values resolve to 1 (wyvern). (T-02-01)
local function NormalizeNextIndex()
	local idx = tonumber(DB.nextIndex) or 1
	if idx < 1 or idx > 3 then idx = 1 end
	DB.nextIndex = idx
end

-- Source: PackLeaderHelper.lua lines 1647–1651
-- Note: Default fallback is "wyvern" (PLH uses "boar"; intentional PLBeast deviation)
local function SetNextBeastId(beastId)
	nextBeastId = beastId or "wyvern"
	DB.nextIndex = INDEX_BY_ID[nextBeastId] or 1
	NormalizeNextIndex()
	-- Phase 4: push texture onto icon when frame exists (guard required: called before frame exists, Pitfall 5)
	if root and root.tex then
		root.tex:SetTexture(ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.wyvern)
	end
end

-- Source: PackLeaderHelper.lua lines 1653–1676 (adapted: readySnapshot arg → flat startTimes table)
-- Sorts added beasts by start time ascending (D-04) then advances rotation via NEXT_BEAST.
local function SyncNextFromAddedReady(addedBeasts, startTimes)
	if not addedBeasts or #addedBeasts == 0 then return end

	table.sort(addedBeasts, function(a, b)
		local sa = (startTimes and startTimes[a]) or 0
		local sb = (startTimes and startTimes[b]) or 0
		if sa > 0 and sb > 0 and sa ~= sb then
			return sa < sb
		end
		return (INDEX_BY_ID[a] or 99) < (INDEX_BY_ID[b] or 99)
	end)

	for _, beastId in ipairs(addedBeasts) do
		SetNextBeastId(NEXT_BEAST[beastId] or "wyvern")
	end
end

-- Source: PackLeaderHelper.lua lines 1688–1716 (trimmed — CDM/wyvern/hogstrider state removed)
-- Only clears prevReady. If resetOrder is true, also resets the rotation to wyvern.
local function ResetAuraState(resetOrder)
	for beastId in pairs(READY_SPELL_BY_ID) do
		prevReady[beastId] = false
	end
	if resetOrder then
		SetNextBeastId("wyvern")
	end
end

-- Shared reset used by PLAYER_ENTERING_WORLD (fresh login) and ENCOUNTER_START (boss pull).
-- SetNextBeastId sets nextBeastId + DB.nextIndex and updates the icon texture.
-- ResetAuraState(false) clears prevReady against the new wyvern starting point;
-- false avoids a redundant SetNextBeastId("wyvern") since SetNextBeastId was just called.
local function ResetRotationToWyvern()
	SetNextBeastId("wyvern")
	ResetAuraState(false)
end

------------------------------------------------------------
-- CDM (Cooldown Manager) Ready-Detection Path
------------------------------------------------------------
-- The Pack Leader beast-ready states are tracked by the Blizzard Cooldown Manager
-- (C_CooldownViewer), NOT exposed as player auras under their spell IDs. Readiness is
-- signaled by a tracked frame's auraInstanceID being a positive number.
-- Adapted from PackLeaderHelper.lua lines 1805–1989 (minimal three-beast subset).

-- Source: PackLeaderHelper.lua lines 1826, 1832–1833 (constants)
local CDM_FRAME_ROOT_NAMES = { "BuffBarCooldownViewer", "BuffIconCooldownViewer", "CDMGroups_Buffs" }
local CDM_CATEGORY_INDEXES = { 0, 1, 2, 3, 4, 5 }
local MAX_DISCOVERY_DEPTH  = 4

-- Source: PackLeaderHelper.lua lines 1805–1824
-- Walks the CDMGroups_Buffs frame tree to find the frame owning a given cooldownID.
local function FindCDMFrameByCooldownID(targetCooldownID)
	local rootFrame = _G["CDMGroups_Buffs"]
	if not rootFrame or not targetCooldownID then return nil end

	local function scan(frame, depth)
		if not frame or depth > MAX_DISCOVERY_DEPTH then return nil end
		local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
		if cdID == targetCooldownID then return frame end
		if frame.GetChildren then
			for i = 1, select("#", frame:GetChildren()) do
				local child = select(i, frame:GetChildren())
				local found = scan(child, depth + 1)
				if found then return found end
			end
		end
		return nil
	end

	return scan(rootFrame, 0)
end

-- Source: PackLeaderHelper.lua lines 1879–1886 — pcall-guarded cooldownID → spellID resolve.
local function ReadSpellFromCooldownID(cooldownID)
	if not cooldownID or cooldownID <= 0 then return nil end
	if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then return nil end
	local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
	if not ok or not info or not info.spellID or info.spellID <= 0 then
		return nil
	end
	return info.spellID
end

-- Source: PackLeaderHelper.lua lines 1888–1899
-- Records a tracked spell's cooldownID + frame ref into the result map.
local function RegisterDiscoveredCooldown(resultMap, cooldownID, frameRef)
	local spellID = ReadSpellFromCooldownID(cooldownID)
	if not spellID or not TRACKED_SPELL_IDS[spellID] then return end
	local slot = resultMap[spellID]
	if not slot then
		resultMap[spellID] = { cooldownID = cooldownID, cdmFrame = frameRef }
		return
	end
	if frameRef and not slot.cdmFrame then
		slot.cdmFrame = frameRef
	end
end

-- Source: PackLeaderHelper.lua lines 1901–1923 — BFS over a CDM frame tree.
local function GatherCooldownsFromFrameTree(resultMap, rootFrame)
	if not rootFrame then return end
	local queue = { { frame = rootFrame, depth = 0 } }
	local qHead = 1
	local seen = {}
	while qHead <= #queue do
		local node = queue[qHead]
		qHead = qHead + 1
		local f = node.frame
		local depth = node.depth
		if f and not seen[f] then
			seen[f] = true
			local cooldownID = f.cooldownID or (f.cooldownInfo and f.cooldownInfo.cooldownID)
			RegisterDiscoveredCooldown(resultMap, cooldownID, f)
			if depth < MAX_DISCOVERY_DEPTH and f.GetChildren then
				for i = 1, select("#", f:GetChildren()) do
					local child = select(i, f:GetChildren())
					queue[#queue + 1] = { frame = child, depth = depth + 1 }
				end
			end
		end
	end
end

-- Source: PackLeaderHelper.lua lines 1925–1934 — pcall-guarded category scan.
local function GatherCooldownsFromViewerCategories(resultMap)
	if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet) then return end
	for _, cat in ipairs(CDM_CATEGORY_INDEXES) do
		local ok, cooldownIDs = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, cat)
		if ok and cooldownIDs then
			for _, cooldownID in ipairs(cooldownIDs) do
				RegisterDiscoveredCooldown(resultMap, cooldownID, nil)
			end
		end
	end
end

-- Source: PackLeaderHelper.lua lines 1936–1949
-- Builds the spellID → { cooldownID, cdmFrame } cache. Guarded against missing CDM API. (T-02-03)
local function BuildCDMCache()
	cdmCache = {}
	cdmCacheBuilt = false
	if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then return end

	local discovered = {}
	for _, frameName in ipairs(CDM_FRAME_ROOT_NAMES) do
		GatherCooldownsFromFrameTree(discovered, _G[frameName])
	end
	GatherCooldownsFromViewerCategories(discovered)

	cdmCache = discovered
	cdmCacheBuilt = true
end

-- Source: PackLeaderHelper.lua lines 1958–1964 (extended for round-2 stale-frame self-heal)
-- Lazily resolves frame refs for entries discovered via category scan (no frame yet),
-- AND re-resolves entries whose cached cdmFrame has gone stale. The Blizzard Cooldown
-- Manager recycles its frame pool: a once-valid cdmFrame can be reassigned to a different
-- cooldown (its .cooldownID no longer matches our cooldownID) or detached. When that
-- happens auraInstanceID reads go nil for all beasts and the rotation freezes (round-2
-- symptom: stuck after ~2 beasts). Detect the mismatch and re-find the owning frame by
-- cooldownID, exactly as the parent does after a BuildCDMCache rebuild. (rotation-stuck-wyvern R2)
local function FrameStillOwnsCooldown(frame, cooldownID)
	if not frame or not cooldownID then return false end
	local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
	return cdID == cooldownID
end

local function EnsureCacheFramesResolved()
	for _, data in pairs(cdmCache) do
		if data.cooldownID then
			if not data.cdmFrame or not FrameStillOwnsCooldown(data.cdmFrame, data.cooldownID) then
				data.cdmFrame = FindCDMFrameByCooldownID(data.cooldownID)
			end
		end
	end
end

-- Source: PackLeaderHelper.lua lines 1977–1989 (primary CDM read path)
-- "Ready" = the tracked CDM frame's auraInstanceID is a positive number.
local function IsReadyViaCDM(spellId)
	local slot = cdmCache[spellId]
	local inst = slot and slot.cdmFrame and slot.cdmFrame.auraInstanceID
	return type(inst) == "number" and inst > 0
end

-- Source: PackLeaderHelper.lua lines 1753–1756 guard pattern (secondary fallback)
-- Guards C_UnitAuras availability; graceful degradation to false when API unavailable. (T-02-03)
local function IsReadyViaAura(spellId)
	if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
		return false
	end
	return C_UnitAuras.GetPlayerAuraBySpellID(spellId) ~= nil
end

-- Combined read: CDM (primary, the source where readiness actually lives) with
-- C_UnitAuras as a secondary fallback. Root cause fix for rotation-stuck-wyvern.
local function IsReadyBuffActive(spellId)
	if IsReadyViaCDM(spellId) then
		return true
	end
	return IsReadyViaAura(spellId)
end

-- Pattern derived from: PackLeaderHelper.lua lines 2076–2111 (snapshot-diff structure)
-- and lines 1991–2003 (C_UnitAuras direct read path)
-- Diffs current aura state against prevReady; advances rotation on each new buff. (D-01, TRACK-05)
local function CheckAuraState()
	-- Ensure the CDM cache exists and frame refs are resolved before reading. The cache is
	-- built lazily here so it survives a not-yet-ready CDM at login. (T-02-03)
	if not cdmCacheBuilt then
		BuildCDMCache()
	end
	if cdmCacheBuilt then
		EnsureCacheFramesResolved()
	end

	local current = {
		wyvern = IsReadyBuffActive(SPELL_READY_WYVERN),
		boar   = IsReadyBuffActive(SPELL_READY_BOAR),
		bear   = IsReadyBuffActive(SPELL_READY_BEAR),
	}

	-- Round-2 self-heal: if the cache is built but yields no readiness for ANY beast via
	-- the CDM path, the cached cooldownID→frame mapping may itself be stale (the CDM pool
	-- was rebuilt and cooldownIDs reassigned, so re-resolving by the OLD cooldownID finds
	-- nothing). Rebuild the whole cache once and re-read. Without this, reads stay all-false
	-- forever and the rotation freezes after ~2 beasts until a /reload. (rotation-stuck-wyvern R2)
	if cdmCacheBuilt and not (current.wyvern or current.boar or current.bear) then
		local now = (GetTime and GetTime()) or 0
		if now - lastCDMRebuildAt >= CDM_REBUILD_COOLDOWN then
			lastCDMRebuildAt = now
			BuildCDMCache()
			if cdmCacheBuilt then
				EnsureCacheFramesResolved()
				current.wyvern = IsReadyBuffActive(SPELL_READY_WYVERN)
				current.boar   = IsReadyBuffActive(SPELL_READY_BOAR)
				current.bear   = IsReadyBuffActive(SPELL_READY_BEAR)
			end
		end
	end

	local addedBeasts = {}
	local startTimes  = {}
	for _, id in ipairs({ "wyvern", "boar", "bear" }) do
		if current[id] and not prevReady[id] then
			addedBeasts[#addedBeasts + 1] = id
			-- Capture start time for multi-beast sort (D-04); nil guards per T-02-06
			local aura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
			             and C_UnitAuras.GetPlayerAuraBySpellID(READY_SPELL_BY_ID[id])
			startTimes[id] = (aura and aura.expirationTime and aura.duration)
			                 and (aura.expirationTime - aura.duration) or 0
		end
	end

	if #addedBeasts > 0 then
		SyncNextFromAddedReady(addedBeasts, startTimes)
	end

	prevReady = current

	-- D-06: use BEAST_LABEL_BY_ID for capitalized next= field (Pitfall 5)
	dprint(
		"next="   .. (BEAST_LABEL_BY_ID[nextBeastId] or "?"),
		"wyvern=" .. tostring(current.wyvern),
		"boar="   .. tostring(current.boar),
		"bear="   .. tostring(current.bear),
		"idx="    .. tostring(DB.nextIndex)
	)
end

-- Pattern: PLH calls PollCDMState() in PLAYER_LOGIN to seed state (line 2588).
-- PLBeast seeds prevReady directly without CDM dependency. (D-02)
-- Must be called BEFORE UNIT_AURA is registered to prevent double-advancement on login (Pitfall 1).
local function SeedAuraSnapshot()
	prevReady.wyvern = IsReadyBuffActive(SPELL_READY_WYVERN)
	prevReady.boar   = IsReadyBuffActive(SPELL_READY_BOAR)
	prevReady.bear   = IsReadyBuffActive(SPELL_READY_BEAR)
end

-- Source: PackLeaderHelper.lua lines 1582–1587 (TRACK-04 spec awareness)
-- Phase 3: spec flags now gate visibility via RefreshVisibility() (not just debug output).
local function RefreshHunterSpecState()
	local specIndex = GetSpecialization and GetSpecialization()
	local specID = specIndex and GetSpecializationInfo
	               and GetSpecializationInfo(specIndex) or nil
	isBeastMastery = specID == SPEC_HUNTER_BEAST_MASTERY
	isSurvival     = specID == SPEC_HUNTER_SURVIVAL
end

-- Source: PackLeaderHelper.lua lines 1574–1580 — direct copy
-- Returns true only when the player has Pack Leader hero talent active,
-- excluding Sentinel and Dark Ranger hero trees (mutually exclusive).
local function IsPackLeaderHeroTalent()
	if not IsPlayerSpell(SPELL_HOTPL_PARENT) then return false end
	if IsPlayerSpell(SPELL_SENTINEL_ANCHOR) or IsPlayerSpell(SPELL_DARK_RANGER_ANCHOR) then
		return false
	end
	return true
end

-- CDM readiness is not reliably delivered via UNIT_AURA (the parent addon drives detection
-- off a polling tick, not UNIT_AURA). These start/stop the C_Timer poll ticker that runs
-- CheckAuraState while isPackLeaderActive. Source: PackLeaderHelper.lua PollCDMState drive.
local function StartPollTicker()
	if pollTicker then return end
	if not (C_Timer and C_Timer.NewTicker) then return end
	pollTicker = C_Timer.NewTicker(POLL_INTERVAL, function()
		CheckAuraState()
	end)
end

local function StopPollTicker()
	if pollTicker then
		pollTicker:Cancel()
		pollTicker = nil
	end
end

-- Source: PackLeaderHelper.lua lines 1605–1620 (adapted — strips wyvern duration logic)
-- Sets isPackLeaderActive flag; conditionally registers/unregisters UNIT_AURA. (D-01, D-02)
local function RefreshVisibility()
	RefreshHunterSpecState()
	local isHunterSpec = isBeastMastery or isSurvival
	local isPackLeader = IsPackLeaderHeroTalent()
	local wasActive    = isPackLeaderActive
	isPackLeaderActive = isHunterSpec and isPackLeader

	-- D-04: debug output works regardless of visibility state
	dprint(
		"spec=" .. (isBeastMastery and "BM" or (isSurvival and "SV" or "other")),
		"packLeader=" .. tostring(isPackLeaderActive)
	)

	if isPackLeaderActive and not wasActive then
		-- Re-activation: build the CDM cache, then seed the snapshot from the (now CDM-aware)
		-- read first to prevent spurious rotation advance on activation (Pitfall 2).
		BuildCDMCache()
		SeedAuraSnapshot()
		eventFrame:RegisterEvent("UNIT_AURA")
		-- CDM readiness is not delivered via UNIT_AURA; the poll ticker is the primary drive.
		StartPollTicker()
	elseif not isPackLeaderActive and wasActive then
		eventFrame:UnregisterEvent("UNIT_AURA")
		StopPollTicker()
	end
	-- Phase 4: visibility bridge — show/hide icon with Pack Leader spec/talent state (D-01)
	if root then
		root:SetShown(isPackLeaderActive)
	end
end

-- Source: PackLeaderHelper.lua lines 1622–1638 (adapted — single pending flag, no wyvern-buff arg)
-- Defers RefreshVisibility() one frame so IsPlayerSpell reads updated talent state. (T-03-05)
local pendingVisibilityRefresh = false

local function QueueVisibilityRefresh()
	if pendingVisibilityRefresh then return end
	pendingVisibilityRefresh = true
	C_Timer.After(0, function()
		pendingVisibilityRefresh = false
		RefreshVisibility()
	end)
end

------------------------------------------------------------
-- UI: Icon Frame
------------------------------------------------------------

-- sizing helper: width and height are always independent
-- D-01: always SetSize(w, h) for independent dimensions — never uniform frame scale.
local function SetIconSize(w, h)
	if not root then return end
	w = w or DB.width or 40
	h = h or DB.height or 40
	DB.width  = w
	DB.height = h
	root:SetSize(DB.width, DB.height)
end

-- Single re-apply entry point for size, position, and border from PLBeastDB. (UI-05, UI-06, UI-07)
-- Phase 5 sliders and color picker will call this after changing a DB value.
-- Source: 04-UI-SPEC.md "Frame Lifecycle Contract" and "Offset capture contract"
local function ApplyIconSettings()
	if not root then return end
	-- Size: independent SetSize via the sync-aware helper (D-01, D-02)
	SetIconSize(DB.width or 40, DB.height or 40)
	-- Position: CENTER anchor on UIParent using persisted offsets (D-09)
	root:ClearAllPoints()
	root:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX or 0, DB.offsetY or 0)
	-- Border: four solid edges sized by DB.borderThickness, colored from DB.borderColor.
	-- Thickness 0 hides the border. Edges overlay the outer `thick` px of the icon, so the
	-- beast art shows in the center with a clean rectangular outline. (UI-02, D-03)
	local edges = root.borderEdges
	if edges then
		local thick = tonumber(DB.borderThickness) or 0
		local c = DB.borderColor or {}
		local r, g, b, a = c.r or 0, c.g or 0, c.b or 0, c.a or 1
		if thick <= 0 then
			edges.top:Hide(); edges.bottom:Hide(); edges.left:Hide(); edges.right:Hide()
		else
			for _, t in pairs(edges) do
				t:SetColorTexture(r, g, b, a)
				t:Show()
			end
			edges.top:ClearAllPoints()
			edges.top:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
			edges.top:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
			edges.top:SetHeight(thick)
			edges.bottom:ClearAllPoints()
			edges.bottom:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0)
			edges.bottom:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
			edges.bottom:SetHeight(thick)
			edges.left:ClearAllPoints()
			edges.left:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
			edges.left:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0)
			edges.left:SetWidth(thick)
			edges.right:ClearAllPoints()
			edges.right:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
			edges.right:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
			edges.right:SetWidth(thick)
		end
	end
end

-- Source: adapted from PackLeaderHelper.lua lines 352–453 (CreateIcon)
-- Stripped: CooldownFrameTemplate, FontString text, glow animation, background dark texture
-- Deviations: SetDesaturated(false) (D-05), SetSize via ApplyIconSettings not inline (D-01),
--             4-texture edge border (D-03), named frame "PLBeastFrame"
-- Order: build frame + texture + border edges + drag scripts → assign root → call ApplyIconSettings
local function CreateBeastIcon()
	local f = CreateFrame("Frame", "PLBeastFrame", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")

	-- Cropped full-color texture (D-04, D-05)
	-- SetTexCoord trims WoW's built-in beveled icon border for a clean flush look.
	local tex = f:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(f)
	tex:SetTexture(ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.wyvern)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	tex:SetDesaturated(false)
	f.tex = tex

	-- Border: four solid edge textures (top/bottom/left/right) on the OVERLAY layer.
	-- A BackdropTemplate WHITE8X8 edge rendered as a full black fill in-game at small
	-- edgeSize, so the outline is drawn explicitly. Sized/colored by ApplyIconSettings.
	f.borderEdges = {
		top    = f:CreateTexture(nil, "OVERLAY"),
		bottom = f:CreateTexture(nil, "OVERLAY"),
		left   = f:CreateTexture(nil, "OVERLAY"),
		right  = f:CreateTexture(nil, "OVERLAY"),
	}

	-- Drag handlers (D-07 default-enabled, D-08 silent combat guard, D-09 CENTER-offset persistence)
	-- Source: PackLeaderHelper.lua lines 904–912 (combat guard); 04-UI-SPEC.md OnDragStop contract
	f:SetScript("OnDragStart", function(self)
		if DB.locked then return end
		if InCombatLockdown and InCombatLockdown() then return end  -- D-08: silent no-op, no chat message
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)  -- suppress WoW LayoutCache.txt (Pitfall 2)
		if not self:GetLeft() then return end  -- nil guard: GetLeft() nil when frame never rendered (Pitfall 3)
		local cx = UIParent:GetWidth()  / 2
		local cy = UIParent:GetHeight() / 2
		local fx = self:GetLeft()   + self:GetWidth()  / 2
		local fy = self:GetBottom() + self:GetHeight() / 2
		DB.offsetX = fx - cx
		DB.offsetY = fy - cy
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX, DB.offsetY)
	end)

	-- Assign root before ApplyIconSettings so the sizing/position/border calls work
	root = f
	ApplyIconSettings()
	return f
end

------------------------------------------------------------
-- Options Frame Helpers
------------------------------------------------------------
-- Source: PackLeaderHelper.lua lines 552–627 (CreateSlider, trimmed — editBox removed)
-- PLBeast sliders are integer-valued and do not need the editBox; dropping it keeps the
-- 280 px-wide frame minimal (editBox adds ~70 px horizontal width). (UI-SPEC)
local function CreateSlider(parent, label, minVal, maxVal, step, getValue, setValue, yOffset)
	local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
	slider:SetWidth(230)
	slider:SetHeight(16)
	slider:SetOrientation("HORIZONTAL")
	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValueStep(step)
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)

	slider.Low:SetText(tostring(minVal))
	slider.High:SetText(tostring(maxVal))
	slider.Text:SetText(label)

	-- Numeric readout below the slider track (UI-SPEC Typography: GameFontHighlightSmall)
	local valText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	valText:SetPoint("TOP", slider, "BOTTOM", 0, -2)
	slider.valText = valText

	slider:SetScript("OnValueChanged", function(self, value)
		-- Integer rounding (D-10: all PLBeast sliders are integer-valued)
		value = math.floor((tonumber(value) or 0) + 0.5)
		self.valText:SetText(tostring(value))
		if setValue then setValue(value) end
	end)

	if getValue then
		local v = getValue()
		if v ~= nil then slider:SetValue(v) end
	end

	return slider
end

-- Source: PackLeaderHelper.lua lines 629–650 (CreateCheckbox, nearly verbatim)
local function CreateCheckbox(parent, label, getValue, setValue, xOffset, yOffset)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetJustifyH("LEFT")
	text:SetText(label)
	check.text = text

	check:SetScript("OnClick", function(self)
		if setValue then
			setValue(self:GetChecked() and true or false)
		end
	end)

	if getValue then
		check:SetChecked(getValue())
	end

	return check
end

-- ToggleOptions() — lazy-creates and toggles the PLBeast options frame.
-- Combat guard runs FIRST (CFG-04, D-07): if in combat, set the deferred-open flag and return.
-- Frame is built once and cached in the module-level upvalue `optionsFrame` (D-05).
-- Source: PackLeaderHelper.lua lines 1021–1048 (ToggleOptions frame skeleton, adapted)
-- UI-SPEC: Frame Architecture, Control Specifications, y-offsets, Interaction Contract
local function ToggleOptions()
	-- Combat guard (CFG-04, D-07, T-05-01)
	if InCombatLockdown and InCombatLockdown() then
		pendingOptionsOpenAfterCombat = true
		Print(L["Cannot open options in combat."])
		return
	end
	pendingOptionsOpenAfterCombat = false

	if not optionsFrame then
		-- Lazy-create on first open (D-05)
		optionsFrame = CreateFrame("Frame", "PLBeastOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
		optionsFrame:SetSize(280, 300)
		optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		optionsFrame:SetFrameStrata("DIALOG")
		optionsFrame:SetMovable(true)
		optionsFrame:EnableMouse(true)
		optionsFrame:RegisterForDrag("LeftButton")
		optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
		optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
		optionsFrame:SetClampedToScreen(true)

		-- Title (UI-SPEC Typography: GameFontHighlight centered on TitleBg)
		optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		optionsFrame.title:SetPoint("CENTER", optionsFrame.TitleBg, "CENTER", 0, 0)
		optionsFrame.title:SetText(L["PLBeast Options"])

		-- Width slider — y-offset -48 (UI-SPEC Control y-offsets)
		-- Setter: SetIconSize(value, DB.height) — D-10, D-11
		CreateSlider(
			optionsFrame,
			L["Width"],
			16, 128, 1,
			function() return DB.width or 40 end,
			function(v)
				SetIconSize(v, DB.height)
			end,
			-48
		)

		-- Height slider — y-offset -96 (UI-SPEC Control y-offsets)
		-- Setter: SetIconSize(DB.width, value) — independent of width (D-10, D-11)
		CreateSlider(
			optionsFrame,
			L["Height"],
			16, 128, 1,
			function() return DB.height or 40 end,
			function(v)
				SetIconSize(DB.width, v)
			end,
			-96
		)

		-- Border thickness slider — y-offset -144 (UI-SPEC Control y-offsets)
		-- Setter: write DB.borderThickness then ApplyIconSettings() — D-10, D-11
		CreateSlider(
			optionsFrame,
			L["Border Thickness"],
			0, 8, 1,
			function() return DB.borderThickness or 1 end,
			function(v)
				DB.borderThickness = v
				ApplyIconSettings()
			end,
			-144
		)

		-- Lock position checkbox — y-offset -236 (spaced to clear the reserved color row and the Sync checkbox)
		-- Writes DB.locked directly; no setter call needed — OnDragStart already reads DB.locked.
		-- D-08: checked = locked, no inversion; default unchecked (false).
		CreateCheckbox(
			optionsFrame,
			L["Lock position"],
			function() return DB.locked or false end,
			function(checked)
				DB.locked = checked
			end,
			16, -236
		)

		-- CreateFrame returns a SHOWN frame; hide it here so the toggle below opens it on the
		-- FIRST /plbeast. Mirrors PackLeaderHelper.lua line 1406 (dropped in the trim). Without
		-- this, the toggle saw a just-created (shown) frame and immediately hid it → "nothing
		-- happens" on the first invocation.
		optionsFrame:Hide()
	end

	-- Toggle show/hide (D-05)
	if optionsFrame:IsShown() then
		optionsFrame:Hide()
	else
		optionsFrame:Show()
	end
end

------------------------------------------------------------
-- Event Handler
------------------------------------------------------------

eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ENCOUNTER_START")

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
		-- Deep-copy guard for table-valued default: the flat-merge above copies the
		-- borderColor reference; Phase 5 sub-field writes would mutate defaults otherwise. (Pitfall 4)
		if DB.borderColor == defaults.borderColor then
			DB.borderColor = { r = 0, g = 0, b = 0, a = 1 }
		end
		-- Type guard: a hand-edited PLBeastDB may store a non-table value (e.g. string "black").
		-- Such values pass the reference-equality check above but would cause "attempt to index a
		-- <type> value" in ApplyIconSettings when accessing DB.borderColor.r. (WR-01)
		if type(DB.borderColor) ~= "table" then
			DB.borderColor = { r = 0, g = 0, b = 0, a = 1 }
		end
		-- Coerce Phase 4 numeric fields: a hand-edited PLBeastDB may store strings (e.g.
		-- width = "60"). SetIconSize's (w >= h) comparison and root:SetPoint's offset args
		-- raise type errors in Lua 5.1 when given strings. Mirror the NormalizeNextIndex
		-- tonumber() pattern. (WR-02)
		DB.width           = tonumber(DB.width)           or 40
		DB.height          = tonumber(DB.height)          or 40
		DB.offsetX         = tonumber(DB.offsetX)         or 0
		DB.offsetY         = tonumber(DB.offsetY)         or 0
		DB.borderThickness = tonumber(DB.borderThickness) or 1
		-- Clamp persisted index and restore nextBeastId (T-02-01, TRACK-03).
		-- ADDON_LOADED intentionally restores the saved index so that a /reload preserves
		-- the current prediction — do NOT call SetNextBeastId("wyvern") unconditionally here.
		-- The fresh-login-only reset to wyvern is handled in the PLAYER_ENTERING_WORLD branch
		-- (gated on isInitialLogin); the boss-pull reset to wyvern is handled in the
		-- ENCOUNTER_START branch. Neither reset belongs in ADDON_LOADED.
		NormalizeNextIndex()
		nextBeastId = ID_BY_INDEX[DB.nextIndex] or "wyvern"
		ResetAuraState(false)
		-- Verify SavedVariables round-trip (D-07)
		dprint("DB loaded: debug=" .. tostring(DB.debug) .. " nextIndex=" .. tostring(DB.nextIndex))

	elseif event == "PLAYER_LOGIN" then
		-- Slash command handler (T-02-04: input normalized; only exact matches route to handlers)
		SLASH_PLBEAST1 = "/plbeast"
		SlashCmdList["PLBEAST"] = function(msg)
			msg = (msg or ""):lower():match("^%s*(.-)%s*$")
			if msg == "debug" then
				-- Source: PackLeaderHelper.lua lines 2541–2543
				DB.debug = not DB.debug
				Print(string.format(L["debug=%s"], tostring(DB.debug)))
			elseif msg == "reset" then
				SetNextBeastId("wyvern")
				ResetAuraState(false)
				SeedAuraSnapshot()
				Print(L["Rotation reset. Next: Wyvern."])
			elseif msg == "" then
				-- Phase 5 (D-06, CFG-01): bare /plbeast opens/toggles the options frame
				-- (combat-deferred via ToggleOptions's own guard)
				ToggleOptions()
			else
				Print(L["PLBeast. /plbeast | debug | reset"])
			end
		end

		-- Create the icon frame eagerly; must happen before RefreshVisibility() so that
		-- the initial root:SetShown(isPackLeaderActive) inside RefreshVisibility() can fire. (D-09)
		CreateBeastIcon()
		-- RefreshVisibility() owns UNIT_AURA registration; replaces unconditional registration (Pitfall 4)
		-- RefreshHunterSpecState() and SeedAuraSnapshot() called inside RefreshVisibility()
		RefreshVisibility()

		-- Round-2 stale-cache fix: the Blizzard Cooldown Manager rebuilds its frame pool
		-- when its settings/data change, invalidating our cached cdmFrame references (the
		-- rotation froze after ~2 beasts until /reload). Rebuild the CDM cache whenever the
		-- CDM signals a data change, exactly as the parent addon does
		-- (PackLeaderHelper.lua:2590–2599). Deferred 0.5s so the CDM finishes rebuilding first.
		if EventRegistry and EventRegistry.RegisterCallback and not eventFrame.cdmSettingsCallbackRegistered then
			EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
				if not (C_Timer and C_Timer.After) then return end
				C_Timer.After(0.5, function()
					BuildCDMCache()
					if cdmCacheBuilt then
						EnsureCacheFramesResolved()
					end
				end)
			end, eventFrame)
			eventFrame.cdmSettingsCallbackRegistered = true
		end

		eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
		eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
		eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
		eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
		eventFrame:RegisterEvent("TRAIT_SUB_TREE_CHANGED")
		-- Phase 5 (D-07, CFG-04): register PLAYER_REGEN_ENABLED so we can auto-open the
		-- options frame after combat when /plbeast was typed during combat.
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		Print(L["PLBeast loaded. Type /plbeast for options."])

	elseif event == "UNIT_AURA" then
		-- T-02-02: Guard immediately for non-player units to prevent unnecessary computation
		local unitTarget = ...
		if unitTarget ~= "player" then return end
		CheckAuraState()

	elseif event == "PLAYER_TALENT_UPDATE"
		or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
		or event == "ACTIVE_COMBAT_CONFIG_CHANGED"
		or event == "TRAIT_CONFIG_UPDATED"
		or event == "TRAIT_SUB_TREE_CHANGED" then
		-- Source: PackLeaderHelper.lua lines 2609–2614
		-- RefreshHunterSpecState() is now called inside RefreshVisibility() via the deferred queue (Pitfall 3)
		QueueVisibilityRefresh()

	elseif event == "PLAYER_REGEN_ENABLED" then
		-- Phase 5 (D-07, CFG-04): if /plbeast was typed during combat, auto-open the frame
		-- now that combat has ended. Defer one frame via C_Timer.After so the lockdown state
		-- is fully cleared before ToggleOptions creates or shows the frame.
		-- Source: PackLeaderHelper.lua lines 2623–2629
		if pendingOptionsOpenAfterCombat then
			if C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					if pendingOptionsOpenAfterCombat then
						ToggleOptions()
					end
				end)
			end
		end

	elseif event == "PLAYER_ENTERING_WORLD" then
		-- Fresh login (isInitialLogin == true): reset rotation to wyvern.
		-- /reload (isReloadingUi == true, isInitialLogin == false): do nothing — the
		-- ADDON_LOADED restore already loaded the saved prediction from DB.nextIndex.
		-- Zoning (both false): do nothing — prediction is unchanged.
		local isInitialLogin, isReloadingUi = ...
		if isInitialLogin then
			ResetRotationToWyvern()
		end

	elseif event == "ENCOUNTER_START" then
		-- Boss pull: reset rotation to wyvern unconditionally.
		-- ENCOUNTER_START fires only on raid/dungeon encounter pulls, never on trash or
		-- world mobs — the correct and exclusive boss-pull trigger (T-02-01, TRACK-03).
		-- The encounterID, encounterName, difficultyID, groupSize args are not inspected;
		-- any encounter start resets the rotation.
		ResetRotationToWyvern()
	end
end)
