-------------------------------------
--      WoWPro_Dailies_Parser      --
-------------------------------------
	
local L = WoWPro_Locale
WoWPro.Dailies.actiontypes = {
	A = "Interface\\GossipFrame\\AvailableQuestIcon",
	C = "Interface\\Icons\\Ability_DualWield",
	T = "Interface\\GossipFrame\\ActiveQuestIcon",
	K = "Interface\\Icons\\Ability_Creature_Cursed_02",
	R = "Interface\\Icons\\Ability_Tracking",
	H = "Interface\\Icons\\INV_Misc_Rune_01",
	h = "Interface\\AddOns\\WoWPro\\Textures\\resting.tga",
	F = "Interface\\Icons\\Ability_Druid_FlightForm",
	N = "Interface\\Icons\\INV_Misc_Note_01",
	B = "Interface\\Icons\\INV_Misc_Coin_01",
	U = "Interface\\Icons\\INV_Misc_Bag_08",
	l = "Interface\\Icons\\INV_Misc_Bag_08",
	r = "Interface\\Icons\\Ability_Repair"
}
WoWPro.Dailies.actionlabels = {
	A = "Accept",
	C = "Complete",
	T = "Turn in",
	K = "Kill",
	R = "Run to",
	H = "Hearth to",
	h = "Set hearth to",
	F = "Fly to",
	N = "Note:",
	B = "Buy",
	U = "Use",
	l = "Loot",
	r = "Repair/Restock"
}

-- Determine Next Active Step (Dailies Module Specific)--
-- This function is called by the main NextStep function in the core broker --
function WoWPro.Dailies:NextStep(k, skip)
	local GID = WoWProDB.char.currentguide

	-- All non-A and non-N steps are Optional Quests --
	if WoWPro.action[k] ~= "A" and WoWPro.action[k] ~= "N" and WoWPro.QID[k] then 
		
		-- Checking Quest Log --
		if WoWPro.QuestLog[tonumber(WoWPro.QID[k])] then 
			skip = false -- If the optional quest is in the quest log, it's NOT skipped --
		end
		
	end

	return skip
end

-- Quest parsing function --
local function ParseQuests(...)
	WoWPro:dbp("Parsing Guide...")
	local i = 1
	for j=1,select("#", ...) do
		local text = select(j, ...)
		if text ~= "" then
			_, _, WoWPro.action[i], WoWPro.step[i] = text:find("^(%a) ([^|]*)(.*)")
			WoWPro.step[i] = WoWPro.step[i]:trim()
			WoWPro.stepcount = WoWPro.stepcount + 1
			WoWPro.QID[i] = text:match("|QID|([^|]*)|?")
			WoWPro.note[i] = text:match("|N|([^|]*)|?")
			WoWPro.map[i] = text:match("|M|([^|]*)|?")
			if text:find("|S|") then 
				WoWPro.sticky[i] = true; 
				WoWPro.stickycount = WoWPro.stickycount + 1 
			end
			if text:find("|US|") then WoWPro.unsticky[i] = true end
			WoWPro.use[i] = text:match("|U|([^|]*)|?")
			WoWPro.zone[i] = text:match("|Z|([^|]*)|?")
			_, _, WoWPro.lootitem[i], WoWPro.lootqty[i] = text:find("|L|(%d+)%s?(%d*)|")
			WoWPro.questtext[i] = text:match("|QO|([^|]*)|?")

			if (WoWPro.action[i] == "R" or WoWPro.action[i] == "r" or WoWPro.action[i] == "N") and WoWPro.map[i] then
				if text:find("|CC|") then WoWPro.waypcomplete[i] = 1
				elseif text:find("|CS|") then WoWPro.waypcomplete[i] = 2
				else WoWPro.waypcomplete[i] = false end
			end

			if text:find("|NC|") then WoWPro.noncombat[i] = true end
			WoWPro.leadin[i] = text:match("|LEAD|([^|]*)|?")
			WoWPro.target[i] = text:match("|T|([^|]*)|?")
			WoWPro.rep[i] = text:match("|REP|([^|]*)|?")
			WoWPro.prof[i] = text:match("|P|([^|]*)|?")

			for _,tag in pairs(WoWPro.Tags) do 
				if not WoWPro[tag][i] then WoWPro[tag][i] = false end
			end
			
			i = i + 1
		end
	end
