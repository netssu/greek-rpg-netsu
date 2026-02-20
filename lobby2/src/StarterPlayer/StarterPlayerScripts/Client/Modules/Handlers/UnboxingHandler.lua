local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerCamera = workspace.Camera
local PlayerGui = Player.PlayerGui

local TD = PlayerGui:WaitForChild("TD")
local Frames = TD:WaitForChild("Frames")
local AutoOpenFrame = Frames:WaitForChild("Worm_Opening_Frame")
local AutoOpenButton = AutoOpenFrame:WaitForChild("AutoOpen")
local DisableAutoOpenButton = AutoOpenFrame:WaitForChild("TurnOff")

local autoOpenEnabled = false

local RarityColors = {
	["Common"] = {TextColor3 = Color3.fromRGB(255, 255, 255)},
	["Uncommon"] = {TextColor3 = Color3.fromRGB(102, 255, 102)},
	["Rare"] = {TextColor3 = Color3.fromRGB(85, 170, 255)},
	["Epic"] = {TextColor3 = Color3.fromRGB(170, 85, 255)},
	["Legendary"] = {TextColor3 = Color3.fromRGB(255, 215, 0)},
}

local AnimationSettings = {
	-- Box fall
	FallDuration = 0.7,

	-- Box rise and burst
	RiseDuration = 0.5,
	RiseHeight = 6,
	DropDuration = 0.15,
	DropDistance = 1.5,
	BurstScale = 2.8,
	BurstDuration = 0.12,
	ShrinkDuration = 0.1,

	-- Unit reveal
	UnitTargetScale = 1.75,
	UnitScaleDuration = 0.4,

	-- Rotation phase
	RotationSpeed = math.rad(50),
	BobAmplitude = .5,
	BobSpeed = 1.8,
	RotationDuration = 7.5,

	-- Camera
	RevealFOV = 48,
	DefaultFOV = 55,
}

local isRotating = false
local isOpening = false
local skipRotation = false

local function hasCrate(crateName)
	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return false end

	local Inventory = UserData:FindFirstChild("Crates")
	if not Inventory then return false end

	local crate = Inventory:FindFirstChild(crateName)
	if not crate then return false end

	return crate.Value > 0
end

local function autoOpen(SelectedCrate)
	if not autoOpenEnabled then return end

	if not hasCrate(SelectedCrate) then
		autoOpenEnabled = false
		AutoOpenButton.Visible = true
		DisableAutoOpenButton.Visible = false
		return
	end

	game.ReplicatedStorage.Remotes.Game.Unbox:FireServer(SelectedCrate)
end

local function tweenPromise(tween)
	tween:Play()
	tween.Completed:Wait()
end

local WasEnabled = {}

local function hideAllUI()
	for _, f in ipairs(Player.PlayerGui:GetDescendants()) do
		if f:IsA("Frame") and f.Visible == true then
			WasEnabled[f] = true
			f.Visible = false
		end
	end
end

local function showAllUI()
	for Frame, Status in pairs(WasEnabled) do
		if Frame and Frame:IsA("Frame") then
			Frame.Visible = true
		end
	end
end

local function finishUnboxCleanup(cutsceneBox, spawnedUnit, connection)
	if connection and connection.Connected then
		connection:Disconnect()
	end

	if cutsceneBox and cutsceneBox.Parent == workspace then
		pcall(function() cutsceneBox:Destroy() end)
	end

	if spawnedUnit and spawnedUnit.Parent == workspace then
		pcall(function() spawnedUnit:Destroy() end)
	end

	pcall(function()
		PlayerCamera.CameraType = Enum.CameraType.Custom
		PlayerCamera.FieldOfView = 70
		showAllUI()

		local openingGui = PlayerGui:FindFirstChild("TD") and PlayerGui.TD:FindFirstChild("Frames") and PlayerGui.TD.Frames:FindFirstChild("Opening")
		if openingGui then openingGui.Visible = false end

		local tapGui = PlayerGui:FindFirstChild("TD") and PlayerGui.TD:FindFirstChild("Frames") and PlayerGui.TD.Frames:FindFirstChild("Tap to Open")
		if tapGui then tapGui.Visible = false end
	end)

	isOpening = false
	skipRotation = false
