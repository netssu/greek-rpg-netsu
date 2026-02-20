local TweenModule = {}
local TweenService = game:GetService("TweenService")

function TweenModule.Tween(object, info, goal)
	local tween = TweenService:Create(object, info, goal)
	tween:Play()
	return tween
end

return TweenModule