local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DailyRewards = {
	[1] = { StatName = "Money", Amount = 500 },
	[2] = { StatName = "Money", Amount = 1200 },
	[3] = { StatName = "Money", Amount = 2800 },
	[4] = { StatName = "Money", Amount = 6500 },
	[5] = { StatName = "Normal", Amount = 3 },
	[6] = { StatName = "Money", Amount = 10000 },
	[7] = { StatName = "Diamond", Amount = 1 },
}

local function GetCurrentDay()
	if RunService:IsStudio() then
		return math.floor(os.time() / 60)
	else
		return math.floor(os.time() / 86400)
	end
end

local function ClaimDailyReward(player)
	local userData = player:FindFirstChild("UserData")
	if not userData then
		warn(player.Name.." has no UserData folder")
		return false
	end

	local lastClaim = userData:FindFirstChild("LastClaim")
	local streak = userData:FindFirstChild("Streak")
	if not lastClaim or not streak then
		warn(player.Name.." is missing LastClaim or Streak values")
		return false
	end

	local today = GetCurrentDay() -- gets the day today
	local daysSince = today - lastClaim.Value

	if daysSince > 3 then -- if last day claimed is over 3 then return to 0
		streak.Value = 0
	end

	if daysSince < 1 then -- if its less then 1 day then return false
		ReplicatedStorage.Remotes.Notification.SendNotification:FireClient(player, "You already claimed today's reward!", "Error")
		return false
	end

	streak.Value = streak.Value + 1
	lastClaim.Value = today

	local dayIndex = ((streak.Value - 1) % #DailyRewards) + 1
	local reward = DailyRewards[dayIndex]

	for _, Data in ipairs(userData:GetDescendants()) do
		if Data and Data.Name == reward.StatName then
			Data.Value = Data.Value + reward.Amount
		end
	end

	ReplicatedStorage.Remotes.Notification.SendNotification:FireClient(player, string.format("You claimed %d %s for Day %d!", reward.Amount, reward.StatName, dayIndex), "Success")

	if dayIndex == 7 then -- if final day return to 0
		streak.Value = 0
	end

	return true
end

ReplicatedStorage.Remotes.Daily.claimReward.OnServerEvent:Connect(function(player)
	ClaimDailyReward(player)
end)

return {}
