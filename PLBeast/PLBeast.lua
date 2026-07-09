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
	plNextBeastId = "wyvern",  -- wyvern: start-of-rotation default anchor (TRACK-03; diverges from D-08/Azor, removable)
	-- Phase 4: icon position, size, border, and drag-lock settings
	offsetX         = 0,
	offsetY         = 0,
	width           = 40,
	height          = 40,
	borderThickness = 1,
	borderColor     = { r = 0, g = 0, b = 0, a = 1 },
	locked          = false,
	-- Phase 7: text display mode settings
	textMode        = false,
	fontSize        = 16,
	textColors      = nil,
	textOutline     = "",  -- allowed: "" (none), "OUTLINE", "THICKOUTLINE"
}

------------------------------------------------------------
-- Spell ID Constants
------------------------------------------------------------
-- Source: PackLeaderHelper.lua lines 13–15, 24–25
local SPELL_READY_WYVERN = 471878
local SPELL_READY_BOAR   = 472324
local SPELL_READY_BEAR   = 472325

-- Source: PackLeaderHelper.lua lines 11, 21-22 — direct copy
local SPELL_HOTPL_PARENT       = 471876  -- Pack Leader parent spell / PL_TALENT; primary hero-talent gate
local SPELL_SENTINEL_ANCHOR    = 1253599 -- Sentinel hero talent anchor; mutually exclusive with Pack Leader
local SPELL_DARK_RANGER_ANCHOR = 466930  -- Dark Ranger hero talent anchor; mutually exclusive with Pack Leader

