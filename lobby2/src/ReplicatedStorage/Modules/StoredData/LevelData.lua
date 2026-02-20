local LevelData = {}

local maxLevel = 50
local baseXP = 100
local scale = 1.154

for level = 1, maxLevel do
	local xpRequired = math.floor(baseXP * ((level - 1) ^ scale + 1))
	LevelData[tostring(level)] = {
		MaxXP = xpRequired
	}
end

return LevelData