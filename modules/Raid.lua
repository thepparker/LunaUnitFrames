local HealComm = AceLibrary("HealComm-1.0")
local AceEvent = AceLibrary("AceEvent-2.0")
local banzai = AceLibrary("Banzai-1.0")
local roster = AceLibrary("RosterLib-2.0")
local ScanTip = CreateFrame("GameTooltip", "ScanTip", nil, "GameTooltipTemplate")
local _, PlayerClass = UnitClass("player")
local HotTexture = (PlayerClass == "PRIEST" and "Interface\\Icons\\Spell_Holy_Renew" or PlayerClass == "DRUID" and "Interface\\Icons\\Spell_Nature_Rejuvenation" or "")
local RegrTexture = "Interface\\Icons\\Spell_Nature_ResistNature"
local classes = {["PRIEST"] = 1, ["PALADIN"] = 2, ["SHAMAN"] = 2, ["WARRIOR"] = 3, ["HUNTER"] = 4, ["WARLOCK"] = 5, ["MAGE"] = 6, ["DRUID"] = 7, ["ROGUE"] = 8}
ScanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
LunaUnitFrames.frames.headers = {}
LunaUnitFrames.frames.members = {}
local RaidRoster = {
					[1] = {};
					[2] = {};
					[3] = {};
					[4] = {};
					[5] = {};
					[6] = {};
					[7] = {};
					[8] = {}
				}
local PetRoster = {}
local playername = UnitName("player")

local function Luna_Raid_OnClick()
	local button, modifier
	if arg1 == "LeftButton" then
		button = 1
	elseif arg1 == "RightButton" then
		button = 2
	elseif arg1 == "MiddleButton" then
		button = 3
	elseif arg1 == "Button4" then
		button = 4
	else
		button = 5
	end
	if IsShiftKeyDown() then
		modifier = 2
	elseif IsAltKeyDown() then
		modifier = 3
	elseif IsControlKeyDown() then
		modifier = 4
	else
		modifier = 1
	end
	local func = loadstring(LunaOptions.clickcast[playername][modifier][button])
	if LunaOptions.clickcast[playername][modifier][button] == "target" then
		if (SpellIsTargeting()) then
			SpellTargetUnit(this.unit)
		elseif (CursorHasItem()) then
			DropItemOnUnit(this.unit)
		else
			TargetUnit(this.unit)
		end
		return
	elseif LunaOptions.clickcast[playername][modifier][button] == "menu" then
		if (SpellIsTargeting()) then
			SpellStopTargeting()
			return;
		end
	elseif UnitIsUnit("target", this.unit) then
		if func then
			func()
		else
			CastSpellByName(LunaOptions.clickcast[playername][modifier][button])
		end
	else
		TargetUnit(this.unit)
		if func then
			func()
		else
			CastSpellByName(LunaOptions.clickcast[playername][modifier][button])
		end
		TargetLastTarget()
	end
end

local function StartMoving()
	this:StartMoving()
end

local function StopMovingOrSizing()
	this:StopMovingOrSizing()
	if not LunaOptions.frames["LunaRaidFrames"][this.id] then
		LunaOptions.frames["LunaRaidFrames"][this.id] = {}
	end
	_,_,_,LunaOptions.frames["LunaRaidFrames"]["positions"][this.id].x, LunaOptions.frames["LunaRaidFrames"]["positions"][this.id].y = this:GetPoint()
end

function LunaUnitFrames:ToggleRaidFrameLock()
	if not LunaUnitFrames.frames.headers[1]:IsMovable() and not LunaOptions.raidinterlock then
		for i=1,9 do
			LunaUnitFrames.frames.headers[i]:SetScript("OnDragStart", StartMoving)
			LunaUnitFrames.frames.headers[i]:SetScript("OnDragStop", StopMovingOrSizing)
			LunaUnitFrames.frames.headers[i]:SetMovable(1)
		end
	elseif LunaOptions.raidinterlock and not LunaUnitFrames.frames.headers[1]:IsMovable() then
		LunaUnitFrames.frames.headers[1]:SetScript("OnDragStart", StartMoving)
		LunaUnitFrames.frames.headers[1]:SetScript("OnDragStop", StopMovingOrSizing)
		LunaUnitFrames.frames.headers[1]:SetMovable(1)
	else
		for i=1,9 do
			LunaUnitFrames.frames.headers[i]:SetScript("OnDragStart", nil)
			LunaUnitFrames.frames.headers[i]:SetScript("OnDragStop", nil)
			LunaUnitFrames.frames.headers[i]:SetMovable(0)
		end
	end
end

local function RaidEventhandler()
	if event == "UNIT_AURA" then
		LunaUnitFrames.Raid_Aura(arg1)
	elseif event == "UNIT_DISPLAYPOWER" then
		LunaUnitFrames.Raid_Displaypower(arg1)
	end
end

local function AdjustHealBar(frame)
	local healed = HealComm:getHeal(UnitName(frame.unit))
	local health, maxHealth = UnitHealth(frame.unit), UnitHealthMax(frame.unit)
	local frameHeight, frameWidth = frame.HealthBar:GetHeight(), frame.HealthBar:GetWidth()
	local healthHeight = frameHeight * (health / maxHealth)
	local healthWidth = frameWidth * (health / maxHealth)
	if( healed > 0 and health < maxHealth and not UnitIsDeadOrGhost(frame.unit)) then
		frame.HealBar:Show()
		if LunaOptions.frames["LunaRaidFrames"].verticalHealth then
			local incHeight = frameHeight * (healed / maxHealth)
			if (healthHeight + incHeight) > frameHeight then
				incHeight = frameHeight - healthHeight
			end
			frame.HealBar:SetHeight(incHeight)
			frame.HealBar:SetWidth(frameWidth)
			frame.HealBar:ClearAllPoints()
			frame.HealBar:SetPoint("BOTTOMLEFT", frame.HealthBar, "BOTTOMLEFT", 0, healthHeight)
		else
			local incWidth = frameWidth * (healed / maxHealth)
			if (healthWidth + incWidth) > frameWidth then
				incWidth = frameWidth - healthWidth
			end
			frame.HealBar:SetWidth(incWidth)
			frame.HealBar:SetHeight(frameHeight)
			frame.HealBar:ClearAllPoints()
			frame.HealBar:SetPoint("TOPLEFT", frame.HealthBar, "TOPLEFT", healthWidth, 0)
		end
	else
		frame.HealBar:Hide()
	end
end

local function Update_RaidUnit_Status()
	this.updateTime = this.updateTime + arg1

	if (this.updateTime < 0.1) then
		return
	end

	this.updateTime = 0

	local now = GetTime()
	if this:IsShown() then
		if not UnitExists(this.unit) then
			if this.unit ~= nil and not string.find(this.unit, "pet") then
				DEFAULT_CHAT_FRAME:AddMessage("Unit " .. this.unit .. " no longer exists, yet frame is shown")
			end
			return
		end
		local _, time = LunaUnitFrames.proximity:GetUnitRange(this.unit)
		local seen = now - (time or 100)
		if time and seen < 3 then
			this:SetAlpha(1)
		else
			this:SetAlpha(0.5)
		end

		if (UnitIsCharmed(this.unit)) then
			this.HealthBar:SetStatusBarColor(unpack(LunaOptions.MiscColors["hostile"]))

			this.charmed = true
		elseif (this.charmed) then
			-- No longer charmed
			this.charmed = false
			LunaUnitFrames:Update_RaidFrame_Health(this)
		end

		if UnitIsConnected(this.unit) then
			if UnitHealth(this.unit) < 2 then
				this.HealBar:Hide()
			end
		else
			this.HealthBar:SetValue(0)
			this.PowerBar:SetValue(0)
			this.HealBar:Hide()
		end
	end
end

function LunaUnitFrames.Update_RaidUnit_Health(unitid)
	--DEFAULT_CHAT_FRAME:AddMessage("LUF: UNIT_HEALTH fired for " .. unitid)
	local frame = nil

	for i = 1, 80 do
		local _frame = LunaUnitFrames.frames.members[i]
		if _frame.unit and UnitIsUnit(_frame.unit, unitid) then
			frame = _frame
			break
		end
	end

	if not frame then
		return
	end

	LunaUnitFrames:Update_RaidFrame_Health(frame)