end
	
-- Guide Load --
function WoWPro.Dailies:LoadGuide()
	local GID = WoWProDB.char.currentguide
	-- Creating a new entry if this guide does not have one
	-- TODO: Make this apply to any module!
	WoWPro_DailiesDB.guide[GID] = WoWPro_DailiesDB.guide[GID] or {}
	WoWPro_DailiesDB.guide[GID].completion = WoWPro_DailiesDB.guide[GID].completion or {}

	-- Parsing quests --
	local sequence = WoWPro.Guides[GID].sequence
	ParseQuests(string.split("\n", sequence()))
	
	WoWPro:dbp("Guide Parsed. "..WoWPro.stepcount.." steps registered.")
		
	WoWPro.Dailies:PopulateQuestLog() --Calling this will populate our quest log table for use here
	
	-- Checking to see if any steps are already complete --
	for i=1, WoWPro.stepcount do
		local action = WoWPro.action[i]
		local completion = WoWPro_DailiesDB.guide[GID].completion[i]
		local numQIDs = select("#", string.split(";", WoWPro.QID[i]))
		for j=1,numQIDs do
			local QID = select(numQIDs-j+1, string.split(";", WoWPro.QID[i]))
			QID = tonumber(QID)
		
			-- Quest Accepts --
			if not completion and action == "A" then 
				if WoWPro.QuestLog[QID] then WoWPro_DailiesDB.guide[GID].completion[i] = true end
			end
			
			-- Turned in quests --
			if not completion and WoWPro_DailiesDB.completedQIDs and WoWPro_DailiesDB.completedQIDs[QID] then
				WoWPro_DailiesDB.guide[GID].completion[i] = true
			end
			
			-- Quest Completions --
			if not completion and WoWPro.QuestLog[QID] then 
				if action == "C" and WoWPro.QuestLog[QID].complete then
					WoWPro_DailiesDB.guide[GID].completion[i] = true
				end
			end
		end
		
	end
	
	-- Checking zone based completion --
	WoWPro:UpdateGuide()
	WoWPro.Dailies:AutoCompleteZone()
	
	-- Scrollbar Settings --
	WoWPro.Scrollbar:SetMinMaxValues(1, math.max(1, WoWPro.stepcount - WoWPro.ShownRows))
end

