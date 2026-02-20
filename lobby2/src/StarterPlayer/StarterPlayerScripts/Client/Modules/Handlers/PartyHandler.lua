local Handler = {}
local Cooldowns = {}

-- Services 

local TweenService = game:GetService("TweenService")

-- Basic variables for needs such as ui

local Players = game.Players
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui 
local MainUi = PlayerGui:WaitForChild("TD")
local Frames = MainUi:WaitForChild("Frames")
local PartyUi = Frames:WaitForChild("Party")
local RequestUi = MainUi:WaitForChild("Request")
local AcceptRequest = RequestUi:WaitForChild("Accept")
local RejectRequest = RequestUi:WaitForChild("Reject")
local PlayerList = PartyUi:WaitForChild("PlayerList")
local YourList = PartyUi:WaitForChild("YourList")
local PlayerListTemplate = PlayerList:WaitForChild("Template")
local YourListTemplate = YourList:WaitForChild("Template")
local PartyText = PartyUi:WaitForChild("PartyText")

-- Remotes / replicatedstorage

local ReplicatedStorage = game.ReplicatedStorage
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PartyRemotes = Remotes:WaitForChild("Party")
local AskToJoin = PartyRemotes:WaitForChild("AskToJoin")
local Accept = PartyRemotes:WaitForChild("Accept")
local Reject = PartyRemotes:WaitForChild("Reject")
local Prompt = PartyRemotes:WaitForChild("Prompt")
local UpdateClient = PartyRemotes:WaitForChild("UpdateClient")

-- Other Variables

local PartyConnections = {}
local CurrentSender = nil

-- Tween Infos

local TimerInfo = TweenInfo.new(10,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut)

-- Basic functions for repeated logic (shortens the code)

local function PurgeList(Frame)
	for _, child in ipairs(Frame:GetChildren()) do
		if child:IsA("ImageButton") and child.Name ~= "Template" then
			child:Destroy()
		end
	end
end

local function ClearRequest()
	RequestUi.Visible = false
	CurrentSender = nil
end

local function UpdatePartyList()
	PurgeList(PlayerList)
	
	for _, SelectedPlayer in ipairs(Players:GetPlayers()) do
		if SelectedPlayer == Player then continue end -- If its the local plr then continue to next
		
		-- Create new frame per a player
		
		local NewListFrame = PlayerListTemplate:Clone()
		NewListFrame.Parent = PlayerList
		NewListFrame.Visible = true
		NewListFrame.Name = SelectedPlayer.Name
		NewListFrame.PlayerName.Text = SelectedPlayer.DisplayName
		
		-- Sets player icon
		
		NewListFrame.PlayerIcon.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..SelectedPlayer.UserId.."&width=420&height=420&format=png"
		
		NewListFrame.Activated:Connect(function()
			if not(Cooldowns[Player]) then
				Cooldowns[Player] = true
				AskToJoin:FireServer(SelectedPlayer)
				task.wait(2)
				Cooldowns[Player] = false
			end
		end)	
	end
end

-- Main Logic

RejectRequest.Activated:Connect(function() -- Handles rejections for party invites
	Reject:FireServer(CurrentSender)
	ClearRequest()
end)

AcceptRequest.Activated:Connect(function() -- Handles accepting for party invites
	Accept:FireServer(CurrentSender)
	ClearRequest()
end)

PartyUi:GetPropertyChangedSignal("Visible"):Connect(UpdatePartyList)

-- Remote Logic

Prompt.OnClientEvent:Connect(function(Sender: Player)

	local UserData = Player:WaitForChild("UserData")
	local InvitesEnabled = UserData.Settings.InvitesEnabled

	if InvitesEnabled.Value == true then
		local SpinningGradient = RequestUi.UIStroke.UIGradient

		CurrentSender = Sender
		RequestUi.Username.Text = "@" .. Sender.Name

		SpinningGradient.Offset = Vector2.new(0.5, 0)
		RequestUi.Visible = true

		local TimerTween = TweenService:Create(SpinningGradient,TimerInfo,{ Offset = Vector2.new(-.5, 0) })
		TimerTween:Play() -- starts the tween for the timer 

		RequestUi.Visible = true

		task.delay(10, function() -- waits 10 seconds till the invite times out
			if RequestUi.Visible and CurrentSender == Sender then
				if not CurrentSender then return end
				RequestUi.Visible = false
				game.ReplicatedStorage.Remotes.Party.Reject:FireServer(CurrentSender)
				CurrentSender = nil
			end
		end)
		
		local content = Players:GetUserThumbnailAsync(Sender.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		RequestUi.PlayerIcon.Image = content
	end
end)

UpdateClient.OnClientEvent:Connect(function(PartyData)
	PurgeList(YourList)

	local AllMembers = {PartyData.Leader}
	local AddedPlayers = {}

	local LeaderName = PartyData.Leader and PartyData.Leader.Name or "Unknown"
	PartyText.Text = LeaderName .. "'s Party"

	for _, Member in ipairs(PartyData.Members or {}) do
		table.insert(AllMembers, Member)
	end

	for _, SelectedPlayer in ipairs(AllMembers) do
		if not(SelectedPlayer) or not(SelectedPlayer:IsDescendantOf(Players)) or AddedPlayers[SelectedPlayer.Name] then continue end

		AddedPlayers[SelectedPlayer.Name] = true

		local NewEntry = YourListTemplate:Clone()
		NewEntry.Name = SelectedPlayer.Name
		NewEntry.Visible = true
		NewEntry.Parent = YourList

		NewEntry.PlayerName.Text = SelectedPlayer.DisplayName
		NewEntry.PlayerIcon.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..SelectedPlayer.UserId.."&width=420&height=420&format=png"
	end

	-- Update party size attribute
	local PartySize = 0
	for _ in pairs(AddedPlayers) do
		PartySize = PartySize + 1
	end
	Player:SetAttribute("PartySize", PartySize)
end)

return Handler