local Handler = {}

local Players = game.Players

-- Important Variables / Ui elements

local Player = game.Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local MainUi = PlayerGui:WaitForChild("TD")
local FramesUi = MainUi:WaitForChild("Frames")
local ClansUi = FramesUi:WaitForChild("Clans")
local ClansButtonHolder = ClansUi:WaitForChild("Holder")
local ClansButton = ClansButtonHolder:WaitForChild("Clans")
local CreateButton = ClansButtonHolder:WaitForChild("Create")
local MyClanButton = ClansButtonHolder:WaitForChild("MyClan")

-- Each Frame (to use to toggle)

local ClansFrame = ClansUi:WaitForChild("DataBase")
local CreateFrame = ClansUi:WaitForChild("Create")
local MyClanFrame = ClansUi:WaitForChild("MyClan")
local JoinText = ClansUi:WaitForChild("Search")
local InserBox = JoinText:WaitForChild("TextBox")

-- Action buttons to use for future logic

local CreateCancel = CreateFrame:WaitForChild("Cancel")
local CreateAction = CreateFrame:WaitForChild("Create")

-- Input areas

local TagBox = CreateFrame:WaitForChild("TagContainer"):WaitForChild("TagTextbox")
local NameBox = CreateFrame:WaitForChild("NameContainer"):WaitForChild("NameTextbox")
local IconBox = CreateFrame:WaitForChild("ClanIcon"):WaitForChild("IconTextbox")

local ReplicatedStorage = game.ReplicatedStorage
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClanRemotes = Remotes:WaitForChild("Clan")
local GetClan = ClanRemotes:WaitForChild("getClan")
local GetTop = ClanRemotes:WaitForChild("getTop")

local MainMyClan = MyClanFrame:WaitForChild("Main")
local MainListFrame = MainMyClan:WaitForChild("List")
local ExampleMember = MainListFrame:WaitForChild("Example")

local ExampleDataBase = ClansFrame:WaitForChild("Example")

local LeaveButton = MainMyClan:WaitForChild("Leave")

local Clan = nil

local Frames = {
	MyClanFrame,
	CreateFrame,
	ClansFrame
}

local function Show(frameToShow) -- Loops through frames table so only one gets enabled rest get disabled
	for _, frame in ipairs(Frames) do
		if frameToShow.Name ~= "Create" then
			ClansButtonHolder.Visible = true	
		end
		frame.Visible = (frame == frameToShow)
	end
end

local function PurgeFrame(ScrollFrame) -- clears all non example frames (to refresh)
	for _, Frame in ipairs(ScrollFrame:GetChildren()) do
		if Frame:IsA("Frame") and Frame.Name ~= "Example" then
			Frame:Destroy()
		end
	end
end

local function UpdateClanInfo(Info) -- Updates info about the clan
	MyClanFrame.Main.Title.Text = Info.ClanName
	MyClanFrame.Main.ClanTag.Text = `[#{Info.Tag}]`
	
	MyClanFrame.Main.Wins.Text = Info.Stats.Wins
	MyClanFrame.Main.Kills.Text = Info.Stats.Killed
	MyClanFrame.Main.Placed.Text = Info.Stats.Placed
	
	-- sets clan icon
	
	MyClanFrame.Main.ClanIcon.Image = `http://www.roblox.com/asset/?id={Info.Icon or ""}`
	
	MyClanFrame.Main.Members.Text = `Members: {#Info.Members}/25`
	
	PurgeFrame(MyClanFrame:WaitForChild("Main"):WaitForChild("List")) -- purges so old doesnt override new list
	
	for _, PlrInfo in ipairs(Info.Members) do
		local NewFrame = ExampleMember:Clone()
		pcall(function()
			NewFrame.User.Text = Players:GetNameFromUserIdAsync(PlrInfo.UserId) or PlrInfo.BackUpName
		end)
		NewFrame.Visible = true
		NewFrame.Parent = MainListFrame
		NewFrame.Name = PlrInfo.UserId
		
		NewFrame.PFP.Image="https://www.roblox.com/headshot-thumbnail/image?userId="..PlrInfo.UserId.."&width=420&height=420&format=png"
		
		if PlrInfo.UserId == Info.Owner then
			NewFrame.Kick.Visible = false
		elseif Player.UserId == Info.Owner then
			NewFrame.Kick.Visible = true
			NewFrame.Kick.Activated:Connect(function()
				ClanRemotes.kickPlayer:FireServer(PlrInfo.UserId)
			end)
		end
	end
