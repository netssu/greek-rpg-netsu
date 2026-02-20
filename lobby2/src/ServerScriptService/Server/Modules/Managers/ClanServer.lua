local DatastoreService = game:GetService("DataStoreService")
local ClanStore = DatastoreService:GetDataStore("Clans_v2")

local TextService = game:GetService("TextService")

local ReplicatedStorage = game.ReplicatedStorage
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Notification = Remotes:WaitForChild("Notification")
local ClanRemotes = Remotes:WaitForChild("Clan")

local SendNotification = Notification:WaitForChild("SendNotification")
local CreateClan = ClanRemotes:WaitForChild("createClan")
local JoinClan = ClanRemotes:WaitForChild("joinClan")
local LeaveClan = ClanRemotes:WaitForChild("leaveClan")
local GetClan = ClanRemotes:WaitForChild("getClan")
local GetTop = ClanRemotes:WaitForChild("getTop")

local ServerStorage = game.ServerStorage
local Modules = ServerStorage:WaitForChild("Modules")
local Managers = Modules:WaitForChild("Managers")
local DataManager = require(Managers:WaitForChild("DataManager"))

local function FilterAndCheck(text, player)
	local success, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId)
	end)

	if not success then
		return nil, true
	end

	local filteredText = result:GetNonChatStringForBroadcastAsync()

	-- If Roblox censored it
	if string.find(filteredText, "#") then
		return nil, true
	end

	return filteredText, false
end

local Clans_Template = {
	Clans = {},
	Keys = {},
	Top25 = {}
}

local Handler = {}
local CachedData = nil
local PlayerCooldowns = {} -- Track cooldowns per player

local LastUpdated = os.time()

local COOLDOWN_TIME = 5 -- 5 second cooldown

-- Check if player is on cooldown
local function IsOnCooldown(userId)
	if PlayerCooldowns[userId] then
		local timeLeft = PlayerCooldowns[userId] - tick()
		if timeLeft > 0 then
			return true, timeLeft
		else
			PlayerCooldowns[userId] = nil
		end
	end
	return false, 0
end

-- Set cooldown for player
local function SetCooldown(userId)
	PlayerCooldowns[userId] = tick() + COOLDOWN_TIME
end

