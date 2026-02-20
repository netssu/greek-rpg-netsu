local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Player    = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

local MainUi               = PlayerGui:WaitForChild("TD")
local Frames               = MainUi:WaitForChild("Frames")
local WormsInventory       = Frames:WaitForChild("Worms")
local InventoryScrollingUi = WormsInventory:WaitForChild("ScrollingFrame")
local WormsInfo            = WormsInventory:WaitForChild("ItemFrame")
local EquipButton          = WormsInfo:WaitForChild("Equip")
local UnequipAll           = WormsInventory:WaitForChild("Unequip")
local EquipAll             = WormsInventory:WaitForChild("Best")
local SellButton           = WormsInventory:WaitForChild("Sell")
local CountFrame           = WormsInventory:WaitForChild("Count")
local InventorySpaceText   = CountFrame:WaitForChild("Count")

local ConsumablesFrame     = WormsInventory:WaitForChild("Consumables")
local ConsumablesScrolling = ConsumablesFrame:WaitForChild("ScrollingFrame")

local LevelFrame = WormsInfo:FindFirstChild("Level")
local RangeFrame = WormsInfo:FindFirstChild("Range")
local RateFrame  = WormsInfo:FindFirstChild("Rate")

local BarBG     = LevelFrame and LevelFrame:FindFirstChild("BarBG")
local BarBT     = BarBG     and BarBG:FindFirstChild("BarBT")
local LevelStat = LevelFrame and LevelFrame:FindFirstChild("Stat")     
local LevelText = LevelFrame and LevelFrame:FindFirstChild("TextLabel") 

local Modules      = ReplicatedStorage:WaitForChild("Modules")
local StoredData   = Modules:WaitForChild("StoredData")
local TowerData    = require(StoredData:WaitForChild("TowerData"))
local TowerLevelData = require(StoredData:WaitForChild("TowerLevelData"))
local ConsumableData = require(StoredData:WaitForChild("ConsumableData"))

local PlayerData        = Player:WaitForChild("UserData")
local PlayerInventory   = PlayerData:WaitForChild("Inventory")   
local PlayerHotbar      = PlayerData:WaitForChild("Hotbar")
local PlayerConsumables = PlayerData:WaitForChild("Consumables")

local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local InventoryRemotes = Remotes:WaitForChild("Inventory")
local SellRemote       = InventoryRemotes:WaitForChild("Sell")
local UseConsumableRemote = InventoryRemotes:WaitForChild("UseConsumable")

local Handler = {}

local Selected           = nil   
local SelectedConsumable = nil

local RarityRanks = { Legendary=5, Epic=4, Rare=3, Uncommon=2, Common=1 }

local RarityColor = {
	["Common"]    = ColorSequence.new(Color3.fromRGB(238,235,255), Color3.fromRGB(57,56,70)),
	["Uncommon"]  = ColorSequence.new(Color3.fromRGB(199,255,213), Color3.fromRGB(23,70,19)),
	["Rare"]      = ColorSequence.new(Color3.fromRGB(148,185,255), Color3.fromRGB(24,40,70)),
	["Epic"]      = ColorSequence.new(Color3.fromRGB(162,69,255),  Color3.fromRGB(34,21,70)),
	["Legendary"] = ColorSequence.new(Color3.fromRGB(255,226,137), Color3.fromRGB(70,53,28)),
}

local LayoutOrder = {
	["Common"]=10, ["Uncommon"]=9, ["Rare"]=8, ["Epic"]=7, ["Legendary"]=6,
}

local function GetModel(ItemName)
	return ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Towers"):FindFirstChild(ItemName)
end

local function getInventorySlot(baseName: string)
	for _, slot in ipairs(PlayerInventory:GetChildren()) do
		if slot:IsA("Folder") then
			local nameVal = slot:FindFirstChild("Name")
			if nameVal and nameVal.Value == baseName then
				return slot
			end
		end
	end
	return nil
end

local function readSlotEntry(baseName: string)
	local slot = getInventorySlot(baseName)
	if not slot then return nil end

	local function val(name, default)
		local v = slot:FindFirstChild(name)
		return v and v.Value or default
	end

	return {
		Name          = val("Name",          baseName),
		Level         = val("Level",         1),
		EXP           = val("EXP",           0),
		Damage   	  = val("Damage",        0),
		Range     	  = val("Range",         0),
		AttackCooldown = val("AttackCooldown", 0),
	}
