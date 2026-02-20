local Handler = {}

--services
local Players = game.Players
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game.ReplicatedStorage

--player references
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

--ui references
local MainGui = PlayerGui:WaitForChild("TD")


--state
local SelectedCategory = "Daily"

--data references
local UserData = Player:WaitForChild("UserData")
local QuestsFolder = UserData:WaitForChild("Quests", 5)

--ui elements
local Frames = MainGui:WaitForChild("Frames")
local QuestsFrame = Frames:WaitForChild("Quests")
local ButtonHolder = QuestsFrame:WaitForChild("Holder")

--category buttons
local DailyButton = ButtonHolder:WaitForChild("Daily")
local WeeklyButton = ButtonHolder:WaitForChild("Weekly")
local MonthlyButton = ButtonHolder:WaitForChild("Monthly")

--quest list
local ScrollingFrame = QuestsFrame:WaitForChild("ScrollingFrame")
local Template = script:WaitForChild("Template")

--clears all quest entries from the list
local function clearList()
	for _, child in ipairs(ScrollingFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= Template then
			child:Destroy()
		end
	end
end

--creates a quest entry in the list
local function addQuestEntry(questFolder)

	--clone template
	local newEntry = Template:Clone()
	newEntry.Visible = true
	newEntry.Parent = ScrollingFrame

	--get ui elements
	local categoryLabel = newEntry:FindFirstChild("Status")
	local nameLabel = newEntry:FindFirstChild("Title")
	local descLabel = newEntry:FindFirstChild("Desc")
	local progressBar = newEntry:FindFirstChild("ProgressBar")
	local progressLabel = progressBar and progressBar:FindFirstChild("Level")
	local progressBarFill = progressBar and progressBar:FindFirstChild("Bar")
	local ClaimButton = newEntry:FindFirstChild("Claim")

	--get quest data
	local questName = questFolder.Name
	local progressValue = questFolder:FindFirstChild("Progress")
	local targetValue = questFolder:FindFirstChild("Target")
	local completedValue = questFolder:FindFirstChild("Completed")
	local descriptionValue = questFolder:FindFirstChild("Description")

	--tag button for interaction system
	ClaimButton:AddTag("Button")

	--gets the category name by traversing up the folder hierarchy
	local function getCategoryName(folder)
		while folder.Parent do
			if folder.Parent.Name == "Quests" then
				return folder.Name
			end
			folder = folder.Parent
		end
		return "Unknown"
	end

	local categoryName = getCategoryName(questFolder)

	--set category label and color
	if categoryLabel then
		categoryLabel.Text = categoryName .. " Quest"

		if categoryName == "Daily" then
			categoryLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
		elseif categoryName == "Weekly" then
			categoryLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
		elseif categoryName == "Monthly" then
			categoryLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
		else
			categoryLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end

	--set quest name and description
	if nameLabel then
		nameLabel.Text = questName
	end

	if descLabel then
		descLabel.Text = descriptionValue and descriptionValue.Value or ""
	end

	--updates the progress bar and labels
	local function updateProgress()
		if not progressLabel or not progressBarFill then return end

		local progress = 0
		local target = 1

		--get current progress values
		if progressValue and targetValue then
			progress = progressValue.Value
			target = math.max(targetValue.Value, 1)
		end

		--update claim button if quest is complete but not claimed
		if progressValue.Value >= targetValue.Value then
			if not ClaimButton then return end

			ClaimButton.ImageColor3 = Color3.fromRGB(0, 255, 127)
			ClaimButton.UIStroke.Color = Color3.fromRGB(0, 115, 56)
			ClaimButton.MainText.UIStroke.Color = Color3.fromRGB(0, 115, 56)
		end

		local percent = math.clamp(progress / target, 0, 1)

		--update labels based on completion state
		if completedValue and completedValue.Value then
			ClaimButton.MainText.Text = "Claimed!"
			progressLabel.Text = "Completed!"
			progressLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			progressLabel.Text = string.format("%s / %s", progress, target)
			progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end

		--animate progress bar
		local goalSize = UDim2.new(percent, 0, 1, 0)

		TweenService:Create(
			progressBarFill,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = goalSize }
		):Play()
	end

	--connect progress listeners
	if progressValue then
		progressValue:GetPropertyChangedSignal("Value"):Connect(updateProgress)
	end

	if completedValue then
		completedValue:GetPropertyChangedSignal("Value"):Connect(updateProgress)
	end

	--initial update
	updateProgress()

	--claim button handler
	ClaimButton.Activated:Connect(function()
		ReplicatedStorage.Remotes.Quests.claimQuest:FireServer(questName)
	end)
end

--recursively gathers all quest folders from a parent folder
local function gatherAllQuestFolders(parent)
	local quests = {}

	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Folder") and child:FindFirstChild("Progress") then
			table.insert(quests, child)
		else
			for _, subQuest in ipairs(gatherAllQuestFolders(child)) do
				table.insert(quests, subQuest)
			end
		end
	end

	return quests
end

--refreshes the quest list for the current category
local function refreshQuests()
	clearList()

	local categoryFolder = QuestsFolder:FindFirstChild(SelectedCategory)
	if not categoryFolder then return end

	local activeFolder = categoryFolder:FindFirstChild("Active")
	if not activeFolder then return end

	local quests = gatherAllQuestFolders(activeFolder)

	for _, questFolder in ipairs(quests) do
		addQuestEntry(questFolder)
	end
end

--connects folder listeners for automatic refresh
local function connectFolder(folder)
	folder.ChildAdded:Connect(function()
		task.wait(0.1)
		refreshQuests()
	end)

	folder.ChildRemoved:Connect(refreshQuests)

	for _, sub in ipairs(folder:GetChildren()) do
		if sub:IsA("Folder") then
			connectFolder(sub)
		end
	end
end

--connect all quest folders
connectFolder(QuestsFolder)

--switches to a different quest category
local function switchCategory(category)
	if SelectedCategory == category then return end

	SelectedCategory = category
	refreshQuests()
end

--category button handlers
DailyButton.Activated:Connect(function()
	switchCategory("Daily")
end)

WeeklyButton.Activated:Connect(function()
	switchCategory("Weekly")
end)

MonthlyButton.Activated:Connect(function()
	switchCategory("Monthly")
end)

--refresh when frame becomes visible
QuestsFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if QuestsFrame.Visible then
		refreshQuests()
	end
end)

--initial load
refreshQuests()

return Handler