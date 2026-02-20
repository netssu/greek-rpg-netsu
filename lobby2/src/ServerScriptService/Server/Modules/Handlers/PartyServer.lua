local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PartyRemotes = Remotes:WaitForChild("Party")
local NotificationRemote = Remotes:WaitForChild("Notification")
local UpdateClient = PartyRemotes:WaitForChild("UpdateClient")

local PartiesFolder = Instance.new("Folder")
PartiesFolder.Name = "Parties"
PartiesFolder.Parent = ServerStorage

local function getPartyFolder(leader: Player)
	return PartiesFolder:FindFirstChild(leader.Name)
end

local function getPartyMembers(leader: Player)
	local partyFolder = getPartyFolder(leader)
	if not partyFolder then return {} end

	local members = {}
	local membersFolder = partyFolder:FindFirstChild("Members")
	if membersFolder then
		for _, memberValue in ipairs(membersFolder:GetChildren()) do
			local member = memberValue.Value
			if member and member.Parent == Players then
				table.insert(members, member)
			end
		end
	end
	return members
end

local function updatePartyClients(leader: Player)
	local partyFolder = getPartyFolder(leader)
	if not partyFolder then return end

	local members = getPartyMembers(leader)
	table.insert(members, leader)

	for _, plr in ipairs(members) do
		print("Firing UpdateClient to", plr)
		UpdateClient:FireClient(plr, {
			Leader = leader,
			Members = members,
		})
	end
end

local function createParty(Leader: Player, NewMember: Player)
	
	if NewMember:GetAttribute("inParty") then
		NotificationRemote.SendNotification:FireClient(Leader, NewMember.Name .. " is already in a party.", "Error")
		return
	end
	
	local partyFolder = getPartyFolder(Leader)

	if not partyFolder then
		partyFolder = Instance.new("Folder")
		partyFolder.Name = Leader.Name
		partyFolder.Parent = PartiesFolder

		local leaderValue = Instance.new("ObjectValue")
		leaderValue.Name = "Leader"
		leaderValue.Value = Leader
		leaderValue.Parent = partyFolder

		local membersFolder = Instance.new("Folder")
		membersFolder.Name = "Members"
		membersFolder.Parent = partyFolder

		local leaderMember = Instance.new("ObjectValue")
		leaderMember.Name = Leader.Name
		leaderMember.Value = Leader
		leaderMember.Parent = membersFolder

		Leader:SetAttribute("inParty", true)
		Leader:SetAttribute("PartyLeader", Leader.Name)
	end

	local membersFolder = partyFolder:FindFirstChild("Members")
	if membersFolder then
		local memberValue = Instance.new("ObjectValue")
		memberValue.Name = NewMember.Name
		memberValue.Value = NewMember
		memberValue.Parent = membersFolder
	end

	NewMember:SetAttribute("inParty", true)
	NewMember:SetAttribute("PartyLeader", Leader.Name)

	NotificationRemote.SendNotification:FireClient(Leader, NewMember.Name .. " joined your party!", "Success")
	NotificationRemote.SendNotification:FireClient(NewMember, "You joined " .. Leader.Name .. "'s party!", "Info")

	updatePartyClients(Leader)
end

local function removeFromParty(player: Player)
	local leaderParty = getPartyFolder(player)

	if leaderParty then
		local membersFolder = leaderParty:FindFirstChild("Members")
		if membersFolder then
			for _, memberValue in ipairs(membersFolder:GetChildren()) do
				local member = memberValue.Value
				if member and member.Parent == Players then
					member:SetAttribute("inParty", false)
					member:SetAttribute("PartyLeader", nil)
					NotificationRemote.SendNotification:FireClient(member, "Your party has been disbanded.", "Warning")
				end
			end
		end

		player:SetAttribute("inParty", false)
		player:SetAttribute("PartyLeader", nil)
		leaderParty:Destroy()

	else
		for _, party in ipairs(PartiesFolder:GetChildren()) do
			local membersFolder = party:FindFirstChild("Members")
			if membersFolder then
				local memberValue = membersFolder:FindFirstChild(player.Name)
				if memberValue then
					local leaderValue = party:FindFirstChild("Leader")
					local leader = leaderValue and leaderValue.Value

					memberValue:Destroy()
					player:SetAttribute("inParty", false)
					player:SetAttribute("PartyLeader", nil)
					NotificationRemote.SendNotification:FireClient(player, "You left the party.", "Info")

					if leader then
						updatePartyClients(leader)
					end
					break
				end
			end
		end
	end
end

PartyRemotes.AskToJoin.OnServerEvent:Connect(function(Sender: Player, Target: Player)
	if Sender and Target then
		local inParty = Target:GetAttribute("inParty")
		if inParty then
			NotificationRemote.SendNotification:FireClient(Sender, Target.Name .. " is already in a party.", "Error")
			return
		end
		NotificationRemote.SendNotification:FireClient(Sender, "Sent " .. Target.Name .. " a party request.", "Success")
		PartyRemotes.Prompt:FireClient(Target, Sender)
	end
end)

PartyRemotes.Reject.OnServerEvent:Connect(function(Rejecter: Player, Sender: Player)
	if Rejecter and Sender then
		NotificationRemote.SendNotification:FireClient(Sender, Rejecter.Name .. " rejected your party offer.", "Error")
	end
end)

PartyRemotes.Accept.OnServerEvent:Connect(function(Accepter: Player, Sender: Player)
	if Accepter and Sender then
		createParty(Sender, Accepter)
	end
end)

Players.PlayerRemoving:Connect(removeFromParty)

return {}