end

local function computeTowerStats(towerName: string, entry: table)
	local towerInfo = TowerData[towerName]
	if not towerInfo or not towerInfo.BaseStats then return nil end

	local baseDamage   = towerInfo.BaseStats.Damage or 0
	local baseRange    = towerInfo.BaseStats.Range or 0
	local baseCooldown = towerInfo.BaseStats.AttackCooldown or 1

	return TowerLevelData.computeStats(
		baseDamage, baseRange, baseCooldown,
		entry.Level,
		entry.Damage,
		entry.Range,
		entry.AttackCooldown
	)
end

local function updateLevelBar(entry: table)
	if not LevelFrame then return end

	local level = entry.Level or 1
	local exp   = entry.EXP  or 0

	if LevelStat then
		if LevelStat:IsA("TextLabel") or LevelStat:IsA("TextBox") then
			LevelStat.Text = tostring(level)
		end
	end

	if BarBT then
		local needed  = TowerLevelData.expToNextLevel(level)
		local ratio   = (needed == math.huge) and 1 or math.clamp(exp / needed, 0, 1)
		BarBT.Size    = UDim2.new(ratio, 0, 1, 0)
	end
end

local function CheckEquipped(UnitName)
	for _, slot in ipairs(PlayerHotbar:GetChildren()) do
		if slot:IsA("StringValue") and slot.Value == UnitName then
			return true
		end
	end
	return false
end

local function PurgeList(Frame)
	for _, child in ipairs(Frame:GetChildren()) do
		if (child:IsA("ImageButton") or child:IsA("Frame")) and child.Name ~= "Example" then
			child:Destroy()
		end
	end
end

local function UpdatePreview(UnitName: string)
	local TowerInfo = TowerData[UnitName]
	if not TowerInfo then return end

	Selected = UnitName

	if CheckEquipped(UnitName) then
		EquipButton.MainText.Text                    = "Unequip"
		EquipButton.UIStroke.Color                   = Color3.fromRGB(58, 1, 2)
		EquipButton.MainText.UIStroke.Color          = Color3.fromRGB(58, 1, 2)
		EquipButton.ImageColor3                      = Color3.fromRGB(255, 28, 51)
	else
		EquipButton.MainText.Text                    = "Equip"
		EquipButton.UIStroke.Color                   = Color3.fromRGB(33, 58, 0)
		EquipButton.MainText.UIStroke.Color          = Color3.fromRGB(33, 58, 0)
		EquipButton.ImageColor3                      = Color3.fromRGB(81, 255, 0)
	end

	WormsInfo.Visible = true

	local TowerModel = GetModel(UnitName)
	if not TowerModel then return end

	WormsInfo.UIGradient.Color       = RarityColor[TowerModel:GetAttribute("Rarity")]
	WormsInfo.UIStroke.UIGradient.Color = RarityColor[TowerModel:GetAttribute("Rarity")]

	WormsInfo.WormName.Text  = UnitName
	WormsInfo.MainIcon.Image = "rbxassetid://" .. TowerInfo.ImageId

	local baseName = UnitName:gsub("_%d+$", "")
	local entry    = readSlotEntry(baseName)

	if entry then
		local stats = computeTowerStats(UnitName, entry)
		if stats then
			if RangeFrame then RangeFrame.Stat.Text = tostring(stats.Range) end
			if WormsInfo:FindFirstChild("Damage") then
				WormsInfo.Damage.Stat.Text = tostring(stats.Damage)
			end
			if RateFrame then RateFrame.Stat.Text  = tostring(stats.AttackCooldown) end
		end
		updateLevelBar(entry)
	else
		local baseStats = TowerInfo.BaseStats
		if RangeFrame then RangeFrame.Stat.Text = tostring(baseStats and baseStats.Range or "—") end
		if WormsInfo:FindFirstChild("Damage") then
			WormsInfo.Damage.Stat.Text = tostring(baseStats and baseStats.Damage or "—")
		end
		if RateFrame then RateFrame.Stat.Text = tostring(baseStats and baseStats.AttackCooldown or "—") end
		if BarBT then BarBT.Size = UDim2.new(0, 0, 1, 0) end
	end
end

