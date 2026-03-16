local ContextActionService: ContextActionService = game:GetService("ContextActionService")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local Debris: Debris = game:GetService("Debris")
local UserInputService: UserInputService = game:GetService("UserInputService")

local POSSESS_KEY: Enum.KeyCode = Enum.KeyCode.E
local POSSESS_ACTION_NAME: string = "PossessExitAction"
local SHOOT_ACTION_NAME: string = "PossessShootAction"
local ABILITY_ONE_ACTION_NAME: string = "PossessAbilityOneAction"
local ABILITY_TWO_ACTION_NAME: string = "PossessAbilityTwoAction"
local BLOCK_ACTION_NAME: string = "PossessBlockAction"
local INPUT_PRIORITY: number = Enum.ContextActionPriority.High.Value + 100

local ABILITY_SLOT_COUNT: number = 2
local ABILITY_DEFAULT_COOLDOWN: number = 1

local MAX_ENERGY: number = 100
local DRAIN_RATE: number = 0
local REGEN_RATE: number = 2
local VM_OFFSET: CFrame = CFrame.new(0, -0.8, -0.8)

local SWAY_POSITION_MULTIPLIER: number = 1.25
local SWAY_ROTATION_MULTIPLIER: number = 1
local SWAY_DAMPING: number = 18
local MAX_SWAY_POSITION: number = 0.18
local MAX_SWAY_ROTATION: number = 0.08

local VISIBLE_NAME_TOKENS: {string} = {
	"arm",
	"hand",
	"weapon",
	"sword",
	"blade",
	"gun",
	"rifle",
	"pistol",
	"bow",
	"staff",
	"wand",
	"shield",
}

local VISIBLE_EXACT_NAMES: {[string]: boolean} = {
	["left arm"] = true,
	["right arm"] = true,
	["lefthand"] = true,
	["righthand"] = true,
	["leftlowerarm"] = true,
	["rightlowerarm"] = true,
	["leftupperarm"] = true,
	["rightupperarm"] = true,
}

local BLOCKED_BODY_NAMES: {[string]: boolean} = {
	["head"] = true,
	["torso"] = true,
	["humanoidrootpart"] = true,
	["uppertorso"] = true,
	["lowertorso"] = true,
	["left leg"] = true,
	["right leg"] = true,
	["leftfoot"] = true,
	["rightfoot"] = true,
	["leftlowerleg"] = true,
	["rightlowerleg"] = true,
	["leftupperleg"] = true,
	["rightupperleg"] = true,
}

local BLOCKED_BODY_TOKENS: {string} = {
	"torso",
	"leg",
	"foot",
	"head",
	"root",
	"pelvis",
}

local player: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera

local events: Folder = ReplicatedStorage:WaitForChild("Events")
local possessEvent: RemoteEvent = events:WaitForChild("PossessTower")
local shootEvent: RemoteEvent = events:WaitForChild("PossessShoot")
local playVFXEvent: RemoteEvent = events:WaitForChild("PlayPossessVFX")

local vfxLoader = require(ReplicatedStorage:WaitForChild("VFX_Loader"))
local PlayerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local controls = PlayerModule:GetControls()

local currentlyPossessing: Model? = nil
local originalCameraCFrame: CFrame? = nil
local currentEnergy: number = MAX_ENERGY

local viewmodelFolder: Folder? = nil
local viewmodelModel: Model? = nil
local currentViewmodelCFrame: CFrame? = nil

local viewmodelSwayPosition: Vector3 = Vector3.zero
local viewmodelSwayRotation: Vector2 = Vector2.zero
local lastCameraCFrame: CFrame? = nil

local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local percentLabel: TextLabel = playerGui:WaitForChild("Ingame_HUD"):WaitForChild("CommandEnergy"):WaitForChild("Percent")
local inCommandFrame: GuiObject = playerGui:WaitForChild("Ingame_HUD"):WaitForChild("InCommandFrame")

local oldMaxZoom: number = player.CameraMaxZoomDistance
local hiddenVFXParts = {}
local cachedUIStates = {}