-- Phase 5.1: PL countdown buff spell ID (Azor's PL_COUNTDOWN)
local PL_COUNTDOWN = 471877

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

-- Phase 5.1: PL_BEASTS ordered iterable array matching Azor Hunter.lua lines 33-37.
-- Scan order matters for PollPackLeader (first active beast wins).
-- Boar first per D-08 and Azor parity.
local PL_BEASTS = {
	{ spell = SPELL_READY_BOAR,   name = "Boar",   id = "boar"   },
	{ spell = SPELL_READY_BEAR,   name = "Bear",   id = "bear"   },
	{ spell = SPELL_READY_WYVERN, name = "Wyvern", id = "wyvern" },
}

-- Expanded to include PL_TALENT (SPELL_HOTPL_PARENT) and PL_COUNTDOWN per D-03;
-- PollPackLeader reads these from CDM cache.
-- Beast spells added dynamically to match Azor's pattern.
local TRACKED_SPELL_IDS = {
	[SPELL_HOTPL_PARENT] = true,
	[PL_COUNTDOWN]       = true,
}
for _, beast in ipairs(PL_BEASTS) do
	TRACKED_SPELL_IDS[beast.spell] = true
end

local BEAST_LABEL_BY_ID = {
	wyvern = "Wyvern",
	boar   = "Boar",
	bear   = "Bear",
}

-- Phase 7: default per-beast text colors (Okabe-Ito colorblind-safe palette, 0-1 normalized)
local DEFAULT_BEAST_COLORS = {
	wyvern = { r = 0.337, g = 0.706, b = 0.914 }, -- sky blue, hex 56B4E9
	boar   = { r = 0.902, g = 0.624, b = 0.000 }, -- orange, hex E69F00
	bear   = { r = 0.000, g = 0.620, b = 0.451 }, -- bluish green, hex 009E73
}

-- Phase 7: resolves the color for a given beast, preferring a user override
-- from DB.textColors and falling back to DEFAULT_BEAST_COLORS.
local function GetBeastColor(beastId)
	local override = DB.textColors and DB.textColors[beastId]
	local c = override or DEFAULT_BEAST_COLORS[beastId] or DEFAULT_BEAST_COLORS.boar
	return c.r, c.g, c.b
end

-- Source: PackLeaderHelper.lua lines 29–31 (ICON_DRAGON_READY, ICON_PIG_READY, ICON_BEAR_READY)
-- Three-beast subset; drives texture selection from nextBeastId.
local ICON_FILE_BY_ID = {
	wyvern = 773276,  -- ICON_DRAGON_READY
	boar   = 132184,  -- ICON_PIG_READY
	bear   = 132183,  -- ICON_BEAR_READY
}

------------------------------------------------------------
-- CDM Frame Root Names (Phase 5.1: all three names per Azor)
------------------------------------------------------------
local CDM_FRAME_NAMES = { "BuffBarCooldownViewer", "BuffIconCooldownViewer", "CDMGroups_Buffs" }

-- Phase 5.1: Enum.CooldownViewerCategory set, guarded per Azor lines 60-66
local CDM_CATS
do
	local cats = Enum and Enum.CooldownViewerCategory
	if cats then
		CDM_CATS = { cats.Essential, cats.Utility, cats.TrackedBuff, cats.TrackedBar }
	end
end

------------------------------------------------------------
-- Module-Level State Variables
------------------------------------------------------------
-- Phase 5.1: Azor-style state machine vars (event-driven CDM polling model)
local nextBeastId    = "wyvern"  -- wyvern: start-of-rotation default anchor (TRACK-03)
local isBeastMastery = false
local isSurvival     = false
local isPackLeaderActive = false  -- true only when BM/SV spec and Pack Leader hero talent active

-- Phase 5.1: self-correcting prediction state machine vars (Azor lines 51-56 adapted)
local plPhase     = "off"   -- 'off' | 'ticking' | 'ready'
local plBeast     = nil     -- current ready beast data entry; used for NEXT_BEAST lookup
-- plHasCdBuff and plDirty removed: dead state (written but never read).
-- Re-add when a consumer exists.

-- Phase 5.1: OnUpdate throttle for PollPackLeader — interval-threshold guard of POLL_INTERVAL seconds
-- (~1Hz, matching Azor's Scheduler interval=1 cadence; enforced by elapsed-threshold comparison)
local POLL_INTERVAL  = 1.0
local lastPolledTime = -1

-- CDM (Cooldown Manager) integration state.
local cdmCache      = {}          -- spellID -> { cooldownID, cdmFrame }
local cdmCacheBuilt = false

-- Phase 5.1: debounced rebuild timer handle (Azor ScheduleRebuild pattern)
local rebuildTimer

-- Forward declaration: eventFrame is created in the Event Handler section below.
local eventFrame

-- Forward declaration: root is assigned inside CreateBeastIcon() at PLAYER_LOGIN.
local root

-- Phase 7: forward declaration for the custom Font object driving text mode font size.
local textFont

-- Phase 5 forward declarations: options frame and combat-deferred open flag.
local optionsFrame
local pendingOptionsOpenAfterCombat = false

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

-- Phase 5.1: SaveState — write DB.plNextBeastId to SavedVariables (Azor lines 221-225 adapted)
local function SaveState()
	DB.plNextBeastId = nextBeastId
end

-- Phase 5.1: RestoreState — read DB.plNextBeastId with legacy DB.nextIndex migration
-- (Azor lines 227-234 adapted; migration per RESEARCH.md Pitfall 4)
local function RestoreState()
	local saved = DB.plNextBeastId
	if saved and NEXT_BEAST[saved] then
		nextBeastId = saved
	end
end

-- Phase 5.1: ClearPackLeaderState — reset state machine vars (Azor lines 236-243)
local function ClearPackLeaderState()
	plPhase     = "off"
	plBeast     = nil
end

-- Source: PackLeaderHelper.lua lines 1647–1651 (adapted)
-- Default fallback is "wyvern" — start-of-rotation anchor (TRACK-03; diverges from Azor D-08, removable)
local function SetNextBeastId(beastId)
	nextBeastId      = beastId or "wyvern"
	DB.plNextBeastId = nextBeastId
	-- Phase 4: push texture onto icon when frame exists (guard required: called before frame exists)
	if root and root.tex then
		root.tex:SetTexture(ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.wyvern)
	end
	-- Phase 7: push text and color onto the text-mode label when frame exists
	if root and root.label then
		root.label:SetText(BEAST_LABEL_BY_ID[nextBeastId] or BEAST_LABEL_BY_ID.boar)
		local r, g, b = GetBeastColor(nextBeastId)
		root.label:SetTextColor(r, g, b)
		-- Re-measure frame size when text mode is active (beast name width varies)
		if DB.textMode then
			local textWidth  = root.label:GetStringWidth()  + 4
			local textHeight = root.label:GetStringHeight() + 4
			root:SetSize(math.max(textWidth, 20), math.max(textHeight, 16))
		end
	end
end

-- Source: PackLeaderHelper.lua lines 1582–1587 (TRACK-04 spec awareness)
local function RefreshHunterSpecState()
	local specIndex = GetSpecialization and GetSpecialization()
	local specID = specIndex and GetSpecializationInfo
	               and GetSpecializationInfo(specIndex) or nil
	isBeastMastery = specID == SPEC_HUNTER_BEAST_MASTERY
	isSurvival     = specID == SPEC_HUNTER_SURVIVAL
end

-- Source: PackLeaderHelper.lua lines 1574–1580 — direct copy
-- Returns true only when the player has Pack Leader hero talent active.
local function IsPackLeaderHeroTalent()
	if not IsPlayerSpell(SPELL_HOTPL_PARENT) then return false end
	if IsPlayerSpell(SPELL_SENTINEL_ANCHOR) or IsPlayerSpell(SPELL_DARK_RANGER_ANCHOR) then
		return false
	end
	return true
end

------------------------------------------------------------
-- CDM (Cooldown Manager) Ready-Detection Path
-- Phase 5.1: Rewritten to match AzortharionUI Hunter.lua architecture
------------------------------------------------------------

-- Phase 5.1: GetFrameCooldownID helper (Azor lines 73-75)
local function GetFrameCooldownID(frame)
	return frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
end

-- Phase 5.1: MatchTrackedSpell — checks all spell ID fields against TRACKED_SPELL_IDS
-- (Azor lines 77-89)
local function MatchTrackedSpell(info)
	if not info then return nil end
	if info.spellID and TRACKED_SPELL_IDS[info.spellID] then return info.spellID end
	if info.overrideSpellID and TRACKED_SPELL_IDS[info.overrideSpellID] then
		return info.overrideSpellID
	end
	if info.linkedSpellIDs then
		for _, id in ipairs(info.linkedSpellIDs) do
			if TRACKED_SPELL_IDS[id] then return id end
		end
	end
	return nil
end

-- Phase 5.1: TryCache — cache entry point using MatchTrackedSpell (Azor lines 91-101)
local function TryCache(frame)
	if not frame then return end
	local cooldownID = GetFrameCooldownID(frame)
	if not cooldownID or cooldownID <= 0 then return end
	if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then return end
	local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
	if not ok then return end
	local matched = MatchTrackedSpell(info)
	if matched then
		cdmCache[matched] = { cdmFrame = frame, cooldownID = cooldownID }
	end
end

-- Phase 5.1: ScanDeep — recursive DFS frame scanner with depth cap 3 (Azor lines 103-112)
local function ScanDeep(frame, depth)
	if not frame or depth > 3 then return end
	TryCache(frame)
	if frame.GetChildren then
		local children = { frame:GetChildren() }
		for i = 1, #children do
			ScanDeep(children[i], depth + 1)
		end
	end
end

-- Phase 5.1: SearchFrameForCooldownID — recursive DFS search for a specific cooldownID
-- (Azor lines 179-190, depth cap 4)
local function SearchFrameForCooldownID(frame, targetID, depth)
	if not frame or depth > 4 then return nil end
	if GetFrameCooldownID(frame) == targetID then return frame end
	if frame.GetChildren then
		local children = { frame:GetChildren() }
		for i = 1, #children do
			local result = SearchFrameForCooldownID(children[i], targetID, depth + 1)
			if result then return result end
		end
	end
	return nil
end

-- Phase 5.1: FindCDMFrameByCooldownID — searches ALL CDM_FRAME_NAMES (Azor lines 192-201)
local function FindCDMFrameByCooldownID(targetID)
	for _, name in ipairs(CDM_FRAME_NAMES) do
		local rootFrame = _G[name]
		if rootFrame then
			local found = SearchFrameForCooldownID(rootFrame, targetID, 0)
			if found then return found end
		end
	end
	return nil
end

-- Phase 5.1: CDMFrameHasAura — lazy per-entry CDM frame re-resolve + auraInstanceID check
-- D-05: lazy re-resolve per cooldownID; no full cache rebuild on miss.
-- (Azor lines 203-214)
local function CDMFrameHasAura(data)
	if not data then return false end
	if not data.cdmFrame and data.cooldownID then
		data.cdmFrame = FindCDMFrameByCooldownID(data.cooldownID)
	end
	if not data.cdmFrame then return false end
	-- Validate frame still owns the expected cooldown (pool recycling guard)
	if data.cooldownID and GetFrameCooldownID(data.cdmFrame) ~= data.cooldownID then
		data.cdmFrame = FindCDMFrameByCooldownID(data.cooldownID)
		if not data.cdmFrame then return false end
	end
	local instId = data.cdmFrame.auraInstanceID
	return type(instId) == "number" and instId > 0
end

-- Phase 5.1: BuildCDMCache — rewritten to use ScanDeep + TryCache + CDM_CATS (Azor lines 137-169)
local function BuildCDMCache()
	cdmCache      = {}
	cdmCacheBuilt = false
	if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
		cdmCacheBuilt = true
		return
	end

	-- Frame tree scan: DFS each CDM root frame
	for _, name in ipairs(CDM_FRAME_NAMES) do
		local f = _G[name]
		if f then ScanDeep(f, 0) end
	end

	-- Category scan: enumerate all cooldownIDs in each CDM category (nil cdmFrame — lazy-resolved later)
	if C_CooldownViewer.GetCooldownViewerCategorySet and CDM_CATS then
		for i = 1, #CDM_CATS do
			local ok, cooldownIDs = pcall(C_CooldownViewer.GetCooldownViewerCategorySet, CDM_CATS[i], true)
			if ok and cooldownIDs then
				for _, cdID in ipairs(cooldownIDs) do
					local ok2, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cdID)
					if ok2 then
						local matched = MatchTrackedSpell(info)
						if matched and not cdmCache[matched] then
							cdmCache[matched] = { cdmFrame = nil, cooldownID = cdID }
						end
					end
				end
			end
		end
	end

	cdmCacheBuilt = true
end

-- Phase 5.1: ScheduleRebuild — 0.5s debounced CDM cache rebuild (Azor lines 171-177)
local function ScheduleRebuild()
	if rebuildTimer and not rebuildTimer:IsCancelled() then
		rebuildTimer:Cancel()
	end
	rebuildTimer = C_Timer.NewTimer(0.5, BuildCDMCache)
end

------------------------------------------------------------
-- Phase 5.1: PollPackLeader — self-correcting prediction model
-- Azor Hunter.lua lines 245-326 adapted for PLBeast single-file structure.
------------------------------------------------------------
local function PollPackLeader()
	if not isPackLeaderActive then
		if plPhase ~= "off" then ClearPackLeaderState() end
		return
	end
	if not cdmCacheBuilt then return end

	local hadReady = (plPhase == "ready")
	local oldBeast = plBeast

	-- Read beast ready buffs by iterating PL_BEASTS in order; first active beast wins
	local nowReady = false
	local nowBeast = nil
	for _, beastData in ipairs(PL_BEASTS) do
		local data = cdmCache[beastData.spell]
		if data and CDMFrameHasAura(data) then
			nowReady = true
			nowBeast = beastData
			break
		end
	end

	-- State transitions (Azor lines 293-325 simplified for PLBeast — no CD-buff display needed)
	if nowReady and not hadReady then
		-- Ready buff appeared: pin prediction to the ready beast (D-06, D-07)
		plPhase = "ready"
		plBeast = nowBeast
		SetNextBeastId(nowBeast.id)
	elseif nowReady and hadReady then
		-- Still ready: update in case beast changed rapidly
		if nowBeast ~= plBeast then
			SetNextBeastId(nowBeast.id)
		end
		plBeast = nowBeast
	elseif not nowReady and hadReady then
		-- Ready buff consumed: advance to next beast (D-06)
		plPhase = "off"
		plBeast = nil
		local nextId = (oldBeast and NEXT_BEAST[oldBeast.id]) or "wyvern"  -- error fallback: wyvern anchor
		SetNextBeastId(nextId)
	end

	if DB and DB.debug then
		dprint(
			"phase=" .. plPhase,
			"next="  .. (BEAST_LABEL_BY_ID[nextBeastId] or "?"),
			"ready=" .. tostring(nowReady),
			"beast=" .. (nowBeast and nowBeast.name or "nil")
		)
	end
end

------------------------------------------------------------
-- Phase 5.1: OnUpdate handler with GetTime() throttle
-- Wired to root frame via root:SetScript("OnUpdate", OnUpdateHandler).
-- (Azor Hunter.Update() lines 411-418 adapted)
------------------------------------------------------------
local function OnUpdateHandler()
	local now = GetTime()
	if now - lastPolledTime < POLL_INTERVAL then return end
	lastPolledTime = now
	PollPackLeader()
end

-- Source: PackLeaderHelper.lua lines 1605–1620 (adapted for Phase 5.1)
-- Sets isPackLeaderActive flag; wires/unwires OnUpdate handler per D-01.
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
		-- Re-activation: build CDM cache, wire OnUpdate handler
		BuildCDMCache()
		if root then
			root:SetScript("OnUpdate", OnUpdateHandler)
		end
	elseif not isPackLeaderActive and wasActive then
		-- Deactivation: unwire OnUpdate handler, clear state
		if root then
			root:SetScript("OnUpdate", nil)
		end
		ClearPackLeaderState()
	end

	-- Phase 4: visibility bridge — show/hide icon with Pack Leader spec/talent state
	if root then
		root:SetShown(isPackLeaderActive)
	end
end

-- Source: PackLeaderHelper.lua lines 1622–1638 (adapted)
-- Defers RefreshVisibility() one frame so IsPlayerSpell reads updated talent state.
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
local function SetIconSize(w, h)
	if not root then return end
	w = w or DB.width or 40
	h = h or DB.height or 40
	DB.width  = w
	DB.height = h
	root:SetSize(DB.width, DB.height)
end

-- Single re-apply entry point for size, position, and border from PLBeastDB.
local function ApplyIconSettings()
	if not root then return end
	SetIconSize(DB.width or 40, DB.height or 40)
	root:ClearAllPoints()
	root:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX or 0, DB.offsetY or 0)
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

