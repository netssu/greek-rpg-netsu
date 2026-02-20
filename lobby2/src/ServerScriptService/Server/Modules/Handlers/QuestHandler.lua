-- // services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- // variables

local Remotes = ReplicatedStorage.Remotes
local QuestRemotes = Remotes.Quests
local QuestData = require(ReplicatedStorage.Modules.StoredData.QuestsData)

-- // functions

local function getQuest(Player : Player, QuestName : string)
	
	local UserData = Player:FindFirstChild("UserData")
	
	for key, Data in ipairs(UserData.Quests:GetDescendants()) do
		if Data.Name == QuestName then
			return Data
		end
	end
	
	return false
	
end

local function getQuestDataFromConfig(Category, QuestName)
	local CategoryData = QuestData[Category]
	if not CategoryData then return nil end

	for _, Data in ipairs(CategoryData) do
		if Data.Name == QuestName then
			return Data
		end
	end

	return nil
end

local function redeemQuest(Player : Player, Quest : Instance)

	print(Player.Name, "is redeeming", Quest.Name)

	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return end

	local CompletedValue = Quest:FindFirstChild("Completed")
	local Category = Quest.Parent.Parent.Name
	local QuestConfig = getQuestDataFromConfig(Category, Quest.Name)

	if CompletedValue.Value == true then
		Remotes.Notification.SendNotification:FireClient(Player, "Already claimed this quest.", "Error")
		return
	end

	if not QuestConfig then return end

	local EXPValue = UserData:FindFirstChild("EXP")
	if EXPValue then
		EXPValue.Value += QuestConfig.XP
	end

	local rewardText = ""

	for rewardType, amount in pairs(QuestConfig.Rewards) do
		rewardText ..= rewardType .. ": " .. tostring(amount) .. " "

		if rewardType == "Cash" or rewardType == "Money" then
			local MoneyValue = UserData:FindFirstChild("Money")
			if MoneyValue then
				MoneyValue.Value += amount
			end
		end
	end

	CompletedValue.Value = true

	Remotes.Notification.SendNotification:FireClient(Player, "Claimed " .. QuestConfig.XP .. " EXP!", "Success")
	Remotes.Notification.SendNotification:FireClient(Player, "Claimed " .. rewardText, "Success")
end

local function checkProgress(Player: Player, Quest: Instance)
	local ProgressValue = Quest:FindFirstChild("Progress", true)
	if not ProgressValue then
		warn("No progress value found.")
		return false
	end

	local GoalAmount = Quest:FindFirstChild("Target", true)
	if not GoalAmount then
		warn("No goal value found.")
		return false
	end

	if ProgressValue.Value >= GoalAmount.Value then
		print("Completed!")
		redeemQuest(Player, Quest)
		return true
	else
		return false
	end
end

-- // code

QuestRemotes.claimQuest.OnServerEvent:Connect(function(Player : Player, QuestName : string)
	
	local FoundQuest = getQuest(Player, QuestName)
	if FoundQuest then
		
		local isCompleted = checkProgress(Player, FoundQuest)
		
		if isCompleted then
			print("Can claim reward")
		else
			warn("Cannot claim")
		end
		
	else
		warn("Cannot find "..QuestName)
	end
	
end)

return {}