type AbilitySlotState = {
	Frame: Frame,
	NameLabel: TextLabel,
	KeyLabel: TextLabel,
	CooldownFill: Frame,
	CooldownLabel: TextLabel,
	Cooldown: number,
	ReadyAt: number,
}

local crosshairGui = Instance.new("ScreenGui")
crosshairGui.Name = "PossessionCrosshair"
crosshairGui.ResetOnSpawn = false
crosshairGui.Enabled = false
crosshairGui.Parent = playerGui

local crosshairCenter = Instance.new("Frame")
crosshairCenter.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairCenter.Position = UDim2.fromScale(0.5, 0.5)
crosshairCenter.Size = UDim2.fromOffset(4, 4)
crosshairCenter.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
crosshairCenter.BorderSizePixel = 0
local corner = Instance.new("UICorner", crosshairCenter)
corner.CornerRadius = UDim.new(1, 0)
crosshairCenter.Parent = crosshairGui

local function createLine(size, pos)
	local line = Instance.new("Frame")
	line.Size = size
	line.Position = pos
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	line.BorderSizePixel = 0
	line.Parent = crosshairGui
end

createLine(UDim2.fromOffset(2, 8), UDim2.new(0.5, 0, 0.5, -12))
createLine(UDim2.fromOffset(2, 8), UDim2.new(0.5, 0, 0.5, 12))
createLine(UDim2.fromOffset(8, 2), UDim2.new(0.5, -12, 0.5, 0))
createLine(UDim2.fromOffset(8, 2), UDim2.new(0.5, 12, 0.5, 0))

local abilityHudGui = Instance.new("ScreenGui")
abilityHudGui.Name = "PossessionAbilityHud"
abilityHudGui.ResetOnSpawn = false
abilityHudGui.Enabled = false
abilityHudGui.Parent = playerGui

local abilityHudContainer = Instance.new("Frame")
abilityHudContainer.Name = "Container"
abilityHudContainer.AnchorPoint = Vector2.new(0.5, 1)
abilityHudContainer.Position = UDim2.fromScale(0.5, 0.98)
abilityHudContainer.Size = UDim2.fromOffset(320, 70)
abilityHudContainer.BackgroundTransparency = 1
abilityHudContainer.Parent = abilityHudGui

local abilityHudLayout = Instance.new("UIListLayout")
abilityHudLayout.FillDirection = Enum.FillDirection.Horizontal
abilityHudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
abilityHudLayout.VerticalAlignment = Enum.VerticalAlignment.Center
abilityHudLayout.Padding = UDim.new(0, 12)
abilityHudLayout.Parent = abilityHudContainer

local abilitySlots: {[number]: AbilitySlotState} = {}

local function create_ability_slot(index: number): AbilitySlotState
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = string.format("AbilitySlot%d", index)
	slotFrame.Size = UDim2.fromOffset(150, 64)
	slotFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	slotFrame.BackgroundTransparency = 0.2
	slotFrame.BorderSizePixel = 0
	slotFrame.Parent = abilityHudContainer

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(90, 90, 90)
	stroke.Transparency = 0.2
	stroke.Parent = slotFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = slotFrame

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "Key"
	keyLabel.BackgroundTransparency = 1
	keyLabel.Position = UDim2.fromOffset(8, 4)
	keyLabel.Size = UDim2.fromOffset(20, 16)
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextSize = 14
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	keyLabel.Text = tostring(index)
	keyLabel.Parent = slotFrame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(8, 20)
	nameLabel.Size = UDim2.new(1, -16, 0, 18)
	nameLabel.Font = Enum.Font.GothamSemibold
	nameLabel.TextSize = 13
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = "Ability"
	nameLabel.Parent = slotFrame

	local cooldownFrame = Instance.new("Frame")
	cooldownFrame.Name = "CooldownFill"
	cooldownFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	cooldownFrame.BackgroundTransparency = 0.78
	cooldownFrame.BorderSizePixel = 0
	cooldownFrame.Position = UDim2.new(0, 0, 0, 0)
	cooldownFrame.Size = UDim2.fromScale(1, 0)
	cooldownFrame.ZIndex = 3
	cooldownFrame.Parent = slotFrame

	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "Cooldown"
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Position = UDim2.fromOffset(8, 42)
	cooldownLabel.Size = UDim2.new(1, -16, 0, 18)
	cooldownLabel.Font = Enum.Font.Gotham
	cooldownLabel.TextSize = 12
	cooldownLabel.TextXAlignment = Enum.TextXAlignment.Left
	cooldownLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	cooldownLabel.Text = "Ready"
	cooldownLabel.Parent = slotFrame

	return {
		Frame = slotFrame,
		NameLabel = nameLabel,
		KeyLabel = keyLabel,
		CooldownFill = cooldownFrame,
		CooldownLabel = cooldownLabel,
		Cooldown = ABILITY_DEFAULT_COOLDOWN,
		ReadyAt = 0,
	}
