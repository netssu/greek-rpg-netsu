local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ServerStorage = game:GetService("ServerStorage")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Matchmaking = Remotes.Matchmaking

local PVP_QUEUE_KEY = "PVPQueue"
local PendingPVP = {}
local LocalQueue = {}

local TELEPORT_IDS = {
	["Tutorial"] = 85841322739304,
	["Frosty Peaks"] = 74693752415649,
	["Jungle"] = 100446623326294,
	["Wild West"] = 130499453325606,
	["Toyland"] = 119232273357893,
}

local PVP_IDS = {
	["Frosty Peaks"] = 135072435156585,
	["Jungle"] = 80721907443358,
	["Wild West"] = 88229996824169,
	["Toyland"] = 137821835172386,
}

local SQUAD_SIZES = {
	["Solo"] = 1,
	["Duos"] = 2,
	["Trios"] = 3,
	["Squads"] = 4,
}

local function queuePVP(player, squadSize, map)
	local queue = MemoryStoreService:GetQueue(PVP_QUEUE_KEY)
	local success, err = pcall(function()
		queue:AddAsync({
			UserId = player.UserId,
			SquadSize = squadSize,
			Map = map
		}, 60)
	end)
	if success then
		PendingPVP[player.UserId] = true
		LocalQueue[player.UserId] = { UserId = player.UserId, SquadSize = squadSize, Map = map }
		print("Queued Player", player.Name)
	else
		warn("Failed to queue:", err)
		Remotes.Notification.SendNotification:FireClient(player, "[!] Failed to join the matchmaking queue. Try again later.", "Error")
	end
end

local function tryMatchPVP(player, squadSize, map, timeout)
	timeout = timeout or 60
	local startTime = tick()
	local queue = MemoryStoreService:GetQueue(PVP_QUEUE_KEY, 0)

	while tick() - startTime < timeout do
		if not PendingPVP[player.UserId] then return nil end -- Player cancelou

		local ok, packed = pcall(function()
			return table.pack(queue:ReadAsync(1, false, 1))
		end)

		if not ok then
			warn("Error accessing queue for", player.Name)
			Matchmaking.ClientSearching:FireClient(player, "Search failed.")
			return nil
		end

		local items = packed[1]
		local readId = packed[2]

		if items and #items > 0 and readId then
			local entry = items[1]
			if entry and entry.UserId and entry.UserId ~= player.UserId and PendingPVP[entry.UserId] then
				local removeOk, removeErr = pcall(function()
					queue:RemoveAsync(readId)
				end)
				if not removeOk then
					warn("Failed to remove queue item:", tostring(removeErr))
				else
					Remotes.Notification.SendNotification:FireClient(player, "[!] Match found!", "Success")
					PendingPVP[entry.UserId] = nil
					print("Matched Player", player.Name, "with", entry.UserId)
					return entry
				end
			end
		end
		task.wait(1)
	end

	Matchmaking.ClientSearching:FireClient(player, "Search failed.")
	Remotes.Notification.SendNotification:FireClient(player, "[!] No opponents found. Matchmaking timed out.", "Error")
	return nil
end

local function UserDataToTable(folder)
	local data = {}
	if not folder then return data end
	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("Folder") then
			data[obj.Name] = UserDataToTable(obj)
		elseif obj:IsA("ValueBase") then
			data[obj.Name] = obj.Value
		end
	end
	return data
end

local function getSquadName(squad)
	if not squad or type(squad) ~= "string" then return "Solo" end
	local s = squad:lower():gsub("%s+", ""):gsub("[%p%d]", "")
	local map = {solo="Solo", solos="Solo", duo="Duos", duos="Duos", trio="Trios", trios="Trios", squad="Squads", squads="Squads"}
	return map[s] or (s:find("duo") and "Duos") or (s:find("trio") and "Trios") or (s:find("squad") and "Squads") or "Solo"
end

local function getPartyInfoFromPlayer(player)
	local inParty = player:GetAttribute("inParty")
	local leaderName = player:GetAttribute("PartyLeader")
	if not inParty or not leaderName then return nil end

	-- Lógica simplificada de party (assumindo estrutura padrão)
	local partyFolder = ServerStorage:FindFirstChild("Parties") and ServerStorage.Parties:FindFirstChild(leaderName)
	if partyFolder and partyFolder:FindFirstChild("Members") then
		local members = {}
		local leader = Players:FindFirstChild(leaderName)
		if leader then table.insert(members, leader) end

		for _, mv in ipairs(partyFolder.Members:GetChildren()) do
			local p = mv.Value
			if p and p ~= leader and p.Parent == Players then
				table.insert(members, p)
			end
		end
		return { leader = leader, members = members }
	end
	return { leader = player, members = {player} }
