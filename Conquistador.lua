--[[--------------------------------------------------------------------------------------------------------------------
	Conquistador - Calculates your weekly Conquest Points cap.
	Copyright © 2012 Talyrius
	All rights reserved.
--]]--------------------------------------------------------------------------------------------------------------------

local addonName, ns = ...

local currencyName = GetCurrencyInfo(CONQUEST_CURRENCY)
local currencyLink = GetCurrencyLink(CONQUEST_CURRENCY)
local defaultsDBPC = {
	["personalBGRating"] = 0,
	["personalArenaRating"] = 0,
}

local function Print(...)
	print("|cFF33FF99Conquistador|r:", ...)
end

local function copyTable(src, dst)
	if type(src) ~= "table" then
		return {}
	end
	
	if type(dst) ~= "table" then
		dst = {}
	end
	
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = copyTable(v, dst[k])
		elseif type(v) ~= type(dst[k]) then
			dst[k] = v
		end
	end
	
	for k, v in pairs(dst) do
		if type(src[k]) == nil then
			dst[k] = nil
		end
	end
	
	return dst
end

local function GetConquestPointCap(rating, ctype)
	if rating < 1 then
		return 0
	elseif rating < 1500 then
		rating = 1500
	elseif rating > 3000 then
		rating = 3000
	end
	
	return ns.ConquestDB[rating][ctype]
end

local function GetServerOffset()
	local serverHour, serverMinute = GetGameTime()
	local localHour, localMinute = tonumber(date("%H")), tonumber(date("%M"))
	local serverTime = serverHour + serverMinute / 60
	local localTime = localHour + localMinute / 60
	local offset = floor((serverTime - localTime) * 1000 + 0.5) / 1000

	if offset >= 12 then
		offset = offset - 24
	elseif offset < -12 then
		offset = offset + 24
	end
	
	return offset
end

local function GetNextWeeklyResetTime()
	local region = GetCVar("portal"):upper()
	local resetDay = {}
	
	if region == "US" then
		resetDay["2"] = true -- Tuesday
	elseif region == "EU" then
		resetDay["3"] = true -- Wednesday
	elseif region == "CN" or region == "KR" or region == "TW" then
		resetDay["4"] = true -- Thursday
	else
		resetDay["2"] = true -- Tuesday?
	end
	
	local offset = GetServerOffset() * 3600
	local resetTime = GetQuestResetTime()
	local dailyReset = time() + resetTime
	
	while not resetDay[date("%w", dailyReset + offset)] do
		dailyReset = dailyReset + 24 * 3600
	end
	
	return dailyReset
end

------------------------------------------------------------------------------------------------------------------------

local Conquistador = CreateFrame("Frame")
Conquistador:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		return self[event](self, event, ...)
	end
end)
Conquistador:RegisterEvent("ADDON_LOADED")

function Conquistador:ADDON_LOADED(event, addon)
	if addon ~= addonName then
		return
	end
	
	self.db = copyTable(defaultsDBPC, ConquistadorDBPC)
	ConquistadorDBPC = self.db
	
	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil

	if IsLoggedIn() then
		self:PLAYER_LOGIN()
	else
		self:RegisterEvent("PLAYER_LOGIN")
	end
end