-- Row Content Update --
function WoWPro.Dailies:RowUpdate(offset)
	local GID = WoWProDB.char.currentguide
	if InCombatLockdown() 
		or not GID 
		or not WoWPro.Guides[GID]
		then return 
	end
	WoWPro.ActiveStickyCount = 0
	local reload = false
	local lootcheck = true
	local k = offset or WoWPro.ActiveStep
	local itemkb = false
	local targetkb = false
	ClearOverrideBindings(WoWPro.MainFrame)
	WoWPro.Dailies.RowDropdownMenu = {}
	
	for i=1,15 do
		
		-- Skipping any skipped steps, unsticky steps, and optional steps unless it's time for them to display --
		if not WoWProDB.profile.guidescroll then
			k = WoWPro:NextStep(k, i)
		end
		
		--Loading Variables --
		local row = WoWPro.rows[i]
		row.index = k
		row.num = i
		local step = WoWPro.step[k]
		local action = WoWPro.action[k] 
		local note = WoWPro.note[k]
		local QID = WoWPro.QID[k] 
		local coord = WoWPro.map[k] 
		local sticky = WoWPro.sticky[k] 
		local unsticky = WoWPro.unsticky[k] 
		local use = WoWPro.use[k] 
		local zone = WoWPro.zone[k] 
		local lootitem = WoWPro.lootitem[k] 
		local lootqty = WoWPro.lootqty[k] 
		local questtext = WoWPro.questtext[k]
		local target = WoWPro.target[k] 
		if WoWPro.prof[k] then
			local prof, proflvl = string.split(" ", WoWPro.prof[k]) 
		end
		local completion = WoWPro_LevelingDB.guide[GID].completion
		
		-- Unstickying stickies --
		if unsticky and i == WoWPro.ActiveStickyCount+1 then
			for n,row in ipairs(WoWPro.rows) do 
				if step == row.step:GetText() and WoWPro.sticky[row.index] and not completion[row.index] then 
					completion[row.index] = true
					return true --reloading
				end
			end
		end
		
		-- Counting stickies that are currently active (at the top) --
		if sticky and i == WoWPro.ActiveStickyCount+1 and not completion[k] then
			WoWPro.ActiveStickyCount = WoWPro.ActiveStickyCount+1
		end
		
		-- Getting the image and text for the step --
		row.step:SetText(step)
		if step then row.check:Show() else row.check:Hide() end
		if completion[k] then
			row.check:SetChecked(true)
			row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		else
			row.check:SetChecked(false)
		end
		if note then note = strtrim(note) end
		if WoWProDB.profile.showcoords and coord and note then note = note.." ("..coord..")" end
		if WoWProDB.profile.showcoords and coord and not note then note = "("..coord..")" end
		if not ( WoWProDB.profile.showcoords and coord ) and not note then note = "" end
		row.note:SetText(note)
		row.action:SetTexture(WoWPro.Dailies.actiontypes[action])
		if WoWPro.noncombat[k] and WoWPro.action[k] == "C" then
			row.action:SetTexture("Interface\\AddOns\\WoWPro\\Textures\\Config.tga")
		end
		
		-- Checkbox Function --
		row.check:SetScript("OnClick", function(self, button, down)
			row.check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
			if row.check:GetChecked() then
				completion[row.index] = true
				if WoWProDB.profile.checksound then	
					PlaySoundFile(WoWProDB.profile.checksoundfile)
				end
			elseif not row.check:GetChecked() then
				completion[row.index] = false
			end
			WoWPro:MapPoint()
			WoWPro:UpdateGuide()
		end)
		
		-- Right-Click Drop-Down --
		local dropdown = {
		}
		if step then
			table.insert(dropdown, 
				{text = step.." Options", isTitle = true}
			)
			QuestMapUpdateAllQuests()
			QuestPOIUpdateIcons()
			local _, x, y, obj
			if QID and not action == "A" then _, x, y, obj = QuestPOIGetIconInfo(tonumber(QID)) end
			if coord or x then
				table.insert(dropdown, 
					{text = "Map Coordinates", func = function()
						WoWPro:MapPoint(row.num)
					end} 
				)
			end
			if not action == "A" and WoWPro.QuestLog[tonumber(QID)] 
			and WoWPro.QuestLog[tonumber(QID)].index and GetNumPartyMembers() > 0 then
				table.insert(dropdown, 
					{text = "Share Quest", func = function()
						QuestLogPushQuest(WoWPro.QuestLog[tonumber(QID)].index)
					end} 
				)
			end
			if sticky then
				table.insert(dropdown, 
					{text = "Un-Sticky", func = function() 
						WoWPro.sticky[row.index] = false
						WoWPro.UpdateGuide()
						WoWPro.UpdateGuide()
						WoWPro.MapPoint()
					end} 
				)
			else
				table.insert(dropdown, 
					{text = "Make Sticky", func = function() 
						WoWPro.sticky[row.index] = true
						WoWPro.unsticky[row.index] = false
						WoWPro.UpdateGuide()
						WoWPro.UpdateGuide()
						WoWPro.MapPoint()
					end} 
				)
			end
		end
		WoWPro.Dailies.RowDropdownMenu[i] = dropdown
		
		-- Item Button --
		if action == "H" then use = 6948 end
		if ( not use ) and action == "C" and WoWPro.QuestLog[tonumber(QID)] then
			local link, icon, charges = GetQuestLogSpecialItemInfo(WoWPro.QuestLog[tonumber(QID)].index)
			if link then
				local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, Name = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
				use = Id
				WoWPro.use[k] = use
			end
		end
		
		if use and GetItemInfo(use) then
			row.itembutton:Show() 
			row.itemicon:SetTexture(GetItemIcon(use))
			row.itembutton:SetAttribute("type1", "item")
			row.itembutton:SetAttribute("item1", "item:"..use)
			row.cooldown:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
			row.cooldown:SetScript("OnEvent", function() 
					local start, duration, enabled = GetItemCooldown(use)
					if enabled then
						row.cooldown:Show()
						row.cooldown:SetCooldown(start, duration)
					else row.cooldown:Hide() end
				end)
			local start, duration, enabled = GetItemCooldown(use)
			if enabled then
				row.cooldown:Show()
				row.cooldown:SetCooldown(start, duration)
			else row.cooldown:Hide() end
			if not itemkb and row.itembutton:IsVisible() then
				local key1, key2 = GetBindingKey("CLICK WoWPro_FauxItemButton:LeftButton")
				if key1 then
					SetOverrideBinding(WoWPro.MainFrame, false, key1, "CLICK WoWPro_itembutton"..i..":LeftButton")
				end
				if key2 then
					SetOverrideBinding(WoWPro.MainFrame, false, key2, "CLICK WoWPro_itembutton"..i..":LeftButton")
				end
				itemkb = true
			end
		else row.itembutton:Hide() end
		
		-- Target Button --
		if target then
			row.targetbutton:Show() 
			row.targetbutton:SetAttribute("macrotext", "/cleartarget\n/targetexact "..target
				.."\n/run if not GetRaidTargetIndex('target') == 8 and not UnitIsDead('target') then SetRaidTarget('target', 8) end")
			if use then
				row.targetbutton:SetPoint("TOPRIGHT", row.itembutton, "TOPLEFT", -5, 0)
			else
				row.targetbutton:SetPoint("TOPRIGHT", row, "TOPLEFT", -10, -7)
			end 
			if not targetkb and row.targetbutton:IsVisible() then
				local key1, key2 = GetBindingKey("CLICK WoWPro_FauxTargetButton:LeftButton")
				if key1 then
					SetOverrideBinding(WoWPro.MainFrame, false, key1, "CLICK WoWPro_targetbutton"..i..":LeftButton")
				end
				if key2 then
					SetOverrideBinding(WoWPro.MainFrame, false, key2, "CLICK WoWPro_targetbutton"..i..":LeftButton")
				end
				targetkb = true
			end
		else
			row.targetbutton:Hide() 
		end
		
		-- Setting the zone for the coordinates of the step --
		zone = zone or strsplit("-(",WoWPro.Guides[GID].zone)
		row.zone = strtrim(zone)

		-- Checking for loot items in bags --
		local lootqtyi
		if lootcheck and ( lootitem or action == "B" ) then
			if not WoWPro.sticky[index] then lootcheck = false end
			if not lootitem then
				if GetItemCount(step) > 0 and not completion[k] then WoWPro.CompleteStep(k) end
			end
			if tonumber(lootqty) ~= nil then lootqtyi = tonumber(lootqty) else lootqtyi = 1 end
			if GetItemCount(lootitem) >= lootqtyi and not completion[k] then WoWPro.CompleteStep(k) end
		end

		WoWPro.rows[i] = row
		
		k = k + 1
	end
	
	WoWPro.ActiveStickyCount = WoWPro.ActiveStickyCount or 0
	WoWPro.CurrentIndex = WoWPro.rows[1+WoWPro.ActiveStickyCount].index
	WoWPro.Dailies:UpdateQuestTracker()

	return reload