end

local function safeReserveServer(placeId)
	for _ = 1, 3 do
		local success, code = pcall(function() return TeleportService:ReserveServer(placeId) end)
		if success and code then return code end
		task.wait(1)
	end
	return nil
end

local function teleportPlayers(players, placeId, teleportData)
	local code = safeReserveServer(placeId)
	if not code then
		for _, plr in ipairs(players) do
			Remotes.Notification.SendNotification:FireClient(plr, "[!] Failed to join match. Try again later.", "Error")
		end
		return
	end

	for _, plr in ipairs(players) do
		if plr and plr.Parent == Players then
			Remotes.Game.ShowLoadingScreen:FireClient(plr)
		end
	end

	pcall(function()
		TeleportService:TeleportToPrivateServer(placeId, code, players, nil, teleportData)
	end)
end

local function beginMatchmaking(player: Player, data)
	warn("--------------------------------------------------------")
	if not player or not player.Parent then return end

	local gamemode = data.Gamemode and data.Gamemode:lower() or "survival"
	local squadCanonical = getSquadName(data.Squad)
	local desiredSize = SQUAD_SIZES[squadCanonical] or 1

	if gamemode ~= "pvp" and squadCanonical == "Solo" then
		if player:GetAttribute("inParty") then
			Remotes.Notification.SendNotification:FireClient(player, "[!] Leave your party to play solo.", "Error")
			return
		end

		-- Match Survival Solo direto
		Matchmaking.ClientSearching:FireClient(player, "Found a match!")
		task.wait(math.random(1, 2)) -- Pequeno delay simulado

		-- Verifica se o player não cancelou nesse meio tempo
		local placeId = TELEPORT_IDS[data.Map]
		if placeId then
			local teleportData = {
				Player = player.UserId, Gamemode = gamemode, Difficulty = data.Difficulty,
				Squad = "Solo", Map = data.Map, UserData = UserDataToTable(player:FindFirstChild("UserData"))
			}
			teleportPlayers({player}, placeId, teleportData)
		end
		return
	end

	if gamemode == "pvp" then
		Matchmaking.ClientSearching:FireClient(player, "Searching Opponent...")
		queuePVP(player, desiredSize, data.Map)
		local opponentData = tryMatchPVP(player, desiredSize, data.Map)

		if opponentData then
			local opponentPlayer = Players:GetPlayerByUserId(opponentData.UserId)
			if opponentPlayer then
				local teleportData = {
					Leader = player.UserId, Members = {player.UserId, opponentData.UserId},
					Gamemode = "PVP", Difficulty = data.Difficulty, Squad = "Duos", Map = data.Map,
					UserData = UserDataToTable(player:FindFirstChild("UserData"))
				}
				teleportPlayers({player, opponentPlayer}, PVP_IDS[data.Map], teleportData)
			end
		end
		return
	end

	-- Lógica Squad Survival
	local placeId = TELEPORT_IDS[data.Map]
	local partyInfo = getPartyInfoFromPlayer(player)
	local membersList = (partyInfo and partyInfo.members) or {player}

	if #membersList == desiredSize then
		local teleportData = {
			Leader = player.UserId, Members = {}, Gamemode = data.Gamemode,
			Difficulty = data.Difficulty, Squad = squadCanonical, Map = data.Map,
			UserData = UserDataToTable(player:FindFirstChild("UserData")),
		}
		for i, p in ipairs(membersList) do teleportData.Members[i] = p.UserId end

		for _, plr in ipairs(membersList) do Matchmaking.ClientSearching:FireClient(plr, "Joining Match...") end
		teleportPlayers(membersList, placeId, teleportData)
	else
		Remotes.Notification.SendNotification:FireClient(player, "[!] Party size mismatch.", "Error")
	end
end

Matchmaking.RequestQueue.OnServerEvent:Connect(beginMatchmaking)
Matchmaking.CancelMatchmaking.OnServerEvent:Connect(function(player)
	if PendingPVP[player.UserId] then
		PendingPVP[player.UserId] = nil
		LocalQueue[player.UserId] = nil
	end
	Matchmaking.ClientSearching:FireClient(player, "Cancelled")
end)

Matchmaking.GetPlayerCount.OnServerInvoke = function(Player)
	return { Survival = 0, PVP = 0 } -- Implementar contagem real se necessário
end

return {}