end

function LunaUnitFrames:Update_RaidFrame_Health(frame)
	--DEFAULT_CHAT_FRAME:AddMessage("LUF: Have unit's frame")
	-- Have unit frame for updated unit. Update the current health

	local color
	if LunaOptions.hbarcolor and frame.charmed then
		color = LunaOptions.MiscColors["hostile"]
	elseif LunaOptions.hbarcolor then
		color = LunaOptions.ClassColors[frame.Class] or LunaOptions.MiscColors["friendly"]
	else
		color = LunaUnitFrames:GetHealthColor(frame.unit)
	end

	frame.HealthBar:SetMinMaxValues(0, UnitHealthMax(frame.unit))
	
	if LunaOptions.frames["LunaRaidFrames"].inverthealth then
		if UnitHealth(frame.unit) < 2 then
			frame.bg:SetVertexColor(unpack(color))
			frame.bg:Show()
			frame.HealthBar:SetValue(0)
			frame.PowerBar:SetValue(0)
			frame.HealBar:Hide()
		else
			frame.bg:Show()
			frame.bg:SetVertexColor(unpack(color))
			frame.HealthBar:SetStatusBarColor(0,0,0)
			frame.HealthBar:SetValue(UnitHealth(frame.unit))
		end
	else
		frame.bg:Hide()
		if UnitHealth(frame.unit) < 2 then
			frame.HealthBar:SetValue(0)
			frame.PowerBar:SetValue(0)
			frame.HealBar:Hide()
		else
			frame.HealthBar:SetValue(UnitHealth(frame.unit))
			frame.HealthBar:SetStatusBarColor(unpack(color))
		end
	end

	AdjustHealBar(frame)
end

function LunaUnitFrames.Update_RaidUnit_Power(unitid)
	--DEFAULT_CHAT_FRAME:AddMessage("LUF: UNIT_POWER fired for " .. unitid)
	local frame = nil

	for i = 1, 80 do
		local _frame = LunaUnitFrames.frames.members[i]
		if _frame.unit and UnitIsUnit(_frame.unit, unitid) then
			frame = _frame
			break
		end
	end

	if not frame then
		return
	end

	LunaUnitFrames:Update_RaidFrame_Power(frame)
end

function LunaUnitFrames:Update_RaidFrame_Power(frame)
	--DEFAULT_CHAT_FRAME:AddMessage("LUF: Have unit's frame")
	-- Update unit's power...

	frame.PowerBar:SetMinMaxValues(0, UnitManaMax(frame.unit))
	if UnitIsConnected(frame.unit) then
		if UnitHealth(frame.unit) < 2 then
			frame.PowerBar:SetValue(0)
		else
			frame.PowerBar:SetValue(UnitMana(frame.unit))
		end
	else
		frame.PowerBar:SetValue(0)
	end
end

function LunaUnitFrames:CreateRaidFrames()
	for i=1, 9 do
		LunaUnitFrames.frames.headers[i] = CreateFrame("Button", "Header"..i, UIParent)
		LunaUnitFrames.frames.headers[i]:Hide()
		LunaUnitFrames.frames.headers[i]:SetMovable(0)
		LunaUnitFrames.frames.headers[i]:RegisterForDrag("LeftButton")
		LunaUnitFrames.frames.headers[i].id = i
		
		LunaUnitFrames.frames.headers[i].GrpName = LunaUnitFrames.frames.headers[i]:CreateFontString(nil, "OVERLAY", LunaUnitFrames.frames.headers[i])
		LunaUnitFrames.frames.headers[i].GrpName:SetPoint("CENTER", LunaUnitFrames.frames.headers[i])
		LunaUnitFrames.frames.headers[i].GrpName:SetJustifyH("CENTER")
		LunaUnitFrames.frames.headers[i].GrpName:SetJustifyV("MIDDLE")
		LunaUnitFrames.frames.headers[i].GrpName:SetShadowColor(0, 0, 0)
		LunaUnitFrames.frames.headers[i].GrpName:SetShadowOffset(0.8, -0.8)
		LunaUnitFrames.frames.headers[i].GrpName:SetTextColor(1,1,1)
	end
	for i=1, 80 do
		LunaUnitFrames.frames.members[i] = CreateFrame("Button", "Raidmember"..i, UIParent)
		LunaUnitFrames.frames.members[i]:Hide()
		LunaUnitFrames.frames.members[i]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i]:RegisterForClicks('LeftButtonUp', 'RightButtonUp', 'MiddleButtonUp', 'Button4Up', 'Button5Up')
		LunaUnitFrames.frames.members[i]:SetScript("OnClick", Luna_Raid_OnClick)
		LunaUnitFrames.frames.members[i]:SetScript("OnEnter", UnitFrame_OnEnter)
		LunaUnitFrames.frames.members[i]:SetScript("OnLeave", UnitFrame_OnLeave)
		
		LunaUnitFrames.frames.members[i].borders = {}
		
		LunaUnitFrames.frames.members[i].borders["TOP"] = LunaUnitFrames.frames.members[i]:CreateTexture("PlayerTopBorder", "ARTWORK")
		LunaUnitFrames.frames.members[i].borders["TOP"]:SetPoint("BOTTOMLEFT", LunaUnitFrames.frames.members[i], "TOPLEFT")
		LunaUnitFrames.frames.members[i].borders["TOP"]:SetHeight(1)
		
		LunaUnitFrames.frames.members[i].borders["BOTTOM"] = LunaUnitFrames.frames.members[i]:CreateTexture("PlayerBottomBorder", "ARTWORK")
		LunaUnitFrames.frames.members[i].borders["BOTTOM"]:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i], "BOTTOMLEFT")
		LunaUnitFrames.frames.members[i].borders["BOTTOM"]:SetHeight(1)
		
		LunaUnitFrames.frames.members[i].borders["LEFT"] = LunaUnitFrames.frames.members[i]:CreateTexture("PlayerLeftBorder", "ARTWORK")
		LunaUnitFrames.frames.members[i].borders["LEFT"]:SetPoint("TOPRIGHT", LunaUnitFrames.frames.members[i], "TOPLEFT", 0, 1)
		LunaUnitFrames.frames.members[i].borders["LEFT"]:SetWidth(1)
		
		LunaUnitFrames.frames.members[i].borders["RIGHT"] = LunaUnitFrames.frames.members[i]:CreateTexture("PlayerBottomBorder", "ARTWORK")
		LunaUnitFrames.frames.members[i].borders["RIGHT"]:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i], "TOPRIGHT", 0, 1)
		LunaUnitFrames.frames.members[i].borders["RIGHT"]:SetWidth(1)
		