-- Phase 7: toggles between icon-texture mode and text-label mode on the root frame.
-- Never force-shows border edges directly; delegates to ApplyIconSettings so a
-- user's borderThickness = 0 preference is respected when returning to icon mode.
local function ApplyDisplayMode()
	if not root then return end
	local textMode = DB.textMode
	if root.tex then
		root.tex:SetShown(not textMode)
	end
	if root.label then
		root.label:SetShown(textMode)
	end
	if textMode then
		local edges = root.borderEdges
		if edges then
			for _, t in pairs(edges) do
				t:Hide()
			end
		end
		if root.label then
			local r, g, b = GetBeastColor(nextBeastId)
			root.label:SetTextColor(r, g, b)
			-- Resize frame to fit text content so drag/click area matches the label
			local textWidth  = root.label:GetStringWidth()  + 4
			local textHeight = root.label:GetStringHeight() + 4
			root:SetSize(math.max(textWidth, 20), math.max(textHeight, 16))
		end
	else
		-- Restore icon dimensions before applying icon settings
		SetIconSize(DB.width or 40, DB.height or 40)
		ApplyIconSettings()
	end
end

-- Source: adapted from PackLeaderHelper.lua lines 352–453 (CreateIcon)
local function CreateBeastIcon()
	local f = CreateFrame("Frame", "PLBeastFrame", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")

	-- Cropped full-color texture
	local tex = f:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(f)
	tex:SetTexture(ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.boar)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	tex:SetDesaturated(false)
	f.tex = tex

	-- Phase 7: custom font object driving the text-mode label, seeded from
	-- GameFontNormalLarge so it inherits the locale-correct font file.
	textFont = CreateFont("PLBeastTextFont")
	local fontFile, _, fontFlags = GameFontNormalLarge:GetFont()
	textFont:SetFont(fontFile, DB.fontSize or 16, DB.textOutline or "")

	-- Phase 7: text-mode label, centered on the root frame; hidden by default
	-- until ApplyDisplayMode() decides which widget to show.
	local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	label:SetPoint("CENTER", f, "CENTER", 0, 0)
	label:SetJustifyH("CENTER")
	label:SetFontObject(textFont)
	label:SetText(BEAST_LABEL_BY_ID[nextBeastId] or BEAST_LABEL_BY_ID.boar)
	do
		local r, g, b = GetBeastColor(nextBeastId)
		label:SetTextColor(r, g, b)
	end
	f.label = label

	-- Border: four solid edge textures
	f.borderEdges = {
		top    = f:CreateTexture(nil, "OVERLAY"),
		bottom = f:CreateTexture(nil, "OVERLAY"),
		left   = f:CreateTexture(nil, "OVERLAY"),
		right  = f:CreateTexture(nil, "OVERLAY"),
	}

	-- Drag handlers
	f:SetScript("OnDragStart", function(self)
		if DB.locked then return end
		if InCombatLockdown and InCombatLockdown() then return end
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)
		if not self:GetLeft() then return end
		local cx = UIParent:GetWidth()  / 2
		local cy = UIParent:GetHeight() / 2
		local fx = self:GetLeft()   + self:GetWidth()  / 2
		local fy = self:GetBottom() + self:GetHeight() / 2
		DB.offsetX = fx - cx
		DB.offsetY = fy - cy
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "CENTER", DB.offsetX, DB.offsetY)
	end)

	-- Assign root before ApplyIconSettings
	root = f
	ApplyIconSettings()
	ApplyDisplayMode()
	return f