local function UpdateInventory()
	PurgeList(InventoryScrollingUi)

	local ItemList = {}
	local MarkedEquipped = {}

	for _, slot in ipairs(PlayerInventory:GetChildren()) do
		if not slot:IsA("Folder") then continue end

		local nameVal = slot:FindFirstChild("Name")
		if not nameVal then continue end

		local unitName  = nameVal.Value
		local TowerInfo = TowerData[unitName]
		if not TowerInfo then continue end

		table.insert(ItemList, {
			Name       = unitName,
			Info       = TowerInfo,
			IsEquipped = CheckEquipped(unitName),
		})
	end

	InventorySpaceText.Text = #ItemList .. "/100"

	table.sort(ItemList, function(a, b)
		if a.IsEquipped ~= b.IsEquipped then return a.IsEquipped end
		local towerA = GetModel(a.Name)
		local towerB = GetModel(b.Name)
		local rarA   = RarityRanks[towerA and towerA:GetAttribute("Rarity")] or 0
		local rarB   = RarityRanks[towerB and towerB:GetAttribute("Rarity")] or 0
		if rarA ~= rarB then return rarA > rarB end
		return a.Name < b.Name
	end)

	for _, ItemData in ipairs(ItemList) do
		local TowerModel = GetModel(ItemData.Name)
		if not TowerModel then continue end

		local Rarity = TowerModel:GetAttribute("Rarity")

		local NewFrame = Instance.new("Frame", InventoryScrollingUi)
		NewFrame.Transparency = 1
		NewFrame.Name = ItemData.Name

		local Template = script:FindFirstChild("Template_" .. (Rarity or "Common"))
		if not Template then continue end

		local Clone = Template:Clone()
		Clone.Name   = ItemData.Name
		Clone.Parent = NewFrame

		NewFrame.LayoutOrder = LayoutOrder[Rarity] or 10

		Clone.Holder.Price.Text = "$" .. ItemData.Info.Price
		Clone.Holder.Visible    = true

		if ItemData.IsEquipped and not MarkedEquipped[ItemData.Name] then
			Clone.Equiped.Visible          = true
			MarkedEquipped[ItemData.Name]  = true
			NewFrame.LayoutOrder           -= 10
		else
			Clone.LayoutOrder      = LayoutOrder[Rarity] or 10
			Clone.Equiped.Visible  = false
		end

		Clone.Worm_Icon.Image = "rbxassetid://" .. ItemData.Info.ImageId
		Clone.WormName.Text   = ItemData.Name

		Clone.Activated:Connect(function()
			UpdatePreview(Clone.Name)
		end)
	end
end

local function UpdateConsumables()
	PurgeList(ConsumablesScrolling)
	SelectedConsumable = nil

	local EffectEmoji = {
		["XP"]       = "⬆️ XP",
		["Damage"]   = "⚔️ DMG",
		["Cooldown"] = "⚡ SPD",
		["Range"]    = "🏹 RNG",
		["Level"]    = "⭐ LVL",
	}

	local EffectColor = {
		["XP"]       = Color3.fromRGB(100, 255, 100),
		["Damage"]   = Color3.fromRGB(255, 80,  80),
		["Cooldown"] = Color3.fromRGB(180, 180, 255),
		["Range"]    = Color3.fromRGB(255, 220, 50),
		["Level"]    = Color3.fromRGB(255, 200, 0),
	}

	for _, Item in ipairs(PlayerConsumables:GetChildren()) do
		if not Item:IsA("StringValue") then continue end

		local ConsumableInfo = ConsumableData[Item.Value]
		if not ConsumableInfo then continue end

		local Template = script:FindFirstChild("Template_Common")
		if not Template then continue end

		local NewFrame = Instance.new("Frame", ConsumablesScrolling)
		NewFrame.Transparency = 1
		NewFrame.Name         = Item.Name

		local Clone   = Template:Clone()
		Clone.Name    = Item.Name
		Clone.Parent  = NewFrame

		local effectType  = ConsumableInfo.Effect and ConsumableInfo.Effect.Type
		local effectValue = ConsumableInfo.Effect and ConsumableInfo.Effect.Value
		local emoji       = EffectEmoji[effectType] or effectType or "?"
		local sign        = (effectValue and effectValue > 0) and "+" or ""

		Clone.Holder.Price.Text       = emoji .. " " .. sign .. tostring(effectValue or "")
		Clone.Holder.Price.TextColor3 = EffectColor[effectType] or Color3.fromRGB(255,255,255)
		Clone.Holder.Visible          = true

		for _, child in ipairs(Clone.Holder:GetChildren()) do
			if child:IsA("GuiObject") and child.Name ~= "Price" then
				child.Visible = false
			end
		end
		Clone.Equiped.Visible = false

		Clone.Worm_Icon.Image = "rbxassetid://" .. ConsumableInfo.ImageId
		Clone.WormName.Text   = Item.Value

		local itemName = Item.Value

		Clone.Activated:Connect(function()
			if not Selected then return end

			for _, child in ipairs(ConsumablesScrolling:GetChildren()) do
				if child:IsA("Frame") then
					local c = child:FindFirstChildOfClass("ImageButton") or child:FindFirstChildOfClass("Frame")
					if c and c:FindFirstChild("Equiped") then
						c.Equiped.Visible = false
					end
				end
			end

			Clone.Equiped.Visible = true
			SelectedConsumable    = itemName

			UseConsumableRemote:FireServer(Selected, itemName)
		end)
	end
