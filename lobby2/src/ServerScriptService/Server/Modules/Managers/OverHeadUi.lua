local Handler = {}
local Players = game.Players

-- creates or updates the overhead gui on a character
local function UpdateOverhead(Character, ClanTag, PlayerName)
	local Head = Character:FindFirstChild("Head")
	if not Head then return end

	-- remove old one if it exists
	local OldOverhead = Head:FindFirstChild("Overhead")
	if OldOverhead then OldOverhead:Destroy() end

	-- clone the template and parent it
	local NewOverhead = script.Overhead:Clone()
	NewOverhead.Parent = Head

	-- setup clan tag label
	local ClanLabel = NewOverhead:FindFirstChild("Clan")
	if ClanLabel then
		ClanLabel.Visible = ClanTag and ClanTag ~= ""
		ClanLabel.Text = ClanTag and `[#{ClanTag}]` or ""
	end

	-- setup username label
	local UserLabel = NewOverhead:FindFirstChild("User")
	if UserLabel then
		UserLabel.Text = PlayerName
	end
end

-- handles all the overhead setup for a player
local function SetupPlayer(Plr)
	local function OnCharacter(Character)
		-- wait for character to be in workspace
		if not Character:IsDescendantOf(workspace) then
			Character.AncestryChanged:Wait()
		end

		-- wait for head to exist
		Character:WaitForChild("Head", 10)

		-- get player data, return if it doesnt exist
		local PlayerData = Plr:WaitForChild("UserData", 10)
		if not PlayerData then return end

		local ClanTag = PlayerData:WaitForChild("ClanTag", 5)
		if not ClanTag then return end

		-- create the initial overhead
		UpdateOverhead(Character, ClanTag.Value, Plr.Name)

		-- update when clan tag changes
		ClanTag:GetPropertyChangedSignal("Value"):Connect(function()
			if Character and Character.Parent then
				UpdateOverhead(Character, ClanTag.Value, Plr.Name)
			end
		end)
	end

	-- handle existing character
	if Plr.Character then
		task.spawn(OnCharacter, Plr.Character)
	end

	-- handle future respawns
	Plr.CharacterAdded:Connect(function(Character)
		task.spawn(OnCharacter, Character)
	end)
end

function Handler.Init()
	-- setup for new players
	Players.PlayerAdded:Connect(SetupPlayer)

	-- setup for players already in game
	for _, Plr in ipairs(Players:GetPlayers()) do
		task.spawn(SetupPlayer, Plr)
	end
end

Handler.Init()

return Handler