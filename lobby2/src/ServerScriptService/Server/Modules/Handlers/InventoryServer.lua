local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")

local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local InventoryRemotes = Remotes:WaitForChild("Inventory")
local PetModels        = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Towers")

local TowerData      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StoredData"):WaitForChild("TowerData"))
local ConsumableData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StoredData"):WaitForChild("ConsumableData"))
local DataManager    = require(game.ServerStorage.Modules.Managers.DataManager)
local ActivePets     = {}

local UseConsumableRemote = InventoryRemotes:FindFirstChild("UseConsumable")
if not UseConsumableRemote then
	UseConsumableRemote = Instance.new("RemoteEvent")
	UseConsumableRemote.Name   = "UseConsumable"
	UseConsumableRemote.Parent = InventoryRemotes
end

local function getBaseName(name: string): string
	return name:gsub("_%d+$", "")
end

local function findInventoryEntry(profile, baseName: string)
	local inv = profile.Data.Inventory
	if typeof(inv) ~= "table" then return nil, nil end
	for key, entry in pairs(inv) do
		if typeof(entry) == "table" and entry.Name == baseName then
			return key, entry
		end
	end
	return nil, nil
end

local function verifyOwnership(Player: Player, UnitName: string): boolean
	local profile = DataManager.Stored[Player.UserId]
	if not profile or not profile:IsActive() then return false end
	local baseName = getBaseName(UnitName)
	local _, entry = findInventoryEntry(profile, baseName)
	return entry ~= nil
end

local function syncEntryToPlayerObject(Player: Player, slotKey: string, entry: table)
	local userFolder = Player:FindFirstChild("UserData")
	if not userFolder then return end
	local invFolder  = userFolder:FindFirstChild("Inventory")
	if not invFolder then return end

	local slotFolder = invFolder:FindFirstChild(slotKey)
	if not slotFolder then
		slotFolder        = Instance.new("Folder")
		slotFolder.Name   = slotKey
		slotFolder.Parent = invFolder
	end

	local fields = {"Name", "Level", "EXP", "Damage", "Range", "AttackCooldown"}
	for _, field in ipairs(fields) do
		local val = entry[field]
		if val == nil then continue end
		local existing = slotFolder:FindFirstChild(field)
		if existing then
			existing.Value = val
		else
			local vtype = typeof(val)
			local inst
			if vtype == "string"      then inst = Instance.new("StringValue")
			elseif vtype == "number"  then inst = Instance.new("NumberValue")
			elseif vtype == "boolean" then inst = Instance.new("BoolValue")
			end
			if inst then
				inst.Name   = field
				inst.Value  = val
				inst.Parent = slotFolder
			end
		end
	end
end

local function verifyConsumableOwnership(Player: Player, ConsumableName: string): boolean
	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return false end
	local ConsumablesFolder = UserData:FindFirstChild("Consumables")
	if not ConsumablesFolder then return false end
	for _, Item in ipairs(ConsumablesFolder:GetChildren()) do
		if Item:IsA("StringValue") and Item.Value == ConsumableName then return true end
	end
	return false
end

local function RemoveConsumable(Player: Player, ConsumableName: string): boolean
	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return false end
	local ConsumablesFolder = UserData:FindFirstChild("Consumables")
	if not ConsumablesFolder then return false end
	local Profile = DataManager.Stored[Player.UserId]
	if not Profile or not Profile:IsActive() then return false end
	for _, Item in ipairs(ConsumablesFolder:GetChildren()) do
		if Item:IsA("StringValue") and Item.Value == ConsumableName then
			if typeof(Profile.Data.Consumables) == "table" then
				Profile.Data.Consumables[Item.Name] = nil
			end
			Item:Destroy()
			return true
		end
	end
	return false
end

