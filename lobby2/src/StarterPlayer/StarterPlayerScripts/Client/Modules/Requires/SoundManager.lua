local Handler = {}

local SoundService = game.SoundService

local Player = game.Players.LocalPlayer

function Handler.PlaySound(Sound)
	if Player.UserData.Settings.SFXEnabled.Value then
		if SoundService:FindFirstChild(Sound) then
			SoundService:FindFirstChild(Sound):Play()
		else
			warn(Sound.." doesnt exist")
		end
	end
end

return Handler