--		LunaUnitFrames.frames.members[i].highlightframe = CreateFrame("Frame")
--		LunaUnitFrames.frames.members[i].highlightframe:SetAllPoints(LunaUnitFrames.frames.members[i])
--		LunaUnitFrames.frames.members[i].highlightframe.texture = LunaUnitFrames.frames.members[i].highlightframe:CreateTexture("raid"..i.."highlight", "ARTWORK")
--		LunaUnitFrames.frames.members[i].highlightframe.texture:SetBlendMode("ADD")
--		LunaUnitFrames.frames.members[i].highlightframe.texture:SetAllPoints(LunaUnitFrames.frames.members[i])
--		LunaUnitFrames.frames.members[i].highlightframe.texture:SetTexture(LunaOptions.highlight)
--		LunaUnitFrames.frames.members[i].highlightframe.texture:SetVertexColor(1,1,1,0.4)
		
		LunaUnitFrames.frames.members[i].SetBorder = function(r,g,b,a)
										if not r or not g or not b then
											this.borders["TOP"]:SetTexture(0,0,0,0)
											this.borders["BOTTOM"]:SetTexture(0,0,0,0)
											this.borders["LEFT"]:SetTexture(0,0,0,0)
											this.borders["RIGHT"]:SetTexture(0,0,0,0)
										else
											this.borders["TOP"]:SetTexture(r,g,b,a)
											this.borders["BOTTOM"]:SetTexture(r,g,b,a)
											this.borders["LEFT"]:SetTexture(r,g,b,a)
											this.borders["RIGHT"]:SetTexture(r,g,b,a)
										end
									end

		LunaUnitFrames.frames.members[i].HealthBar = CreateFrame("StatusBar", nil, LunaUnitFrames.frames.members[i])

		LunaUnitFrames.frames.members[i].HealBar = CreateFrame("StatusBar", nil, LunaUnitFrames.frames.members[i])
		LunaUnitFrames.frames.members[i].HealBar:SetMinMaxValues(0, 1)
		LunaUnitFrames.frames.members[i].HealBar:SetValue(1)
		
		LunaUnitFrames.frames.members[i].bg = LunaUnitFrames.frames.members[i]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i])
		LunaUnitFrames.frames.members[i].bg:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i], "TOPLEFT")
		
		LunaUnitFrames.frames.members[i].PowerBar = CreateFrame("StatusBar", nil, LunaUnitFrames.frames.members[i])
		
		LunaUnitFrames.frames.members[i].Name = LunaUnitFrames.frames.members[i].HealthBar:CreateFontString(nil, "ARTWORK", LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].Name:SetJustifyH("CENTER")
		LunaUnitFrames.frames.members[i].Name:SetJustifyV("BOTTOM")
		LunaUnitFrames.frames.members[i].Name:SetShadowColor(0, 0, 0)
		LunaUnitFrames.frames.members[i].Name:SetShadowOffset(0.8, -0.8)
		LunaUnitFrames.frames.members[i].Name:SetTextColor(1,1,1)
		LunaUnitFrames.frames.members[i].Name:SetPoint("BOTTOM", LunaUnitFrames.frames.members[i].HealthBar, "CENTER")
		
		LunaUnitFrames.frames.members[i].Healthtext = LunaUnitFrames.frames.members[i].HealthBar:CreateFontString(nil, "ARTWORK", LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].Healthtext:SetJustifyH("CENTER")
		LunaUnitFrames.frames.members[i].Healthtext:SetJustifyV("TOP")
		LunaUnitFrames.frames.members[i].Healthtext:SetShadowColor(0, 0, 0)
		LunaUnitFrames.frames.members[i].Healthtext:SetShadowOffset(0.8, -0.8)
		LunaUnitFrames.frames.members[i].Healthtext:SetTextColor(1,1,1)
		LunaUnitFrames.frames.members[i].Healthtext:SetPoint("TOP", LunaUnitFrames.frames.members[i].HealthBar, "CENTER")
					
		LunaUnitFrames.frames.members[i].RezIcon = LunaUnitFrames.frames.members[i].HealthBar:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].RezIcon:SetTexture(LunaOptions.resIcon)
		LunaUnitFrames.frames.members[i].RezIcon:SetPoint("TOPRIGHT", LunaUnitFrames.frames.members[i], "TOPRIGHT")
		LunaUnitFrames.frames.members[i].RezIcon:Hide()
		
		LunaUnitFrames.frames.members[i].aggro = CreateFrame("Frame", nil, LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].aggro:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].aggro:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].aggro:SetPoint("BOTTOMLEFT", LunaUnitFrames.frames.members[i].HealthBar, "BOTTOMLEFT")
		LunaUnitFrames.frames.members[i].aggro.texture = LunaUnitFrames.frames.members[i].aggro:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].aggro)
		LunaUnitFrames.frames.members[i].aggro.texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].aggro.texture:SetAllPoints(LunaUnitFrames.frames.members[i].aggro)
		LunaUnitFrames.frames.members[i].aggro.texture:SetTexture(1, 0, 0)
		LunaUnitFrames.frames.members[i].aggro:Hide()
		
		LunaUnitFrames.frames.members[i].buffs = {}
		
		LunaUnitFrames.frames.members[i].buffs[1] = CreateFrame("Frame", nil, LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].buffs[1]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].buffs[1]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].buffs[1]:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i].HealthBar, "TOPLEFT")
		LunaUnitFrames.frames.members[i].buffs[1].texture = LunaUnitFrames.frames.members[i].buffs[1]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].buffs[1])
		LunaUnitFrames.frames.members[i].buffs[1].texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].buffs[1].texture:SetTexture(0, 1, 0)
		LunaUnitFrames.frames.members[i].buffs[1].texture:SetAllPoints(LunaUnitFrames.frames.members[i].buffs[1])
		LunaUnitFrames.frames.members[i].buffs[1]:Hide()
		
		LunaUnitFrames.frames.members[i].buffs[2] = CreateFrame("Frame", nil, LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].buffs[2]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].buffs[2]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].buffs[2]:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i].buffs[1], "TOPRIGHT")
		LunaUnitFrames.frames.members[i].buffs[2].texture = LunaUnitFrames.frames.members[i].buffs[2]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].buffs[2])
		LunaUnitFrames.frames.members[i].buffs[2].texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].buffs[2].texture:SetTexture(0, 1, 0)
		LunaUnitFrames.frames.members[i].buffs[2].texture:SetAllPoints(LunaUnitFrames.frames.members[i].buffs[2])
		LunaUnitFrames.frames.members[i].buffs[2]:Hide()

		LunaUnitFrames.frames.members[i].buffs[3] = CreateFrame("Frame", nil, LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].buffs[3]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].buffs[3]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].buffs[3]:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i].buffs[1], "BOTTOMLEFT")
		LunaUnitFrames.frames.members[i].buffs[3].texture = LunaUnitFrames.frames.members[i].buffs[3]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].buffs[3])
		LunaUnitFrames.frames.members[i].buffs[3].texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].buffs[3].texture:SetTexture(0, 1, 0)
		LunaUnitFrames.frames.members[i].buffs[3].texture:SetAllPoints(LunaUnitFrames.frames.members[i].buffs[3])
		LunaUnitFrames.frames.members[i].buffs[3]:Hide()

		LunaUnitFrames.frames.members[i].debuffs = {}
		
		LunaUnitFrames.frames.members[i].debuffs[1] = CreateFrame("Frame", nil, LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].debuffs[1]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].debuffs[1]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].debuffs[1]:SetPoint("TOPRIGHT", LunaUnitFrames.frames.members[i].HealthBar, "TOPRIGHT")
		LunaUnitFrames.frames.members[i].debuffs[1].texture = LunaUnitFrames.frames.members[i].debuffs[1]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].debuffs[1])
		LunaUnitFrames.frames.members[i].debuffs[1].texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].debuffs[1].texture:SetAllPoints(LunaUnitFrames.frames.members[i].debuffs[1])
		LunaUnitFrames.frames.members[i].debuffs[1]:Hide()
		
		LunaUnitFrames.frames.members[i].debuffs[2] = CreateFrame("Frame", nil, LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].debuffs[2]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].debuffs[2]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].debuffs[2]:SetPoint("TOPRIGHT", LunaUnitFrames.frames.members[i].debuffs[1], "TOPLEFT")
		LunaUnitFrames.frames.members[i].debuffs[2].texture = LunaUnitFrames.frames.members[i].debuffs[2]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].debuffs[2])
		LunaUnitFrames.frames.members[i].debuffs[2].texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].debuffs[2].texture:SetAllPoints(LunaUnitFrames.frames.members[i].debuffs[2])
		LunaUnitFrames.frames.members[i].debuffs[2]:Hide()

		LunaUnitFrames.frames.members[i].debuffs[3] = CreateFrame("Frame", nil, LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].debuffs[3]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].debuffs[3]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].debuffs[3]:SetPoint("TOPRIGHT", LunaUnitFrames.frames.members[i].debuffs[1], "BOTTOMRIGHT")
		LunaUnitFrames.frames.members[i].debuffs[3].texture = LunaUnitFrames.frames.members[i].debuffs[3]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].debuffs[3])
		LunaUnitFrames.frames.members[i].debuffs[3].texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].debuffs[3].texture:SetAllPoints(LunaUnitFrames.frames.members[i].debuffs[3])
		LunaUnitFrames.frames.members[i].debuffs[3]:Hide()
		
		LunaUnitFrames.frames.members[i].wsoul = CreateFrame("Frame", nil, LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].wsoul:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].wsoul:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].wsoul:SetPoint("BOTTOMRIGHT", LunaUnitFrames.frames.members[i].HealthBar, "BOTTOMRIGHT")
		LunaUnitFrames.frames.members[i].wsoul.texture = LunaUnitFrames.frames.members[i].wsoul:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].wsoul)
		LunaUnitFrames.frames.members[i].wsoul.texture:SetAllPoints(LunaUnitFrames.frames.members[i].wsoul)
		LunaUnitFrames.frames.members[i].wsoul.texture:SetTexture("Interface\\Icons\\Spell_Holy_AshesToAshes")
		LunaUnitFrames.frames.members[i].wsoul:Hide()

		LunaUnitFrames.frames.members[i].healreduc = CreateFrame("Frame", nil, LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].healreduc:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].healreduc:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].healreduc:SetPoint("BOTTOMRIGHT", LunaUnitFrames.frames.members[i].wsoul, "BOTTOMLEFT")
		LunaUnitFrames.frames.members[i].healreduc.texture = LunaUnitFrames.frames.members[i].healreduc:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].healreduc)
		LunaUnitFrames.frames.members[i].healreduc.texture:SetAllPoints(LunaUnitFrames.frames.members[i].healreduc)
		LunaUnitFrames.frames.members[i].healreduc.texture:SetTexture("Interface\\Icons\\Ability_Warrior_SavageBlow")
		LunaUnitFrames.frames.members[i].healreduc:Hide()
		
		LunaUnitFrames.frames.members[i].centericons = {}
		
		LunaUnitFrames.frames.members[i].centericons[1] = CreateFrame("Frame", "CenterIcon1", LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].centericons[1]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].centericons[1]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].centericons[1]:SetPoint("CENTER", LunaUnitFrames.frames.members[i].HealthBar, "CENTER")
		LunaUnitFrames.frames.members[i].centericons[1].texture = LunaUnitFrames.frames.members[i].centericons[1]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].centericons[1])
		LunaUnitFrames.frames.members[i].centericons[1].texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].centericons[1].texture:SetAllPoints(LunaUnitFrames.frames.members[i].centericons[1])
		LunaUnitFrames.frames.members[i].centericons[1]:Hide()
		
		LunaUnitFrames.frames.members[i].centericons[1].cd = CreateFrame("Model", "CenterIcon1CD", LunaUnitFrames.frames.members[i].centericons[1], "CooldownFrameTemplate")
		LunaUnitFrames.frames.members[i].centericons[1].cd:ClearAllPoints()
		LunaUnitFrames.frames.members[i].centericons[1].cd:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i].centericons[1], "TOPLEFT")
		LunaUnitFrames.frames.members[i].centericons[1].cd:SetHeight(36)
		LunaUnitFrames.frames.members[i].centericons[1].cd:SetWidth(36)
		
		LunaUnitFrames.frames.members[i].centericons[2] = CreateFrame("Frame", "CenterIcon2", LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].centericons[2]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].centericons[2]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].centericons[2]:SetPoint("TOPRIGHT", LunaUnitFrames.frames.members[i].centericons[1], "TOPLEFT")
		LunaUnitFrames.frames.members[i].centericons[2].texture = LunaUnitFrames.frames.members[i].centericons[2]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].centericons[2])
		LunaUnitFrames.frames.members[i].centericons[2].texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].centericons[2].texture:SetAllPoints(LunaUnitFrames.frames.members[i].centericons[2])
		LunaUnitFrames.frames.members[i].centericons[2]:Hide()
		
		LunaUnitFrames.frames.members[i].centericons[2].cd = CreateFrame("Model", "CenterIcon2CD", LunaUnitFrames.frames.members[i].centericons[2], "CooldownFrameTemplate")
		LunaUnitFrames.frames.members[i].centericons[2].cd:ClearAllPoints()
		LunaUnitFrames.frames.members[i].centericons[2].cd:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i].centericons[2], "TOPLEFT")
		LunaUnitFrames.frames.members[i].centericons[2].cd:SetHeight(36)
		LunaUnitFrames.frames.members[i].centericons[2].cd:SetWidth(36)
		
		LunaUnitFrames.frames.members[i].centericons[3] = CreateFrame("Frame", "CenterIcon3", LunaUnitFrames.frames.members[i].HealthBar)
		LunaUnitFrames.frames.members[i].centericons[3]:SetBackdrop(LunaOptions.backdrop)
		LunaUnitFrames.frames.members[i].centericons[3]:SetBackdropColor(0,0,0,1)
		LunaUnitFrames.frames.members[i].centericons[3]:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i].centericons[1], "TOPRIGHT")
		LunaUnitFrames.frames.members[i].centericons[3].texture = LunaUnitFrames.frames.members[i].centericons[3]:CreateTexture(nil, "OVERLAY", LunaUnitFrames.frames.members[i].centericons[3])
		LunaUnitFrames.frames.members[i].centericons[3].texture:SetTexture(LunaOptions.indicator)
		LunaUnitFrames.frames.members[i].centericons[3].texture:SetAllPoints(LunaUnitFrames.frames.members[i].centericons[3])
		LunaUnitFrames.frames.members[i].centericons[3]:Hide()
		
		LunaUnitFrames.frames.members[i].centericons[3].cd = CreateFrame("Model", "CenterIcon3CD", LunaUnitFrames.frames.members[i].centericons[3], "CooldownFrameTemplate")
		LunaUnitFrames.frames.members[i].centericons[3].cd:ClearAllPoints()
		LunaUnitFrames.frames.members[i].centericons[3].cd:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i].centericons[3], "TOPLEFT")
		LunaUnitFrames.frames.members[i].centericons[3].cd:SetHeight(36)
		LunaUnitFrames.frames.members[i].centericons[3].cd:SetWidth(36)
		
		LunaUnitFrames.frames.members[i]:RegisterEvent("UNIT_AURA")
		LunaUnitFrames.frames.members[i]:RegisterEvent("UNIT_DISPLAYPOWER")
		LunaUnitFrames.frames.members[i]:SetScript("OnEvent", RaidEventhandler)
		LunaUnitFrames.frames.members[i]:SetScript("OnUpdate", Update_RaidUnit_Status)

		LunaUnitFrames.frames.members[i].updateTime = 0
		LunaUnitFrames.frames.members[i].charmed = false
	end
	
	LunaUnitFrames:UpdateRaidLayout()
	AceEvent:RegisterEvent("UNIT_HEALTH", LunaUnitFrames.Update_RaidUnit_Health)
	-- Register event for ENERGY, MANA and RAGE
	AceEvent:RegisterEvent("UNIT_ENERGY", LunaUnitFrames.Update_RaidUnit_Power)
	AceEvent:RegisterEvent("UNIT_MANA", LunaUnitFrames.Update_RaidUnit_Power)
	AceEvent:RegisterEvent("UNIT_RAGE", LunaUnitFrames.Update_RaidUnit_Power)

	AceEvent:RegisterEvent("UNIT_PET", LunaUnitFrames.QueuePetRosterUpdate)
	AceEvent:RegisterEvent("Banzai_UnitGainedAggro", LunaUnitFrames.Raid_Aggro)
	AceEvent:RegisterEvent("Banzai_UnitLostAggro", LunaUnitFrames.Raid_Aggro)
	AceEvent:RegisterEvent("HealComm_Ressupdate", LunaUnitFrames.Raid_Res)
	AceEvent:RegisterEvent("HealComm_Hotupdate", LunaUnitFrames.Raid_Hot)
	AceEvent:RegisterEvent("HealComm_Healupdate", LunaUnitFrames.Raid_Heal)