end

for i = 1, ABILITY_SLOT_COUNT do
	abilitySlots[i] = create_ability_slot(i)
end

local function refresh_camera(): ()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		camera = currentCamera
		lastCameraCFrame = currentCamera.CFrame

		if viewmodelFolder then
			viewmodelFolder.Parent = currentCamera
		end
	end
end

local function clamp_vector3_magnitude(value: Vector3, maxMagnitude: number): Vector3
	local magnitude = value.Magnitude
	if magnitude > maxMagnitude and magnitude > 0 then
		return value.Unit * maxMagnitude
	end

	return value
end

local function clamp_vector2_magnitude(value: Vector2, maxMagnitude: number): Vector2
	local magnitude = value.Magnitude
	if magnitude > maxMagnitude and magnitude > 0 then
		return value.Unit * maxMagnitude
	end

	return value
end

local function getAimPosition(): Vector3
	local rayOrigin = camera.CFrame.Position
	local rayDirection = camera.CFrame.LookVector * 2000

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {player.Character, currentlyPossessing, viewmodelFolder}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if rayResult then
		return rayResult.Position
	end

	return rayOrigin + rayDirection
end

local function clearViewmodel(): ()
	if viewmodelFolder then
		viewmodelFolder:Destroy()
		viewmodelFolder = nil
	end

	viewmodelModel = nil
	currentViewmodelCFrame = nil
	viewmodelSwayPosition = Vector3.zero
	viewmodelSwayRotation = Vector2.zero
	lastCameraCFrame = nil
end

local function is_seed_viewmodel_part(part: BasePart): boolean
	local lowerName = string.lower(part.Name)

	if VISIBLE_EXACT_NAMES[lowerName] then
		return true
	end

	for _, token in ipairs(VISIBLE_NAME_TOKENS) do
		if string.find(lowerName, token, 1, true) then
			return true
		end
	end

	return false
end

local function is_blocked_body_part(part: BasePart): boolean
	local lowerName = string.lower(part.Name)

	if is_seed_viewmodel_part(part) then
		return false
	end

	if BLOCKED_BODY_NAMES[lowerName] then
		return true
	end

	for _, token in ipairs(BLOCKED_BODY_TOKENS) do
		if string.find(lowerName, token, 1, true) then
			return true
		end
	end

	return false
end

local function add_part_link(adjacency: {[BasePart]: {BasePart}}, part0: BasePart?, part1: BasePart?): ()
	if not part0 or not part1 then
		return
	end

	if not adjacency[part0] then
		adjacency[part0] = {}
	end

	if not adjacency[part1] then
		adjacency[part1] = {}
	end

	table.insert(adjacency[part0], part1)
	table.insert(adjacency[part1], part0)
end

local function get_parent_basepart(obj: Instance, rootModel: Model): BasePart?
	local current = obj.Parent

	while current and current ~= rootModel do
		if current:IsA("BasePart") then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function has_visible_basepart_ancestor(obj: Instance, rootModel: Model, visibleParts: {[BasePart]: boolean}): boolean
	local current = obj.Parent

	while current and current ~= rootModel do
		if current:IsA("BasePart") and visibleParts[current] then
			return true
		end

		current = current.Parent
	end

	return false
end

