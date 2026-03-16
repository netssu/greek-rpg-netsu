------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")
local Debris: Debris = game:GetService("Debris")

------------------//CONSTANTS
local PROJECTILE_LIFETIME: number = 5
local ABILITY_STUN_DURATION: number = 0.6
local ALLOWED_POSSESSION_RARITIES: {[string]: boolean} = {
	Secret = true,
}

------------------//VARIABLES
local events: Folder = ReplicatedStorage:WaitForChild("Events")
local possessEvent: RemoteEvent = events:WaitForChild("PossessTower")
local shootEvent: RemoteEvent = events:WaitForChild("PossessShoot")
local playVFXEvent: RemoteEvent = events:WaitForChild("PlayPossessVFX")

local upgradesModule = require(ReplicatedStorage:WaitForChild("Upgrades"))
local towerFunctionModule = require(ServerScriptService:WaitForChild("Main"):WaitForChild("TowerFunctions"))

local playerPossessions = {}

------------------//FUNCTIONS
local function get_towers_folder(): Folder?
	local towersFolder = workspace:FindFirstChild("Towers")
	if towersFolder and towersFolder:IsA("Folder") then
		return towersFolder
	end

	return nil
end

local function get_vfx_parent(): Instance
	return workspace:FindFirstChild("VFX") or workspace
end

local function getTowerStats(towerModel: Model): {[string]: any}
	local towerName = towerModel.Name
	local config = towerModel:FindFirstChild("Config")
	local upgradeValue = config and config:FindFirstChild("Upgrade")
	local upgradeLevel = towerModel:GetAttribute("Upgrade") or (upgradeValue and upgradeValue:IsA("IntValue") and upgradeValue.Value) or 1

	local stats = {
		Damage = 10,
		Cooldown = 1,
		Range = 15,
		AOESize = 4,
		AttackName = nil,
		AOEType = "Single",
		Rarity = nil,
		BasicAttack = nil,
		Abilities = {},
	}

	local towerData = upgradesModule[towerName]
	if towerData and towerData.Upgrades then
		stats.Rarity = towerData.Rarity

		local firstUpgrade = towerData.Upgrades[1]
		if firstUpgrade then
			stats.BasicAttack = {
				Damage = firstUpgrade.Damage or stats.Damage,
				Cooldown = firstUpgrade.Cooldown or stats.Cooldown,
				Range = firstUpgrade.Range or stats.Range,
				AOESize = firstUpgrade.AOESize or stats.AOESize,
				AttackName = firstUpgrade.AttackName,
				AOEType = firstUpgrade.AOEType or stats.AOEType,
			}
		end

		local attackProgression = {}
		for index, upgradeData in ipairs(towerData.Upgrades) do
			if index > upgradeLevel then
				break
			end

			local attackName = upgradeData.AttackName
			if attackName then
				attackProgression[attackName] = {
					Damage = upgradeData.Damage or stats.Damage,
					Cooldown = upgradeData.Cooldown or stats.Cooldown,
					Range = upgradeData.Range or stats.Range,
					AOESize = upgradeData.AOESize or stats.AOESize,
					AttackName = attackName,
					AOEType = upgradeData.AOEType or stats.AOEType,
				}
			end
		end

		local currentUpgrade = towerData.Upgrades[upgradeLevel]
		if currentUpgrade then
			stats.Damage = currentUpgrade.Damage or stats.Damage
			stats.Cooldown = currentUpgrade.Cooldown or stats.Cooldown
			stats.Range = currentUpgrade.Range or stats.Range
			stats.AOESize = currentUpgrade.AOESize or stats.AOESize
			stats.AttackName = currentUpgrade.AttackName
			stats.AOEType = currentUpgrade.AOEType or stats.AOEType
		end

		local basicAttackName = stats.BasicAttack and stats.BasicAttack.AttackName
		if basicAttackName and attackProgression[basicAttackName] then
			stats.BasicAttack = attackProgression[basicAttackName]
		end

		local abilityNames = {}
		for _, upgradeData in ipairs(towerData.Upgrades) do
			local attackName = upgradeData.AttackName
			if attackName and attackName ~= basicAttackName and attackProgression[attackName] then
				if not table.find(abilityNames, attackName) then
					table.insert(abilityNames, attackName)
				end
			end
		end

		for i = 1, 2 do
			local abilityName = abilityNames[i]
			if abilityName and attackProgression[abilityName] then
				stats.Abilities[i] = attackProgression[abilityName]
			end
		end
	end

	return stats