end

-- Left-Click Row Function --
function WoWPro.Dailies:RowLeftClick(i)
	if WoWPro.QID[WoWPro.rows[i].index] and not WoWPro.action[WoWPro.rows[i].index]=="A"
	and WoWPro.QuestLog[tonumber(WoWPro.QID[WoWPro.rows[i].index])] then
		QuestLog_OpenToQuest(WoWPro.QuestLog[tonumber(WoWPro.QID[WoWPro.rows[i].index])].index)
	end
	WoWPro.rows[i]:SetChecked(false)
end

-- Event Response Logic --
function WoWPro.Dailies:EventHandler(self, event, ...)

	-- Receiving the result of the completed quest query --
	if event == "QUEST_QUERY_COMPLETE" then
		WoWPro_DailiesDB.completedQIDs = {}
		GetQuestsCompleted(WoWPro_DailiesDB.completedQIDs)
		collectgarbage("collect")
		WoWPro.UpdateGuide()
	end
		
	-- Noting that a quest is being completed for quest log update events --
	if event == "QUEST_COMPLETE" then
		WoWPro.Dailies.CompletingQuest = true
	end
	
	-- Auto-Completion --
	if event == "CHAT_MSG_SYSTEM" then
		WoWPro.Dailies:AutoCompleteSetHearth(...)
	end	
	if event == "CHAT_MSG_LOOT" then
		WoWPro.Dailies:AutoCompleteLoot(...)
	end	
	if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "MINIMAP_ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
		WoWPro.Dailies:AutoCompleteZone(...)
	end
	if event == "QUEST_LOG_UPDATE" then
		WoWPro.Dailies:PopulateQuestLog(...)
		WoWPro.Dailies:AutoCompleteQuestUpdate(...)
		WoWPro.Dailies:UpdateQuestTracker()
	end
