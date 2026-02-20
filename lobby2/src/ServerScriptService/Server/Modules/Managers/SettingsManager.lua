-- // services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- // variables

local Remotes = ReplicatedStorage.Remotes

-- // functions

local function findSetting(Player : Player, SettingName : string)
	local UserData = Player:FindFirstChild("UserData")
	for _, Value in ipairs(UserData:GetDescendants()) do
		if Value.Name == SettingName then
			return Value
		end
	end
end

-- // code

Remotes.Settings.changeSetting.OnServerEvent:Connect(function(Player : Player, SettingName : string, Value : boolean)
	
	local TargetValue = findSetting(Player, SettingName)
	if not TargetValue then	return end
	
	TargetValue.Value = Value
	
end)

return {}