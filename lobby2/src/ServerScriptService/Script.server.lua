-- SERVICES

local Players = game:GetService("Players")

-- CONSTANTS

local TARGET_PLAYER = "ckaosgames2"
local CONSUMABLES_TO_GIVE = { "Apple", "Banana", "Orange" }

-- FUNCTIONS

local function GiveConsumables(Player: Player)
	if Player.Name ~= TARGET_PLAYER then return end

	local UserData = Player:WaitForChild("UserData", 15)
	if not UserData then warn("[TEST] UserData não encontrado.") return end

	local ConsumablesFolder = UserData:WaitForChild("Consumables", 15)
	if not ConsumablesFolder then warn("[TEST] Pasta Consumables não encontrada.") return end

	local DataManager = require(game.ServerStorage.Modules.Managers.DataManager)

	local Profile = DataManager.Stored[Player.UserId]
	if not Profile or not Profile:IsActive() then
		warn("[TEST] Profile não encontrado para " .. Player.Name)
		return
	end

	if typeof(Profile.Data.Consumables) ~= "table" then
		Profile.Data.Consumables = {}
	end

	for _, ConsumableName in ipairs(CONSUMABLES_TO_GIVE) do
		local key = tostring(#ConsumablesFolder:GetChildren() + 1)

		local NewValue = Instance.new("StringValue")
		NewValue.Name = key
		NewValue.Value = ConsumableName
		NewValue.Parent = ConsumablesFolder

		Profile.Data.Consumables[key] = ConsumableName

		print("[TEST] Dado consumível: " .. ConsumableName .. " para " .. Player.Name)
	end
end

-- INIT

for _, Player in ipairs(Players:GetPlayers()) do
	task.spawn(GiveConsumables, Player)
end

Players.PlayerAdded:Connect(GiveConsumables)