end

-- Populate the Quest Log table for other functions to call on --
function WoWPro.Dailies:PopulateQuestLog()
	-- Not updating if there is no guide loaded ir if the Leveling module is already updating
	if not WoWProDB.char.currentguide or (WoWPro.Leveling and WoWPro.Leveling:IsEnabled()) then 
		return 
	end 
	
	WoWPro.oldQuests = WoWPro.QuestLog or {}
	WoWPro.newQuest, WoWPro.missingQuest = false, false
	
	-- Generating the Quest Log table --
	WoWPro.QuestLog = {} -- Reinitiallizing the Quest Log table
	local i, currentHeader = 1, "None"
	local entries = GetNumQuestLogEntries()
	for i=1,tonumber(entries) do
		local questTitle, level, questTag, suggestedGroup, isHeader, 
			isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(i)
		local leaderBoard
		if isHeader then
			currentHeader = questTitle
		else
			if GetNumQuestLeaderBoards(i) and GetQuestLogLeaderBoard(1, i) then
				leaderBoard = {} 
				for j=1,GetNumQuestLeaderBoards(i) do 
					leaderBoard[j] = GetQuestLogLeaderBoard(j, i)
				end 
			else leaderBoard = nil end
			local link, icon, charges = GetQuestLogSpecialItemInfo(i)
			local use
			if link then
				local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, Name = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
				use = Id
			end
			local coords
			QuestMapUpdateAllQuests()
			QuestPOIUpdateIcons()
			WorldMapFrame_UpdateQuests()
			local x, y = WoWPro:findBlizzCoords(questID)
			if x and y then coords = string.format("%.2f",x)..","..string.format("%.2f",y) end
			WoWPro.QuestLog[questID] = {
				title = questTitle,
				level = level,
				tag = questTag,
				group = suggestedGroup,
				complete = isComplete,
				daily = isDaily,
				leaderBoard = leaderBoard,
				header = currentHeader,
				use = use,
				coords = coords,
				index = i
			}
		end
	end
	if WoWPro.oldQuests == {} then return end

	-- Generating table WoWPro.newQuest --
	for QID, questInfo in pairs(WoWPro.QuestLog) do
		if not WoWPro.oldQuests[QID] then 
			WoWPro.newQuest = QID 
			WoWPro:dbp("New Quest: "..WoWPro.QuestLog[QID].title)
		end
	end
	
	-- Generating table WoWPro.missingQuest --
	for QID, questInfo in pairs(WoWPro.oldQuests) do
		if not WoWPro.QuestLog[QID] then 
			WoWPro.missingQuest = QID 
			WoWPro:dbp("Missing Quest: "..WoWPro.oldQuests[QID].title)
		end
	end
	
end