end

function Handler.Init()
	print("Started Clans | Client!")

	ClansButton.Activated:Connect(function()
		Show(ClansFrame) -- Shows clan list
		ClanRemotes:WaitForChild("getTop"):FireServer()
	end)

	MyClanButton.Activated:Connect(function() -- Shows YOUR clan
		GetClan:FireServer()
		
		if Clan then
			MyClanFrame.Main.Visible = true
			MyClanFrame.Invalid.Visible = false
		else
			MyClanFrame.Invalid.Visible = true
			MyClanFrame.Main.Visible = false
		end
		Show(MyClanFrame)
	end)

	CreateButton.Activated:Connect(function() -- Shows create frame
		Show(CreateFrame)
		ClansButtonHolder.Visible = false -- Disables buttons so it doesnt overlap	
	end)
	
	CreateCancel.Activated:Connect(function() -- Shows cancel frame
		Show(ClansFrame)
		ClansButtonHolder.Visible = true
	end)
	
	CreateAction.Activated:Connect(function()
		
		-- Gets all the text from text box's to send to server
		
		local nameText = NameBox.Text:match("^%s*(.-)%s*$")
		local tagText = TagBox.Text:match("^%s*(.-)%s*$")
		local iconText = IconBox.Text:match("^%s*(.-)%s*$")

		if nameText == "" and #nameText <= 25 then
			print("cant have a empty name")
			return
		end

		if #tagText < 2 or #tagText > 5 then
			print("needs 2-5 characters")
			return
		end

		if iconText ~= "" and not tonumber(iconText) then
			print("Needs asset id")
			return
		end

		-- Sends to server after cleint sided validation

		game.ReplicatedStorage.Remotes.Clan.createClan:FireServer(tagText:upper(),nameText,iconText)
		
		Show(MyClanFrame) -- Then loads your clan after you create it
	end)
	
	GetClan.OnClientEvent:Connect(function(ClanData) -- Recieves clan info from server
		Clan = ClanData
		
		if Clan then
			MyClanFrame.Main.Visible = true
			MyClanFrame.Invalid.Visible = false
			
			UpdateClanInfo(ClanData) -- Updates it using the earlier function
		else
			MyClanFrame.Invalid.Visible = true
			MyClanFrame.Main.Visible = false
		end
		
		ClansButtonHolder.Visible = true
	end)
	
	LeaveButton.Activated:Connect(function()
		print("Attempting leave")
		
		ClanRemotes.leaveClan:FireServer() -- makes you leave the clan
	end)
	
	GetTop.OnClientEvent:Connect(function(All, Top)
		PurgeFrame(ClansFrame) -- clears the previous list
		
		for Key, Info in ipairs(Top) do -- Loads Clans infos
			local NewExample = ExampleDataBase:Clone()
			NewExample.Parent = ClansFrame
			NewExample.Visible = true
			NewExample.Title.Text = All[Info.Tag].ClanName or "Error"
			NewExample.Wins.Text = All[Info.Tag].Stats.Wins
			NewExample.Enemies.Text = All[Info.Tag].Stats.Killed
			NewExample.Towers.Text = All[Info.Tag].Stats.Placed
			NewExample.Rank.Text = "#"..Key
			NewExample.ClanTag.Text = `[#{Info.Tag}]`
			NewExample.ClanIcon.Image = `http://www.roblox.com/asset/?id={All[Info.Tag].Icon or ""}`
			NewExample.Members.Text = #All[Info.Tag].Members.."/25"
			
			NewExample.Name = "New"
			
			NewExample.Join.Activated:Connect(function()
				print("click")
				ClanRemotes.joinClan:FireServer(Info.Tag)
			end)
		end
	end)
	
	ClanRemotes:WaitForChild("getTop"):FireServer()
	GetClan:FireServer()
	
	InserBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			print(InserBox.Text)
			if InserBox.Text then
				ClanRemotes.joinClan:FireServer(InserBox.Text)
			end
		end
	end)
end

Handler.Init()

return Handler