--[[------------------------------------------------------------------------------------------------
	Conquistador - Calculates your Conquest Points cap.
	Copyright © 2011 GameMaster128
	All rights reserved.
--]]------------------------------------------------------------------------------------------------

local addonName, ns = ...

local currencyName = GetCurrencyInfo(CONQUEST_CURRENCY)
local currencyLink = GetCurrencyLink(CONQUEST_CURRENCY)

local function Print(...)
	print("|cFF33FF99Conquistador|r:", ...)
end

local function VerifyDB(self)
	ConquistadorDBPC = ConquistadorDBPC or {}
	self.db = ConquistadorDBPC
	
	if self.db.personalBGRating == nil or self.db.personalArenaRating == nil then
		self.db = {
			personalBGRating = 0,
			personalArenaRating = 0
		}
	end
	
	return self
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

----------------------------------------------------------------------------------------------------

local Conquistador = CreateFrame("Frame")
Conquistador:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		return self[event](self, event, ...)
	end
end)
Conquistador:RegisterEvent("ADDON_LOADED")



function Conquistador:ADDON_LOADED(_, addon)
	if addon ~= addonName then
		return
	end

	VerifyDB(self)

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
	VerifyDB(self)
	
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

----------------------------------------------------------------------------------------------------

SLASH_CONQUISTADOR1 = "/conquistador"
SLASH_CONQUISTADOR2 = "/conquest"
SLASH_CONQUISTADOR3 = "/cq"

function SlashCmdList.CONQUISTADOR(msg, editbox)
	local rating = tonumber(msg)
	
	if msg:lower() == "reset" then
		Conquistador.db = {}
		Conquistador:PLAYER_ENTERING_WORLD()
	elseif not rating or rating < 1 then
		Print("You must specify a valid personal rating.")
	else
		Print(format("A personal rating of |cFF00FF00%d|r will provide you with the following %s cap.\n\n%s |cFF00FF00%d|r\n%s |cFF00FF00%d|r",
		rating, currencyLink, FROM_ARENA, GetConquestPointCap(rating, "ARENA"), FROM_RATEDBG, GetConquestPointCap(rating, "RBG")))
	end
end
