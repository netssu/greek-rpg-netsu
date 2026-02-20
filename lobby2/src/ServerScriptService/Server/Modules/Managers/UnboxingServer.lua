local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local StoredData = Modules:WaitForChild("StoredData")

local CrateData = require(StoredData:WaitForChild("CrateData"))

local ActiveUnboxes = {}

local function GenerateHash(length)
	length = length or 16
	local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local hash = ""
	for i = 1, length do
		local randIndex = math.random(1, #charset)
		hash ..= charset:sub(randIndex, randIndex)
	end
	return hash
end

local function GetRandomUnitOfRarity(targetRarity)
	local candidates = {}

	for unitName, tier in pairs(CrateData.UnitTiers) do
		if tier == targetRarity then
			table.insert(candidates, unitName)
		end
	end

	if #candidates > 0 then
		return candidates[math.random(1, #candidates)]
	end
	return nil
end

local function UpdatePity(Player, BoxType, reset)
	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return end

	local PityFolder = UserData:FindFirstChild("BannerPity")
	if not PityFolder then
		PityFolder = Instance.new("Folder")
		PityFolder.Name = "BannerPity"
		PityFolder.Parent = UserData
	end

	local PityValue = PityFolder:FindFirstChild(BoxType)
	if not PityValue then
		PityValue = Instance.new("IntValue")
		PityValue.Name = BoxType
		PityValue.Parent = PityFolder
	end

	if reset then
		PityValue.Value = 0
	else
		PityValue.Value += 1
	end

	return PityValue.Value
end

local function GetPity(Player, BoxType)
	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return 0 end

	local PityFolder = UserData:FindFirstChild("BannerPity")
	if not PityFolder then return 0 end

	local PityValue = PityFolder:FindFirstChild(BoxType)
	return PityValue and PityValue.Value or 0
end

local function CheckOwnership(Player, UnitName)
	local DataManager = require(game.ServerStorage.Modules.Managers.DataManager)
	local profile = DataManager.Stored[Player.UserId]
	if profile and profile:IsActive() and type(profile.Data.Inventory) == "table" then
		for _, entry in pairs(profile.Data.Inventory) do
			if type(entry) == "table" and entry.Name == UnitName then
				return true
			end
		end
	end
	return false
end

local function GrantTowerToPlayer(Player, UnitName, InventoryFolder)
	local DataManager = require(game.ServerStorage.Modules.Managers.DataManager)
	local profile = DataManager.Stored[Player.UserId]
	if not profile or not profile:IsActive() then return end

	local slotKey = GenerateHash(32)

	local newEntry = {
		Name           = UnitName,
		Level          = 1,
		EXP            = 0,
		Damage         = 0,
		Range          = 0,
		AttackCooldown = 0,
	}

	if type(profile.Data.Inventory) == "table" then
		profile.Data.Inventory[slotKey] = newEntry
	end

	if InventoryFolder then
		local slotFolder = Instance.new("Folder")
		slotFolder.Name = slotKey
		slotFolder.Parent = InventoryFolder

		local fields = {
			{Name = "Name",           Type = "StringValue", Value = newEntry.Name},
			{Name = "Level",          Type = "NumberValue", Value = newEntry.Level},
			{Name = "EXP",            Type = "NumberValue", Value = newEntry.EXP},
			{Name = "Damage",         Type = "NumberValue", Value = newEntry.Damage},
			{Name = "Range",          Type = "NumberValue", Value = newEntry.Range},
			{Name = "AttackCooldown", Type = "NumberValue", Value = newEntry.AttackCooldown},
		}

		for _, fieldData in ipairs(fields) do
			local inst = Instance.new(fieldData.Type)
			inst.Name = fieldData.Name
			inst.Value = fieldData.Value
			inst.Parent = slotFolder
		end
	end
end

Remotes.Game.Unbox.OnServerEvent:Connect(function(Player, BoxType)
	if ActiveUnboxes[Player] then return end

	local BannerInfo = CrateData.Banners[BoxType]
	if not BannerInfo then return end

	local UserData = Player:FindFirstChild("UserData")
	if not UserData then return end

	local Crates = UserData:FindFirstChild("Crates")
	local Inventory = UserData:FindFirstChild("Inventory")

	local CrateItem = Crates and Crates:FindFirstChild(BoxType)

	if not CrateItem or CrateItem.Value < 1 then
		Remotes.Notification.SendNotification:FireClient(Player, "You don't have this crate!", "Error")
		return
	end

	ActiveUnboxes[Player] = true

	CrateItem.Value -= 1

	local currentPity = GetPity(Player, BoxType)
	local chosenRarity = "Common"
	local isPityTrigger = currentPity >= (BannerInfo.PityThreshold or 50)

	if isPityTrigger then
		if BannerInfo.Rates["Mythic"] and BannerInfo.Rates["Mythic"] > 0 then
			chosenRarity = "Mythic"
		elseif BannerInfo.Rates["Legendary"] and BannerInfo.Rates["Legendary"] > 0 then
			chosenRarity = "Legendary"
		else
			chosenRarity = "Epic"
		end
		UpdatePity(Player, BoxType, true)
	else
		local roll = math.random(1, 10000)
		local cumulative = 0
		local rarityOrder = {"Common", "Rare", "Epic", "Legendary", "Mythic"}

		for _, rarity in ipairs(rarityOrder) do
			local rate = BannerInfo.Rates[rarity] or 0
			if rate > 0 then
				cumulative += rate
				if roll <= cumulative then
					chosenRarity = rarity
					break
				end
			end
		end

		if chosenRarity == "Legendary" or chosenRarity == "Mythic" then
			UpdatePity(Player, BoxType, true)
		else
			UpdatePity(Player, BoxType, false)
		end
	end

	local SelectedUnit = GetRandomUnitOfRarity(chosenRarity)

	if not SelectedUnit then
		SelectedUnit = "Scout" 
		warn("No unit found for rarity: " .. chosenRarity)
	end

	if not CheckOwnership(Player, SelectedUnit) then
		GrantTowerToPlayer(Player, SelectedUnit, Inventory)
	end

	Remotes.Game.DisplayUnbox:FireClient(Player, SelectedUnit, BoxType)

	task.wait(1.5)
	ActiveUnboxes[Player] = nil
end)

Remotes.Game.PurchaseBox.OnServerEvent:Connect(function(Player, BoxType)
	local BannerInfo = CrateData.Banners[BoxType]
	if not BannerInfo then return end

	local UserData = Player:FindFirstChild("UserData")
	local Crates = UserData:FindFirstChild("Crates")
	if not UserData or not Crates then return end

	local CurrencyName = BannerInfo.Currency or "Coins"
	local Price = BannerInfo.Price

	local CurrencyStore = UserData
	if CurrencyName == "Gems" then
		if UserData:FindFirstChild("Gems") then
			CurrencyStore = UserData:FindFirstChild("Gems")
		elseif UserData:FindFirstChild("Stats") and UserData.Stats:FindFirstChild("Gems") then
			CurrencyStore = UserData.Stats.Gems
		else
			CurrencyStore = UserData:FindFirstChild("Gems") 
		end
	elseif CurrencyName == "Coins" then
		CurrencyStore = UserData:FindFirstChild("Money")
	end

	if CurrencyName == "Robux" then
		return 
	end

	if CurrencyStore and type(CurrencyStore.Value) == "number" then
		if CurrencyStore.Value >= Price then
			CurrencyStore.Value -= Price

			local CrateItem = Crates:FindFirstChild(BoxType)
			if not CrateItem then
				CrateItem = Instance.new("IntValue")
				CrateItem.Name = BoxType
				CrateItem.Parent = Crates
			end
			CrateItem.Value += 1

			Remotes.Notification.SendNotification:FireClient(Player, "Purchased " .. BannerInfo.DisplayName, "Success")
		else
			Remotes.Notification.SendNotification:FireClient(Player, "Not enough " .. CurrencyName, "Error")
		end
	end
end)

return {}