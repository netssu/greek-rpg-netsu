local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ProfileService = require(game.ReplicatedStorage.Modules.Packages.ProfileService)

local LeaderboardUpdateTime = 60
local LeaderboardMax = 100
local BaseStoreName = "GlobalLeaderboard_"

local Leaderboards = workspace:WaitForChild("Leaderboards")
local Digits = require(game.ReplicatedStorage.Modules.Utility.Digits)

local function getPlayerValue(player, dataName)
	local userData = player:FindFirstChild("UserData")

	if userData then
		for _, descendant in ipairs(userData:GetDescendants()) do
			if descendant.Name == dataName and descendant:IsA("ValueBase") then
				return descendant.Value
			end
		end
	end

	local attrValue = player:GetAttribute(dataName)
	if attrValue ~= nil then
		return attrValue
	end

	return 0
end

local function formatPlayTime(seconds)
	if seconds <= 0 then
		return "0m"
	end

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)

	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	else
		return string.format("%dm", minutes)
	end
end

local function clearBoard(scrollingFrame, template)
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") and child ~= template then
			child:Destroy()
		end
	end
end

local function updateLeaderboards()
	for _, Leaderboard in ipairs(Leaderboards:GetChildren()) do
		if not Leaderboard:IsA("Model") then continue end

		local TargetData = Leaderboard:GetAttribute("Data")
		if not TargetData then continue end

		local Screen = Leaderboard:FindFirstChild("Screen")
		local SurfaceGui = Screen and Screen:FindFirstChild("SurfaceGui")
		local ScrollingFrame = SurfaceGui and SurfaceGui:FindFirstChild("ScrollingFrame")
		local Template = ScrollingFrame and ScrollingFrame:FindFirstChild("Template")

		if not (ScrollingFrame and Template) then continue end

		Template.Visible = false

		local dataStore = DataStoreService:GetOrderedDataStore(BaseStoreName .. TargetData)

		for _, player in ipairs(Players:GetPlayers()) do
			local value = getPlayerValue(player, TargetData)
			if value then
				pcall(function()
					local last = dataStore:GetAsync(player.UserId)
					if not last or value > last then
						dataStore:SetAsync(player.UserId, value)
					end
				end)
			end
		end

		local success, pages = pcall(function()
			return dataStore:GetSortedAsync(false, LeaderboardMax)
		end)

		if not success then continue end

		local data = pages:GetCurrentPage()

		clearBoard(ScrollingFrame, Template)

		local entriesToLoad = {}

		for rank, entry in ipairs(data) do
			local userId = entry.key
			local value = entry.value

			local clone = Template:Clone()
			clone.Name = "Entry_" .. rank
			clone.Visible = true
			clone.Parent = ScrollingFrame

			local rankLabel = clone:FindFirstChild("Rank")
			local nameLabel = clone:FindFirstChild("Username")
			local valueLabel = clone:FindFirstChild("WinCount")
			local profileImage = clone:FindFirstChild("Profile")

			if rankLabel then rankLabel.Text = tostring(rank) end
			if nameLabel then nameLabel.Text = "Loading..." end

			if TargetData == "TimePlaying" then
				if valueLabel then valueLabel.Text = formatPlayTime(value) end
			else
				if valueLabel then valueLabel.Text = Digits.Abbreviate(value) end
			end

			if profileImage and profileImage:IsA("ImageLabel") then
				profileImage.Image = ""
			end

			table.insert(entriesToLoad, {
				userId = userId,
				nameLabel = nameLabel,
				profileImage = profileImage
			})
		end

		task.spawn(function()
			for _, entryData in ipairs(entriesToLoad) do
				if not entryData.nameLabel or not entryData.nameLabel.Parent then
					continue
				end

				local name = "Unknown"
				pcall(function()
					name = Players:GetNameFromUserIdAsync(entryData.userId)
				end)

				if entryData.nameLabel and entryData.nameLabel.Parent then
					entryData.nameLabel.Text = "@" .. name
				end

				if entryData.profileImage and entryData.profileImage.Parent and entryData.profileImage:IsA("ImageLabel") then
					pcall(function()
						local thumb, ready = Players:GetUserThumbnailAsync(
							entryData.userId,
							Enum.ThumbnailType.HeadShot,
							Enum.ThumbnailSize.Size100x100
						)
						if ready and entryData.profileImage.Parent then
							entryData.profileImage.Image = thumb
						end
					end)
				end

				task.wait()
			end
		end)
	end
end

task.spawn(function()
	while true do
		updateLeaderboards()
		task.wait(LeaderboardUpdateTime)
	end
end)

return {}