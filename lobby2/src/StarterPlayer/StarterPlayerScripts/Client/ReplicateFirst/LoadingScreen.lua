-- // services

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local ContentProvider = game:GetService("ContentProvider") -- added for preloading
local RunService = game:GetService("RunService")

-- // variables

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 5)
if not PlayerGui then return end

local LoadingScreen = PlayerGui:WaitForChild("Loading", 5)
if not LoadingScreen then
	warn("Loading GUI not found!")
	return
end

local MainGui = PlayerGui:WaitForChild("TD")

local Remotes = ReplicatedStorage.Remotes

local public = {}
local isAnimating = false

-- // preload UI assets

local function preloadLoadingUI()
	local imagesToPreload = {}

	local Holder = LoadingScreen:WaitForChild("Holder")
	for _, child in ipairs(Holder:GetChildren()) do
		if child:IsA("ImageLabel") and child.Image ~= "" then
			table.insert(imagesToPreload, child)
		end
	end

	if #imagesToPreload > 0 then
		ContentProvider:PreloadAsync(imagesToPreload)
	end
end

-- // functions

local function disableLoadingScreen()
	MainGui.Enabled = true
	LoadingScreen.Enabled = false
	isAnimating = false
end

local function enableLoadingScreen()
	local Holder = LoadingScreen:WaitForChild("Holder")
	if not Holder then return end

	MainGui.Enabled = false
	LoadingScreen.Enabled = true

	if isAnimating then return end
	isAnimating = true

	local jumpScale = 1.5
	local duration = 0.2
	local delayBetween = 0.05

	local images = {}
	for _, image in ipairs(Holder:GetChildren()) do
		if image:IsA("ImageLabel") then
			local uiScale = image:FindFirstChildOfClass("UIScale")
			if not uiScale then
				uiScale = Instance.new("UIScale")
				uiScale.Scale = 1
				uiScale.Parent = image
			end
			table.insert(images, uiScale)
		end
	end

	task.spawn(function()
		while LoadingScreen.Enabled do
			for _, uiScale in ipairs(images) do
				if not LoadingScreen.Enabled then break end

				local tweenUp = TweenService:Create(uiScale, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Scale = jumpScale
				})
				local tweenDown = TweenService:Create(uiScale, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
					Scale = 1
				})

				tweenUp:Play()
				tweenUp.Completed:Wait()
				tweenDown:Play()
				tweenDown.Completed:Wait()

				task.wait(delayBetween)
			end
		end
	end)
end

local function init()
	if RunService:IsStudio() then return end
	preloadLoadingUI()
	enableLoadingScreen()
end

function public.Hide()
	disableLoadingScreen()
end

-- // code

if game.Players.LocalPlayer then
	init()
end

Remotes.Game.HideLoadingScreen.OnClientEvent:Connect(disableLoadingScreen)
Remotes.Game.ShowLoadingScreen.OnClientEvent:Connect(init)

TeleportService:SetTeleportGui(LoadingScreen)

return public