end

function LunaUnitFrames:UpdateRaidRoster()
	LunaUnitFrames:WipeRaidTags()
	roster:ScanFullRoster()
	if ((GetNumRaidMembers() == 0 or not RAID_SUBGROUP_LISTS) and ((GetNumPartyMembers() == 0 or not LunaOptions.partyraidframe) and not LunaOptions.AlwaysRaid)) or LunaOptions.enableRaid == 0 then
		for i=1,8 do
			LunaUnitFrames.frames.headers[i]:Hide()
		end
		for i=1,40 do
			LunaUnitFrames.frames.members[i].unit = nil
			LunaUnitFrames.frames.members[i]:Hide()
		end
		LunaUnitFrames:UpdatePetRoster()
		return
	end
	if LunaOptions.frames["LunaRaidFrames"].grpmode == "GROUP" then
		if GetNumRaidMembers() == 0 then
			for i=1,8 do
				RaidRoster[i] = {}
			end
			RaidRoster[1][1] = UnitName("player")
			for i=1,4 do
				RaidRoster[1][i+1] = UnitName("party"..i)
			end
			table.sort(RaidRoster[1], function(a,b) return a<b end)
			LunaUnitFrames.frames.headers[1].GrpName:SetText("GRP 1")
		elseif RAID_SUBGROUP_LISTS then
			for i=1,8 do
				RaidRoster[i] = {}
				for z=1,5 do
					if RAID_SUBGROUP_LISTS[i][z] then
						RaidRoster[i][z] = UnitName("raid"..RAID_SUBGROUP_LISTS[i][z])
					else
						RaidRoster[i][z] = nil
					end
				end
				table.sort(RaidRoster[i], function(a,b) return a<b end)
				LunaUnitFrames.frames.headers[i].GrpName:SetText("GRP "..i)
			end
		else
			return
		end
	else
		if GetNumRaidMembers() == 0 then
			for i=1,8 do
				RaidRoster[i] = {}
			end
			local engClass,class = UnitClass("player")
			table.insert(RaidRoster[classes[class]], 1, UnitName("player"))
			LunaUnitFrames.frames.headers[classes[class]].GrpName:SetText(engClass)
			for i=1, 4 do
				engClass,class = UnitClass("party"..i)
				if class then
					table.insert(RaidRoster[classes[class]], 1, UnitName("party"..i))
					LunaUnitFrames.frames.headers[classes[class]].GrpName:SetText(engClass)
				end
			end
		elseif RAID_SUBGROUP_LISTS then
			for i=1,8 do
				RaidRoster[i] = {}
			end
			local class
			for i=1, 40 do
				engClass,class = UnitClass("raid"..i)
				if class then
					table.insert(RaidRoster[classes[class]], 1, UnitName("raid"..i))
					LunaUnitFrames.frames.headers[classes[class]].GrpName:SetText(engClass)
				end
			end
		else
			return
		end
		for i=1,8 do
			table.sort(RaidRoster[i], function(a,b) return a<b end)
		end
	end
	local numFrame = 1
	for i=1,8 do
		if (LunaOptions.frames["LunaRaidFrames"].ShowRaidGroupTitles or 1) == 1 and getn(RaidRoster[i]) > 0 then
			LunaUnitFrames.frames.headers[i]:Show()
		else
			LunaUnitFrames.frames.headers[i]:Hide()
		end
		for v,k in pairs(RaidRoster[i]) do
			local frame = LunaUnitFrames.frames.members[numFrame]
			frame.unit = roster:GetUnitIDFromName(k)
			if frame.unit then
				LunaUnitFrames:RegisterFontstring(frame.Name, frame.unit, LunaOptions.frames["LunaRaidFrames"].toptext)
				LunaUnitFrames:RegisterFontstring(frame.Healthtext, frame.unit, LunaOptions.frames["LunaRaidFrames"].bottomtext)
				_,frame.Class = UnitClass(frame.unit)
				local power = UnitPowerType(frame.unit)
				if power == 1 then
					frame.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Rage"][1], LunaOptions.PowerColors["Rage"][2], LunaOptions.PowerColors["Rage"][3])
				elseif power == 3 then
					frame.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Energy"][1], LunaOptions.PowerColors["Energy"][2], LunaOptions.PowerColors["Energy"][3])
				else
					frame.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Mana"][1], LunaOptions.PowerColors["Mana"][2], LunaOptions.PowerColors["Mana"][3])
				end
				LunaUnitFrames:Update_RaidFrame_Auras(frame)
				LunaUnitFrames:Update_RaidFrame_Health(frame)
				LunaUnitFrames:Update_RaidFrame_Power(frame)
				frame:Show()
				if HealComm:UnitisResurrecting(UnitName(frame.unit)) then
					frame.RezIcon:Show()
				else
					frame.RezIcon:Hide()
				end
				if banzai:GetUnitAggroByUnitId(frame.unit) and LunaOptions.aggro then
					frame.aggro:Show()
				else
					frame.aggro:Hide()
				end
			end
			numFrame = numFrame + 1
		end
	end
	-- Hide left over frames if raid is not full
	for i=numFrame, 40 do
		LunaUnitFrames.frames.members[i]:Hide()
	end
	LunaUnitFrames.UpdatePetRoster()
	LunaUnitFrames:UpdateRaidLayout()
