local Handler = {}

--services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

--player references
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui

--ui references
local MainGui = PlayerGui:WaitForChild("TD")
local Frames = MainGui:WaitForChild("Frames")

--data references
local UserData = Player:WaitForChild("UserData")

--modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local StoredData = Modules:WaitForChild("StoredData")
local TowerData = require(StoredData:WaitForChild("TowerData"))
local CrateData = require(StoredData:WaitForChild("CrateData"))

--config and assets
local CurrencyConfig = {
	Coins = {Symbol = "$", Color = Color3.fromRGB(255, 213, 0), UseIcon = true},
	Gems = {Symbol = "", Color = Color3.fromRGB(0, 255, 127), UseIcon = false},
	Robux = {Symbol = "R$", Color = Color3.fromRGB(0, 255, 0), UseIcon = false}
}

local RarityOrder = {"Mythic", "Legendary", "Epic", "Rare", "Common"}

--chance templates
local ChanceCommon = script.Template_Common_Chance
local ChanceUncommon = script.Template_Uncommon_Chance
local ChanceRare = script.Template_Rare_Chance
local ChanceEpic = script.Template_Epic_Chance
local ChanceLegendary = script.Template_Legendary_Chance

--returns the appropriate chance template based on rarity
local function getChance(rarity)
	rarity = rarity or "Common"

	if rarity == "Common" then
		return ChanceCommon:Clone()
	elseif rarity == "Uncommon" then
		return ChanceUncommon:Clone()
	elseif rarity == "Rare" then
		return ChanceRare:Clone()
	elseif rarity == "Epic" then
		return ChanceEpic:Clone()
	elseif rarity == "Legendary" or rarity == "Mythic" then
		return ChanceLegendary:Clone()
	end

	warn("Unknown rarity:", rarity)
	return ChanceCommon:Clone()
end

--formats a number with commas
local function formatWithCommas(n)
	return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

--rotation logic
local function getUnitsInRotation(targetRarity)
	local allUnitsOfRarity = {}

	for unitName, tier in pairs(CrateData.UnitTiers) do
		if tier == targetRarity then
			table.insert(allUnitsOfRarity, unitName)
		end
	end

	table.sort(allUnitsOfRarity) 

	if #allUnitsOfRarity == 0 then return {} end

	local currentHour = math.floor(os.time() / 3600)
	local rng = Random.new(currentHour)

	if #allUnitsOfRarity <= 2 then
		return allUnitsOfRarity
	end

	local rotatedUnits = {}
	local available = {table.unpack(allUnitsOfRarity)} 

	for i = 1, 2 do
		if #available == 0 then break end
		local idx = rng:NextInteger(1, #available)
		table.insert(rotatedUnits, available[idx])
		table.remove(available, idx)
	end

	return rotatedUnits
end

--helper to get the best unit
local function getBestUnitForBanner(bannerName)
	local bannerInfo = CrateData.Banners[bannerName]
	if not bannerInfo then return nil end

	for _, rarity in ipairs(RarityOrder) do
		if bannerInfo.Rates[rarity] and bannerInfo.Rates[rarity] > 0 then
			local units = getUnitsInRotation(rarity)
			if units and #units > 0 then
				return units[1] 
			end
		end
	end

	return "Scout"
end

-- Function to completely detach a button from GuiManager
local function SanitizeButton(originalButton, parent)
	local clone = originalButton:Clone()

	-- Remove the tag so GuiManager ignores it
	if CollectionService:HasTag(clone, "Button") then
		CollectionService:RemoveTag(clone, "Button")
	end

	clone.Parent = parent
	originalButton:Destroy() -- Kill the old one that GuiManager is tracking

	return clone
end

-- Custom Hover Animation
local function AddHoverEffect(button)
	local originalSize = button.Size

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.new(originalSize.X.Scale * 1.075, 0, originalSize.Y.Scale * 1.075, 0)
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = originalSize
		}):Play()
	end)

	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.new(originalSize.X.Scale * 0.9, 0, originalSize.Y.Scale * 0.9, 0)
		}):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.new(originalSize.X.Scale * 1.1, 0, originalSize.Y.Scale * 1.1, 0)
		}):Play()
	end)
end

