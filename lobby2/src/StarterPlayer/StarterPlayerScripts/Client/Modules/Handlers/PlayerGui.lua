-- services

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")

-- variables

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local Digits = require(game.ReplicatedStorage.Modules.Utility.Digits)
local GuiManager = require(script.Parent.Parent.Managers.GuiManager)

-- ui variables

local MainGui = PlayerGui:WaitForChild("TD")
local LeftGui = MainGui:WaitForChild("Left")

local RequestGui = MainGui:WaitForChild("Request")
local PlayerIcon = RequestGui:WaitForChild("PlayerIcon")
local UsernameText = RequestGui:WaitForChild("Username")
local AcceptButton = RequestGui:WaitForChild("Accept")
local RejectButton = RequestGui:WaitForChild("Reject")

local ReplicatedStorage = game.ReplicatedStorage
local Modules = ReplicatedStorage:WaitForChild("Modules")
local StoredData = Modules:WaitForChild("StoredData")
local TowerData = require(StoredData:WaitForChild("TowerData"))

-- functions

local function getUserData() -- returns player's userdata folder
	return Player:WaitForChild("UserData")
end

local function handleZone() -- unlocks level 10 gate and endless mode if player meets level requirement
	local Level10Gate = workspace:WaitForChild("Level10Gate")
	local UserData = getUserData()

	local Level = UserData:WaitForChild("Level")

	if Level.Value >= 5 then
		PlayerGui.TD.Frames.GameModes.Holder.Pvp.Locked.Visible = false
		PlayerGui.TD.Frames.GameModes.Holder.Pvp.Interactable = true
	end
	if Level.Value >= 10 then
		Level10Gate:Destroy()
		PlayerGui.TD.Frames.GameModes.Holder.Endless.Locked.Visible = false
		PlayerGui.TD.Frames.GameModes.Holder.Endless.Interactable = true
	end

end

local function sendNotification(text : string, type : string) -- displays notification with color based on type
	local Notification = MainGui:WaitForChild("Notifications")
	local Template = Notification:WaitForChild("Template"):Clone()
	local TargetSize = UDim2.new(1, 0, 0.75, 0)
	local StartingSize = UDim2.new(0,0,0,0)

	Template.Text = text

	-- set color based on notification type
	if type == "Error" then
		Template.TextColor3 = Color3.fromRGB(255, 0, 0)
	elseif type == "Normal" then
		Template.TextColor3 = Color3.fromRGB(255, 255, 255)
	elseif type == "Success" then
		Template.TextColor3 = Color3.fromRGB(0, 255, 0)
	end

	Template.Size = StartingSize

	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back)
	local tweenIn = TweenService:Create(Template, tweenInfo, { Size = TargetSize })
	local tweenOut = TweenService:Create(Template, tweenInfo, { Size = StartingSize })

	Template.Parent = Notification
	Template.Visible = true

	tweenIn:Play()

	-- auto hide after 5 seconds
	task.spawn(function()
		task.wait(5)
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			Template:Destroy()
		end)
	end)
end

local function preloadUI() -- preloads all images, textures, and sounds in the ui
	local assets = {}

	for _, descendant in ipairs(MainGui:GetDescendants()) do
		if descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			if descendant.Image and descendant.Image ~= "" then
				table.insert(assets, descendant.Image)
			end
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			if descendant.Texture and descendant.Texture ~= "" then
				table.insert(assets, descendant.Texture)
			end
		elseif descendant:IsA("Sound") then
			if descendant.SoundId and descendant.SoundId ~= "" then
				table.insert(assets, descendant.SoundId)
			end
		end
	end

	if #assets > 0 then
		local success, err = pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
		if not success then
			warn("UI preload failed:", err)
		end
	end
end

local function setupButtonTween(Button) -- adds hover and click animations to buttons
	local Icon = Button:FindFirstChild("Icon")

	local UserData = getUserData()
	local SFXEnabled = UserData:FindFirstChild("Settings"):FindFirstChild("SFXEnabled")

	local rotationOnEnter = 15
	local rotationOnLeave = 0
	local enterScale = 1.05
	local downScale = 0.9
	local duration = 0.5

	-- skip untouchable buttons
	if Button.Name == "Untouchable" or CollectionService:HasTag(Button, "Untouchable") then
		return
	end

	-- create uiscale if it doesn't exist
	local parent = Button
	local uiScale = parent:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = parent
	end

	local function tweenScale(toScale)
		TweenService:Create(uiScale, TweenInfo.new(0.1), { Scale = toScale }):Play()
	end

	local function rotateIcon(degrees)
		if Icon then
			local rotateTween = TweenService:Create(Icon, TweenInfo.new(.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Rotation = degrees
			})
			rotateTween:Play()
		end
	end

	-- hover effect
	Button.MouseEnter:Connect(function()
		if SFXEnabled.Value == true then
			game.SoundService.SFX.UI.Hover:Play()
		end
		rotateIcon(rotationOnEnter)
		tweenScale(enterScale)
	end)

	-- leave effect
	Button.MouseLeave:Connect(function()
		rotateIcon(rotationOnLeave)
		tweenScale(1)
	end)

	-- click down effect
	Button.MouseButton1Down:Connect(function()
		tweenScale(downScale)
	end)

	-- click release effect
	Button.MouseButton1Up:Connect(function()
		tweenScale(enterScale)
	end)