end

------------------------------------------------------------
-- Options Frame Helpers
------------------------------------------------------------
-- Source: PackLeaderHelper.lua lines 552–627 (CreateSlider, trimmed)
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

	local valText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	valText:SetPoint("TOP", slider, "BOTTOM", 0, -2)
	slider.valText = valText

	slider:SetScript("OnValueChanged", function(self, value)
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

-- Source: PackLeaderHelper.lua lines 629–650 (CreateCheckbox)
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

-- Phase 7: creates a small clickable color swatch + label for per-beast color
-- customization. Opens the built-in ColorPickerFrame on click; saves to
-- DB.textColors and live-updates root.label when the beast matches nextBeastId.
local function CreateColorSwatch(parent, label, beastId, xOffset, yOffset)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(16, 16)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

	local swatchTex = button:CreateTexture(nil, "OVERLAY")
	swatchTex:SetAllPoints(button)
	do
		local r, g, b = GetBeastColor(beastId)
		swatchTex:SetColorTexture(r, g, b)
	end

	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("LEFT", button, "RIGHT", 6, 0)
	text:SetJustifyH("LEFT")
	text:SetText(label)
	button.label = text

	local function ApplyColor(r, g, b)
		DB.textColors = DB.textColors or {}
		DB.textColors[beastId] = { r = r, g = g, b = b }
		swatchTex:SetColorTexture(r, g, b)
		if root and root.label and nextBeastId == beastId then
			root.label:SetTextColor(r, g, b)
		end
	end

	button:SetScript("OnClick", function()
		local origR, origG, origB = GetBeastColor(beastId)
		-- Snapshot DB state: was there an explicit override before opening?
		local origOverride = DB.textColors and DB.textColors[beastId]
		local savedOverride = origOverride
			and { r = origOverride.r, g = origOverride.g, b = origOverride.b }
			or nil

		local function OnColorChanged()
			local r, g, b = ColorPickerFrame:GetColorRGB()
			ApplyColor(r, g, b)
		end

		local function OnCancel()
			-- Restore original DB state, not the resolved color
			if savedOverride then
				DB.textColors = DB.textColors or {}
				DB.textColors[beastId] = savedOverride
			else
				if DB.textColors then
					DB.textColors[beastId] = nil
				end
			end
			swatchTex:SetColorTexture(origR, origG, origB)
			if root and root.label and nextBeastId == beastId then
				root.label:SetTextColor(origR, origG, origB)
			end
		end

		if ColorPickerFrame.SetupColorPickerAndShow then
			-- 11.0+ single-table API
			ColorPickerFrame:SetupColorPickerAndShow({
				r = origR, g = origG, b = origB,
				hasOpacity = false,
				swatchFunc = OnColorChanged,
				func = OnColorChanged,
				cancelFunc = OnCancel,
			})
		else
			-- Legacy pattern
			ColorPickerFrame.hasOpacity = false
			ColorPickerFrame.func = OnColorChanged
			ColorPickerFrame.swatchFunc = OnColorChanged
			ColorPickerFrame.cancelFunc = OnCancel
			ColorPickerFrame:SetColorRGB(origR, origG, origB)
			ShowUIPanel(ColorPickerFrame)
		end
	end)

	return button
end

-- Phase text-mode-ux: ordered list of the three supported font outline
-- styles, mapping the DB-persisted flag string to its locale label key.
local OUTLINE_STYLES = {
	{ value = "",             labelKey = "None" },
	{ value = "OUTLINE",      labelKey = "Thin Outline" },
	{ value = "THICKOUTLINE", labelKey = "Thick Outline" },
}

-- Creates a small cycle-button (no dropdown/menu-API dependency) that
-- advances DB.textOutline through None -> Outline -> Thick Outline -> None
-- on each click, applying the flag live to PLBeastTextFont.
local function CreateOutlineControl(parent, xOffset, yOffset)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(150, 22)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

	local function CurrentIndex()
		for i, style in ipairs(OUTLINE_STYLES) do
			if style.value == (DB.textOutline or "") then
				return i
			end
		end
		return 1
	end

	local function SetOutlineText()
		local style = OUTLINE_STYLES[CurrentIndex()]
		button:SetText(L["Outline"] .. ": " .. L[style.labelKey])
	end

	button:SetScript("OnClick", function()
		local nextIndex = CurrentIndex() + 1
		if nextIndex > #OUTLINE_STYLES then nextIndex = 1 end
		DB.textOutline = OUTLINE_STYLES[nextIndex].value
		if textFont then
			local file, size = textFont:GetFont()
			textFont:SetFont(file, size, DB.textOutline)
		end
		-- Re-measure frame size when text mode is active (mirrors Font Size slider)
		if DB.textMode and root and root.label then
			local textWidth  = root.label:GetStringWidth()  + 4
			local textHeight = root.label:GetStringHeight() + 4
			root:SetSize(math.max(textWidth, 20), math.max(textHeight, 16))
		end
		SetOutlineText()
	end)

	SetOutlineText()
	return button
end

------------------------------------------------------------
-- Options Frame Layout
------------------------------------------------------------
-- Phase text-mode-ux: CreateCheckbox/.text, CreateSlider/.valText, and
-- CreateColorSwatch/.label are all parented to the OPTIONS FRAME (not to the
-- widget itself), so calling SetShown() on the widget alone leaves the label
-- floating as an orphan. This helper hides/shows the widget and any of its
-- known parent-owned label fontstrings together.
local function SetControlShown(w, shown)
	if not w then return end
	w:SetShown(shown)
	if w.valText then w.valText:SetShown(shown) end
	if w.text then w.text:SetShown(shown) end
	if w.label then w.label:SetShown(shown) end
end

-- RelayoutOptions() — repositions and shows/hides every options-frame
-- control based on DB.textMode. Called on initial build, every subsequent
-- open, and immediately after the Text Mode checkbox is toggled, so the
-- panel never displays a stale mix of icon-mode and text-mode controls.
local function RelayoutOptions(frame)
	if not frame or not frame.controls then return end
	local c = frame.controls
	local textMode = DB.textMode
	local y = -40

	-- Always on top, in both modes.
	SetControlShown(c.textMode, true)
	c.textMode:ClearAllPoints()
	c.textMode:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y)
	y = y - 30

	SetControlShown(c.lock, true)
	c.lock:ClearAllPoints()
	c.lock:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y)
	y = y - 30

	if textMode then
		SetControlShown(c.width, false)
		SetControlShown(c.height, false)
		SetControlShown(c.border, false)

		SetControlShown(c.fontSize, true)
		c.fontSize:ClearAllPoints()
		c.fontSize:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y - 14)
		y = y - 48

		SetControlShown(c.outline, true)
		c.outline:ClearAllPoints()
		c.outline:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y)
		y = y - 30

		SetControlShown(c.wyvern, true)
		c.wyvern:ClearAllPoints()
		c.wyvern:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y)
		y = y - 24

		SetControlShown(c.boar, true)
		c.boar:ClearAllPoints()
		c.boar:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y)
		y = y - 24

		SetControlShown(c.bear, true)
		c.bear:ClearAllPoints()
		c.bear:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y)
		y = y - 24
	else
		SetControlShown(c.fontSize, false)
		SetControlShown(c.outline, false)
		SetControlShown(c.wyvern, false)
		SetControlShown(c.boar, false)
		SetControlShown(c.bear, false)

		SetControlShown(c.width, true)
		c.width:ClearAllPoints()
		c.width:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y - 14)
		y = y - 48

		SetControlShown(c.height, true)
		c.height:ClearAllPoints()
		c.height:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y - 14)
		y = y - 48

		SetControlShown(c.border, true)
		c.border:ClearAllPoints()
		c.border:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, y - 14)
		y = y - 48
	end