local function collect_visible_viewmodel_parts(model: Model): {[BasePart]: boolean}
	local visibleParts: {[BasePart]: boolean} = {}
	local adjacency: {[BasePart]: {BasePart}} = {}
	local queue: {BasePart} = {}

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") and is_seed_viewmodel_part(obj) then
			visibleParts[obj] = true
			table.insert(queue, obj)
		end
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("Motor6D") or obj:IsA("Weld") then
			add_part_link(adjacency, obj.Part0, obj.Part1)
		elseif obj:IsA("WeldConstraint") then
			add_part_link(adjacency, obj.Part0, obj.Part1)
		elseif obj:IsA("RigidConstraint") then
			local attachment0 = obj.Attachment0
			local attachment1 = obj.Attachment1

			local parent0 = attachment0 and attachment0.Parent
			local parent1 = attachment1 and attachment1.Parent

			local part0 = parent0 and parent0:IsA("BasePart") and parent0 or nil
			local part1 = parent1 and parent1:IsA("BasePart") and parent1 or nil

			add_part_link(adjacency, part0, part1)
		end
	end

	local queueIndex = 1

	while queueIndex <= #queue do
		local currentPart = queue[queueIndex]
		queueIndex += 1

		local neighbors = adjacency[currentPart]
		if neighbors then
			for _, neighbor in ipairs(neighbors) do
				if not visibleParts[neighbor] and not is_blocked_body_part(neighbor) then
					visibleParts[neighbor] = true
					table.insert(queue, neighbor)
				end
			end
		end
	end

	return visibleParts
end

local function configure_viewmodel(model: Model): ()
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("FaceControls") then
			obj:Destroy()
		end
	end

	local visibleParts = collect_visible_viewmodel_parts(model)

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			local isVisible = visibleParts[obj]
			local hasVisibleAncestor = has_visible_basepart_ancestor(obj, model, visibleParts)
			local parentBasePart = get_parent_basepart(obj, model)

			if parentBasePart and not hasVisibleAncestor then
				obj:Destroy()
			else
				obj.Anchored = false
				obj.CanCollide = false
				obj.CanTouch = false
				obj.CanQuery = false
				obj.Massless = true
				obj.CastShadow = false
				obj.LocalTransparencyModifier = 0

				if isVisible or hasVisibleAncestor then
					obj.Transparency = 0
				else
					obj.Transparency = 1
				end
			end
		end
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("Decal") or obj:IsA("Texture") then
			local parent = obj.Parent

			if parent and parent:IsA("BasePart") then
				local isVisible = visibleParts[parent]
				local hasVisibleAncestor = has_visible_basepart_ancestor(parent, model, visibleParts)

				if isVisible or hasVisibleAncestor then
					obj.Transparency = 0
				else
					obj.Transparency = 1
				end
			end
		elseif obj:IsA("Humanoid") then
			obj.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			obj.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			obj.NameDisplayDistance = 0
			obj.HealthDisplayDistance = 0
		end
	end

	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.Anchored = true
		model.PrimaryPart = rootPart
	end
end

local function create_viewmodel(sourceModel: Model): ()
	clearViewmodel()

	viewmodelFolder = Instance.new("Folder")
	viewmodelFolder.Name = "Viewmodel"
	viewmodelFolder.Parent = camera

	viewmodelModel = sourceModel:Clone()
	viewmodelModel.Name = "VM"
	viewmodelModel.Parent = viewmodelFolder

	configure_viewmodel(viewmodelModel)

	currentViewmodelCFrame = camera.CFrame * VM_OFFSET
	viewmodelSwayPosition = Vector3.zero
	viewmodelSwayRotation = Vector2.zero
	lastCameraCFrame = camera.CFrame
end