end

local function updateStats() -- updates money display when value changes
	local userData = getUserData()
	local Money : NumberValue = userData:FindFirstChild("Money")
	local MoneyGui = LeftGui:WaitForChild("Container"):WaitForChild("Cash")
	local MoneyAmountText = MoneyGui:WaitForChild("Amount")

	Money:GetPropertyChangedSignal("Value"):Connect(function()
		MoneyAmountText.Text = Digits.AddCommas(Money.Value)
	end)

	MoneyAmountText.Text = Digits.AddCommas(Money.Value)
end

local function setupButtons() -- initializes all button tweens and click handlers
	for _, Button in ipairs(MainGui:GetDescendants()) do
		if Button:IsA("ImageButton") or Button:IsA("TextButton") then

			setupButtonTween(Button)

			Button.Activated:Connect(function()

				-- level locked notifications
				if Button.Name == "Level9" then
					sendNotification("You must be level 10 to unlock.", "Error")
				elseif Button.Name == "Level15" then
					sendNotification("You must be level 15 to unlock.", "Error")
				end

				local UserData = getUserData()
				local SFXEnabled = UserData:FindFirstChild("Settings"):FindFirstChild("SFXEnabled")

				if SFXEnabled.Value == true then
					game.SoundService.SFX.UI.ClickSoundEffect:Play()
				end

				local FrameName = Button:GetAttribute("FrameName")
				if not FrameName then return end

				GuiManager.ToggleUi(FrameName)
			end)

		end
	end
end

local function hideAllCore() -- hides all core ui frames
	for _, Frame in ipairs(MainGui:GetChildren()) do
		if Frame:IsA("Frame") then
			Frame.Visible = false
		end
	end
end

local function showAllCore() -- shows all core ui frames except request and searching
	for _, Frame in ipairs(MainGui:GetChildren()) do
		if Frame:IsA("Frame") and Frame.Name ~= "Request" and Frame.Name ~= "Searching" then
			Frame.Visible = true
		end
	end
end

local activeFrame = nil
local isAnimating = false

local lastPopupTime = 0
local DEBOUNCE_TIME = 0.8

local function closeFrame(Frame: Frame)
	if not Frame or not Frame.Visible then return end
	local Holder = Frame:FindFirstChild("Holder")
	if Holder then
		for _, Button in ipairs(Holder:GetChildren()) do
			if Button:IsA("ImageButton") then
				local uiScale = Button:FindFirstChildOfClass("UIScale")
				if uiScale then
					TweenService:Create(uiScale, TweenInfo.new(0.15), { Scale = 0.001 }):Play()
				end
			end
		end
		task.wait(0.15)
	end
	Frame.Visible = false

	if activeFrame == Frame then
		activeFrame = nil
	end
end

local activeFrame = nil
local currentAnimationId = 0