end

-- ToggleOptions() — lazy-creates and toggles the PLBeast options frame.
local function ToggleOptions()
	if InCombatLockdown and InCombatLockdown() then
		pendingOptionsOpenAfterCombat = true
		Print(L["Cannot open options in combat."])
		return
	end
	pendingOptionsOpenAfterCombat = false

	if not optionsFrame then
		optionsFrame = CreateFrame("Frame", "PLBeastOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
		optionsFrame:SetSize(280, 460)
		optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		optionsFrame:SetFrameStrata("DIALOG")
		optionsFrame:SetMovable(true)
		optionsFrame:EnableMouse(true)
		optionsFrame:RegisterForDrag("LeftButton")
		optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
		optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
		optionsFrame:SetClampedToScreen(true)
		optionsFrame.controls = {}

		optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		optionsFrame.title:SetPoint("CENTER", optionsFrame.TitleBg, "CENTER", 0, 0)
		optionsFrame.title:SetText(L["PLBeast Options"])

		optionsFrame.controls.width = CreateSlider(
			optionsFrame,
			L["Width"],
			16, 128, 1,
			function() return DB.width or 40 end,
			function(v)
				SetIconSize(v, DB.height)
			end,
			-48
		)

		optionsFrame.controls.height = CreateSlider(
			optionsFrame,
			L["Height"],
			16, 128, 1,
			function() return DB.height or 40 end,
			function(v)
				SetIconSize(DB.width, v)
			end,
			-96
		)

		optionsFrame.controls.border = CreateSlider(
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

		optionsFrame.controls.lock = CreateCheckbox(
			optionsFrame,
			L["Lock position"],
			function() return DB.locked or false end,
			function(checked)
				DB.locked = checked
			end,
			16, -236
		)

		optionsFrame.controls.textMode = CreateCheckbox(
			optionsFrame,
			L["Text Mode"],
			function() return DB.textMode or false end,
			function(checked)
				DB.textMode = checked
				ApplyDisplayMode()
				RelayoutOptions(optionsFrame)
			end,
			16, -268
		)

		optionsFrame.controls.fontSize = CreateSlider(
			optionsFrame,
			L["Font Size"],
			8, 32, 1,
			function() return DB.fontSize or 16 end,
			function(v)
				DB.fontSize = v
				if textFont then
					local file, _, flags = textFont:GetFont()
					textFont:SetFont(file, v, flags)
				end
				-- Re-measure frame size when text mode is active
				if DB.textMode and root and root.label then
					local textWidth  = root.label:GetStringWidth()  + 4
					local textHeight = root.label:GetStringHeight() + 4
					root:SetSize(math.max(textWidth, 20), math.max(textHeight, 16))
				end
			end,
			-316
		)

		optionsFrame.controls.outline = CreateOutlineControl(optionsFrame, 20, -350)

		optionsFrame.controls.wyvern = CreateColorSwatch(optionsFrame, L["Wyvern Color"], "wyvern", 20, -370)
		optionsFrame.controls.boar   = CreateColorSwatch(optionsFrame, L["Boar Color"],   "boar",   20, -392)
		optionsFrame.controls.bear   = CreateColorSwatch(optionsFrame, L["Bear Color"],   "bear",   20, -414)

		RelayoutOptions(optionsFrame)
		optionsFrame:Hide()
	end

	if optionsFrame:IsShown() then
		optionsFrame:Hide()
	else
		RelayoutOptions(optionsFrame)
		optionsFrame:Show()
	end
end

------------------------------------------------------------
-- Event Handler
------------------------------------------------------------

eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= addonName then return end

		-- Phase 5.1: SavedVariables migration — run BEFORE flat defaults merge (RESEARCH Pitfall 4)
		-- If old integer-based DB.nextIndex exists but DB.plNextBeastId is nil, migrate.
		PLBeastDB = PLBeastDB or {}
		if PLBeastDB.nextIndex ~= nil and PLBeastDB.plNextBeastId == nil then
			local legacyMap = { [1] = "wyvern", [2] = "boar", [3] = "bear" }
			PLBeastDB.plNextBeastId = legacyMap[tonumber(PLBeastDB.nextIndex)] or "boar"
		end

		-- Flat defaults merge
		for k, v in pairs(defaults) do
			if PLBeastDB[k] == nil then PLBeastDB[k] = v end
		end
		DB = PLBeastDB

		-- Deep-copy guard for table-valued default
		if DB.borderColor == defaults.borderColor then
			DB.borderColor = { r = 0, g = 0, b = 0, a = 1 }
		end
		if type(DB.borderColor) ~= "table" then
			DB.borderColor = { r = 0, g = 0, b = 0, a = 1 }
		end

		-- Coerce numeric fields
		DB.width           = tonumber(DB.width)           or 40
		DB.height          = tonumber(DB.height)          or 40
		DB.offsetX         = tonumber(DB.offsetX)         or 0
		DB.offsetY         = tonumber(DB.offsetY)         or 0
		DB.borderThickness = tonumber(DB.borderThickness) or 1

		-- Phase 7: coerce/validate text display mode fields
		-- clamp to the same bounds the Font Size slider enforces (8-32) so a
		-- corrupt/hand-edited save cannot push an out-of-range size into SetFont
		DB.fontSize = math.max(8, math.min(32, tonumber(DB.fontSize) or 16))
		if DB.textMode == nil then DB.textMode = false end
		local allowedOutlines = { [""] = true, ["OUTLINE"] = true, ["THICKOUTLINE"] = true }
		if not allowedOutlines[DB.textOutline] then DB.textOutline = "" end
		if DB.textColors ~= nil then
			if type(DB.textColors) ~= "table" then
				DB.textColors = nil
			else
				for beastId in pairs(BEAST_LABEL_BY_ID) do
					local c = DB.textColors[beastId]
					if c ~= nil then
						if type(c) ~= "table"
							or type(c.r) ~= "number"
							or type(c.g) ~= "number"
							or type(c.b) ~= "number" then
							DB.textColors[beastId] = nil
						end
					end
				end
			end
		end

		-- Phase 5.1: Restore saved prediction from DB.plNextBeastId (with legacy migration)
		RestoreState()

		dprint("DB loaded: debug=" .. tostring(DB.debug) .. " plNextBeastId=" .. tostring(DB.plNextBeastId))

	elseif event == "PLAYER_LOGIN" then
		-- Slash command handler
		SLASH_PLBEAST1 = "/plbeast"
		SlashCmdList["PLBEAST"] = function(msg)
			msg = (msg or ""):lower():match("^%s*(.-)%s*$")
			if msg == "debug" then
				DB.debug = not DB.debug
				Print(string.format(L["debug=%s"], tostring(DB.debug)))
			elseif msg == "reset" then
				-- reset to wyvern (start-of-rotation anchor; TRACK-03 — diverges from D-08, removable)
				ClearPackLeaderState()
				SetNextBeastId("wyvern")
				Print(L["Rotation reset. Next: Wyvern."])
			elseif msg == "" then
				ToggleOptions()
			else
				Print(L["PLBeast. /plbeast | debug | reset"])
			end
		end

		-- Create the icon frame eagerly
		CreateBeastIcon()
		-- RefreshVisibility owns OnUpdate wiring (D-01)
		RefreshVisibility()

		-- Phase 5.1: D-03 — subscribe to all 3 CDM rebuild triggers via ScheduleRebuild
		if EventRegistry and EventRegistry.RegisterCallback and not eventFrame.cdmSettingsCallbackRegistered then
			EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", ScheduleRebuild, eventFrame)
			eventFrame.cdmSettingsCallbackRegistered = true
		end

		-- Phase 5.1: register CDM data events and combat-enter cache fallback (D-03, D-04)
		eventFrame:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
		eventFrame:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
		eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

		eventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
		eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
		eventFrame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
		eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
		eventFrame:RegisterEvent("TRAIT_SUB_TREE_CHANGED")
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		-- TRACK-03: register login and boss-pull reset events
		eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		eventFrame:RegisterEvent("ENCOUNTER_START")
		Print(L["PLBeast loaded. Type /plbeast for options."])

	elseif event == "COOLDOWN_VIEWER_DATA_LOADED"
		or event == "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED" then
		-- Phase 5.1: D-03 — all CDM data events route through debounced ScheduleRebuild
		ScheduleRebuild()

	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Phase 5.1: D-04 — build CDM cache on combat enter if cache is empty
		if not next(cdmCache) then BuildCDMCache() end

	elseif event == "PLAYER_TALENT_UPDATE"
		or event == "ACTIVE_COMBAT_CONFIG_CHANGED"
		or event == "TRAIT_CONFIG_UPDATED"
		or event == "TRAIT_SUB_TREE_CHANGED" then
		QueueVisibilityRefresh()

	elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
		-- spec change resets prediction to wyvern anchor (TRACK-03; diverges from D-08, removable)
		ClearPackLeaderState()
		SetNextBeastId("wyvern")
		QueueVisibilityRefresh()

	elseif event == "PLAYER_REGEN_ENABLED" then
		-- Phase 5 (D-07, CFG-04): if /plbeast was typed during combat, auto-open the frame
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
		-- TRACK-03: reset to wyvern on initial login only (isInitialLogin is first vararg)
		local isInitialLogin = ...
		if isInitialLogin then
			ClearPackLeaderState()
			SetNextBeastId("wyvern")
			SaveState()
		end

	elseif event == "ENCOUNTER_START" then
		-- TRACK-03: reset to wyvern on every boss pull (event-driven, zero per-frame cost)
		ClearPackLeaderState()
		SetNextBeastId("wyvern")
		SaveState()
	end
end)