local function toggleCameraVFX(isVisible: boolean)
	if not isVisible then
		hiddenVFXParts = {}
		for _, child in ipairs(camera:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(hiddenVFXParts, {instance = child, trans = child.Transparency})
				child.Transparency = 1

				for _, desc in ipairs(child:GetDescendants()) do
					if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
						table.insert(hiddenVFXParts, {instance = desc, trans = desc.Transparency})
						desc.Transparency = 1
					end
				end
			end
		end
	else
		for _, data in ipairs(hiddenVFXParts) do
			if data.instance and data.instance.Parent then
				data.instance.Transparency = data.trans
			end
		end
		hiddenVFXParts = {}
	end
end

local function hideAndCacheUIElements()
	cachedUIStates = {}
	local targetUIs = {"Slots", "SelectionUi", "PhoneControls", "Controls"}
	for _, name in ipairs(targetUIs) do
		local ui = playerGui:FindFirstChild(name, true)
		if ui and ui:IsA("GuiObject") then
			table.insert(cachedUIStates, {element = ui, wasVisible = ui.Visible})
			ui.Visible = false
		end
	end
end

local function restoreUIElements()
	for _, data in ipairs(cachedUIStates) do
		if data.element and data.element.Parent then
			data.element.Visible = data.wasVisible
		end
	end
	cachedUIStates = {}
end


local function reset_ability_hud(): ()
	for index, slot in pairs(abilitySlots) do
		slot.NameLabel.Text = string.format("Ability %d", index)
		slot.Cooldown = ABILITY_DEFAULT_COOLDOWN
		slot.ReadyAt = 0
		slot.CooldownFill.Size = UDim2.fromScale(1, 0)
		slot.CooldownLabel.Text = "Ready"
		slot.Frame.Visible = false
	end
end

local function configure_ability_hud(possessionData: {[string]: any}?): ()
	reset_ability_hud()

	if not possessionData then
		return
	end

	local abilities = possessionData.Abilities
	if typeof(abilities) ~= "table" then
		return
	end

	for index = 1, ABILITY_SLOT_COUNT do
		local slotData = abilities[index]
		local slot = abilitySlots[index]
		if slotData and slot then
			local name = slotData.Name
			local cooldown = slotData.Cooldown

			slot.NameLabel.Text = (typeof(name) == "string" and name ~= "") and name or string.format("Ability %d", index)
			slot.Cooldown = (typeof(cooldown) == "number" and cooldown > 0) and cooldown or ABILITY_DEFAULT_COOLDOWN
			slot.Frame.Visible = true
		end
	end
end

local function trigger_ability_cooldown(slotIndex: number): boolean
	local slot = abilitySlots[slotIndex]
	if not slot or not slot.Frame.Visible then
		return false
	end

	local now = os.clock()
	if now < slot.ReadyAt then
		return false
	end

	slot.ReadyAt = now + slot.Cooldown
	slot.CooldownFill.Size = UDim2.fromScale(1, 1)
	slot.CooldownLabel.Text = string.format("%.1fs", slot.Cooldown)

	local tween = TweenService:Create(slot.CooldownFill, TweenInfo.new(slot.Cooldown, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 0)
	})
	tween:Play()
	return true
end