end

local function goUpExpand(Box, UnboxedUnit, CrateName: string)
	local Highlight = Box:FindFirstChild("BurstHighlight")
	local startPos = Box.Position
	local cameraY = PlayerCamera.CFrame.Position.Y

	-- Phase 1: Rise up smoothly
	local riseTarget = Vector3.new(startPos.X, cameraY + AnimationSettings.RiseHeight, startPos.Z)

	local riseTween = TweenService:Create(
		Box,
		TweenInfo.new(AnimationSettings.RiseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = riseTarget}
	)

	-- Camera follows with slight zoom
	local zoomTween = TweenService:Create(
		PlayerCamera,
		TweenInfo.new(AnimationSettings.RiseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{FieldOfView = AnimationSettings.RevealFOV}
	)

	riseTween:Play()
	zoomTween:Play()
	riseTween.Completed:Wait()

	-- Phase 2: Quick drop down (wind-up before burst)
	local dropTarget = Vector3.new(riseTarget.X, riseTarget.Y - AnimationSettings.DropDistance, riseTarget.Z)

	local dropTween = TweenService:Create(
		Box,
		TweenInfo.new(AnimationSettings.DropDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = dropTarget - Vector3.new(0, 6, 0)}
	)
	tweenPromise(dropTween)

	if Highlight then
		Highlight.Enabled = true
	end

	local burstTween = TweenService:Create(
		Box,
		TweenInfo.new(AnimationSettings.BurstDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Size = Box.Size * AnimationSettings.BurstScale, Transparency = 0.3}
	)
	burstTween:Play()

	task.delay(AnimationSettings.BurstDuration * 0.7, function()
		local shrinkTween = TweenService:Create(
			Box,
			TweenInfo.new(AnimationSettings.ShrinkDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{Size = Vector3.new(0, 0, 0), Transparency = 1}
		)
		shrinkTween:Play()
		shrinkTween.Completed:Wait()
		if Box then Box:Destroy() end
	end)

	-- Spawn unit in front of camera, facing the camera
	local cameraCF = PlayerCamera.CFrame
	local spawnPos = cameraCF.Position + cameraCF.LookVector * 12 - Vector3.new(0, 1, 0)
	local unitCF = CFrame.lookAt(spawnPos, cameraCF.Position)

	UnboxedUnit.Parent = workspace
	UnboxedUnit:SetPrimaryPartCFrame(unitCF)

	local targetScale = UnboxedUnit.Name == "Airport" and 1.25 or AnimationSettings.UnitTargetScale

	-- Scale in with smooth animation
	UnboxedUnit:ScaleTo(0.01)

	local scaleStart = tick()
	local scaleDuration = AnimationSettings.UnitScaleDuration

	while tick() - scaleStart < scaleDuration do
		local progress = (tick() - scaleStart) / scaleDuration
		-- Back ease out
		local c1 = 1.70158
		local c3 = c1 + 1
		local eased = 1 + c3 * math.pow(progress - 1, 3) + c1 * math.pow(progress - 1, 2)
		UnboxedUnit:ScaleTo(targetScale * math.max(0.01, eased))
		RunService.RenderStepped:Wait()
	end
	UnboxedUnit:ScaleTo(targetScale)

	-- Setup rotation phase
	if not isRotating then
		isRotating = true
		skipRotation = false

		local skipConnection
		skipConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 
				or input.UserInputType == Enum.UserInputType.Touch then
				skipRotation = true
			end
		end)

		task.spawn(function()
			local startTime = tick()

			-- Store the initial camera-facing CFrame
			local baseCF = UnboxedUnit:GetPivot()
			local basePos = baseCF.Position
			local rotation = 0

			while UnboxedUnit and UnboxedUnit.Parent == workspace do
				if skipRotation or (tick() - startTime > AnimationSettings.RotationDuration) then
					break
				end

				local elapsed = tick() - startTime
				rotation += AnimationSettings.RotationSpeed * 0.03

				local bobY = math.sin(elapsed * AnimationSettings.BobSpeed) * AnimationSettings.BobAmplitude

				-- Apply rotation relative to the original camera-facing orientation
				local newCF = CFrame.new(basePos.X, basePos.Y + bobY, basePos.Z) * (baseCF - baseCF.Position) * CFrame.Angles(0, rotation, 0)

				UnboxedUnit:PivotTo(newCF)
				task.wait(0.03)
			end

			if skipConnection then
				skipConnection:Disconnect()
			end

			-- Exit animation
			if UnboxedUnit and UnboxedUnit.Parent == workspace then
				local exitStart = tick()
				local exitDuration = 0.25

				while tick() - exitStart < exitDuration do
					local progress = (tick() - exitStart) / exitDuration
					UnboxedUnit:ScaleTo(targetScale * (1 - progress))
					task.wait()
				end
				UnboxedUnit:Destroy()
			end

			-- Reset camera
			local resetTween = TweenService:Create(
				PlayerCamera,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{FieldOfView = 70}
			)
			resetTween:Play()
			resetTween.Completed:Wait()

			PlayerCamera.CameraType = Enum.CameraType.Custom
			showAllUI()
			autoOpen(CrateName)
			AutoOpenFrame.Visible = false
			PlayerGui.TD.Frames.Opening.Visible = false
			isRotating = false
			isOpening = false
			skipRotation = false
		end)
	end

	-- Show UI
	local OpeningGui = PlayerGui.TD.Frames.Opening
	local TowerName = OpeningGui:WaitForChild("TowerName")
	local RarityText = OpeningGui:WaitForChild("Rarity")

	local rarity = UnboxedUnit:GetAttribute("Rarity") or "Common"
	local colorData = RarityColors[rarity] or RarityColors["Common"]

	TowerName.Text = UnboxedUnit.Name
	RarityText.Text = rarity
	RarityText.TextColor3 = colorData.TextColor3

	local stroke = RarityText:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = Color3.fromRGB(0, 0, 0) end

	TowerName.TextTransparency = 1
	RarityText.TextTransparency = 1
	OpeningGui.Visible = true

	TweenService:Create(TowerName, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
	task.delay(0.08, function()
		TweenService:Create(RarityText, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
	end)
end

local function hitTween(Box)
	local originalCFrame = Box.CFrame

	for i = 1, 4 do
		local intensity = 0.8 + (i * 0.1)
		local offset = Vector3.new(
			(math.random() - 0.5) * 0.6 * intensity,
			(math.random() - 0.5) * 0.3 * intensity,
			(math.random() - 0.5) * 0.6 * intensity
		)
		local angles = CFrame.Angles(
			math.rad((math.random() - 0.5) * 16 * intensity),
			math.rad((math.random() - 0.5) * 16 * intensity),
			math.rad((math.random() - 0.5) * 16 * intensity)
		)

		local shakeTween = TweenService:Create(
			Box,
			TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CFrame = originalCFrame * CFrame.new(offset) * angles}
		)
		shakeTween:Play()
		shakeTween.Completed:Wait()
	end

	local returnTween = TweenService:Create(
		Box,
		TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{CFrame = originalCFrame}
	)
	returnTween:Play()
	returnTween.Completed:Wait()
end

local function Unbox(UnitName: string, CrateName: string)
	if isOpening then return end

	isOpening = true
	skipRotation = false

	local connection
	local CutsceneBox
	local UnboxedUnitClone

	local success, err = pcall(function()
		hideAllUI()

		local BoxesFolder = workspace:WaitForChild("Crates")
		local UnboxedUnit = game.ReplicatedStorage.Storage.Towers:FindFirstChild(UnitName)
		if not UnboxedUnit then error("Unit not found") end

		UnboxedUnitClone = UnboxedUnit:Clone()

		local UnboxCamera = workspace:WaitForChild("UnboxCam")
		if not UnboxCamera then error("UnboxCam missing") end

		PlayerCamera.CameraType = Enum.CameraType.Scriptable
		PlayerCamera.CFrame = UnboxCamera.CFrame
		PlayerCamera.FieldOfView = AnimationSettings.DefaultFOV

		print(CrateName)

		local SelectedCrate = BoxesFolder:FindFirstChild(CrateName)
		if not SelectedCrate then error("Crate missing") end

		CutsceneBox = SelectedCrate:Clone()
		CutsceneBox.Parent = workspace
		CutsceneBox.Name = "CutsceneBox_" .. CrateName
		CutsceneBox.Transparency = 0

		local TargetPosition = SelectedCrate:GetPivot().Position
		local HiddenPosition = TargetPosition + Vector3.new(0, 14, 0)

		CutsceneBox:PivotTo(CFrame.new(HiddenPosition))

		local FallTween = TweenService:Create(
			CutsceneBox,
			TweenInfo.new(AnimationSettings.FallDuration, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
			{CFrame = CFrame.new(TargetPosition)}
		)
		FallTween:Play()

		local clicks = 0
		local canClick = true

		FallTween.Completed:Connect(function()
			local skipUnboxing = Player:FindFirstChild("UserData")
				and Player.UserData:FindFirstChild("Settings")
				and Player.UserData.Settings:FindFirstChild("SkipUnboxing")
				and Player.UserData.Settings.SkipUnboxing.Value == true

			if skipUnboxing then
				goUpExpand(CutsceneBox, UnboxedUnitClone, CrateName)
				return
			end

			PlayerGui.TD.Frames:WaitForChild("Tap to Open").Visible = true

			connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed or not canClick or not isOpening then return end

				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					canClick = false
					task.delay(0.1, function() canClick = true end)

					clicks += 1

					task.spawn(function()
						hitTween(CutsceneBox)
					end)

					task.spawn(function()
						local pulse = AnimationSettings.DefaultFOV - (2 + clicks)
						local zoomIn = TweenService:Create(PlayerCamera, TweenInfo.new(0.06), {FieldOfView = pulse})
						local zoomOut = TweenService:Create(PlayerCamera, TweenInfo.new(0.06), {FieldOfView = AnimationSettings.DefaultFOV})
						zoomIn:Play()
						zoomIn.Completed:Wait()
						zoomOut:Play()
					end)

					if clicks >= 5 then
						PlayerGui.TD.Frames:WaitForChild("Tap to Open").Visible = false
						if connection then connection:Disconnect() end
						goUpExpand(CutsceneBox, UnboxedUnitClone, CrateName)
					end
				end
			end)
		end)
	end)

	if not success then
		warn("Unbox failed:", err)
		finishUnboxCleanup(CutsceneBox, UnboxedUnitClone, connection)
	end
end

AutoOpenButton.Activated:Connect(function()
	if autoOpenEnabled then return end
	autoOpenEnabled = true
	game.ReplicatedStorage.Remotes.Settings.changeSetting:FireServer("SkipUnboxing", true)
	AutoOpenButton.Visible = false
	DisableAutoOpenButton.Visible = true
end)

DisableAutoOpenButton.Activated:Connect(function()
	autoOpenEnabled = false
	game.ReplicatedStorage.Remotes.Settings.changeSetting:FireServer("SkipUnboxing", false)
	AutoOpenButton.Visible = true
	DisableAutoOpenButton.Visible = false
end)

game.ReplicatedStorage.Remotes.Game.DisplayUnbox.OnClientEvent:Connect(function(UnitName: string, CrateName: string)
	Unbox(UnitName, CrateName)
	AutoOpenFrame.Visible = true
end)

return {}