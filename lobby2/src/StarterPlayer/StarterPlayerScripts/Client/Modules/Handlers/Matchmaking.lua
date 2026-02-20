local Handler = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local MainUi = PlayerGui:WaitForChild("TD")
local Frames = MainUi:WaitForChild("Frames")
local SearchingFrame = MainUi:WaitForChild("Searching") -- Tela de "Procurando..."
local InnerSearch = SearchingFrame:WaitForChild("Frame")
local CancelButton = InnerSearch:WaitForChild("End")
local StatusLabel = InnerSearch:WaitForChild("Status")
local TimeLabel = InnerSearch:WaitForChild("Time")

local SetupFrameName = "MatchSetup" -- Exemplo: Frames.MatchSetup
local PlayButtonName = "Play" -- Nome do botão "Jogar" dentro dessa frame

-- Referência para a Frame de Setup (Crie essa UI em Frames se não existir)
local SetupFrame = Frames:FindFirstChild(SetupFrameName) 
if not SetupFrame then
	-- Tenta achar recursivamente se não estiver direto em Frames
	SetupFrame = Frames:FindFirstChild(SetupFrameName, true) 
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchmakingRemotes = Remotes:WaitForChild("Matchmaking")
local ClientSearching = MatchmakingRemotes:WaitForChild("ClientSearching")
local RequestQueue = MatchmakingRemotes:WaitForChild("RequestQueue")
local CancelMatchmaking = MatchmakingRemotes:WaitForChild("CancelMatchmaking")

local MatchmakingZones = Workspace:WaitForChild("TouchParts") 

local currentZone = nil
local isQueued = false
local isSettingUp = false
local timerRunning = false

-- Verifica em qual zona o jogador está
local function getZoneCharacterIsIn()
	local character = Player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end

	local hrp = character.HumanoidRootPart
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local parts = Workspace:GetPartsInPart(hrp, overlapParams)

	for _, part in ipairs(parts) do
		if part.Parent == MatchmakingZones then
			return part
		end
	end
	return nil
end

-- Chamado quando o jogador clica em "Jogar" no menu de Setup
local function startMatchmakingFromSetup()
	if not currentZone then return end
	if not SetupFrame then return end

	-- Aqui você coleta os dados que o jogador escolheu na UI
	-- Se você usar atributos na Frame (ex: setar "SelectedDifficulty" quando clicar no botão "Hard"), pegue aqui.
	-- Caso contrário, pegamos o padrão da Zona.

	local map = currentZone:GetAttribute("Map")
	local gamemode = SetupFrame:GetAttribute("SelectedGamemode") or currentZone:GetAttribute("Gamemode") or "survival"
	local difficulty = SetupFrame:GetAttribute("SelectedDifficulty") or currentZone:GetAttribute("Difficulty") or "Normal"
	local squad = SetupFrame:GetAttribute("SelectedSquad") or currentZone:GetAttribute("Squad") or "Solo"

	local data = {
		Map = map,
		Gamemode = gamemode,
		Difficulty = difficulty,
		Squad = squad
	}

	-- Transição de Setup -> Fila
	isSettingUp = false
	isQueued = true
	SetupFrame.Visible = false 
	warn("aq")
	RequestQueue:FireServer(data)
end

------------------//VARIABLES
local joinedAt: number = os.clock()

------------------//INIT
if SetupFrame then
	local btn: Instance? = SetupFrame:FindFirstChild(PlayButtonName, true)
	if btn and btn:IsA("GuiButton") then
		btn.MouseButton1Click:Connect(function()
			if os.clock() - joinedAt < 1 then return end
			if not isSettingUp then return end
			if not SetupFrame.Visible then return end
			startMatchmakingFromSetup()
		end)
	else
		warn("Matchmaking: Botão '" .. PlayButtonName .. "' não encontrado na Frame de Setup.")
	end
end


RunService.Heartbeat:Connect(function()
	local zone = getZoneCharacterIsIn()

	if zone then
		-- Jogador está DENTRO da zona
		if zone ~= currentZone then
			-- Mudança de zona ou entrou agora
			currentZone = zone

			-- Se estava na fila de outra zona, cancela
			if isQueued then
				warn("aq")
				CancelMatchmaking:FireServer()
				isQueued = false
			end

			-- MOSTRA O SETUP
			isSettingUp = true
			if SetupFrame then
				SetupFrame.Visible = true
			end
			SearchingFrame.Visible = false
		end

		-- Se o jogador continuar na zona, nada acontece até ele clicar em "Jogar"

	else
		-- Jogador está FORA da zona
		if currentZone then
			-- Saiu da zona agora

			if isQueued then
				warn("aq")
				CancelMatchmaking:FireServer() -- Cancela a busca
				StatusLabel.Text = "Cancelled (Left Zone)"
				isQueued = false
			end

			if isSettingUp then
				if SetupFrame then SetupFrame.Visible = false end -- Fecha o setup
				isSettingUp = false
			end

			SearchingFrame.Visible = false
			currentZone = nil
		end
	end
end)

-- Resposta do Servidor (Começou a buscar ou Cancelou)
ClientSearching.OnClientEvent:Connect(function(statusText: string)
	if statusText == "Cancelled" then
		SearchingFrame.Visible = false
		isQueued = false
		-- Se cancelou mas ainda tá na zona, reabre o setup
		if currentZone and SetupFrame then
			isSettingUp = true
			SetupFrame.Visible = true
		end
		return
	end

	StatusLabel.Text = statusText
	SearchingFrame.Visible = true

	-- Garante que o setup sumiu
	if SetupFrame then SetupFrame.Visible = false end

	-- Timer visual
	if timerRunning then return end
	timerRunning = true
	local startTime = tick()
	task.spawn(function()
		while SearchingFrame.Visible do
			local elapsed = math.floor(tick() - startTime)
			TimeLabel.Text = string.format("%02d:%02d", elapsed // 60, elapsed % 60)
			task.wait(1)
		end
		timerRunning = false
	end)
end)

CancelButton.Activated:Connect(function()
	SearchingFrame.Visible = false
	isQueued = false
	warn("aq")
	CancelMatchmaking:FireServer()
end)

return Handler