end

function LunaUnitFrames:UpdatePetRoster()
	LunaUnitFrames:WipeRaidPetTags()
	PetRoster = {}
	local index = 1
	if not GetNumRaidMembers() or GetNumRaidMembers() < 2 then
		if UnitIsVisible("pet") then
			PetRoster[index] = {}
			PetRoster[index].unitid = "pet"
			PetRoster[index].name = UnitName("pet")
			index = index + 1
		end
		for i=1, 4 do
			if UnitIsVisible("partypet"..i) then
				PetRoster[index] = {}
				PetRoster[index].unitid = "partypet"..i
				PetRoster[index].name = UnitName("partypet"..i)
				index = index + 1
			end
		end
	else
		for i=1, 40 do
			if UnitIsVisible("raidpet"..i) then
				PetRoster[index] = {}
				PetRoster[index].unitid = "raidpet"..i
				PetRoster[index].name = UnitName("raidpet"..i)
				index = index + 1
			end
		end
	end
	table.sort(PetRoster, function(a,b) return a.name<b.name end)
	local enable = (LunaOptions.frames["LunaRaidFrames"].ShowRaidGroupTitles or 1) == 1 and getn(PetRoster) > 0 and LunaOptions.frames["LunaRaidFrames"].petgroup and (GetNumRaidMembers() > 1 or LunaOptions.AlwaysRaid) and LunaOptions.enableRaid == 1
	if enable then
		LunaUnitFrames.frames.headers[9]:Show()
	else
		LunaUnitFrames.frames.headers[9]:Hide()
	end
	enable = getn(PetRoster) > 0 and LunaOptions.frames["LunaRaidFrames"].petgroup and (GetNumRaidMembers() > 1 or LunaOptions.AlwaysRaid) and LunaOptions.enableRaid == 1
	for i=1, 40 do
		local frame = LunaUnitFrames.frames.members[i+40]
		if PetRoster[i] and enable then
			frame.unit = PetRoster[i].unitid
			LunaUnitFrames:RegisterFontstring(frame.Name, frame.unit, LunaOptions.frames["LunaRaidFrames"].toptext or "")
			LunaUnitFrames:RegisterFontstring(frame.Healthtext, frame.unit, LunaOptions.frames["LunaRaidFrames"].bottomtext or "")
			local power = UnitPowerType(frame.unit)
			if power == 1 then
				frame.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Rage"][1], LunaOptions.PowerColors["Rage"][2], LunaOptions.PowerColors["Rage"][3])
			elseif power == 2 then
				frame.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Focus"][1], LunaOptions.PowerColors["Focus"][2], LunaOptions.PowerColors["Focus"][3])
			elseif power == 3 then
				frame.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Energy"][1], LunaOptions.PowerColors["Energy"][2], LunaOptions.PowerColors["Energy"][3])
			else
				frame.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Mana"][1], LunaOptions.PowerColors["Mana"][2], LunaOptions.PowerColors["Mana"][3])
			end
			LunaUnitFrames:Update_RaidFrame_Auras(frame)
			LunaUnitFrames:Update_RaidFrame_Health(frame)
			LunaUnitFrames:Update_RaidFrame_Power(frame)
			frame:Show()
		else
			frame.unit = nil
			frame:Hide()
		end
	end