local function UpdateTop25()
	local list = {}
	for tag, info in pairs(CachedData.Clans) do
		table.insert(list, {Tag = tag, Wins = info.Stats.Wins or 0})
	end
	table.sort(list, function(a, b) return a.Wins > b.Wins end)
	local trimmed = {}
	for i = 1, math.min(25, #list) do
		table.insert(trimmed, list[i])
	end
	CachedData.Top25 = trimmed
end

function Handler.GetClanData()
	local success, data = pcall(function()
		return ClanStore:GetAsync("Data")
	end)
	if success then
		if data then
			CachedData = data
		--[[else
			CachedData = Clans_Template
			pcall(function()
				ClanStore:SetAsync("Data", CachedData)
			end)--]]
		end
	else
		warn("Error getting clans:", data)
		CachedData = Clans_Template
	end
	return CachedData
end

function Handler.SaveClanData(ClanData)
	UpdateTop25()
	local success, err = pcall(function()
		ClanStore:SetAsync("Data", ClanData)
	end)
	if not success then
		warn("Error saving clans:", err)
	end
	return success
end

function Handler.CreateClan(Plr, ClanName, Key, Icon)
	-- Check cooldown
	
	local filteredClanName, clanNameFiltered = FilterAndCheck(ClanName, Plr)
	if clanNameFiltered then
		SendNotification:FireClient(Plr, "This is filtered", "Error")
		return
	end

	-- Filter Clan Tag
	local filteredKey, keyFiltered = FilterAndCheck(Key, Plr)
	if keyFiltered then
		SendNotification:FireClient(Plr, "This is filtered", "Error")
		return
	end
	
	local onCooldown, timeLeft = IsOnCooldown(Plr.UserId)
	if onCooldown then
		SendNotification:FireClient(Plr, "Please wait " .. math.ceil(timeLeft) .. " seconds before trying again!", "Error")
		return
	end

	local plrdata = DataManager.Stored[Plr.UserId]
	if not plrdata then
		SendNotification:FireClient(Plr, "Player data not loaded!", "Error")
		return
	end

	if plrdata.Data.ClanTag then
		SendNotification:FireClient(Plr, "You are already in a clan!", "Error")
		return
	end

	local data = Handler.GetClanData()

	if data.Clans[Key] then
		SendNotification:FireClient(Plr, "A clan already exists with this tag!", "Error")
		return
	end

	-- Set cooldown
	SetCooldown(Plr.UserId)

	data.Clans[Key] = {
		Owner = Plr.UserId,
		Members = {
			{
				BackUpName = Plr.Name,
				UserId = Plr.UserId,
				Rank = "Owner"
			}
		},
		Tag = Key,
		Icon = Icon,
		ClanName = ClanName,
		Stats = {
			Placed = 0,
			Wins = 0,
			Killed = 0
		}
	}

	plrdata.Data.ClanTag = Key
	if Plr:FindFirstChild("UserData") and Plr.UserData:FindFirstChild("ClanTag") then
		Plr.UserData.ClanTag.Value = Key
	end

	table.insert(data.Keys, Key)

	if Handler.SaveClanData(data) then
		GetClan:FireClient(Plr, CachedData.Clans[Key])
		SendNotification:FireClient(Plr, "Clan created successfully!", "Success")
	else
		SendNotification:FireClient(Plr, "Failed to save clan data!", "Error")
	end
end

function Handler.Init()
	Handler.GetClanData()

	CreateClan.OnServerEvent:Connect(function(Plr, Id, Name, Icon)
		Handler.CreateClan(Plr, Name, Id, Icon)
	end)
	
	ClanRemotes:WaitForChild("kickPlayer").OnServerEvent:Connect(function(Plr, UserId)
		local clantag = Plr.UserData.ClanTag.Value
		
		local CachedData = Handler.GetClanData()
		
		if CachedData.Clans[clantag] then
			if CachedData.Clans[clantag].Owner ~= Plr.UserId then
				SendNotification:FireClient(Plr, "You arent the clan owner!", "Error")
				return
			end
			for num, PlayerInfo in ipairs(CachedData.Clans[clantag].Members) do
				if PlayerInfo.UserId == UserId then
					table.remove(CachedData.Clans[clantag].Members, num)
					break
				end
			end
		end
		
		Handler.SaveClanData(CachedData)
		
		GetClan:FireClient(Plr, CachedData.Clans[clantag])
	end)

	LeaveClan.OnServerEvent:Connect(function(Plr)
		-- Check cooldown
		local onCooldown, timeLeft = IsOnCooldown(Plr.UserId)
		if onCooldown then
			SendNotification:FireClient(Plr, "Please wait " .. math.ceil(timeLeft) .. " seconds before trying again!", "Error")
			return
		end

		local plrdata = DataManager.Stored[Plr.UserId]
		if not plrdata then
			SendNotification:FireClient(Plr, "Player data not loaded!", "Error")
			return
		end

		if not plrdata.Data.ClanTag then
			SendNotification:FireClient(Plr, "You are not in a clan!", "Error")
			return
		end

		-- Set cooldown
		SetCooldown(Plr.UserId)

		local clandata = Handler.GetClanData()

		if not clandata.Clans[plrdata.Data.ClanTag] then
			SendNotification:FireClient(Plr, "Clan data not found!", "Error")
			plrdata.Data.ClanTag = nil
			if Plr:FindFirstChild("UserData") and Plr.UserData:FindFirstChild("ClanTag") then
				Plr.UserData.ClanTag.Value = ""
			end
			return
		end

		if clandata.Clans[plrdata.Data.ClanTag].Owner == Plr.UserId then
			-- Owner is deleting the clan
			clandata.Clans[plrdata.Data.ClanTag] = nil
			plrdata.Data.ClanTag = nil
			if Plr:FindFirstChild("UserData") and Plr.UserData:FindFirstChild("ClanTag") then
				Plr.UserData.ClanTag.Value = ""
			end
			SendNotification:FireClient(Plr, "Deleted your clan!", "Success")
		else
			-- Member is leaving the clan
			local m = clandata.Clans[plrdata.Data.ClanTag].Members
			for i = #m, 1, -1 do
				if m[i].UserId == Plr.UserId then
					table.remove(m, i)
					break
				end
			end
			plrdata.Data.ClanTag = nil
			if Plr:FindFirstChild("UserData") and Plr.UserData:FindFirstChild("ClanTag") then
				Plr.UserData.ClanTag.Value = ""
			end
			SendNotification:FireClient(Plr, "Left the clan!", "Success")
		end

		GetClan:FireClient(Plr, nil)
		Handler.SaveClanData(clandata)
	end)

	JoinClan.OnServerEvent:Connect(function(Plr, Id)
		-- Check cooldown
		local onCooldown, timeLeft = IsOnCooldown(Plr.UserId)
		if onCooldown then
			SendNotification:FireClient(Plr, "Please wait " .. math.ceil(timeLeft) .. " seconds before trying again!", "Error")
			return
		end

		local plrdata = DataManager.Stored[Plr.UserId]
		if not plrdata then
			SendNotification:FireClient(Plr, "Player data not loaded!", "Error")
			return
		end

		-- FIX: Check if player is already in a clan
		if plrdata.Data.ClanTag then
			SendNotification:FireClient(Plr, "You are already in a clan!", "Error")
			return
		end

		local ClanData = Handler.GetClanData()

		if not ClanData.Clans[Id] then
			SendNotification:FireClient(Plr, "Clan not found!", "Error")
			return
		end

		if #ClanData.Clans[Id].Members >= 25 then
			SendNotification:FireClient(Plr, "Clan is full!", "Error")
			return
		end

		-- Set cooldown
		SetCooldown(Plr.UserId)

		-- FIX: Correctly set ClanTag in player data
		plrdata.Data.ClanTag = Id
		if Plr:FindFirstChild("UserData") and Plr.UserData:FindFirstChild("ClanTag") then
			print("set here")
			Plr.UserData.ClanTag.Value = Id
		end

		table.insert(ClanData.Clans[Id].Members, {
			BackUpName = Plr.Name,
			Rank = "Member",
			UserId = Plr.UserId
		})

		if Handler.SaveClanData(ClanData) then
			GetClan:FireClient(Plr, CachedData.Clans[Id])
			SendNotification:FireClient(Plr, "Joined clan!", "Success")
		else
			SendNotification:FireClient(Plr, "Failed to join clan!", "Error")
		end
	end)

	GetClan.OnServerEvent:Connect(function(Plr)
		local plrdata
		local t = 0
		repeat
			plrdata = DataManager.Stored[Plr.UserId]
			t += task.wait()
		until type(plrdata) ~= "boolean" or t >= 5

		--warn(CachedData)
		
		if os.time() - LastUpdated >= 20 then
			LastUpdated = os.time()
			CachedData = Handler.GetClanData()
		end

		if type(plrdata) == "table" and plrdata.Data and plrdata.Data.ClanTag then
			local tag = tostring(plrdata.Data.ClanTag)
			if CachedData.Clans[tag] then
				print(tag)
				local found = false
				
				for _, PlrInfo in ipairs(CachedData.Clans[tag].Members) do
					if PlrInfo.UserId == Plr.UserId then
						found = true
					end
				end
				
				if found then
					GetClan:FireClient(Plr, CachedData.Clans[tag])
				else
					print("None found lol")
					
					plrdata.Data.ClanTag = nil
					Plr.UserData.ClanTag.Value = ""
				end
			else
				if Plr:FindFirstChild("UserData") and Plr.UserData:FindFirstChild("ClanTag") then
					Plr.UserData.ClanTag.Value = ""
				end
				plrdata.Data.ClanTag = nil
				DataManager.Stored[Plr.UserId] = plrdata
			end
		end
	end)

	GetTop.OnServerEvent:Connect(function(Plr)
		GetTop:FireClient(Plr, CachedData.Clans, CachedData.Top25)
	end)

	-- Clean up cooldowns when players leave
	game.Players.PlayerRemoving:Connect(function(Plr)
		PlayerCooldowns[Plr.UserId] = nil
	end)
end

Handler.Init()

return Handler