local function equip(Player: Player, UnitName: string)
	local UserData = Player:FindFirstChild("UserData")
	local Level    = UserData:FindFirstChild("Level")
	local Hotbar   = UserData:FindFirstChild("Hotbar")

	local HotbarSlots = {}
	for _, Slot in ipairs(Hotbar:GetChildren()) do
		table.insert(HotbarSlots, Slot)
	end
	table.sort(HotbarSlots, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	for _, Slot in ipairs(HotbarSlots) do
		if Slot.Value == UnitName then
			Slot.Value = ""
			Remotes.Notification.SendNotification:FireClient(Player, "Unequipped " .. UnitName .. "!", "Info")
			return nil
		end
	end

	for _, Slot in ipairs(HotbarSlots) do
		local slotNumber = tonumber(Slot.Name)
		if slotNumber == 5 and Level.Value < 10 then
			Remotes.Notification.SendNotification:FireClient(Player, "You need to be level 10 to equip slot 5!", "Error")
			return nil
		elseif slotNumber == 6 and Level.Value < 15 then
			Remotes.Notification.SendNotification:FireClient(Player, "You need to be level 15 to equip slot 6!", "Error")
			return nil
		end
		if Slot.Value == "" then return Slot end
	end

	Remotes.Notification.SendNotification:FireClient(Player, "No empty hotbar slots available!", "Error")
	return nil
end

local function EquipPet(Player: Player, PetName: string)

end

local function ApplyConsumable(Player: Player, TowerName: string, ConsumableName: string): boolean
	local ConsumableInfo = ConsumableData[ConsumableName]
	if not ConsumableInfo then return false end

	local Effect      = ConsumableInfo.Effect
	local effectType  = Effect.Type
	local effectValue = Effect.Value

	local profile = DataManager.Stored[Player.UserId]
	if not profile or not profile:IsActive() then return false end

	local baseName     = getBaseName(TowerName)
	local slotKey, entry = findInventoryEntry(profile, baseName)

	if not entry then
		warn("[InventoryServer] Torre não encontrada no Inventory:", baseName)
		return false
	end

	local TowerLevelData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("StoredData"):WaitForChild("TowerLevelData"))

	if effectType == "XP" then
		entry.EXP = (entry.EXP or 0) + effectValue
		while entry.Level < TowerLevelData.MAX_LEVEL do
			local needed = TowerLevelData.expToNextLevel(entry.Level)
			if entry.EXP >= needed then
				entry.EXP = entry.EXP - needed
				entry.Level = entry.Level + 1
			else
				break
			end
		end

	elseif effectType == "Level" then
		local newLevel = math.clamp((entry.Level or 1) + effectValue, 1, TowerLevelData.MAX_LEVEL)
		entry.Level = newLevel

	elseif effectType == "Damage" then
		entry.Damage = (entry.Damage or 0) + effectValue

	elseif effectType == "Range" then
		entry.Range = (entry.Range or 0) + effectValue

	elseif effectType == "AttackCooldown" then
		entry.AttackCooldown = (entry.AttackCooldown or 0) + effectValue

	else
		warn("[InventoryServer] Tipo de consumível desconhecido:", effectType)
		return false
	end

	profile.Data.Inventory[slotKey] = entry
	syncEntryToPlayerObject(Player, slotKey, entry)

	return true
end

local function OnPlayerAdded(Plr)
	local UserData = Plr:WaitForChild("UserData", 15)
	if not UserData then return end
	local HotBar = UserData:WaitForChild("Hotbar", 15)
	if not HotBar then return end

	repeat task.wait() until Plr.Character
	task.wait(1)

	for _, StrVal in ipairs(HotBar:GetChildren()) do
		if StrVal.Value ~= "" then EquipPet(Plr, StrVal.Value) end
	end
end

InventoryRemotes.Equip.OnServerEvent:Connect(function(Player: Player, UnitName: string)
	if not verifyOwnership(Player, UnitName) then return end

	local Slot = equip(Player, UnitName)
	if Slot then
		Slot.Value = UnitName
		EquipPet(Player, UnitName)
		Remotes.Notification.SendNotification:FireClient(Player, "Equipped " .. UnitName .. "!", "Success")
	end
end)