end

function LunaUnitFrames:SetRaidFrameSize()
	local pBars = LunaOptions.frames["LunaRaidFrames"].pBars
	local height = LunaOptions.frames["LunaRaidFrames"].height or 30
	local width = LunaOptions.frames["LunaRaidFrames"].width or 60
	local scale = LunaOptions.frames["LunaRaidFrames"].scale or 1
	
	for i=1,9 do
		LunaUnitFrames.frames.headers[i]:SetHeight(height)
		LunaUnitFrames.frames.headers[i]:SetWidth(width)
		LunaUnitFrames.frames.headers[i]:SetScale(scale)
		LunaUnitFrames.frames.headers[i].GrpName:SetFont(LunaOptions.font, height*0.4)
	end
	LunaUnitFrames.frames.headers[9].GrpName:SetText("PETS")
	for i=1,80 do
		LunaUnitFrames.frames.members[i]:SetHeight(height)
		LunaUnitFrames.frames.members[i]:SetWidth(width)
		LunaUnitFrames.frames.members[i]:SetScale(scale)
		LunaUnitFrames.frames.members[i].borders["TOP"]:SetWidth(width)
		LunaUnitFrames.frames.members[i].borders["BOTTOM"]:SetWidth(width)
		LunaUnitFrames.frames.members[i].borders["LEFT"]:SetHeight(height+2)
		LunaUnitFrames.frames.members[i].borders["RIGHT"]:SetHeight(height+2)
		if not pBars then
			LunaUnitFrames.frames.members[i].HealthBar:SetHeight(height)
			LunaUnitFrames.frames.members[i].HealthBar:SetWidth(width)
			LunaUnitFrames.frames.members[i].bg:SetHeight(height)
			LunaUnitFrames.frames.members[i].bg:SetWidth(width)
		elseif pBars == 1 then
			LunaUnitFrames.frames.members[i].HealthBar:SetHeight(math.floor(height*0.85))
			LunaUnitFrames.frames.members[i].HealthBar:SetWidth(width)
			LunaUnitFrames.frames.members[i].bg:SetHeight(math.floor(height*0.85))
			LunaUnitFrames.frames.members[i].bg:SetWidth(width)
			LunaUnitFrames.frames.members[i].PowerBar:SetHeight(height-LunaUnitFrames.frames.members[i].HealthBar:GetHeight())
			LunaUnitFrames.frames.members[i].PowerBar:SetWidth(width)
		else
			LunaUnitFrames.frames.members[i].HealthBar:SetHeight(height)
			LunaUnitFrames.frames.members[i].HealthBar:SetWidth(math.floor(width*0.85))
			LunaUnitFrames.frames.members[i].bg:SetHeight(height)
			LunaUnitFrames.frames.members[i].bg:SetWidth(math.floor(width*0.85))
			LunaUnitFrames.frames.members[i].PowerBar:SetHeight(height)
			LunaUnitFrames.frames.members[i].PowerBar:SetWidth(width-LunaUnitFrames.frames.members[i].HealthBar:GetWidth())
		end
		LunaUnitFrames.frames.members[i].Name:SetWidth(LunaUnitFrames.frames.members[i].HealthBar:GetWidth())
		LunaUnitFrames.frames.members[i].Name:SetHeight(LunaUnitFrames.frames.members[i].HealthBar:GetHeight()/2)
		LunaUnitFrames.frames.members[i].Name:SetFont(LunaOptions.font, 0.14*(width+height))
		LunaUnitFrames.frames.members[i].Healthtext:SetWidth(LunaUnitFrames.frames.members[i].HealthBar:GetWidth())
		LunaUnitFrames.frames.members[i].Healthtext:SetHeight(LunaUnitFrames.frames.members[i].HealthBar:GetHeight()/2)
		LunaUnitFrames.frames.members[i].Healthtext:SetFont(LunaOptions.font, 0.14*(width+height))
		LunaUnitFrames.frames.members[i].aggro:SetHeight(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
		LunaUnitFrames.frames.members[i].aggro:SetWidth(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
		LunaUnitFrames.frames.members[i].wsoul:SetHeight(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
		LunaUnitFrames.frames.members[i].wsoul:SetWidth(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
		LunaUnitFrames.frames.members[i].healreduc:SetHeight(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
		LunaUnitFrames.frames.members[i].healreduc:SetWidth(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
		
		for z=1, 3 do
			LunaUnitFrames.frames.members[i].buffs[z]:SetHeight(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
			LunaUnitFrames.frames.members[i].buffs[z]:SetWidth(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
			LunaUnitFrames.frames.members[i].debuffs[z]:SetHeight(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
			LunaUnitFrames.frames.members[i].debuffs[z]:SetWidth(height*0.25*(LunaOptions.frames["LunaRaidFrames"].cornericonscale or 1))
			LunaUnitFrames.frames.members[i].centericons[z]:SetHeight(height*0.6*(LunaOptions.frames["LunaRaidFrames"].centericonscale or 1))
			LunaUnitFrames.frames.members[i].centericons[z]:SetWidth(height*0.6*(LunaOptions.frames["LunaRaidFrames"].centericonscale or 1))
			LunaUnitFrames.frames.members[i].centericons[z].cd:SetScale(height*0.6*(LunaOptions.frames["LunaRaidFrames"].centericonscale or 1)/36)
		end
		LunaUnitFrames.frames.members[i].RezIcon:SetHeight(height/1.5)
		LunaUnitFrames.frames.members[i].RezIcon:SetWidth(height/1.5)
	end
end

function LunaUnitFrames:QueuePetRosterUpdate()
	if AceEvent:IsEventScheduled("LunaUpdatePetRoster") then
		AceEvent:CancelScheduledEvent("LunaUpdatePetRoster")
		LunaUnitFrames.UpdatePetRoster()
	end
	AceEvent:ScheduleEvent("LunaUpdatePetRoster", LunaUnitFrames.UpdatePetRoster, 0.5)
end

function LunaUnitFrames:UpdateRaidLayout()
	local Padding = LunaOptions.frames["LunaRaidFrames"].padding or 4
	local pBars = LunaOptions.frames["LunaRaidFrames"].pBars
	local verticalHealth = LunaOptions.frames["LunaRaidFrames"].verticalHealth
	local sAnchor, tAnchor, xPadding, yPadding, frame
	local numFrame = 1
	if LunaOptions.frames["LunaRaidFrames"].growthdir == "UP" then
		sAnchor = "BOTTOM"
		tAnchor = "TOP"
		xPadding = 0
		yPadding = Padding
	elseif LunaOptions.frames["LunaRaidFrames"].growthdir == "DOWN" then
		sAnchor = "TOP"
		tAnchor = "BOTTOM"
		xPadding = 0
		yPadding = Padding*(-1)
	elseif LunaOptions.frames["LunaRaidFrames"].growthdir == "RIGHT" then
		sAnchor = "LEFT"
		tAnchor = "RIGHT"
		xPadding = Padding
		yPadding = 0
	else
		sAnchor = "RIGHT"
		tAnchor = "LEFT"
		xPadding = Padding*(-1)
		yPadding = 0
	end
	for i=1, 8 do
		if LunaOptions.raidinterlock then
			if i == 1 then
				LunaUnitFrames.frames.headers[i]:ClearAllPoints()
				LunaUnitFrames.frames.headers[i]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", LunaOptions.frames["LunaRaidFrames"]["positions"][i].x, LunaOptions.frames["LunaRaidFrames"]["positions"][i].y)
			else
				LunaUnitFrames.frames.headers[i]:SetScript("OnDragStart", nil)
				LunaUnitFrames.frames.headers[i]:SetMovable(0)
				LunaUnitFrames.frames.headers[i]:ClearAllPoints()
				LunaUnitFrames.frames.headers[i]:SetPoint("TOPLEFT", LunaUnitFrames.frames.headers[i-1], "TOPRIGHT", LunaOptions.frames["LunaRaidFrames"].invertgrowth and (Padding *(-1)) or Padding, 0)
			end
		else
			LunaUnitFrames.frames.headers[i]:ClearAllPoints()
			LunaUnitFrames.frames.headers[i]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", LunaOptions.frames["LunaRaidFrames"]["positions"][i].x, LunaOptions.frames["LunaRaidFrames"]["positions"][i].y)
		end
		for z=1,getn(RaidRoster[i]) do
			frame = LunaUnitFrames.frames.members[numFrame]
			
			if z == 1 then
				frame:ClearAllPoints()
				frame:SetPoint(sAnchor, LunaUnitFrames.frames.headers[i], tAnchor)
			else
				frame:ClearAllPoints()
				frame:SetPoint(sAnchor, LunaUnitFrames.frames.members[numFrame-1], tAnchor, xPadding, yPadding)
			end
			frame.HealthBar:ClearAllPoints()
			if verticalHealth then
				frame.HealthBar:SetOrientation("VERTICAL")
				frame.HealBar:SetOrientation("VERTICAL")
			else
				frame.HealthBar:SetOrientation("HORIZONTAL")
				frame.HealBar:SetOrientation("HORIZONTAL")
			end
			frame.HealthBar:SetPoint("TOPLEFT", frame, "TOPLEFT")
			frame.PowerBar:ClearAllPoints()
			if pBars == 1 then
				frame.PowerBar:SetOrientation("HORIZONTAL")
				frame.PowerBar:Show()
			elseif pBars == 2 then
				frame.PowerBar:SetOrientation("VERTICAL")
				frame.PowerBar:Show()
			else
				frame.PowerBar:Hide()
			end
			frame.PowerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")

			numFrame = numFrame + 1
		end
	end
	if LunaOptions.raidinterlock then
		LunaUnitFrames.frames.headers[9]:SetScript("OnDragStart", nil)
		LunaUnitFrames.frames.headers[9]:SetMovable(0)
		LunaUnitFrames.frames.headers[9]:ClearAllPoints()
		if LunaOptions.frames["LunaRaidFrames"].growthdir == "UP" or LunaOptions.frames["LunaRaidFrames"].growthdir == "DOWN" then
			LunaUnitFrames.frames.headers[9]:SetPoint("RIGHT", LunaUnitFrames.frames.headers[1], "LEFT", Padding*(-1), 0)
		else
			LunaUnitFrames.frames.headers[9]:SetPoint("BOTTOM", LunaUnitFrames.frames.headers[1], "TOP", 0, Padding)
		end
	else
		LunaUnitFrames.frames.headers[9]:ClearAllPoints()
		LunaUnitFrames.frames.headers[9]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", LunaOptions.frames["LunaRaidFrames"]["positions"][9].x, LunaOptions.frames["LunaRaidFrames"]["positions"][9].y)
	end
	for i=41, 80 do
		if i == 41 then
			LunaUnitFrames.frames.members[i]:ClearAllPoints()
			LunaUnitFrames.frames.members[i]:SetPoint(sAnchor, LunaUnitFrames.frames.headers[9], tAnchor, 0, 0)
		else
			LunaUnitFrames.frames.members[i]:ClearAllPoints()
			LunaUnitFrames.frames.members[i]:SetPoint(sAnchor, LunaUnitFrames.frames.members[i-1], tAnchor, xPadding, yPadding)
		end
		LunaUnitFrames.frames.members[i].HealthBar:ClearAllPoints()
		if verticalHealth then
			LunaUnitFrames.frames.members[i].HealthBar:SetOrientation("VERTICAL")
		else
			LunaUnitFrames.frames.members[i].HealthBar:SetOrientation("HORIZONTAL")
		end
		LunaUnitFrames.frames.members[i].HealthBar:SetPoint("TOPLEFT", LunaUnitFrames.frames.members[i], "TOPLEFT")
		LunaUnitFrames.frames.members[i].PowerBar:ClearAllPoints()
		if pBars == 1 then
			LunaUnitFrames.frames.members[i].PowerBar:SetOrientation("HORIZONTAL")
			LunaUnitFrames.frames.members[i].PowerBar:Show()
		elseif pBars == 2 then
			LunaUnitFrames.frames.members[i].PowerBar:SetOrientation("VERTICAL")
			LunaUnitFrames.frames.members[i].PowerBar:Show()
		else
			LunaUnitFrames.frames.members[i].PowerBar:Hide()
		end
		LunaUnitFrames.frames.members[i].PowerBar:SetPoint("BOTTOMRIGHT", LunaUnitFrames.frames.members[i], "BOTTOMRIGHT")
	end
	LunaUnitFrames:SetRaidFrameSize()
end

function LunaUnitFrames.Raid_Displaypower(unitid)
	if this.unit ~= unitid then
		return
	end
	local power = UnitPowerType(unitid)
	if power == 1 then
		this.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Rage"][1], LunaOptions.PowerColors["Rage"][2], LunaOptions.PowerColors["Rage"][3])
	elseif power == 3 then
		this.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Energy"][1], LunaOptions.PowerColors["Energy"][2], LunaOptions.PowerColors["Energy"][3])
	else
		this.PowerBar:SetStatusBarColor(LunaOptions.PowerColors["Mana"][1], LunaOptions.PowerColors["Mana"][2], LunaOptions.PowerColors["Mana"][3])
	end
end

-- Event handler for unit aura changes
function LunaUnitFrames.Raid_Aura(unitid)
	if not this.unit or this.unit ~= unitid then
		return
	end

	LunaUnitFrames:Update_RaidFrame_Auras(this)
end

function LunaUnitFrames:Update_RaidFrame_Auras(frame)
	if frame == nil or frame.unit == nil then
		return
	end
	--local maxDebuffs = ((LunaOptions.frames["LunaRaidFrames"].centerIcon and PlayerClass == "PRIEST") and 2) or ((LunaOptions.frames["LunaRaidFrames"].centerIcon and PlayerClass == "DRUID") and 1) or 3
	local maxDebuffs = 3

    local lastfound = 1
    local debuffCount = 1
    
    frame:SetBackdropColor(0,0,0,1)
    classDispellable = CLASS_DISPELS[PlayerClass]

    -- Hide weakened soul frame
    local weakenedSoul = false
    local healReduc = false
    frame.wsoul:Hide()
    frame.healreduc:Hide()
    for i = 1, 16 do
        texture,_,dispeltype = UnitDebuff(frame.unit,i)

        dispeltype = dispeltype or IDENTIFIED_DEBUFFS[texture]
        -- We have a debuff. If we're only showing dispellable debuffs and the player can dispel
        -- it, show it. If we're not showing dispellable debuffs show it regardless.
        
        if ((dispeltype and LunaOptions.showdispelable and classDispellable[dispeltype]) or (not LunaOptions.showdispelable)) then
        	--if dispeltype and LunaOptions.HighlightDebuffs then
			--	frame:SetBackdropColor(unpack(LunaOptions.DebuffTypeColor[dispeltype]))
			--end

            if texture and debuffCount <= maxDebuffs then
                if LunaOptions.frames["LunaRaidFrames"].centerIcon then
                    frame.centericons[debuffCount].texture:SetTexture(texture)
                    frame.centericons[debuffCount]:Show()
                    frame.debuffs[debuffCount]:Hide()
                elseif LunaOptions.frames["LunaRaidFrames"].texturedebuff then
                    frame.centericons[debuffCount]:Hide()
                    frame.debuffs[debuffCount]:Show()
                    frame.debuffs[debuffCount].texture:SetTexture(texture)
                elseif dispeltype then
                    frame.centericons[debuffCount]:Hide()
                    frame.debuffs[debuffCount]:Show()
                    frame.debuffs[debuffCount].texture:SetTexture(unpack(LunaOptions.DebuffTypeColor[dispeltype]))
                else
                    frame.centericons[debuffCount]:Hide()
                    frame.debuffs[debuffCount]:Show()
                    frame.debuffs[debuffCount].texture:SetTexture(0,0,0)
                end

                debuffCount = debuffCount + 1
            end

            if debuffCount > maxDebuffs then
                break
            end
        end

        -- Avoid scanning debuffs more than necessary
        if (not healReduc) then
	        ScanTip:ClearLines()
	        ScanTip:SetUnitDebuff(frame.unit, i)
	        local debufftext = ScanTipTextLeft2:GetText()

	        if (debufftext and string.find(debufftext, "Healing effects reduced by")) then
	        	healReduc = true
	        	frame.healreduc.texture:SetTexture(texture)
	        	frame.healreduc:Show()
	        end
    	end

        if not weakenedSoul and LunaOptions.frames["LunaRaidFrames"].wsoul and PlayerClass == "PRIEST" and texture == "Interface\\Icons\\Spell_Holy_AshesToAshes" then
            frame.wsoul:Show()
            weakenedSoul = true
        end
    end

    -- Remove any buff textures leftover from previous updates (i.e. hide frames above the debuff count)
    for i = debuffCount, maxDebuffs do
        frame.debuffs[i]:Hide()
        frame.centericons[i]:Hide()
    end


    if LunaOptions.frames["LunaRaidFrames"].hottracker and PlayerClass == "PRIEST" then
        for i=1,32 do
            local texture = UnitBuff(frame.unit,i)
            if texture == HotTexture then
                if LunaOptions.frames["LunaRaidFrames"].centerIcon then
                    frame.centericons[3]:Show()
                    frame.centericons[3].texture:SetTexture(texture)
                else
                    frame.centericons[1]:Show()
                    frame.centericons[1].texture:SetTexture(texture)
                end
            end
        end
    elseif LunaOptions.frames["LunaRaidFrames"].hottracker and PlayerClass == "DRUID" then
        for i=1,32 do
            local texture = UnitBuff(frame.unit,i)
            if texture == HotTexture then
                if LunaOptions.frames["LunaRaidFrames"].centerIcon then
                    frame.centericons[3]:Show()
                    frame.centericons[3].texture:SetTexture(texture)
                else
                    frame.centericons[1]:Show()
                    frame.centericons[1].texture:SetTexture(texture)
                end
            elseif texture == RegrTexture then
                if LunaOptions.frames["LunaRaidFrames"].centerIcon then
                    frame.centericons[2]:Show()
                    frame.centericons[2].texture:SetTexture(texture)
                else
                    frame.centericons[2]:Show()
                    frame.centericons[2].texture:SetTexture(texture)
                end
            end
        end
    end

    local buffCount = 1
    local maxBuffs = 3
    for h=1,32 do
        ScanTip:ClearLines()
        ScanTip:SetUnitBuff(frame.unit, h)
        if ScanTipTextLeft1:GetText() then
            local buffname = ScanTipTextLeft1:GetText()
            buffname = string.lower(buffname)
            local a = (string.find(buffname, string.lower(LunaOptions.Raidbuff)) and LunaOptions.Raidbuff ~= "")
            local b = (string.find(buffname, string.lower(LunaOptions.Raidbuff2)) and LunaOptions.Raidbuff2 ~= "")
            local c = (string.find(buffname, string.lower(LunaOptions.Raidbuff3)) and LunaOptions.Raidbuff3 ~= "")
            if a or b or c then
                if LunaOptions.frames["LunaRaidFrames"].texturebuff then
                    texture = UnitBuff(frame.unit,h)
                    if frame.buffs and frame.buffs[buffCount] ~= nil then
                        frame.buffs[buffCount].texture:SetTexture(texture)
                        frame.buffs[buffCount]:Show()
                    end
                else
                    frame.buffs[buffCount].texture:SetTexture(a and 1 or 0, b and 1 or 0, c and 1 or 0)
                    frame.buffs[buffCount]:Show()
                end
                buffCount = buffCount + 1

                if buffCount > maxBuffs then
                	break
                end
            end
        end
    end

    for i = buffCount, maxBuffs do
    	frame.buffs[i]:Hide()
    end
end


function LunaUnitFrames.Raid_Aggro(unit)
	if not LunaOptions.aggro then
		return
	end
	local frame
	for i=1,80 do
		if LunaUnitFrames.frames.members[i].unit and UnitIsUnit(LunaUnitFrames.frames.members[i].unit, unit) then
			frame = LunaUnitFrames.frames.members[i]

			break
		end
	end
	if not frame then
		return
	end
	if banzai:GetUnitAggroByUnitId(unit) then
		frame.aggro:Show()
	else
		frame.aggro:Hide()
	end
end

function LunaUnitFrames.Raid_Res(unitName)
	local unit = roster:GetUnitIDFromName(unitName)
	if not unit then
		return
	end
	local frame
	for i=1, 40 do
		if LunaUnitFrames.frames.members[i].unit == unit then
			frame = LunaUnitFrames.frames.members[i]
		end
	end
	if not frame then
		return
	end
	if HealComm:UnitisResurrecting(unitName) then
		frame.RezIcon:Show()
	else
		frame.RezIcon:Hide()
	end
end

function LunaUnitFrames.Raid_Hot(unit, hot)
	if not LunaOptions.frames["LunaRaidFrames"].hottracker or (GetNumPartyMembers() > 0 and not LunaOptions.AlwaysRaid) or (not LunaOptions.enableRaid and GetNumRaidMembers() > 0) then
		return
	end
	local frame
	if not UnitIsPlayer(unit) then
		for i=41, 80 do
			if LunaUnitFrames.frames.members[i].unit == unit then
				frame = LunaUnitFrames.frames.members[i]
				break
			end
		end
	else
		for i=1, 40 do
			if LunaUnitFrames.frames.members[i].unit == unit then
				frame = LunaUnitFrames.frames.members[i]
				break
			end
		end
	end
	if not frame then
		return
	end
	local start, dur
	if PlayerClass == "PRIEST" and hot == "Renew" then
		start, dur = HealComm:getRenewTime(unit)
	elseif PlayerClass == "DRUID" and hot == "Rejuvenation" then
		start, dur = HealComm:getRejuTime(unit)
	elseif PlayerClass == "DRUID" and hot == "Regrowth" then
		start, dur = HealComm:getRegrTime(unit)
	else
		return
	end
	if not start then
		return
	end
	if LunaOptions.frames["LunaRaidFrames"].centerIcon and hot ~= "Regrowth" then
		CooldownFrame_SetTimer(frame.centericons[3].cd,tonumber(start),tonumber(dur),1,1)
	elseif hot ~= "Regrowth" then
		CooldownFrame_SetTimer(frame.centericons[1].cd,tonumber(start),tonumber(dur),1,1)
	else
		CooldownFrame_SetTimer(frame.centericons[2].cd,tonumber(start),tonumber(dur),1,1)
	end
end



function LunaUnitFrames.Raid_Heal(unitName)
	local frame

	for i = 1,80 do
		_frame = LunaUnitFrames.frames.members[i]
		if (_frame.HealBar and UnitExists(_frame.unit) and UnitName(_frame.unit) == unitName) then
			frame = _frame
			break
		end
	end

	if (frame == nil) then
		return
	end

	AdjustHealBar(frame)
end

function LunaUnitFrames.Raid_Auras_Update()
	-- Updates all raid buffs and debuffs
	for i=1,80 do
		if LunaUnitFrames.frames.members[i].unit then
			LunaUnitFrames:Update_RaidFrame_Auras(LunaUnitFrames.frames.members[i])
		end
	end
end

function LunaUnitFrames.Raid_Pos_Reset()
	for i = 1, 9 do
		LunaOptions.frames["LunaRaidFrames"]["positions"][i].x = 400
		LunaOptions.frames["LunaRaidFrames"]["positions"][i].y = -400
		LunaUnitFrames.frames.headers[i]:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -400)
	end
end