end

local function build_possession_ui_data(stats: {[string]: any}): {[string]: any}
	local function pack_attack_data(attackData: {[string]: any}?): {[string]: any}?
		if not attackData then
			return nil
		end

		return {
			Name = attackData.AttackName or "Ability",
			Cooldown = attackData.Cooldown or 1,
		}
	end

	return {
		Basic = pack_attack_data(stats.BasicAttack),
		Abilities = {
			pack_attack_data(stats.Abilities[1]),
			pack_attack_data(stats.Abilities[2]),
		},
	}
end

local function setCharacterVisibility(char: Model, isVisible: boolean): ()
	for _, obj in ipairs(char:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
			if not isVisible then
				obj:SetAttribute("OldTrans", obj.Transparency)
				obj.Transparency = 1
			else
				obj.Transparency = obj:GetAttribute("OldTrans") or 0
			end
		elseif obj:IsA("Decal") and obj.Name == "face" then
			if not isVisible then
				obj:SetAttribute("OldTrans", obj.Transparency)
				obj.Transparency = 1
			else
				obj.Transparency = obj:GetAttribute("OldTrans") or 0
			end
		end
	end
end

local function restore_bodygyro_state(towerModel: Model): ()
	local humanoidRootPart = towerModel:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		return
	end

	local bodyGyro = humanoidRootPart:FindFirstChildOfClass("BodyGyro")
	if not bodyGyro then
		return
	end

	local originalTorque = towerModel:GetAttribute("OriginalBodyGyroMaxTorque")
	if originalTorque and typeof(originalTorque) == "Vector3" then
		bodyGyro.MaxTorque = originalTorque
	end
end

local function disable_bodygyro_state(towerModel: Model): ()
	local humanoidRootPart = towerModel:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		return
	end

	local bodyGyro = humanoidRootPart:FindFirstChildOfClass("BodyGyro")
	if not bodyGyro then
		return
	end

	if towerModel:GetAttribute("OriginalBodyGyroMaxTorque") == nil then
		towerModel:SetAttribute("OriginalBodyGyroMaxTorque", bodyGyro.MaxTorque)
	end

	bodyGyro.MaxTorque = Vector3.zero
end

local function set_tower_baseparts_cframe(towerModel: Model, targetCFrame: CFrame): ()
	for _, partName in ipairs({"TowerBasePart", "VFXTowerBasePart"}) do
		local basePart = towerModel:FindFirstChild(partName)
		if basePart and basePart:IsA("BasePart") then
			basePart.CFrame = targetCFrame
		end
	end
end

local function unpossessTower(player: Player, char: Model?): ()
	local towerModel = playerPossessions[player]
	local towersFolder = get_towers_folder()

	if towerModel and towerModel.Parent then
		local humanoidRootPart = towerModel:FindFirstChild("HumanoidRootPart")

		if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			if not humanoidRootPart.Anchored then
				pcall(function()
					humanoidRootPart:SetNetworkOwner(nil)
				end)
			end

			humanoidRootPart.Anchored = true
		end

		towerModel:SetAttribute("Possessed", false)
		restore_bodygyro_state(towerModel)

		local config = towerModel:FindFirstChild("Config")
		local canAttack = config and config:FindFirstChild("CanAttack")
		if canAttack and canAttack:IsA("BoolValue") then
			canAttack.Value = true
		end

		local originalCFrame = towerModel:GetAttribute("OriginalCFrame")
		if originalCFrame and typeof(originalCFrame) == "CFrame" and humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			humanoidRootPart.CFrame = originalCFrame
			set_tower_baseparts_cframe(towerModel, originalCFrame)
		end
	end

	playerPossessions[player] = nil
	player:SetAttribute("PossessingTower", nil)

	if char then
		local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			humanoidRootPart.Anchored = false
		end

		setCharacterVisibility(char, true)

		local originalCFrame = char:GetAttribute("OriginalCFrame")
		if originalCFrame and typeof(originalCFrame) == "CFrame" and humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			humanoidRootPart.CFrame = originalCFrame
		end
	end
end

local function processPossessionRequest(player: Player, towerModel: Instance?): ()
	local char = player.Character
	if not char then
		return
	end

	local characterRoot = char:FindFirstChild("HumanoidRootPart")
	if not characterRoot or not characterRoot:IsA("BasePart") then
		return
	end

	if towerModel == nil then
		unpossessTower(player, char)
		possessEvent:FireClient(player, nil, false)
		return
	end

	if not towerModel:IsA("Model") then
		return
	end

	local towersFolder = get_towers_folder()
	if not towersFolder or not towerModel:IsDescendantOf(towersFolder) then
		return
	end

	local towerStats = getTowerStats(towerModel)
	if not ALLOWED_POSSESSION_RARITIES[towerStats.Rarity] then
		possessEvent:FireClient(player, nil, false)
		return
	end

	local towerRoot = towerModel:FindFirstChild("HumanoidRootPart")
	if not towerRoot or not towerRoot:IsA("BasePart") then
		possessEvent:FireClient(player, nil, false)
		return
	end

	local currentOwner = towerModel:GetAttribute("Possessed")
	local currentTower = playerPossessions[player]

	if currentOwner and currentTower ~= towerModel then
		possessEvent:FireClient(player, nil, false)
		return
	end

	unpossessTower(player, char)

	char:SetAttribute("OriginalCFrame", characterRoot.CFrame)
	towerModel:SetAttribute("OriginalCFrame", towerRoot.CFrame)

	characterRoot.Anchored = true
	setCharacterVisibility(char, false)

	playerPossessions[player] = towerModel
	player:SetAttribute("PossessingTower", towerModel.Name)
	towerModel:SetAttribute("Possessed", true)

	disable_bodygyro_state(towerModel)

	towerRoot.Anchored = false
	pcall(function()
		towerRoot:SetNetworkOwner(player)
	end)

	local config = towerModel:FindFirstChild("Config")
	local canAttack = config and config:FindFirstChild("CanAttack")
	if canAttack and canAttack:IsA("BoolValue") then
		canAttack.Value = false
	end

	possessEvent:FireClient(player, towerModel, true, build_possession_ui_data(towerStats))
end

local function onPossessShoot(player: Player, targetPosition: Vector3, lookVector: Vector3, abilitySlot: number?): ()
	if typeof(targetPosition) ~= "Vector3" or typeof(lookVector) ~= "Vector3" then
		return
	end

	if abilitySlot ~= nil and typeof(abilitySlot) ~= "number" then
		return
	end

	local towerModel = playerPossessions[player]
	if not towerModel or not towerModel:IsA("Model") or towerModel:GetAttribute("Possessed") ~= true then
		return
	end

	local spawnPart = towerModel:FindFirstChild("HumanoidRootPart")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return
	end

	local stunnedUntil = towerModel:GetAttribute("PossessionStunnedUntil")
	if typeof(stunnedUntil) == "number" and os.clock() < stunnedUntil then
		return
	end

	local stats = getTowerStats(towerModel)
	local selectedAttack = stats.BasicAttack

	if abilitySlot and abilitySlot >= 1 and abilitySlot <= 2 then
		selectedAttack = stats.Abilities[abilitySlot]
		if not selectedAttack then
			return
		end
	end

	if not selectedAttack then
		selectedAttack = {
			Damage = stats.Damage,
			Cooldown = stats.Cooldown,
			Range = stats.Range,
			AOESize = stats.AOESize,
			AttackName = stats.AttackName,
			AOEType = stats.AOEType,
		}
	end

	local now = os.clock()
	local lastShotAttribute = abilitySlot and string.format("LastShot_Ability%d", abilitySlot) or "LastShot_Basic"
	local lastShot = towerModel:GetAttribute(lastShotAttribute) or 0

	if now - lastShot < selectedAttack.Cooldown then
		return
	end

	towerModel:SetAttribute(lastShotAttribute, now)

	if abilitySlot and abilitySlot >= 1 and abilitySlot <= 2 then
		towerModel:SetAttribute("PossessionStunnedUntil", now + ABILITY_STUN_DURATION)
	end

	local isMelee = selectedAttack.Range <= 15
	local direction = (targetPosition - spawnPart.Position).Unit

	if direction.Magnitude ~= direction.Magnitude then
		direction = lookVector.Unit
	end

	local maxTargetDistance = isMelee and selectedAttack.Range or 2000

	set_tower_baseparts_cframe(towerModel, spawnPart.CFrame)

	local hitPosition = targetPosition
	local rayResult: RaycastResult? = nil
	local mobsFolder = workspace:FindFirstChild("Mobs")

	if mobsFolder then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {mobsFolder}
		raycastParams.FilterType = Enum.RaycastFilterType.Include

		rayResult = workspace:Raycast(spawnPart.Position, direction * maxTargetDistance, raycastParams)
	end

	if rayResult then
		hitPosition = rayResult.Position
	else
		hitPosition = spawnPart.Position + (direction * maxTargetDistance)
	end

	if selectedAttack.AttackName then
		playVFXEvent:FireAllClients(towerModel, towerModel.Name, selectedAttack.AttackName, hitPosition)
	end

	local mockTarget = Instance.new("Model")
	mockTarget.Name = "ServerMockTarget"

	local mockHRP = Instance.new("Part")
	mockHRP.Name = "HumanoidRootPart"
	mockHRP.CFrame = CFrame.new(hitPosition)
	mockHRP.Anchored = true
	mockHRP.Transparency = 1
	mockHRP.CanCollide = false
	mockHRP.Parent = mockTarget

	local mockHumanoid = Instance.new("Humanoid")
	mockHumanoid.Parent = mockTarget

	mockTarget.PrimaryPart = mockHRP
	mockTarget.Parent = get_vfx_parent()
	Debris:AddItem(mockTarget, PROJECTILE_LIFETIME)

	task.spawn(function()
		local config = towerModel:FindFirstChild("Config")
		local rangeValue = config and config:FindFirstChild("Range")
		local originalRange = rangeValue and rangeValue:IsA("NumberValue") and rangeValue.Value or selectedAttack.Range

		if not isMelee and rangeValue and rangeValue:IsA("NumberValue") then
			rangeValue.Value = 2000
		end

		pcall(function()
			towerFunctionModule.DamageFunction(towerModel, mockTarget)
		end)

		if selectedAttack.AOEType == "Single" and rayResult then
			local enemyModel = rayResult.Instance:FindFirstAncestorOfClass("Model")
			if enemyModel then
				local humanoid = enemyModel:FindFirstChild("Humanoid")
				if humanoid and humanoid:IsA("Humanoid") and humanoid.Health > 0 then
					humanoid:TakeDamage(selectedAttack.Damage)
				end
			end
		end

		task.wait(1.5)

		if not isMelee and rangeValue and rangeValue:IsA("NumberValue") then
			rangeValue.Value = originalRange
		end
	end)
end

local function onPlayerRemoving(player: Player): ()
	unpossessTower(player, player.Character)
end

------------------//INIT
possessEvent.OnServerEvent:Connect(processPossessionRequest)
shootEvent.OnServerEvent:Connect(onPossessShoot)
Players.PlayerRemoving:Connect(onPlayerRemoving)