InventoryRemotes.UnequipAll.OnServerEvent:Connect(function(Player: Player)
	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return end
	local Hotbar = UserData:FindFirstChild("Hotbar")
	if not Hotbar then return end

	local done = false
	for _, Slot in ipairs(Hotbar:GetChildren()) do
		if Slot:IsA("StringValue") and Slot.Value ~= "" then
			Slot.Value = "" done = true
		end
	end

	if done then
		Remotes.Notification.SendNotification:FireClient(Player, "All units have been unequipped!", "Success")
	end
end)

InventoryRemotes.Sell.OnServerEvent:Connect(function(Player: Player, UnitName: string)
	if not verifyOwnership(Player, UnitName) then
		Remotes.Notification.SendNotification:FireClient(Player, "You don't own this unit!", "Error")
		return
	end

	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return end

	local profile = DataManager.Stored[Player.UserId]
	if not profile or not profile:IsActive() then return end

	local Hotbar = UserData:FindFirstChild("Hotbar")
	local Money  = UserData:FindFirstChild("Money")
	if not Hotbar or not Money then return end

	for _, Slot in ipairs(Hotbar:GetChildren()) do
		if Slot:IsA("StringValue") and Slot.Value == UnitName then
			Remotes.Notification.SendNotification:FireClient(Player, "You can't sell an equipped unit!", "Error")
			return
		end
	end

	local TowerModel = PetModels:FindFirstChild(UnitName)
	local Rarity     = TowerModel and TowerModel:GetAttribute("Rarity")
	local TowerInfo  = TowerData[UnitName]

	local SellValue = 100
	if TowerInfo and Rarity then
		local prices = { Common=250, Uncommon=500, Rare=1000, Epic=2500, Legendary=5000 }
		SellValue = prices[Rarity] or 100
	end

	local baseName = getBaseName(UnitName)
	local slotKey, _ = findInventoryEntry(profile, baseName)
	if slotKey then
		profile.Data.Inventory[slotKey] = nil

		local invFolder = UserData:FindFirstChild("Inventory")
		if invFolder then
			local slotFolder = invFolder:FindFirstChild(slotKey)
			if slotFolder then slotFolder:Destroy() end
		end
	end

	Money.Value += SellValue
	Remotes.Notification.SendNotification:FireClient(Player, "Sold " .. UnitName .. " for $" .. SellValue .. "!", "Success")
	InventoryRemotes.Sell:FireClient(Player)
end)

UseConsumableRemote.OnServerEvent:Connect(function(Player: Player, TowerName: string, ConsumableName: string)
	if not verifyConsumableOwnership(Player, ConsumableName) then
		Remotes.Notification.SendNotification:FireClient(Player, "You don't own this consumable!", "Error")
		return
	end

	if not TowerData[TowerName] then
		Remotes.Notification.SendNotification:FireClient(Player, "Invalid tower selected!", "Error")
		return
	end

	local success = ApplyConsumable(Player, TowerName, ConsumableName)
	if not success then
		Remotes.Notification.SendNotification:FireClient(Player, "Failed to apply consumable!", "Error")
		return
	end

	RemoveConsumable(Player, ConsumableName)
	Remotes.Notification.SendNotification:FireClient(Player, "Used " .. ConsumableName .. " on " .. TowerName .. "!", "Success")
end)

Remotes:WaitForChild("Pets").EquipPet.Event:Connect(function(Player, WormName)
	EquipPet(Player, WormName)
end)

for _, Plr in ipairs(Players:GetPlayers()) do
	task.spawn(OnPlayerAdded, Plr)
end

Players.PlayerAdded:Connect(OnPlayerAdded)

Remotes:WaitForChild("Like").OnServerEvent:Connect(function(Plr)
	local UserData    = Plr:WaitForChild("UserData")
	local ClaimedLike = UserData:WaitForChild("ClaimedLike")

	if ClaimedLike.Value then
		Remotes.Notification.SendNotification:FireClient(Plr, "Already claimed!", "Error")
	else
		if Plr:IsInGroupAsync(103774916) then
			UserData.Money.Value += 3_000
			ClaimedLike.Value = true
			Remotes.Notification.SendNotification:FireClient(Plr, "Claimed!", "Success")
		else
			Remotes.Notification.SendNotification:FireClient(Plr, "Need to like and join!", "Error")
		end
	end
end)

return {}