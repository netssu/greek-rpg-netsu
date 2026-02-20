local Handler = {}

local MarketPlaceService = game:GetService("MarketplaceService")

-- Important variables / locations

local Players = game.Players
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local MainUi = PlayerGui:WaitForChild("TD")

local Started = false
local FrameCooldown = false
local OpenedFrames = {}

-- Preset TweenInfo's 

local OpenFrame = TweenInfo.new(.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)
local CloseFrame = TweenInfo.new(.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local HoverIn = TweenInfo.new(.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, 0)
local HoverOut = TweenInfo.new(.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local ClickSquish = TweenInfo.new(.08, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local ClickBounce = TweenInfo.new(.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, false, 0)
local IconWobble = TweenInfo.new(.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local IconReset = TweenInfo.new(.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Requires

local Requires = script.Parent.Parent:WaitForChild("Requires")
local TweenModule = require(Requires:WaitForChild("TweenManager"))
local SoundManager = require(Requires:WaitForChild("SoundManager"))
local MaidHandler = require(Requires:WaitForChild("MaidHandler")) -- maid handler is used to clear up unneeded connections (when a button is removed)

-- Services

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

function Handler.GetSize(Size, Multi : number)
	return UDim2.new(Size.X.Scale * Multi, 0, Size.Y.Scale * Multi, 0)
end

function Handler.GetPrice(productId, Type)
	local success, info = pcall(function()
		return MarketPlaceService:GetProductInfo(productId, Type)
	end)
	return (success and info and info.PriceInRobux) or nil
end

function Handler.ToggleUi(Frame) -- FRAME Toggle (Enables / Disables Frames)
	if FrameCooldown then return end
	FrameCooldown = true

	Frame = MainUi.Frames:FindFirstChild(Frame)

	-- Disables all currently open frames

	for i = #OpenedFrames, 1, -1 do
		if OpenedFrames[i] ~= Frame then
			OpenedFrames[i].Visible = false
			table.remove(OpenedFrames, i)
		end
	end

	if Frame and Frame.Visible then -- If frames visible play the close anim
		TweenService:Create(Frame, CloseFrame, {Position = UDim2.new(.5,0,1.3,0)}):Play()
		TweenService:Create(workspace.CurrentCamera, CloseFrame, {FieldOfView = 70}):Play()
		task.wait(.18)
		Frame.Visible = false
	elseif Frame then -- Open it otherwise
		Frame.Visible = true
		Frame.Position = UDim2.new(.5,0,1.3,0)
		table.insert(OpenedFrames, Frame)
		TweenService:Create(Frame, OpenFrame, {Position = UDim2.new(.5,0,.5,0)}):Play()
		TweenService:Create(workspace.CurrentCamera, OpenFrame, {FieldOfView = 90}):Play()
		task.wait(.25)
	end
	FrameCooldown = false -- Toggles cooldown so anims dont overlap
end

function Handler.Button(Button, MainUi)
	if not(Button) or Handler[Button] then return end
	local connections = {}
	local OriginalSize = Button.Size
	local OriginalPos = Button.Position
	local Hovering = false
	local Clicking = false
	local Icon = Button:FindFirstChild("Icon")
	local OriginalRotation = Icon and Icon.Rotation or 0

	if Button.Name ~= "Endless" then
		Button.Interactable = true 
	end

	Handler[Button] = true

	local productId = Button:GetAttribute("ProductId")
	local gamepassId = Button:GetAttribute("GamepassId")

	if Button:FindFirstChild("Price") then
		if productId then
			Button.Price.Text = Handler.GetPrice(productId, Enum.InfoType.Product)
		elseif gamepassId then
			Button.Price.Text = Handler.GetPrice(gamepassId, Enum.InfoType.GamePass)
		end
	end

	table.insert(connections, Button.AncestryChanged:Connect(function(_, parent)
		if not parent then
			MaidHandler.CleanConnections(connections)
		end
	end))

	table.insert(connections, Button.MouseEnter:Connect(function()
		Hovering = true
		if not Clicking then
			TweenModule.Tween(Button, HoverIn, {
				Size = Handler.GetSize(OriginalSize, 1.075),
				Position = UDim2.new(OriginalPos.X.Scale, OriginalPos.X.Offset, OriginalPos.Y.Scale, OriginalPos.Y.Offset - 4)
			})
		end
		if Icon then
			TweenModule.Tween(Icon, IconWobble, {Rotation = OriginalRotation + 12})
		end
		SoundManager.PlaySound("Hover")
	end))

	table.insert(connections, Button.MouseLeave:Connect(function()
		Hovering = false
		if not Clicking then
			TweenModule.Tween(Button, HoverOut, {
				Size = OriginalSize,
				Position = OriginalPos
			})
		end
		if Icon then
			TweenModule.Tween(Icon, IconReset, {Rotation = OriginalRotation})
		end
	end))

	table.insert(connections, Button.Activated:Connect(function()
		Clicking = true

		TweenModule.Tween(Button, ClickSquish, {
			Size = Handler.GetSize(OriginalSize, .85),
			Position = UDim2.new(OriginalPos.X.Scale, OriginalPos.X.Offset, OriginalPos.Y.Scale, OriginalPos.Y.Offset + 3)
		})

		if Icon then
			TweenModule.Tween(Icon, ClickSquish, {Rotation = OriginalRotation - 8})
		end

		if Button:GetAttribute("ProductId") then
			MarketPlaceService:PromptProductPurchase(game.Players.LocalPlayer, Button:GetAttribute("ProductId"))
		elseif Button:GetAttribute("GamepassId") then
			MarketPlaceService:PromptGamePassPurchase(game.Players.LocalPlayer, Button:GetAttribute("GamepassId"))
		end

		task.delay(.08, function()
			Clicking = false
			local targetSize = Hovering and Handler.GetSize(OriginalSize, 1.1) or OriginalSize
			local targetPos = Hovering and UDim2.new(OriginalPos.X.Scale, OriginalPos.X.Offset, OriginalPos.Y.Scale, OriginalPos.Y.Offset - 4) or OriginalPos
			TweenModule.Tween(Button, ClickBounce, {Size = targetSize, Position = targetPos})
			if Icon then
				local targetRot = Hovering and (OriginalRotation + 12) or OriginalRotation
				TweenModule.Tween(Icon, IconWobble, {Rotation = targetRot})
			end
		end)

		if Button:GetAttribute("FrameName") then
			Handler.ToggleUi(Button:GetAttribute("FrameName"))
		end

		SoundManager.PlaySound("Click")
	end))
end

function Handler.Init()
	if Started then return end

	Started = true

	for _, Button in ipairs(CollectionService:GetTagged("Button")) do
		if Button:IsA("GuiButton") then
			Handler.Button(Button)
		end
	end
	
	CollectionService:GetInstanceAddedSignal("Button"):Connect(function(Button)
	--	print(Button)
		if Button:IsA("GuiButton") then
			Handler.Button(Button)
		end
	end)
end

Handler.Init()

return Handler