-- Auto-Complete: Quest Update --
function WoWPro.Dailies:AutoCompleteQuestUpdate()
	local GID = WoWProDB.char.currentguide
	if not GID or not WoWPro.Guides[GID] or not WoWPro.Guides[GID].guidetype=="Dailies" then return end

	if WoWPro_DailiesDB.guide[GID] then
		for i=1,#WoWPro.action do
			local action = WoWPro.action[i]
			local completion = WoWPro_DailiesDB.guide[GID].completion[i]
			local numQIDs = select("#", string.split(";", WoWPro.QID[i]))
			for j=1,numQIDs do
				local QID = tonumber(select(numQIDs-j+1, string.split(";", WoWPro.QID[i])))
			
				-- Quest Turn-Ins --
				if WoWPro.Dailies.CompletingQuest and action == "T" and not completion and WoWPro.missingQuest == QID then
					WoWPro.CompleteStep(i)
					WoWPro.Dailies.CompletingQuest = false
				end
				
				-- Abandoned Quests --
				if not WoWPro.Dailies.CompletingQuest and ( action == "A" or action == "C" ) 
				and completion and WoWPro.missingQuest == QID then
					WoWPro_DailiesDB.guide[GID].completion[i] = nil
					WoWPro:UpdateGuide()
					WoWPro:MapPoint()
				end
				
				-- Quest Accepts --
				if WoWPro.newQuest == QID and action == "A" and not completion then
					WoWPro.CompleteStep(i)
				end
				
				-- Quest Completion --
				if WoWPro.QuestLog[QID] and action == "C" and not completion and WoWPro.QuestLog[QID].complete then
					WoWPro.CompleteStep(i)
				end
				
				-- Partial Completion --
				if WoWPro.QuestLog[QID] and WoWPro.QuestLog[QID].leaderBoard and WoWPro.questtext[i] 
				and not WoWPro_DailiesDB.guide[GID].completion[i] then 
					local numquesttext = select("#", string.split(";", WoWPro.questtext[i]))
					local complete = true
					for l=1,numquesttext do
						local lquesttext = select(numquesttext-l+1, string.split(";", WoWPro.questtext[i]))
						local lcomplete = false
						for _, objective in pairs(WoWPro.QuestLog[QID].leaderBoard) do --Checks each of the quest log objectives
							if lquesttext == objective then --if the objective matches the step's criteria, mark true
								lcomplete = true
							end
						end
						if not lcomplete then complete = false end --if one of the listed objectives isn't complete, then the step is not complete.
					end
					if complete then WoWPro.CompleteStep(i) end --if the step has not been found to be incomplete, run the completion function
				end
			end
		end
	
	end
	
	-- First Map Point --
	if WoWPro.Dailies.FirstMapCall then
		WoWPro:MapPoint()
		WoWPro.Dailies.FirstMapCall = false
	end
	
end

-- Update Item Tracking --
local function GetLootTrackingInfo(lootitem,lootqty,count)
--[[Purpose: Creates a string containing:
	- tracked item's name
	- how many the user has
	- how many the user needs
	- a complete symbol if the ammount the user has is equal to the ammount they need 
]]
	if not GetItemInfo(lootitem) then return "" end
	local track = "" 												--If the function did have a track string, adds a newline
	track = track.." - "..GetItemInfo(lootitem)..": " 	--Adds the item's name to the string
	numinbag = GetItemCount(lootitem)+(count or 0)		--Finds the number in the bag, and adds a count if supplied
	track = track..numinbag										--Adds the number in bag to the string
	track = track.."/"..lootqty								--Adds the total number needed to the string
	if lootqty == numinbag then
		track = track.." (C)"									--If the user has the requisite number of items, adds a complete marker
	end
	return track													--Returns the track string to the calling function
end

-- Auto-Complete: Loot based --
function WoWPro.Dailies:AutoCompleteLoot(msg)
	local lootqtyi
	local _, _, itemid, name = msg:find(L["^You .*Hitem:(%d+).*(%[.+%])"])
	local _, _, _, _, count = msg:find(L["^You .*Hitem:(%d+).*(%[.+%]).*x(%d+)."])
	if count == nil then count = 1 end
	for i = 1,1+WoWPro.ActiveStickyCount do
		local index = WoWPro.rows[i].index
		if tonumber(WoWPro.lootqty[index]) ~= nil then lootqtyi = tonumber(WoWPro.lootqty[index]) else lootqtyi = 1 end
		if WoWProDB.profile.track and WoWPro.lootitem[index] then
			local track = GetLootTrackingInfo(WoWPro.lootitem[index],lootqtyi,count)
			WoWPro.rows[i].track:SetText(strtrim(track))
		end
		if WoWPro.lootitem[index] and WoWPro.lootitem[index] == itemid and GetItemCount(WoWPro.lootitem[index]) + count >= lootqtyi 
		and not WoWPro_DailiesDB.guide[WoWProDB.char.currentguide].completion[index] then
			WoWPro.CompleteStep(index)
		end
	end
	for i = 1,15 do
	end
end
			
