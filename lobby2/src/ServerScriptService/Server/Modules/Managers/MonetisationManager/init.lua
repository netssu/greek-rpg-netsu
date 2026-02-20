-- // services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local BadgeService = game:GetService("BadgeService")

-- // tables

local productIds = require(script.Products)
local gamepassIds = require(script.Gamepasses)

local purchaseData = {}

-- // functions

local function findData(UserDataFolder : Folder, DataName : string)
	for _, Value in ipairs(UserDataFolder:GetDescendants()) do
		if Value:IsA("StringValue") or Value:IsA("IntValue") or Value:IsA("NumberValue") or Value:IsA("BoolValue") then
			if Value.Name == DataName then
				return Value
			end
		end
	end
end

-- // connections

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	if purchased == true then
		
		local Player = game.Players:GetPlayerByUserId(userId)
		if not Player then return end
		
		ReplicatedStorage.Remotes.Notification.SendNotification:FireClient(Player, "Thank you for your purchase!", "Success")
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	
	-- // safely locate player

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		warn("Player not found for userId: " .. receiptInfo.PlayerId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	-- // vars

	local productId = receiptInfo.ProductId
	local ProductInfo = MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	local Price = ProductInfo.PriceInRobux
	
	-- // get userdata
	
	local UserData = player:FindFirstChild("UserData")
	if not UserData then return end
	
	local RobuxSpent = findData(UserData, "RobuxSpent")
	if not RobuxSpent then return end
	
	if productId == productIds["500 Coins"] then
		local Coins = findData(UserData, "Money")
		if not Coins then return end
		
		Coins.Value = Coins.Value + 500
	elseif productId == productIds["1000 Coins"] then
		local Coins = findData(UserData, "Money")
		if not Coins then return end

		Coins.Value = Coins.Value + 1000
	elseif productId == productIds["3000 Coins"] then
		local Coins = findData(UserData, "Money")
		if not Coins then return end

		Coins.Value = Coins.Value + 3000
	elseif productId == productIds["15000 Coins"] then
		local Coins = findData(UserData, "Money")
		if not Coins then return end

		Coins.Value = Coins.Value + 15000
	elseif productId == productIds["55000 Coins"] then
		local Coins = findData(UserData, "Money")
		if not Coins then return end

		Coins.Value = Coins.Value + 55000
	elseif productId == productIds["Diamond Crate"] then
		
		local Data = findData(UserData, "Diamond")
		if not Data then return end

		Data.Value = Data.Value + 1
		
	elseif productId == productIds["5 Diamond Crates"] then

		local Data = findData(UserData, "Diamond")
		if not Data then return end

		Data.Value = Data.Value + 5
		
	elseif productId == productIds["10 Diamond Crates"] then

		local Data = findData(UserData, "Diamond")
		if not Data then return end

		Data.Value = Data.Value + 10
	
	end
	
	RobuxSpent.Value = RobuxSpent.Value + Price
	
end


return {}