local function popupFrame(Frame: Frame)
	currentAnimationId += 1
	local thisAnimationId = currentAnimationId

	GuiManager.ToggleUi("")

	if activeFrame and activeFrame ~= Frame then
		activeFrame.Visible = false
	end

	local Holder = Frame:FindFirstChild("Holder")
	if not Holder then return end

	if Frame.Name == "GameModes" then
		task.spawn(function()
			local Callback = game.ReplicatedStorage.Remotes.Matchmaking.GetPlayerCount:InvokeServer()
			if Callback and Frame.Visible then
				local PVPButton = Holder:FindFirstChild("Pvp")
				local SurvivalButton = Holder:FindFirstChild("Survival")
				if PVPButton then PVPButton.PlayCount.Text = Callback.PVP .. " Playing" end
				if SurvivalButton then SurvivalButton.PlayCount.Text = Callback.Survival .. " Playing" end
			end
		end)
	end

	for _, Button in ipairs(Holder:GetChildren()) do
		if Button:IsA("ImageButton") then
			local uiScale = Button:FindFirstChildOfClass("UIScale")
			if not uiScale then
				uiScale = Instance.new("UIScale")
				uiScale.Parent = Button
			end
			uiScale.Scale = 0.001
		end
	end

	Frame.Visible = true
	activeFrame = Frame

	task.spawn(function()
		task.wait(0.05)

		for _, Button in ipairs(Holder:GetChildren()) do
			if thisAnimationId ~= currentAnimationId then return end

			if Button:IsA("ImageButton") then
				local uiScale = Button:FindFirstChildOfClass("UIScale")
				if uiScale then
					TweenService:Create(uiScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
					task.wait(0.05)
				end
			end
		end
	end)
end

local selectedData = {} -- stores player's gamemode selections

local function handlePlayButton()
	local PlayButton = MainGui:WaitForChild("Bottom"):WaitForChild("Frame"):WaitForChild("Play")
	if not PlayButton then return end

	local Frames = MainGui:WaitForChild("Frames")
	if not Frames then return end

	local GamemodeFrame = Frames:WaitForChild("GameModes")
	local SquadFrame = Frames:WaitForChild("Squad")
	local PVPSquadFrame = Frames:WaitForChild("PVPSquad")
	local DifficultyFrame = Frames:WaitForChild("ChoosingDifficulty")
	local MapFrame = Frames:WaitForChild("Maps")

	local CloseButtonGamemode = GamemodeFrame:WaitForChild("Back")
	local CloseButtonSquad = SquadFrame:WaitForChild("Back")
	local CloseButtonPVPSquad = PVPSquadFrame:WaitForChild("Back")
	local CloseButtonDifficulty = DifficultyFrame:WaitForChild("Back")
	local CloseButtonMap = MapFrame:WaitForChild("Close")

	CloseButtonGamemode.Activated:Connect(function()
		currentAnimationId += 1
		GamemodeFrame.Visible = false
		activeFrame = nil
		showAllCore()
	end)

	CloseButtonSquad.Activated:Connect(function()
		SquadFrame.Visible = false
		hideAllCore()
		popupFrame(GamemodeFrame)
	end)

	CloseButtonPVPSquad.Activated:Connect(function()
		PVPSquadFrame.Visible = false
		hideAllCore()
		popupFrame(GamemodeFrame)
	end)

	CloseButtonDifficulty.Activated:Connect(function()
		DifficultyFrame.Visible = false
		hideAllCore()
		if selectedData.Gamemode == "Pvp" then
			popupFrame(PVPSquadFrame)
		else
			popupFrame(SquadFrame)
		end
	end)

	CloseButtonMap.Activated:Connect(function()
		MapFrame.Visible = false
		hideAllCore()
		popupFrame(DifficultyFrame)
	end)

	PlayButton.Activated:Connect(function()
		hideAllCore()
		popupFrame(GamemodeFrame)
	end)

	local ModeHolder = GamemodeFrame:WaitForChild("Holder")
	for _, modeButton in ipairs(ModeHolder:GetChildren()) do
		if modeButton:IsA("ImageButton") then
			modeButton.Activated:Connect(function()
				selectedData.Gamemode = modeButton.Name
				GamemodeFrame.Visible = false
				if selectedData.Gamemode == "Pvp" then
					popupFrame(PVPSquadFrame)
				else
					popupFrame(SquadFrame)
				end
			end)
		end
	end

	local SquadHolder = SquadFrame:WaitForChild("Holder")
	for _, squadButton in ipairs(SquadHolder:GetChildren()) do
		if squadButton:IsA("ImageButton") then
			squadButton.Activated:Connect(function()
				selectedData.Squad = squadButton.Name
				SquadFrame.Visible = false
				popupFrame(DifficultyFrame)
			end)
		end
	end

	local PVPSquadHolder = PVPSquadFrame:WaitForChild("Holder")
	for _, pvpButton in ipairs(PVPSquadHolder:GetChildren()) do
		if pvpButton:IsA("ImageButton") then
			pvpButton.Activated:Connect(function()
				selectedData.Squad = pvpButton.Name
				PVPSquadFrame.Visible = false
				popupFrame(DifficultyFrame)
			end)
		end
	end

	local DifficultyHolder = DifficultyFrame:WaitForChild("Holder")
	for _, diffButton in ipairs(DifficultyHolder:GetChildren()) do
		if diffButton:IsA("ImageButton") then
			diffButton.Activated:Connect(function()
				selectedData.Difficulty = diffButton.Name
				DifficultyFrame.Visible = false
				popupFrame(MapFrame)
			end)
		end
	end

	local MapHolder = MapFrame:WaitForChild("Holder")
	for _, mapButton in ipairs(MapHolder:GetChildren()) do
		if mapButton:IsA("ImageButton") then
			mapButton.Activated:Connect(function()
				selectedData.Map = mapButton.Name
				game.ReplicatedStorage.Remotes.Matchmaking.RequestQueue:FireServer(selectedData)
				MapFrame.Visible = false
				activeFrame = nil
				showAllCore()
			end)
		end
	end
end

local function updateHotbarSlot(Slot, HotBar, TowerData) -- updates single hotbar slot ui
	local SlotNumber = Slot.Name
	local UISlot = HotBar:FindFirstChild(SlotNumber)

	-- clear slot if empty
	if Slot.Value == "" then
		local UnitIcon = UISlot:FindFirstChild("UnitIcon")
		if UnitIcon then
			UnitIcon.Image = ""
			UISlot.Holder.Visible = false
		end
		return
	end

	-- update slot with tower info
	local ImageId = TowerData[Slot.Value] and TowerData[Slot.Value].ImageId
	local UnitIcon : ImageLabel = UISlot:FindFirstChild("UnitIcon")

	UISlot.Holder.Price.Text = `${TowerData[Slot.Value].Price}`
	UISlot.Holder.Visible = true
	UnitIcon.Image = "rbxassetid://"..ImageId
end

local function setupHotbar() -- initializes hotbar slots and level unlocks

	local TowerData = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StoredData"):WaitForChild("TowerData"))
	local UserData = getUserData()
	local Level = UserData:WaitForChild("Level")
	local InventoryFolder = UserData:WaitForChild("Hotbar")
	local HotBar = MainGui:WaitForChild("Bottom"):WaitForChild("Hotbar")

	-- unlock slots based on level
	if Level.Value >= 15 then
		local Level15 = HotBar:WaitForChild("Level15")
		local Level9 = HotBar:WaitForChild("Level9")
		local Slot5 = HotBar:WaitForChild("5")
		local Slot6 = HotBar:WaitForChild("6")
		Level15.Visible = false
		Level9.Visible = false
		Slot5.Visible = true
		Slot6.Visible = true
	elseif Level.Value >= 10 then
		local Level9 = HotBar:WaitForChild("Level9")
		local Slot5 = HotBar:WaitForChild("5")
		Level9.Visible = false
		Slot5.Visible = true
	end

	-- initial slot setup
	for _, Slot in ipairs(InventoryFolder:GetChildren()) do
		updateHotbarSlot(Slot, HotBar, TowerData)
	end

	-- listen for slot changes
	for _, Slot in ipairs(InventoryFolder:GetChildren()) do
		Slot.Changed:Connect(function()
			updateHotbarSlot(Slot, HotBar, TowerData)
		end)
	end

end

local function promptTutorial() -- shows tutorial prompt for new players

	local UserData = getUserData()
	local CompletedTutorial = UserData:FindFirstChild("CompletedTutorial")
	local TutorialGui = MainGui:WaitForChild("Frames"):WaitForChild("Tutorial")
	local YesButton = TutorialGui:WaitForChild("Yes")
	local NoButton = TutorialGui:WaitForChild("No")

	local SelectedData = {
		["Difficulty"] = "Easy",
		["Gamemode"] = "Survival",
		["Map"] = "Tutorial",
		["Squad"] = "Solo"
	}

	-- start tutorial
	YesButton.Activated:Connect(function()
		TutorialGui.Visible = false
		game.ReplicatedStorage.Remotes.Matchmaking.RequestQueue:FireServer(SelectedData)
	end)

	-- skip tutorial
	NoButton.Activated:Connect(function()
		TutorialGui.Visible = false
		game.ReplicatedStorage.Remotes.Game.SkipTutorial:FireServer()
	end)

	if CompletedTutorial.Value == true then return end 

	task.spawn(function()
		--game.ReplicatedStorage.Remotes.Matchmaking.RequestQueue:FireServer(SelectedData)
		TutorialGui.Visible = true
	end)

end

local function handleBottomVisibility() -- hides bottom bar when frames are open
	local Bottom = MainGui:WaitForChild("Bottom")
	local Frames = MainGui:WaitForChild("Frames")

	local function updateBottom()
		local anyVisible = false
		for _, frame in ipairs(Frames:GetChildren()) do
			if frame:IsA("Frame") and frame.Visible then
				anyVisible = true
				break
			end
		end
		Bottom.Frame.Visible = not anyVisible
	end

	-- listen to frame visibility changes
	for _, frame in ipairs(Frames:GetChildren()) do
		if frame:IsA("Frame") and frame.Name ~= "Searching" then
			frame:GetPropertyChangedSignal("Visible"):Connect(updateBottom)
		end
	end

	updateBottom()
end

local function handleInteractiveZones() -- handles touch part interactions in world

	local TouchParts = workspace.TouchParts
	if not TouchParts then return end

	local Level10Gate = workspace:FindFirstChild("Level10Gate")
	if not Level10Gate then print("Gate not found") end

	local cooldowns = {}
	local cooldownTime = 2

	for _, Part in ipairs(TouchParts:GetChildren()) do
		if Part:IsA("UnionOperation") or Part:IsA("BasePart") then
			Part.Touched:Connect(function(Hit)
				local Character = Hit.Parent
				if not Character then return end

				local TouchingPlayer = game.Players:GetPlayerFromCharacter(Character)
				if not TouchingPlayer then return end

				if TouchingPlayer == game.Players.LocalPlayer then
					-- check cooldown
					if cooldowns[Part] and tick() - cooldowns[Part] < cooldownTime then
						return
					end

					cooldowns[Part] = tick()

					-- handle specific touch parts
					if Part.Name == "Play" then
						hideAllCore()
						popupFrame(MainGui:WaitForChild("Frames"):WaitForChild("GameModes"))
						return
					elseif Part.Name == "Endless" then
						hideAllCore()
						popupFrame(MainGui:WaitForChild("Frames"):WaitForChild("Squad"))
						return
					elseif Part.Name == "AFK" then
						PlayerGui.TD.Frames.AFK.Reward.Text = "Nothing yet!"
						game.ReplicatedStorage.Remotes.AFK.BeginAFK:FireServer()
					end

					-- toggle corresponding frame
					if not(PlayerGui.TD.Frames:FindFirstChild(Part.Name).Visible) then
						GuiManager.ToggleUi(Part.Name)
					end
				end
			end)
		end
	end

	-- level 10 gate touch handler
	if Level10Gate then
		Level10Gate.Touched:Connect(function(Hit)
			local Character = Hit.Parent
			if not Character then return end

			local TouchingPlayer = game.Players:GetPlayerFromCharacter(Character)
			if not TouchingPlayer then return end

			if TouchingPlayer == game.Players.LocalPlayer and Level10Gate then
				if cooldowns[Level10Gate] and tick() - cooldowns[Level10Gate] < cooldownTime then
					return
				end

				cooldowns[Level10Gate] = tick()
				sendNotification("You must be level 10 to access Endless Mode", "Error")
			end
		end)
	end

end

local function handleLevels() -- manages level and exp bar ui
	local LevelData = require(game.ReplicatedStorage.Modules.StoredData.LevelData)

	local UserData = getUserData()

	local EXP = UserData:WaitForChild("EXP")
	local Level = UserData:WaitForChild("Level")

	local LevelBarContainer = MainGui:WaitForChild("Bottom"):WaitForChild("ProgressBar")
	local LevelLabel = LevelBarContainer:WaitForChild("Level")
	local LevelBar = LevelBarContainer:WaitForChild("Bar")

	local function updateUI()
		local currentLevel = Level.Value
		local currentXP = EXP.Value
		local maxXP = LevelData[tostring(currentLevel)] and LevelData[tostring(currentLevel)].MaxXP or 100
		LevelLabel.Text = string.format("Level %d [%d/%d]", currentLevel, currentXP, maxXP)
		LevelBar.Size = UDim2.new(math.clamp(currentXP / maxXP, 0, 1), 0, 1, 0)
	end

	local function checkLevelUp()
		local currentLevel = Level.Value
		local currentXP = EXP.Value
		local maxXP = LevelData[tostring(currentLevel)] and LevelData[tostring(currentLevel)].MaxXP
		if not maxXP then return end

		-- process level ups
		while currentXP >= maxXP and currentLevel < 50 do
			currentXP -= maxXP
			currentLevel += 1
			maxXP = LevelData[tostring(currentLevel)] and LevelData[tostring(currentLevel)].MaxXP
		end

		EXP.Value = currentXP
		Level.Value = currentLevel
		updateUI()
	end

	EXP:GetPropertyChangedSignal("Value"):Connect(function()
		checkLevelUp()
	end)

	Level:GetPropertyChangedSignal("Value"):Connect(function()
		updateUI()
	end)

	updateUI()
end

local function handleShop() -- handles shop category scrolling
	local ShopFrame = MainGui:WaitForChild("Frames"):WaitForChild("Shop")
	local CategoryButtons = ShopFrame:WaitForChild("Holder")
	local MoneySection = CategoryButtons:WaitForChild("Money")
	local GamepassSection = CategoryButtons:WaitForChild("Gamepass")
	local TowersSection = CategoryButtons:WaitForChild("Towers")
	local ScrollingFrame = ShopFrame:FindFirstChildOfClass("ScrollingFrame")

	local function scrollTo(positionY)
		local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(ScrollingFrame, tweenInfo, {CanvasPosition = Vector2.new(0, positionY)}):Play()
	end

	MoneySection.Activated:Connect(function()
		scrollTo(600)
	end)

	TowersSection.Activated:Connect(function()
		scrollTo(0)
	end)

	GamepassSection.Activated:Connect(function()
		scrollTo(200)
	end)
end

local function handleSettings() -- manages settings toggle buttons
	local UserData = getUserData()
	local Settings = UserData:WaitForChild("Settings", 60)
	local SettingsFrame = MainGui:WaitForChild("Frames"):WaitForChild("Settings")
	local SettingsScroll = SettingsFrame:WaitForChild("ScrollingFrame")

	for _, ToggleButton in ipairs(SettingsScroll:GetDescendants()) do
		if ToggleButton:IsA("ImageButton") and ToggleButton.Name == "OnOff" then
			local DataName = ToggleButton.Parent.Name
			local TargetData = Settings:FindFirstChild(DataName)
			local MainText = ToggleButton:FindFirstChild("MainText")
			local UIStroke = ToggleButton:FindFirstChild("UIStroke")

			local function setOff()
				ToggleButton.ImageColor3 = Color3.fromRGB(255, 42, 0)
				UIStroke.Color = Color3.fromRGB(107, 16, 0)
				MainText.UIStroke.Color = Color3.fromRGB(107, 16, 0)
				MainText.Text = "Off"

				if DataName == "MusicEnabled" then
					game.SoundService.SFX.BackgroundMusic.Lobby.Volume = 0
				end
			end

			local function setOn()
				ToggleButton.ImageColor3 = Color3.fromRGB(89, 255, 0)
				UIStroke.Color = Color3.fromRGB(0, 103, 15)
				MainText.UIStroke.Color = Color3.fromRGB(0, 103, 15)
				MainText.Text = "On"

				if DataName == "MusicEnabled" then
					game.SoundService.SFX.BackgroundMusic.Lobby.Volume = 0.5
				end
			end

			-- set initial state
			if TargetData.Value == true then
				setOn()
			else
				setOff()
			end

			-- toggle handler
			ToggleButton.Activated:Connect(function()
				if MainText.Text == "On" then
					setOff()
					game.ReplicatedStorage.Remotes.Settings.changeSetting:FireServer(ToggleButton.Parent.Name, false)
				else
					setOn()
					game.ReplicatedStorage.Remotes.Settings.changeSetting:FireServer(ToggleButton.Parent.Name, true)
				end
			end)
		end
	end
end

local function handleDailyRewards() -- manages daily reward streak ui
	local DailyFrame = MainGui:WaitForChild("Frames"):WaitForChild("Daily")
	local StreakText = DailyFrame:WaitForChild("Streak")
	local ClaimButton = DailyFrame:WaitForChild("Claim")

	local Days = {
		[1] = DailyFrame:FindFirstChild("Day1"),
		[2] = DailyFrame:FindFirstChild("Day2"),
		[3] = DailyFrame:FindFirstChild("Day3"),
		[4] = DailyFrame:FindFirstChild("Day4"),
		[5] = DailyFrame:FindFirstChild("Day5"),
		[6] = DailyFrame:FindFirstChild("Day6"),
		[7] = DailyFrame:FindFirstChild("Day7"),
	}

	local function updateStreak()

		local UserData = getUserData()

		local StreakData = UserData:WaitForChild("Streak")
		if not StreakData then return end 

		StreakText.Text = StreakData.Value

		-- update claimed status for each day
		for i = 1, #Days do
			if Days[i] and Days[i]:FindFirstChild("Claimed") then
				if i <= StreakData.Value then
					Days[i].Claimed.Visible = true
				else
					Days[i].Claimed.Visible = false
				end
			end
		end
	end

	ClaimButton.Activated:Connect(function()
		game.ReplicatedStorage.Remotes.Daily.claimReward:FireServer()
		task.spawn(function()
			task.wait(0.5)
			updateStreak()
		end)
	end)

	updateStreak()
end

local function handleBox() -- manages reward crate timer display
	local GoldCrate = workspace:FindFirstChild("Crate")
	local UIPart = GoldCrate:FindFirstChild("UIPart")
	local Billboard = UIPart:FindFirstChild("BillboardGui")
	local TimerLabel = Billboard:FindFirstChild("Timer")
	local UserData = getUserData()
	local RemainingTimer = UserData:FindFirstChild("RemainingTimer")

	local function updateLabel(value)
		if value <= 0 then
			TimerLabel.Text = "CLAIM!"
			return
		end

		-- format time as hh:mm:ss or mm:ss
		local hours = math.floor(value / 3600)
		local minutes = math.floor((value % 3600) / 60)
		local seconds = value % 60

		if hours > 0 then
			TimerLabel.Text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
		else
			TimerLabel.Text = string.format("%02d:%02d", minutes, seconds)
		end
	end

	updateLabel(RemainingTimer.Value)

	RemainingTimer.Changed:Connect(updateLabel)
end

local function handleAFK() -- manages afk mode ui and rewards

	local AFK = MainGui:WaitForChild("Frames"):WaitForChild("AFK")
	local LeaveAFK = AFK:WaitForChild("Close")
	local TimerText = AFK:FindFirstChild("Timer")
	local RewardLabel = AFK:FindFirstChild("Reward")

	local currentCountdownId = 0
	local counting = false
	local remainingTime = 0

	local function formatTime(num)
		num = math.floor(num)
		local hours = math.floor(num / 3600)
		local minutes = math.floor((num % 3600) / 60)
		local seconds = num % 60

		if hours > 0 then
			return string.format("%dh %dm %ds", hours, minutes, seconds)
		elseif minutes > 0 then
			return string.format("%dm %ds", minutes, seconds)
		else
			return string.format("%ds", seconds)
		end
	end

	-- leave afk handler
	LeaveAFK.Activated:Connect(function()
		counting = false
		currentCountdownId += 1
		game.ReplicatedStorage.Remotes.AFK.EndAFK:FireServer()
	end)

	-- receive timer from server
	game.ReplicatedStorage.Remotes.AFK.sendTimer.OnClientEvent:Connect(function(Time: number)
		remainingTime = Time
		counting = true
		currentCountdownId += 1
		local countdownId = currentCountdownId

		task.spawn(function()
			while counting and remainingTime > 0 and countdownId == currentCountdownId do
				if TimerText then
					TimerText.Text = formatTime(remainingTime)
				end
				task.wait(1)
				remainingTime -= 1
			end

			if countdownId == currentCountdownId and TimerText then
				TimerText.Text = "0s"
			end
		end)
	end)

	-- update rewards display
	game.ReplicatedStorage.Remotes.AFK.updateRewards.OnClientEvent:Connect(function(rewardText: string)
		if not RewardLabel then return end

		local currentText = RewardLabel.Text

		if currentText == "Nothing yet!" or currentText == "" then
			RewardLabel.Text = rewardText
			return
		end

		local updated = false
		local rewards = {}

		-- parse existing rewards
		for part in string.gmatch(currentText, "[^,]+") do
			table.insert(rewards, part:match("^%s*(.-)%s*$"))
		end

		-- handle money rewards
		local moneyAmount = rewardText:match("%+%$(%d+)")
		if moneyAmount then
			local newAmount = tonumber(moneyAmount)

			for i, entry in ipairs(rewards) do
				local existingAmount = entry:match("%+%$(%d+)")
				if existingAmount then
					rewards[i] = "+$" .. (tonumber(existingAmount) + newAmount)
					updated = true
					break
				end
			end

			if not updated then
				table.insert(rewards, rewardText)
			end
		else
			-- handle item rewards
			local count, name = rewardText:match("(%d+)x%s+(.*)")
			if count and name then
				for i, entry in ipairs(rewards) do
					local existingCount, existingName = entry:match("(%d+)x%s+(.*)")
					if existingName == name then
						rewards[i] = (tonumber(existingCount) + tonumber(count)) .. "x " .. existingName
						updated = true
						break
					end
				end

				if not updated then
					table.insert(rewards, rewardText)
				end
			else
				table.insert(rewards, rewardText)
			end
		end

		RewardLabel.Text = table.concat(rewards, ", ")
	end)
end

local function getLeaderboardRank() -- handles leaderboard display and scroll buttons

	local Leaderboards = workspace.Leaderboards

	local function getRank(leaderboardName : string)
		local Leaderboard = Leaderboards:FindFirstChild(leaderboardName)
		if not Leaderboard then return end 

		local ScrollingFrame = Leaderboard:FindFirstChild("Screen"):FindFirstChild("SurfaceGui"):FindFirstChild("ScrollingFrame")
		if not ScrollingFrame then return end 

		-- find local player's rank
		for _, Frame in ipairs(ScrollingFrame:GetChildren()) do
			if Frame.Name == game.Players.LocalPlayer.Name then
				return Frame.Rank.Text
			end
		end
	end

	local function handleScrollButtons(Leaderboard : Model)
		local ScrollingFrame = Leaderboard:FindFirstChild("Screen"):FindFirstChild("SurfaceGui"):FindFirstChild("ScrollingFrame")
		if not ScrollingFrame then return end 

		local UpButton = nil
		local DownButton = nil

		-- find scroll buttons
		for _, BasePart in ipairs(Leaderboard:GetDescendants()) do
			if BasePart:IsA("BasePart") then
				if BasePart.Name == "ScrollUp" then
					UpButton = BasePart
				elseif BasePart.Name == "ScrollDown" then
					DownButton = BasePart
				end
			end
		end

		-- setup scroll up
		if UpButton and not UpButton:FindFirstChildOfClass("ClickDetector") then
			local cd = Instance.new("ClickDetector")
			cd.Parent = UpButton
			cd.MouseClick:Connect(function()
				ScrollingFrame.CanvasPosition = Vector2.new(0, math.max(0, ScrollingFrame.CanvasPosition.Y - 1 * ScrollingFrame.Template.AbsoluteSize.Y))
			end)
		end

		-- setup scroll down
		if DownButton and not DownButton:FindFirstChildOfClass("ClickDetector") then
			local cd = Instance.new("ClickDetector")
			cd.Parent = DownButton
			cd.MouseClick:Connect(function()
				ScrollingFrame.CanvasPosition = Vector2.new(0, ScrollingFrame.CanvasPosition.Y + 1 * ScrollingFrame.Template.AbsoluteSize.Y)
			end)
		end

	end

	local function applyLeaderboards()
		for  _, Leaderboard in ipairs(Leaderboards:GetChildren()) do

			local NamePlate = Leaderboard:FindFirstChild("NamePlate")
			if not NamePlate then return end 

			local TextLabel = NamePlate:FindFirstChild("SurfaceGui"):FindFirstChild("TextLabel")
			if not TextLabel then return end

			local RankData = getRank(Leaderboard.Name)
			if not RankData then return end
			handleScrollButtons(Leaderboard)

			TextLabel.Text = "You - #"..RankData
		end
	end

	-- delay to allow leaderboard data to load
	task.spawn(function()
		task.wait(5)
		applyLeaderboards()
	end)
end

-- initialization

task.spawn(handleZone)
task.spawn(getLeaderboardRank)
task.spawn(handleAFK)
task.spawn(handleBox)
task.spawn(handleDailyRewards)
task.spawn(handleSettings)
task.spawn(handleShop)
task.spawn(handleLevels)
--task.spawn(preloadUI)
task.spawn(setupHotbar)
task.spawn(handlePlayButton)
task.spawn(updateStats)
task.spawn(promptTutorial)
task.spawn(handleInteractiveZones)
task.spawn(handleBottomVisibility)

-- events

game.ReplicatedStorage.Remotes.Notification.SendNotification.OnClientEvent:Connect(function(NotificationText : string, Type : string)
	sendNotification(NotificationText, Type)
end)

-- idk why this is here but it hides stuff

local PlayerGui = Player.PlayerGui
local MainUi = PlayerGui:WaitForChild("TD")
local Frames = MainUi:WaitForChild("Frames")
local Squad = Frames:WaitForChild("Squad")

Squad.Holder.Duo.Locked.Visible = true
Squad.Holder.Trio.Locked.Visible = true
Squad.Holder.Squad.Locked.Visible = true
Squad.Holder.Squad.Interactable = false
Squad.Holder.Trio.Interactable = false
Squad.Holder.Duo.Interactable = false

Player:GetAttributeChangedSignal("inParty"):Connect(function()
	local Party = Player:GetAttribute("inParty")
	
	if Party then
		Squad.Holder.Duo.Locked.Visible = false
		Squad.Holder.Trio.Locked.Visible = false
		Squad.Holder.Squad.Locked.Visible = false
		Squad.Holder.Squad.Interactable = true
		Squad.Holder.Trio.Interactable = true
		Squad.Holder.Duo.Interactable = true
	else
		Squad.Holder.Duo.Locked.Visible = true
		Squad.Holder.Trio.Locked.Visible = true
		Squad.Holder.Squad.Locked.Visible = true
		Squad.Holder.Squad.Interactable = false
		Squad.Holder.Trio.Interactable = false
		Squad.Holder.Duo.Interactable = false
	end
end)

return {}