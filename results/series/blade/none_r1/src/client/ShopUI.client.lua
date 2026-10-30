local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local S = Config.Shop
local UI = Config.UI
local player = Players.LocalPlayer

-- Display only: the server validates every purchase and reroll.
local coins = player:WaitForChild(Config.Stats.Folder):WaitForChild(Config.Stats.Coins)

local gui = Instance.new("ScreenGui")
gui.Name = "ShopGui"
gui.ResetOnSpawn = false
gui.Enabled = false

local function addCorner(instance: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius and UDim.new(0, radius) or UI.CornerRadius
	corner.Parent = instance
end

local function addStroke(instance: Instance, color: Color3, thickness: number, transparency: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

local function makeLabel(size: UDim2, position: UDim2, font: Enum.Font, textSize: number, color: Color3, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextColor3 = color
	label.Parent = parent
	return label
end

local function makeButton(size: UDim2, position: UDim2, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = ""
	button.AutoButtonColor = true
	addCorner(button, 8)
	button.Parent = parent
	return button
end

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(600, 350)
panel.BackgroundColor3 = UI.Panel
panel.BorderSizePixel = 0
panel.Parent = gui
addCorner(panel)
addStroke(panel, UI.Accent, 2, 0.3)

local title = makeLabel(UDim2.fromOffset(220, 40), UDim2.fromOffset(20, 8), Enum.Font.GothamBold, 22, UI.Accent, panel)
title.Text = "UPGRADE SHOP"
title.TextXAlignment = Enum.TextXAlignment.Left

local coinLabel = makeLabel(UDim2.fromOffset(150, 40), UDim2.new(1, -290, 0, 8), Enum.Font.GothamBold, 20, UI.Coin, panel)
coinLabel.TextXAlignment = Enum.TextXAlignment.Right

local timerLabel = makeLabel(UDim2.fromOffset(110, 40), UDim2.new(1, -125, 0, 8), Enum.Font.GothamBold, 18, UI.Text, panel)
timerLabel.TextXAlignment = Enum.TextXAlignment.Right

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -40, 0, 1)
divider.Position = UDim2.fromOffset(20, 52)
divider.BackgroundColor3 = UI.Accent
divider.BackgroundTransparency = 0.6
divider.BorderSizePixel = 0
divider.Parent = panel

local cards = {}
for slot = 1, S.OfferCount do
	local card = Instance.new("Frame")
	card.Position = UDim2.new(0, 20 + (slot - 1) * 190, 0, 66)
	card.Size = UDim2.fromOffset(180, 214)
	card.BackgroundColor3 = UI.PanelLight
	card.BorderSizePixel = 0
	card.Parent = panel
	addCorner(card)
	local stroke = addStroke(card, UI.Accent, 2, 0.1)

	local name = makeLabel(UDim2.new(1, -16, 0, 28), UDim2.fromOffset(8, 10), Enum.Font.GothamBold, 18, UI.Text, card)
	local rarity = makeLabel(UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, 38), Enum.Font.GothamBold, 13, UI.Text, card)
	local desc = makeLabel(UDim2.new(1, -20, 0, 52), UDim2.fromOffset(10, 62), Enum.Font.Gotham, 15, UI.TextDim, card)
	desc.TextYAlignment = Enum.TextYAlignment.Top
	local owned = makeLabel(UDim2.new(1, -16, 0, 16), UDim2.fromOffset(8, 122), Enum.Font.Gotham, 13, UI.TextDim, card)
	local buy = makeButton(UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 1, -48), card)

	buy.Activated:Connect(function()
		Remotes.PurchaseUpgrade:FireServer(slot)
	end)
	cards[slot] = { frame = card, stroke = stroke, name = name, rarity = rarity, desc = desc, owned = owned, buy = buy }
end

local reroll = makeButton(UDim2.fromOffset(220, 38), UDim2.new(0.5, -110, 1, -56), panel)
reroll.TextSize = 15
reroll.TextColor3 = UI.Panel
addStroke(reroll, UI.Accent, 1.5, 0.2)

local function refresh()
	local endsAt = workspace:GetAttribute(Config.Waves.BreakAttribute) or 0
	local remaining = endsAt - workspace:GetServerTimeNow()
	local open = endsAt > 0 and remaining > 0 and player:GetAttribute(S.OfferAttribute .. 1) ~= ""
	gui.Enabled = open
	if not open then
		return
	end

	coinLabel.Text = "● " .. coins.Value
	timerLabel.Text = string.format("%d:%02d", math.ceil(remaining) // 60, math.ceil(remaining) % 60)
	timerLabel.TextColor3 = remaining <= 5 and UI.HealthLow or UI.Text

	for slot, card in cards do
		local def = Upgrades.byId[player:GetAttribute(S.OfferAttribute .. slot)]
		local sold = player:GetAttribute(S.SoldAttribute .. slot)
		card.frame.Visible = def ~= nil
		if def then
			local color = S.RarityColors[def.Rarity] or UI.Text
			card.name.Text = def.Name
			card.rarity.Text = string.upper(def.Rarity)
			card.rarity.TextColor3 = color
			card.stroke.Color = color
			card.stroke.Transparency = sold and 0.7 or 0.1
			card.desc.Text = def.Description
			card.owned.Text = "Owned: " .. Upgrades.getLevel(player, def.Id)
			local affordable = coins.Value >= def.Cost
			card.buy.Text = sold and "SOLD" or ("● " .. def.Cost)
			card.buy.Active = not sold and affordable
			if sold or not affordable then
				card.buy.BackgroundColor3 = UI.Disabled
				card.buy.TextColor3 = UI.TextDim
			else
				card.buy.BackgroundColor3 = UI.Coin
				card.buy.TextColor3 = UI.Panel
			end
		end
	end

	local canReroll = coins.Value >= S.RerollCost
	reroll.Text = "Reroll  ● " .. S.RerollCost
	reroll.Active = canReroll
	reroll.BackgroundColor3 = canReroll and UI.Accent or UI.Disabled
	reroll.TextColor3 = canReroll and UI.Panel or UI.TextDim
end

gui.Parent = player:WaitForChild("PlayerGui")

-- Cheap UI; refresh on a short loop so the countdown ticks and state changes show immediately.
task.spawn(function()
	while true do
		refresh()
		task.wait(0.1)
	end
end)