end

local function watchSlot(slot: Folder)
	for _, valueObj in ipairs(slot:GetChildren()) do
		if valueObj:IsA("ValueBase") then
			valueObj.Changed:Connect(function()
				local nameVal = slot:FindFirstChild("Name")
				if nameVal and Selected and nameVal.Value:gsub("_%d+$","") == Selected:gsub("_%d+$","") then
					UpdatePreview(Selected)
				end
			end)
		end
	end
end

for _, slot in ipairs(PlayerInventory:GetChildren()) do
	if slot:IsA("Folder") then
		watchSlot(slot)
	end
end

PlayerInventory.ChildAdded:Connect(function(slot)
	if slot:IsA("Folder") then
		watchSlot(slot)
		UpdateInventory()
	end
end)

PlayerInventory.ChildRemoved:Connect(function()
	UpdateInventory()
	if Selected then
		WormsInfo.Visible = false
		Selected = nil
	end
end)

local debounce = false

EquipButton.Activated:Connect(function()
	if Selected and not debounce then
		debounce = true
		InventoryRemotes.Equip:FireServer(Selected)
		task.wait(0.1)
		UpdatePreview(Selected)
		UpdateInventory()
		task.delay(0.3, function() debounce = false end)
	end
end)

SellButton.Activated:Connect(function()
	if Selected then
		InventoryRemotes.Sell:FireServer(Selected)
		task.wait(0.2)
		UpdateInventory()
	end
end)

UnequipAll.Activated:Connect(function()
	InventoryRemotes.UnequipAll:FireServer()
	task.wait(0.1)
	if Selected then UpdatePreview(Selected) end
	UpdateInventory()
end)

EquipAll.Activated:Connect(function()
	local bestUnit = nil
	local bestRank = 0

	for _, slot in ipairs(PlayerInventory:GetChildren()) do
		if not slot:IsA("Folder") then continue end
		local nameVal = slot:FindFirstChild("Name")
		if not nameVal then continue end

		local unitName = nameVal.Value
		local info     = TowerData[unitName]
		if not info then continue end

		local towerModel = GetModel(unitName)
		local rarity     = towerModel and towerModel:GetAttribute("Rarity")
		local rank       = RarityRanks[rarity] or 0

		if rank > bestRank then
			bestRank = rank
			bestUnit = unitName
		end
	end

	if bestUnit then
		InventoryRemotes.Equip:FireServer(bestUnit)
		task.spawn(function()
			task.wait(0.1)
			UpdatePreview(bestUnit)
			UpdateInventory()
		end)
	end
end)

SellRemote.OnClientEvent:Connect(function()
	WormsInfo.Visible = false
end)

PlayerConsumables.ChildAdded:Connect(function()
	UpdateConsumables()
end)

PlayerConsumables.ChildRemoved:Connect(function()
	UpdateConsumables()
	if Selected then UpdatePreview(Selected) end
end)

WormsInventory:GetPropertyChangedSignal("Visible"):Connect(function()
	if WormsInventory.Visible then
		UpdateInventory()
		UpdateConsumables()
	end
end)

return Handler