-- Auto-Complete: Set hearth --
function WoWPro.Dailies:AutoCompleteSetHearth(...)
	local msg = ...
	local _, _, loc = msg:find(L["(.*) is now your home."])
	if loc then
		WoWPro_DailiesDB.guide.hearth = loc
		for i = 1,15 do
			local index = WoWPro.rows[i].index
			if WoWPro.action[index] == "h" and WoWPro.step[index] == loc 
			and not WoWPro_DailiesDB.guide[WoWProDB.char.currentguide].completion[index] then
				WoWPro.CompleteStep(index)
			end
		end
	end	
end

-- Auto-Complete: Zone based --
function WoWPro.Dailies:AutoCompleteZone()
	WoWPro.ActiveStickyCount = WoWPro.ActiveStickyCount or 0
	local currentindex = WoWPro.rows[1+WoWPro.ActiveStickyCount].index
	local action = WoWPro.action[currentindex]
	local step = WoWPro.step[currentindex]
	local coord = WoWPro.map[currentindex]
	local waypcomplete = WoWPro.waypcomplete[currentindex]
	local zonetext, subzonetext = GetZoneText(), string.trim(GetSubZoneText())
	if action == "F" or action == "H" or (action == "R" and not waypcomplete) then
		if step == zonetext or step == subzonetext 
		and not WoWPro_DailiesDB.guide[WoWProDB.char.currentguide].completion[currentindex] then
			WoWPro.CompleteStep(currentindex)
		end
	end
end

-- Update Quest Tracker --
function WoWPro.Dailies:UpdateQuestTracker()
	local GID = WoWProDB.char.currentguide
	if not GID or not WoWPro.Guides[GID] then return end
	
	for i,row in ipairs(WoWPro.rows) do
		local index = row.index
		local questtext = WoWPro.questtext[index] 
		local action = WoWPro.action[index] 
		if action == "A" then return end
		local lootitem = WoWPro.lootitem[index] 
		local lootqty = WoWPro.lootqty[index] 
					if tonumber(lootqty) ~= nil then lootqty = tonumber(lootqty) else lootqty = 1 end
		local QID = tonumber(WoWPro.QID[index])
		-- Setting up quest tracker --
		row.trackcheck = false
		local track = ""
		if WoWProDB.profile.track and ( action == "C" or questtext or lootitem) then
			if WoWPro.QuestLog[QID] and WoWPro.QuestLog[QID].leaderBoard then
				local j = WoWPro.QuestLog[QID].index
				row.trackcheck = true
				if not questtext and action == "C" then
					if WoWPro.QuestLog[QID].leaderBoard[1] then
						track = "- "..WoWPro.QuestLog[QID].leaderBoard[1]
						if select(3,GetQuestLogLeaderBoard(1, j)) then
							track =  track.." (C)"
						end
					end
					for l=1,#WoWPro.QuestLog[QID].leaderBoard do 
						if l > 1 then
							if WoWPro.QuestLog[QID].leaderBoard[l] then
								track = track.."\n- "..WoWPro.QuestLog[QID].leaderBoard[l]
								if select(3,GetQuestLogLeaderBoard(l, j)) then
									track =  track.." (C)"
								end
							end
						end
					end
				elseif questtext then --Partial completion steps only track pertinent objective.
					local numquesttext = select("#", string.split(";", questtext))
					for l=1,numquesttext do
						local lquesttext = select(numquesttext-l+1, string.split(";", questtext))
						for m=1,GetNumQuestLeaderBoards(j) do 
							if GetQuestLogLeaderBoard(m, j) then
								local _, _, itemName, _, _ = string.find(GetQuestLogLeaderBoard(m, j), "(.*):%s*([%d]+)%s*/%s*([%d]+)");
								if itemName and string.find(lquesttext,itemName) then
									track = "- "..GetQuestLogLeaderBoard(m, j)
									if select(3,GetQuestLogLeaderBoard(m, j)) then
										track =  track.." (C)"
									end
								end
							end
						end
					end
				end
			end
			if lootitem then
				row.trackcheck = true
				if tonumber(lootqty) ~= nil then lootqty = tonumber(lootqty) else lootqty = 1 end
				track = GetLootTrackingInfo(lootitem,lootqty)
			end
		end
		row.track:SetText(track)
	end
	if not InCombatLockdown() then WoWPro:RowSizeSet(); WoWPro:PaddingSet() end
end