local function on_possess_confirm(towerModel: Model?, state: boolean, possessionData: {[string]: any}?): ()
	if state and towerModel then
		inCommandFrame.Visible = true
		originalCameraCFrame = camera.CFrame
		currentlyPossessing = towerModel
		currentEnergy = MAX_ENERGY

		hideAndCacheUIElements()

		local hrp = towerModel:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
			hrp.AssemblyLinearVelocity = Vector3.new(0, 0.01, 0) 
		end

		local head = towerModel:FindFirstChild("Head")
		if not head then
			head = Instance.new("Part")
			head.Name = "Head"
			head.Size = Vector3.new(1, 1, 1)
			head.Transparency = 1
			head.CanCollide = false
			head.Massless = true

			if hrp then
				head.CFrame = hrp.CFrame * CFrame.new(0, 1.5, 0)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hrp
				weld.Part1 = head
				weld.Parent = head
			end
			head.Parent = towerModel
		end

		local humanoid = towerModel:FindFirstChild("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end

		oldMaxZoom = player.CameraMaxZoomDistance
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5

		UserInputService.MouseIconEnabled = false
		crosshairGui.Enabled = true
		abilityHudGui.Enabled = true
		configure_ability_hud(possessionData)

		ContextActionService:BindActionAtPriority(
			BLOCK_ACTION_NAME,
			function() return Enum.ContextActionResult.Sink end,
			false,
			INPUT_PRIORITY,
			Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Q, Enum.KeyCode.R, Enum.KeyCode.X, Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift
		)

		create_viewmodel(towerModel)
	else
		inCommandFrame.Visible = false
		currentlyPossessing = nil

		restoreUIElements()

		local character = player.Character
		if character then
			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid and humanoid:IsA("Humanoid") then
				camera.CameraSubject = humanoid
			end
		end

		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = oldMaxZoom

		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		crosshairGui.Enabled = false
		abilityHudGui.Enabled = false
		reset_ability_hud()

		ContextActionService:UnbindAction(BLOCK_ACTION_NAME)

		toggleCameraVFX(true)
		clearViewmodel()

		local currentMinZoom = player.CameraMinZoomDistance
		player.CameraMinZoomDistance = 15

		task.delay(0.05, function()
			player.CameraMinZoomDistance = currentMinZoom

			if originalCameraCFrame then
				camera.CFrame = originalCameraCFrame
			end
		end)
	end
end

local function on_possess_action(_: string, inputState: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if currentlyPossessing then
		possessEvent:FireServer(nil)
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

local function fire_possession_attack(abilitySlot: number?): Enum.ContextActionResult
	if currentlyPossessing then
		if abilitySlot and not trigger_ability_cooldown(abilitySlot) then
			return Enum.ContextActionResult.Sink
		end

		local targetPosition = getAimPosition()
		shootEvent:FireServer(targetPosition, camera.CFrame.LookVector, abilitySlot)
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

local function on_shoot_action(_: string, inputState: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	return fire_possession_attack(nil)
end

local function on_ability_one_action(_: string, inputState: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	return fire_possession_attack(1)
end

local function on_ability_two_action(_: string, inputState: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	return fire_possession_attack(2)
end

local function on_play_vfx(towerModel: Model, moduleName: string, attackName: string, hitPosition: Vector3): ()
	local humanoidRootPart = towerModel:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		return
	end

	for _, partName in ipairs({"TowerBasePart", "VFXTowerBasePart"}) do
		local basePart = towerModel:FindFirstChild(partName)
		if basePart and basePart:IsA("BasePart") then
			basePart.CFrame = humanoidRootPart.CFrame
		end
	end

	local mockTarget = Instance.new("Model")
	mockTarget.Name = "DummyEnemy"

	local mockHRP = Instance.new("Part")
	mockHRP.Name = "HumanoidRootPart"
	mockHRP.Size = Vector3.new(2, 2, 2)
	mockHRP.Position = hitPosition
	mockHRP.CFrame = CFrame.new(hitPosition)
	mockHRP.Anchored = true
	mockHRP.Transparency = 1
	mockHRP.CanCollide = false
	mockHRP.Parent = mockTarget

	mockTarget.PrimaryPart = mockHRP

	local hum = Instance.new("Humanoid")
	hum.Parent = mockTarget

	mockTarget.Parent = workspace:FindFirstChild("VFX") or workspace
	Debris:AddItem(mockTarget, 5)

	if vfxLoader[moduleName] and type(vfxLoader[moduleName]) == "table" and vfxLoader[moduleName][attackName] then
		task.spawn(function()
			pcall(function()
				vfxLoader[moduleName][attackName](humanoidRootPart, mockTarget)
			end)
		end)
	end
end

local function sync_viewmodel_motors(): ()
	if not currentlyPossessing or not viewmodelModel then
		return
	end

	for _, obj in ipairs(currentlyPossessing:GetDescendants()) do
		if obj:IsA("Motor6D") then
			local motorParent = obj.Parent

			if motorParent then
				local vmPart = viewmodelModel:FindFirstChild(motorParent.Name, true)
				if vmPart then
					local vmMotor = vmPart:FindFirstChild(obj.Name)
					if vmMotor and vmMotor:IsA("Motor6D") then
						vmMotor.Transform = obj.Transform
					end
				end
			end
		end
	end
end

local function on_render_step(deltaTime: number): ()
	if currentlyPossessing then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		toggleCameraVFX(false)

		if DRAIN_RATE <= 0 then
			currentEnergy = MAX_ENERGY
		else
			currentEnergy = math.max(0, currentEnergy - (DRAIN_RATE * deltaTime))

			if currentEnergy <= 0 then
				possessEvent:FireServer(nil)
				currentlyPossessing = nil
			end
		end
	else
		currentEnergy = math.min(MAX_ENERGY, currentEnergy + (REGEN_RATE * deltaTime))
	end

	percentLabel.Text = math.floor(currentEnergy) .. "%"

	for _, slot in pairs(abilitySlots) do
		if slot.Frame.Visible then
			local remaining = math.max(0, slot.ReadyAt - os.clock())
			if remaining > 0 then
				slot.CooldownLabel.Text = string.format("%.1fs", remaining)
			else
				slot.CooldownLabel.Text = "Ready"
			end
		end
	end

	if currentlyPossessing then
		local humanoid = currentlyPossessing:FindFirstChild("Humanoid")
		if humanoid and humanoid:IsA("Humanoid") then
			local moveVector = controls:GetMoveVector()
			humanoid:Move(moveVector, true)
		end
	end

	if viewmodelModel and viewmodelModel.PrimaryPart then
		local baseCFrame = camera.CFrame * VM_OFFSET
		local deltaCFrame = CFrame.new()

		if lastCameraCFrame then
			deltaCFrame = lastCameraCFrame:ToObjectSpace(camera.CFrame)
		end

		local deltaPosition = deltaCFrame.Position
		local deltaPitch, deltaYaw, _ = deltaCFrame:ToOrientation()

		local targetSwayPosition = Vector3.new(
			-deltaPosition.X,
			-deltaPosition.Y,
			deltaPosition.Z * 0.25
		) * SWAY_POSITION_MULTIPLIER

		local targetSwayRotation = Vector2.new(
			-deltaPitch,
			-deltaYaw
		) * SWAY_ROTATION_MULTIPLIER

		targetSwayPosition = clamp_vector3_magnitude(targetSwayPosition, MAX_SWAY_POSITION)
		targetSwayRotation = clamp_vector2_magnitude(targetSwayRotation, MAX_SWAY_ROTATION)

		local swayAlpha = 1 - math.exp(-SWAY_DAMPING * deltaTime)

		viewmodelSwayPosition = viewmodelSwayPosition:Lerp(targetSwayPosition, swayAlpha)
		viewmodelSwayRotation = viewmodelSwayRotation:Lerp(targetSwayRotation, swayAlpha)

		currentViewmodelCFrame = baseCFrame
			* CFrame.new(viewmodelSwayPosition)
			* CFrame.Angles(viewmodelSwayRotation.X, viewmodelSwayRotation.Y, 0)

		viewmodelModel:PivotTo(currentViewmodelCFrame)
		sync_viewmodel_motors()
	end

	lastCameraCFrame = camera.CFrame
end

inCommandFrame.Visible = false

ContextActionService:BindActionAtPriority(
	POSSESS_ACTION_NAME,
	on_possess_action,
	false,
	INPUT_PRIORITY,
	POSSESS_KEY
)

ContextActionService:BindActionAtPriority(
	SHOOT_ACTION_NAME,
	on_shoot_action,
	false,
	INPUT_PRIORITY,
	Enum.UserInputType.MouseButton1
)

ContextActionService:BindActionAtPriority(
	ABILITY_ONE_ACTION_NAME,
	on_ability_one_action,
	false,
	INPUT_PRIORITY,
	Enum.KeyCode.One
)

ContextActionService:BindActionAtPriority(
	ABILITY_TWO_ACTION_NAME,
	on_ability_two_action,
	false,
	INPUT_PRIORITY,
	Enum.KeyCode.Two
)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refresh_camera)
possessEvent.OnClientEvent:Connect(on_possess_confirm)
playVFXEvent.OnClientEvent:Connect(on_play_vfx)
RunService.RenderStepped:Connect(on_render_step)