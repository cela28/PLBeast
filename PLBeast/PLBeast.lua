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
	plNextBeastId = "boar",  -- D-08: default is boar (Azor parity)
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
local nextBeastId    = "boar"  -- D-08: default is boar, not wyvern
local isBeastMastery = false
local isSurvival     = false
local isPackLeaderActive = false  -- true only when BM/SV spec and Pack Leader hero talent active

-- Phase 5.1: self-correcting prediction state machine vars (Azor lines 51-56 adapted)
local plPhase     = "off"   -- 'off' | 'ticking' | 'ready'
local plBeast     = nil     -- current ready beast data entry; used for NEXT_BEAST lookup
local plHasCdBuff = false   -- countdown buff active
local plDirty     = true    -- change flag (kept for future consumers; PLBeast updates icon synchronously)

-- Phase 5.1: OnUpdate throttle for PollPackLeader (GetTime guard, ~1Hz)
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
	plHasCdBuff = false
	plDirty     = true
end

-- Source: PackLeaderHelper.lua lines 1647–1651 (adapted for D-08 default)
-- Note: Default fallback is "boar" per D-08 (Azor parity)
local function SetNextBeastId(beastId)
	nextBeastId      = beastId or "boar"
	DB.plNextBeastId = nextBeastId
	-- Phase 4: push texture onto icon when frame exists (guard required: called before frame exists)
	if root and root.tex then
		root.tex:SetTexture(ICON_FILE_BY_ID[nextBeastId] or ICON_FILE_BY_ID.boar)
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
		plHasCdBuff = false
		plDirty     = true
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
		local nextId = (oldBeast and NEXT_BEAST[oldBeast.id]) or "boar"
		SetNextBeastId(nextId)
		plDirty = true
	end

	dprint(
		"phase=" .. plPhase,
		"next="  .. (BEAST_LABEL_BY_ID[nextBeastId] or "?"),
		"ready=" .. tostring(nowReady),
		"beast=" .. (nowBeast and nowBeast.name or "nil")
	)
end

------------------------------------------------------------
-- Phase 5.1: OnUpdate handler with GetTime() throttle
-- Wired to root frame via root:SetScript("OnUpdate", OnUpdateHandler).
-- (Azor Hunter.Update() lines 411-418 adapted)
------------------------------------------------------------
local function OnUpdateHandler()
	local now = GetTime()
	if now == lastPolledTime then return end
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
		optionsFrame:SetSize(280, 300)
		optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		optionsFrame:SetFrameStrata("DIALOG")
		optionsFrame:SetMovable(true)
		optionsFrame:EnableMouse(true)
		optionsFrame:RegisterForDrag("LeftButton")
		optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
		optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
		optionsFrame:SetClampedToScreen(true)

		optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		optionsFrame.title:SetPoint("CENTER", optionsFrame.TitleBg, "CENTER", 0, 0)
		optionsFrame.title:SetText(L["PLBeast Options"])

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

		CreateCheckbox(
			optionsFrame,
			L["Lock position"],
			function() return DB.locked or false end,
			function(checked)
				DB.locked = checked
			end,
			16, -236
		)

		optionsFrame:Hide()
	end

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
				-- D-08: reset to boar (not wyvern)
				ClearPackLeaderState()
				SetNextBeastId("boar")
				Print(L["Rotation reset. Next: Boar."])
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
		-- Phase 5.1: D-08 — spec change resets prediction to boar (Azor DetectSpec(true) line 436)
		ClearPackLeaderState()
		SetNextBeastId("boar")
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

	-- Phase 5.1: PLAYER_ENTERING_WORLD and ENCOUNTER_START are not registered.
	-- Per D-09: no login/boss-pull reset. The self-correcting model handles re-sync.
	end
end)
