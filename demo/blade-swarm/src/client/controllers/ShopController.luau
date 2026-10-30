--!nonstrict
-- Between-wave upgrade shop overlay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local MathUtil = require(Shared.MathUtil)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local ShopController = {}

local localPlayer = Players.LocalPlayer
local colors = Theme.Colors

local gui: ScreenGui
local dim: Frame
local window: Frame
local timerLabel: TextLabel
local cardArea: Frame
local rerollButton: TextButton
local readyButton: TextButton
local coinsLabel: TextLabel
local cards = {}

local phase = "Waiting"
local endsAt = 0
local coins = 0
local offers = nil
local rerollCost = Config.RerollBaseCost
local ready = false
local displayedSignature = ""
local isOpen = false

local function canAfford(price: number): boolean
	return coins >= price
end

local function signatureOf(list): string
	local ids = {}
	for _, offer in list do
		table.insert(ids, offer.id)
	end
	return table.concat(ids, ",")
end

-- Card construction --------------------------------------------------------

local function makeCard(index: number)
	local holder = Theme.new("Frame", {
		Name = "Card" .. index,
		LayoutOrder = index,
		Size = UDim2.new(0.31, 0, 1, 0),
		BackgroundTransparency = 1,
	}, cardArea)

	local card = Theme.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.PanelLight,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, holder)
	Theme.corner(card, 14)
	local stroke = Theme.stroke(card, colors.Common, 2.5, 0.2)
	local hover = Theme.scaleOf(card, "HoverScale")

	local strip = Theme.new("Frame", {
		Name = "Strip",
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = colors.Common,
		BorderSizePixel = 0,
	}, card)

	local rarity = Theme.label(card, {
		Name = "Rarity",
		Position = UDim2.fromScale(0, 0.04),
		Size = UDim2.fromScale(1, 0.07),
		FontFace = Theme.Fonts.Bold,
		TextScaled = true,
		TextColor3 = colors.Common,
		Text = "COMMON",
	})
	Theme.textSizeLimit(rarity, 8, 14)

	local icon = Theme.label(card, {
		Name = "Icon",
		Position = UDim2.fromScale(0, 0.12),
		Size = UDim2.fromScale(1, 0.26),
		TextScaled = true,
		Text = "?",
	})
	Theme.textSizeLimit(icon, 20, 72)

	local name = Theme.label(card, {
		Name = "Name",
		Position = UDim2.fromScale(0.05, 0.39),
		Size = UDim2.fromScale(0.9, 0.1),
		FontFace = Theme.Fonts.Title,
		TextScaled = true,
		Text = "",
	})
	Theme.textSizeLimit(name, 12, 26)

	local description = Theme.label(card, {
		Name = "Description",
		Position = UDim2.fromScale(0.08, 0.5),
		Size = UDim2.fromScale(0.84, 0.2),
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = colors.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
	})
	Theme.textSizeLimit(description, 9, 17)

	local buy = Theme.new("TextButton", {
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.94),
		Size = UDim2.fromScale(0.74, 0.16),
		BackgroundColor3 = colors.Gold,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = Theme.Fonts.Title,
		TextScaled = true,
		TextColor3 = Color3.fromHex("2b1d00"),
		Text = "🪙 0",
	}, card)
	Theme.corner(buy, 12)
	Theme.textSizeLimit(buy, 12, 26)
	Theme.new("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0) }, buy)

	local sold = Theme.new("Frame", {
		Name = "Sold",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
	}, card)
	local soldLabel = Theme.label(sold, {
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.Title,
		Text = "SOLD",
		TextColor3 = colors.Good,
		TextScaled = true,
		Rotation = -12,
		ZIndex = 11,
	})
	Theme.textSizeLimit(soldLabel, 20, 64)
	Theme.new("UIPadding", {
		PaddingTop = UDim.new(0.38, 0),
		PaddingBottom = UDim.new(0.38, 0),
		PaddingLeft = UDim.new(0.1, 0),
		PaddingRight = UDim.new(0.1, 0),
	}, soldLabel)

	card.MouseEnter:Connect(function()
		Theme.tween(hover, 0.12, { Scale = 1.05 })
	end)
	card.MouseLeave:Connect(function()
		Theme.tween(hover, 0.12, { Scale = 1 })
	end)

	buy.MouseButton1Click:Connect(function()
		local offer = offers and offers[index]
		if offer and not offer.sold and canAfford(offer.price) and not ready then
			Remotes.get("BuyUpgrade"):FireServer(index)
		end
	end)

	cards[index] = {
		holder = holder,
		stroke = stroke,
		strip = strip,
		rarity = rarity,
		icon = icon,
		name = name,
		description = description,
		buy = buy,
		sold = sold,
	}
end

local function updateCard(index: number)
	local card = cards[index]
	local offer = offers and offers[index]
	if card == nil then
		return
	end
	card.holder.Visible = offer ~= nil
	if offer == nil then
		return
	end

	local rarityColor = Theme.rarityColor(offer.rarity)
	card.stroke.Color = rarityColor
	card.strip.BackgroundColor3 = rarityColor
	card.rarity.Text = string.upper(offer.rarity)
	card.rarity.TextColor3 = rarityColor
	card.icon.Text = offer.icon
	card.name.Text = offer.name
	card.description.Text = offer.description
	card.sold.Visible = offer.sold

	local affordable = canAfford(offer.price)
	card.buy.Text = "🪙 " .. MathUtil.formatNumber(offer.price)
	card.buy.Active = affordable and not offer.sold
	card.buy.BackgroundColor3 = if affordable then colors.Gold else Color3.fromHex("4b5263")
	card.buy.TextColor3 = if affordable then Color3.fromHex("2b1d00") else colors.TextDim
	card.buy.Visible = not offer.sold
end

local function updateButtons()
	local canReroll = not ready and canAfford(rerollCost)
	rerollButton.Text = "🎲 Reroll  🪙 " .. rerollCost
	rerollButton.BackgroundColor3 = if canReroll then colors.Accent else Color3.fromHex("4b5263")
	rerollButton.TextColor3 = if canReroll then Color3.fromHex("032a31") else colors.TextDim

	readyButton.Text = if ready then "Waiting for others..." else "READY ✔"
	readyButton.BackgroundColor3 = if ready then Color3.fromHex("4b5263") else colors.Good
	readyButton.TextColor3 = if ready then colors.TextDim else Color3.fromHex("032a1c")

	coinsLabel.Text = "🪙 " .. MathUtil.formatNumber(coins)
end

local function render()
	if not isOpen or offers == nil then
		return
	end

	local signature = signatureOf(offers)
	local rebuild = signature ~= displayedSignature
	displayedSignature = signature

	for index = 1, Config.ShopOfferCount do
		updateCard(index)
		if rebuild and cards[index] and offers[index] then
			Theme.popIn(cards[index].holder, 0.08 * (index - 1) + 0.05, 0.4)
		end
	end
	updateButtons()
end

-- Open / close -------------------------------------------------------------

local function open()
	if isOpen then
		return
	end
	isOpen = true
	displayedSignature = ""
	gui.Enabled = true

	dim.BackgroundTransparency = 1
	Theme.tween(dim, 0.25, { BackgroundTransparency = 0.45 })
	Theme.popIn(window, 0, 0.4)
	render()
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	offers = nil
	ready = false
	displayedSignature = ""
	gui.Enabled = false
end

local function onStateChanged(newPhase: string, _wave: number, newEndsAt: number)
	phase = newPhase
	endsAt = newEndsAt
	if phase == "Shop" then
		open()
	else
		close()
	end
end

local function onOffers(newOffers, newRerollCost: number, newReady: boolean)
	offers = newOffers
	rerollCost = newRerollCost
	ready = newReady
	render()
end

local function onStats(_stats, newCoins: number)
	coins = newCoins
	if isOpen then
		render()
	end
end

-- Construction -------------------------------------------------------------

local function build()
	gui = Theme.new("ScreenGui", {
		Name = "BladeSwarmShop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, localPlayer:WaitForChild("PlayerGui"))

	dim = Theme.new("Frame", {
		Name = "Dim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromHex("05070d"),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, gui)

	window = Theme.panel(dim, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.78),
		BackgroundTransparency = 0.08,
	})
	Theme.corner(window, 18)
	Theme.new("UIAspectRatioConstraint", { AspectRatio = 1.55, AspectType = Enum.AspectType.FitWithinMaxSize }, window)
	Theme.new("UISizeConstraint", { MinSize = Vector2.new(520, 340), MaxSize = Vector2.new(980, 640) }, window)
	Theme.new("UIScale", { Name = "PopScale", Scale = 1 }, window)

	local title = Theme.label(window, {
		Name = "Title",
		Position = UDim2.fromScale(0.04, 0.03),
		Size = UDim2.fromScale(0.62, 0.1),
		FontFace = Theme.Fonts.Title,
		Text = "Choose your upgrades",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.textSizeLimit(title, 14, 40)

	local timerPill = Theme.panel(window, {
		Name = "TimerPill",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.96, 0.035),
		Size = UDim2.fromScale(0.16, 0.085),
		BackgroundColor3 = colors.PanelLight,
	})
	Theme.corner(timerPill, 20)
	timerLabel = Theme.label(timerPill, {
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.Title,
		Text = "0:20",
		TextColor3 = colors.Accent,
		TextScaled = true,
	})
	Theme.textSizeLimit(timerLabel, 12, 26)
	Theme.new("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0) }, timerLabel)

	cardArea = Theme.new("Frame", {
		Name = "Cards",
		Position = UDim2.fromScale(0.04, 0.16),
		Size = UDim2.fromScale(0.92, 0.6),
		BackgroundTransparency = 1,
	}, window)
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0.03, 0),
	}, cardArea)

	for index = 1, Config.ShopOfferCount do
		makeCard(index)
	end

	rerollButton = Theme.new("TextButton", {
		Name = "Reroll",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.04, 0.95),
		Size = UDim2.fromScale(0.3, 0.11),
		BackgroundColor3 = colors.Accent,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = Theme.Fonts.Title,
		Text = "",
		TextScaled = true,
	}, window)
	Theme.corner(rerollButton, 14)
	Theme.textSizeLimit(rerollButton, 12, 24)
	Theme.new("UIPadding", { PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0) }, rerollButton)

	coinsLabel = Theme.label(window, {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.26, 0.11),
		FontFace = Theme.Fonts.Title,
		Text = "🪙 0",
		TextColor3 = colors.Gold,
		TextScaled = true,
	})
	Theme.textSizeLimit(coinsLabel, 14, 34)

	readyButton = Theme.new("TextButton", {
		Name = "Ready",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.96, 0.95),
		Size = UDim2.fromScale(0.3, 0.11),
		BackgroundColor3 = colors.Good,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = Theme.Fonts.Title,
		Text = "",
		TextScaled = true,
	}, window)
	Theme.corner(readyButton, 14)
	Theme.textSizeLimit(readyButton, 12, 24)
	Theme.new("UIPadding", { PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0) }, readyButton)

	rerollButton.MouseButton1Click:Connect(function()
		if not ready and canAfford(rerollCost) then
			Remotes.get("Reroll"):FireServer()
		end
	end)
	readyButton.MouseButton1Click:Connect(function()
		if not ready then
			ready = true
			updateButtons()
			Remotes.get("ReadyUp"):FireServer()
		end
	end)
	for _, button in { rerollButton, readyButton } do
		button.MouseEnter:Connect(function()
			Theme.tween(Theme.scaleOf(button, "HoverScale"), 0.1, { Scale = 1.05 })
		end)
		button.MouseLeave:Connect(function()
			Theme.tween(Theme.scaleOf(button, "HoverScale"), 0.1, { Scale = 1 })
		end)
	end
end

function ShopController.init()
	build()
end

function ShopController.start()
	Remotes.get("StateChanged").OnClientEvent:Connect(onStateChanged)
	Remotes.get("StatsChanged").OnClientEvent:Connect(onStats)
	Remotes.get("ShopOffers").OnClientEvent:Connect(onOffers)

	RunService.Heartbeat:Connect(function()
		if isOpen then
			timerLabel.Text = MathUtil.formatClock(endsAt - workspace:GetServerTimeNow())
		end
	end)
end

return ShopController
