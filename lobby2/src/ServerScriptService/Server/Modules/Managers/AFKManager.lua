-- // services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- // variables

local Remotes = ReplicatedStorage.Remotes
local AFKRemotes = Remotes.AFK

-- // tables

local PlayersAFK = {}
local afkTime = 300

-- // functions

local function giveRandomRewards(Player: Player)
	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return end

	local Money = UserData:FindFirstChild("Money")
	local Crates = UserData:FindFirstChild("Crates")
	if not Money or not Crates then return end

	local NormalCrate = Crates:FindFirstChild("Normal")
	local SteelCrate = Crates:FindFirstChild("Steel")
	local GoldenCrate = Crates:FindFirstChild("Golden")

	local rewardText = ""

	local roll = math.random(1, 100) -- Gets random value
	if roll <= 60 then -- 60% chance for a random amount of coins
		local amount = math.round(math.random(250, 750)/100)*100 -- rounds to nearest 100
		Money.Value += amount
		rewardText = "+$" .. tostring(amount)
	elseif roll <= 90 then -- 30% chance for a crate (50% chance if its norma or steel)
		if math.random(1, 2) == 1 and NormalCrate then
			NormalCrate.Value += 1
			rewardText = "1x Normal Crate"
		elseif SteelCrate then
			SteelCrate.Value += 1
			rewardText = "1x Steel Crate"
		end
	else -- 10% chance for a golden crate
		if GoldenCrate then
			GoldenCrate.Value += 1
			rewardText = "1x Golden Crate"
		end
	end

	if rewardText ~= "" then
		AFKRemotes.updateRewards:FireClient(Player, rewardText)
	end
end

local function enterAFK(Player : Player)
	if PlayersAFK[Player] then return end
	
	PlayersAFK[Player] = true -- adds players to the afk table
	
	task.spawn(function()
		while PlayersAFK[Player] == true do
			AFKRemotes.sendTimer:FireClient(Player, afkTime)
			task.wait(afkTime)
			if PlayersAFK[Player] then
				giveRandomRewards(Player)
			end
		end
	end)
end

local function leaveAFK(Player : Player)
	if not PlayersAFK[Player] then return end

	PlayersAFK[Player] = nil

	print(Player.Name .. " is no longer AFK.")
end

-- // code

AFKRemotes.BeginAFK.OnServerEvent:Connect(enterAFK)

AFKRemotes.EndAFK.OnServerEvent:Connect(leaveAFK)

return {}