--handles all crate ui functionality
local function HandleCrateUI()
	task.spawn(function()

		--ui references
		local CrateFrame = Frames:WaitForChild("Crates")
		local PreviewContainer = CrateFrame:WaitForChild("ItemFrame")
		local ChancesFrame = CrateFrame:WaitForChild("ChancesFrame")
		local CratesContainer = CrateFrame:WaitForChild("ScrollingFrame")

		--remove layout constraints to prevent button jumping
		for _, child in ipairs(PreviewContainer:GetChildren()) do
			if child:IsA("UIListLayout") or child:IsA("UIGridLayout") then
				child:Destroy()
			end
		end

		--preview elements
		local PreviewTitle = PreviewContainer:WaitForChild("CrateName")
		local OpenButtonOriginal = PreviewContainer:WaitForChild("Open")
		local PurchaseButtonOriginal = PreviewContainer:WaitForChild("Buy")
		local ChancesButtonOriginal = PreviewContainer:WaitForChild("Chances")

		-- REPLACE BUTTONS TO KILL GUIMANAGER CONFLICT
		local ChancesButton = SanitizeButton(ChancesButtonOriginal, PreviewContainer)
		AddHoverEffect(ChancesButton)

		local OpenButton = OpenButtonOriginal
		local PurchaseButton = PurchaseButtonOriginal

		local PriceText = PurchaseButton:WaitForChild("Frame"):WaitForChild("Price")
		local OwnedAmountLabel = OpenButton:WaitForChild("Owned")
		local CrateIcon = PreviewContainer:WaitForChild("MainIcon")

		--scripted ui elements

		--timer label
		local TimerLabel = Instance.new("TextLabel")
		TimerLabel.Name = "ResetTimer"
		TimerLabel.Size = UDim2.new(1, 0, 0, 35)
		TimerLabel.Position = UDim2.new(0, 0, 0.12, 0) 
		TimerLabel.BackgroundTransparency = 1
		TimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		TimerLabel.TextStrokeTransparency = 0
		TimerLabel.Font = Enum.Font.GothamBlack 
		TimerLabel.TextSize = 32
		TimerLabel.ZIndex = 100 
		TimerLabel.Parent = PreviewContainer

		--chances button positioning setup
		ChancesButton.AnchorPoint = Vector2.new(0.5, 0)
		ChancesButton.Position = UDim2.new(0.5, 0, 0.22, 0)
		-- ZINDEX 302: O botão ? tem que estar ACIMA da lista (que será 300)
		--ChancesButton.ZIndex = 302 

		--pity label
		local PityLabel = Instance.new("TextLabel")
		PityLabel.Name = "PityCounter"
		PityLabel.Size = UDim2.new(1, 0, 0, 20)
		PityLabel.Position = UDim2.new(0, 0, 0.65, 0) 
		PityLabel.BackgroundTransparency = 1
		PityLabel.TextColor3 = Color3.fromRGB(255, 85, 127)
		PityLabel.TextStrokeTransparency = 0
		PityLabel.Font = Enum.Font.GothamBlack
		PityLabel.TextSize = 16
		PityLabel.ZIndex = 100 
		PityLabel.Parent = PreviewContainer

		--state
		local SelectedCrate = "Normal"

		--crate icon assets
		local CrateIcons = {
			Normal = "rbxassetid://79132028062877",
			Steel = "rbxassetid://78854786317873",
			Golden = "rbxassetid://77544826310708",
			Diamond = "rbxassetid://139414131564390",
		}

		--update preview function
		local function updatePreview(hideItemFrame)
			local BannerInfo = CrateData.Banners[SelectedCrate]

			--toggle visibility
			if not hideItemFrame then
				CrateFrame.ItemFrame.Visible = true
			else
				CrateFrame.ChancesFrame.Visible = false
			end

			--update labels
			PreviewTitle.Text = BannerInfo and BannerInfo.DisplayName or SelectedCrate

			--update pity
			local pityFolder = UserData:FindFirstChild("BannerPity")
			local currentPity = 0
			if pityFolder and pityFolder:FindFirstChild(SelectedCrate) then
				currentPity = pityFolder[SelectedCrate].Value
			end
			local threshold = BannerInfo and BannerInfo.PityThreshold or 50
			PityLabel.Text = "PITY: " .. currentPity .. " / " .. threshold

			--update icon
			if CrateIcons[SelectedCrate] then
				CrateIcon.Image = CrateIcons[SelectedCrate]
			end

			--update owned amount
			local CratesFolder = UserData:FindFirstChild("Crates")
			local ownedAmount = 0
			if CratesFolder and CratesFolder:FindFirstChild(SelectedCrate) then
				ownedAmount = CratesFolder[SelectedCrate].Value
			end

			OwnedAmountLabel.Visible = true
			OwnedAmountLabel.Text = "Owned: " .. ownedAmount
			OpenButton.Visible = true 

			--update price
			if BannerInfo then
				local currencyData = CurrencyConfig[BannerInfo.Currency] or CurrencyConfig.Coins

				PriceText.TextColor3 = currencyData.Color
				PriceText.Parent.Icon.Visible = currencyData.UseIcon

				if BannerInfo.Currency == "Gems" then
					PriceText.Text = currencyData.Symbol .. " " .. formatWithCommas(BannerInfo.Price)
				else
					PriceText.Text = currencyData.Symbol .. formatWithCommas(BannerInfo.Price)
				end
			else
				PriceText.Text = "???"
			end
		end

		--timer loop WITH POSITION LOCK
		RunService.Heartbeat:Connect(function()
			if not CrateFrame.Visible then return end

			local currentTime = os.time()
			local nextHour = math.ceil(currentTime / 3600) * 3600
			local diff = nextHour - currentTime

			local minutes = math.floor(diff / 60)
			local seconds = diff % 60

			TimerLabel.Text = string.format("RESET: %02d:%02d", minutes, seconds)

			if minutes < 1 then
				TimerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			else
				TimerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			end

			-- FORCE POSITION EVERY FRAME (Double protection)
			ChancesButton.AnchorPoint = Vector2.new(0.5, 0)
			ChancesButton.Position = UDim2.new(0.5, 0, 0.22, 0)
		end)

		--setup crate buttons (REMOVED VIEWPORT LOGIC AS REQUESTED)
		for _, Button in ipairs(CratesContainer:GetChildren()) do
			if not Button:IsA("ImageButton") then continue end

			local Holder = Button:FindFirstChild("Holder")
			local ButtonPriceText = Holder:FindFirstChild("Price")

			local BannerInfo = CrateData.Banners[Button.Name]

			if BannerInfo then
				local currencyData = CurrencyConfig[BannerInfo.Currency] or CurrencyConfig.Coins

				if BannerInfo.Currency == "Gems" then
					ButtonPriceText.Text = currencyData.Symbol .. " " .. formatWithCommas(BannerInfo.Price)
					ButtonPriceText.TextColor3 = currencyData.Color
				else
					ButtonPriceText.Text = currencyData.Symbol .. formatWithCommas(BannerInfo.Price)
					ButtonPriceText.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			else
				ButtonPriceText.Text = "N/A"
			end

			Button.Activated:Connect(function()
				SelectedCrate = Button.Name
				ChancesFrame.Visible = false
				updatePreview()
			end)

			-- REMOVIDO: MouseEnter/MouseLeave do Viewport (O "segundo glossário")
		end

		--visible signal
		CrateFrame:GetPropertyChangedSignal("Visible"):Connect(function()
			if CrateFrame.Visible then
				updatePreview(true)
			end
		end)

		--chances hover
		ChancesButton.MouseEnter:Connect(function()
			ChancesFrame.Visible = true
			-- ZINDEX 300: Glossário acima de tudo, menos do botão ?
			ChancesFrame.ZIndex = 300 

			for _, Frame in ipairs(ChancesFrame:GetChildren()) do
				if Frame:IsA("ImageButton") then
					Frame:Destroy()
				end
			end

			if not SelectedCrate then return end
			local BannerInfo = CrateData.Banners[SelectedCrate]
			if not BannerInfo then return end

			local Rates = BannerInfo.Rates

			for _, RarityName in ipairs(RarityOrder) do
				local RateValue = Rates[RarityName]

				if RateValue and RateValue > 0 then

					local activeUnits = getUnitsInRotation(RarityName)

					if #activeUnits == 0 then continue end

					for _, unitName in ipairs(activeUnits) do
						local NewEntry = getChance(RarityName)
						NewEntry.Parent = ChancesFrame
						NewEntry.Visible = true

						NewEntry.Size = UDim2.new(1, 0, 0, 50) 
						-- ZINDEX 301: Itens da lista acima do fundo da lista
						NewEntry.ZIndex = 301

						local individualChance = (RateValue / 100) / #activeUnits

						NewEntry.Chance.Text = string.format("%.2f%%", individualChance)
						NewEntry.WormName.Text = unitName 

						-- Setar ZIndex dos textos e imagens
						NewEntry.Chance.ZIndex = 301
						NewEntry.WormName.ZIndex = 301

						if TowerData[unitName] and TowerData[unitName].ImageId then
							NewEntry.Worm_Icon.Visible = true
							NewEntry.Worm_Icon.Image = "rbxassetid://" .. TowerData[unitName].ImageId
							NewEntry.Worm_Icon.ZIndex = 301
						else
							NewEntry.Worm_Icon.Visible = false
						end
					end
				end
			end
		end)

		ChancesButton.MouseLeave:Connect(function()
			ChancesFrame.Visible = false
		end)

		--open handler
		OpenButton.Activated:Connect(function()
			ReplicatedStorage.Remotes.Game.Unbox:FireServer(SelectedCrate)
			updatePreview()
		end)

		--buy handler
		PurchaseButton.Activated:Connect(function()
			local CratesFolder = UserData:FindFirstChild("Crates")
			if not CratesFolder then return end

			local BannerInfo = CrateData.Banners[SelectedCrate]
			if not BannerInfo then return end

			local Crate = CratesFolder:FindFirstChild(SelectedCrate)
			local oldAmount = Crate and Crate.Value or 0

			if BannerInfo.Currency == "Robux" then
				if SelectedCrate == "Diamond" then
					MarketplaceService:PromptProductPurchase(Player, 3449816999)
				end
			else
				ReplicatedStorage.Remotes.Game.PurchaseBox:FireServer(SelectedCrate)
			end

			task.spawn(function()
				local timeout = 5
				local startTime = tick()
				local found = false

				repeat
					task.wait(0.1)
					Crate = CratesFolder:FindFirstChild(SelectedCrate)
					if Crate and Crate.Value > oldAmount then
						found = true
					end
				until found or (tick() - startTime > timeout)

				if found then
					ReplicatedStorage.Remotes.Game.Unbox:FireServer(SelectedCrate)
					updatePreview()
				end
			end)
		end)
	end)
end

--initialize
HandleCrateUI()

return Handler