function Conquistador:PLAYER_LOGIN()
	local isNil = self.UNIT_LEVEL == nil
	
	if UnitLevel("player") >= SHOW_CONQUEST_LEVEL then
		if not isNil then
			self:UnregisterEvent("UNIT_LEVEL")
			self.UNIT_LEVEL = nil
		end
		
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:PLAYER_ENTERING_WORLD()
		
		self:UnregisterEvent("PLAYER_LOGIN")
		self.PLAYER_LOGIN = nil
		
		PVPFrameConquestBar:HookScript("OnEnter", function()
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Conquistador", 0.2, 1, 0.6)
			GameTooltip:AddLine(format("%s you may earn the next week:", currencyName), 1, 1, 1)
			GameTooltip:AddLine(" ")
			
			if GetConquestPointCap(self.db.personalBGRating, "RBG") > GetConquestPointCap(self.db.personalArenaRating, "ARENA") then
				GameTooltip:AddDoubleLine(FROM_ALL_SOURCES, format("(%d) %d", self.db.personalBGRating, GetConquestPointCap(self.db.personalBGRating, "RBG")), 1, 1, 1, 1, 1, 1)
			else
				GameTooltip:AddDoubleLine(FROM_ALL_SOURCES, format("(%d) %d", self.db.personalArenaRating, GetConquestPointCap(self.db.personalArenaRating, "ARENA")), 1, 1, 1, 1, 1, 1)
			end
			
			GameTooltip:AddDoubleLine(" -"..FROM_RATEDBG, format("(%d) %d", self.db.personalBGRating, GetConquestPointCap(self.db.personalBGRating, "RBG")), 1, 1, 1, 1, 1, 1)
			GameTooltip:AddDoubleLine(" -"..FROM_ARENA, format("(%d) %d", self.db.personalArenaRating, GetConquestPointCap(self.db.personalArenaRating, "ARENA")), 1, 1, 1, 1, 1, 1)
			GameTooltip:AddLine(" ")
			
			local timeFmt
			if GetCVarBool("timeMgrUseMilitaryTime") then
				timeFmt = "%A - %H:%M"
			else
				timeFmt = "%A - %I:%M %p"
			end
			
			GameTooltip:AddDoubleLine("Next Reset", date(timeFmt, GetNextWeeklyResetTime()), nil, nil, nil, 1, 1, 1)
			GameTooltip:AddLine(format("The new week starts in %s.", SecondsToTime(GetNextWeeklyResetTime() - time(), nil, 1)), 1, 1, 1)
			
			GameTooltip:Show()
		end)
		
		for i = 1, 2 do
			_G["PVPFrameConquestBarCap"..i.."Marker"]:HookScript("OnEnter", function(s)
				local isTier1 = s:GetID() == 1
				
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("Conquistador", 0.2, 1, 0.6)

				if isTier1 then
					GameTooltip:AddLine(format("%s Next Week: (%d) %d", currencyName, self.db.personalArenaRating, GetConquestPointCap(self.db.personalArenaRating, "ARENA")))
				else
					GameTooltip:AddLine(format("%s Next Week: (%d) %d", currencyName, self.db.personalBGRating, GetConquestPointCap(self.db.personalBGRating, "RBG")))
				end
				
				GameTooltip:Show()
			end)
		end
	elseif isNil then
		self.UNIT_LEVEL = self.PLAYER_LOGIN
		self:RegisterEvent("UNIT_LEVEL")
	end
end

function Conquistador:PLAYER_ENTERING_WORLD()
	local arenaActive, rbgActive = false, false

	for i = 1, MAX_ARENA_TEAMS do
		local _, _, _, _, _, _, _, playerPlayed, _, _, playerRating = GetArenaTeam(i)
		
		if playerPlayed > 0 then
			arenaActive = true
			
			if playerRating > self.db.personalArenaRating then
				self.db.personalArenaRating = playerRating
			end
		end
	end
	
	local personalBGRating, ratedBGReward, _, _, tier2Quantity = GetPersonalRatedBGInfo()
	
	if tier2Quantity >= ratedBGReward then
		rbgActive = true
		
		if personalBGRating > self.db.personalBGRating then
			self.db.personalBGRating = personalBGRating
		end
	end
	
	if not arenaActive then
		self.db.personalArenaRating = 0
	end
	
	if not rbgActive then
		self.db.personalBGRating = 0
	end
end

------------------------------------------------------------------------------------------------------------------------

SLASH_CONQUISTADOR1 = "/conquistador"
SLASH_CONQUISTADOR2 = "/conquest"
SLASH_CONQUISTADOR3 = "/cq"

function SlashCmdList.CONQUISTADOR(msg, editbox)
	local rating = tonumber(msg)
	
	if msg:lower() == "reset" then
		ConquistadorDBPC = nil
		ConquistadorDBPC = copyTable(defaultsDBPC, ConquistadorDBPC)
		Conquistador:PLAYER_ENTERING_WORLD()
	elseif not rating or rating < 1 then
		Print("You must specify a valid personal rating.")
	else
		Print(format("A personal rating of |cFF00FF00%d|r will provide you with the following %s cap.\n\n%s |cFF00FF00%d|r\n%s |cFF00FF00%d|r",
		rating, currencyLink, FROM_ARENA, GetConquestPointCap(rating, "ARENA"), FROM_RATEDBG, GetConquestPointCap(rating, "RBG")))
	end
end
