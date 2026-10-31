-- Shop panel shown during the break between waves. Display only: buying/rerolling is requested via remotes
-- and validated by ShopService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local UIKit = require(Shared:WaitForChild("UIKit"))

local shop = Config.Shop
local ui = Config.UI
local player = Players.LocalPlayer
local buyEvent = Remotes.get("ShopBuy")
local rerollEvent = Remotes.get("ShopReroll")

local CARD_WIDTH, CARD_HEIGHT, CARD_GAP, PADDING = 170, 150, 12, 14
local HEADER_HEIGHT, FOOTER_HEIGHT = 40, 52

local byId = {}
for _, upgrade in shop.Upgrades do
	byId[upgrade.Id] = upgrade
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShopUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local count = shop.OffersPerPlayer
local panel = UIKit.panel(gui, "Panel")
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -20)
panel.Size = UDim2.fromOffset(
	PADDING * 2 + count * CARD_WIDTH + (count - 1) * CARD_GAP,
	HEADER_HEIGHT + CARD_HEIGHT + FOOTER_HEIGHT + PADDING
)

local title = UIKit.label(panel, "Title", "UPGRADE SHOP", 20, ui.Accent)
title.Position = UDim2.fromOffset(PADDING, 8)
title.Size = UDim2.new(0.5, -PADDING, 0, 28)
title.TextXAlignment = Enum.TextXAlignment.Left

local timer = UIKit.label(panel, "Timer", "", 16, ui.TextDim)
timer.Position = UDim2.new(0.5, 0, 0, 8)
timer.Size = UDim2.new(0.5, -PADDING, 0, 28)
timer.TextXAlignment = Enum.TextXAlignment.Right

local cards: { TextButton } = {}
for slot = 1, count do
	local card = Instance.new("TextButton")
	card.Name = `Card{slot}`
	card.Position = UDim2.fromOffset(PADDING + (slot - 1) * (CARD_WIDTH + CARD_GAP), HEADER_HEIGHT)
	card.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	card.BackgroundColor3 = ui.NavyLight
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = true
	card.Parent = panel
	UIKit.corner(card, 10)
	UIKit.stroke(card, shop.RarityColors.Common, 2)

	local band = Instance.new("Frame") -- rarity-colored header strip
	band.Name = "Band"
	band.Size = UDim2.new(1, 0, 0, 6)
	band.BorderSizePixel = 0
	band.Parent = card
	UIKit.corner(band, 10)

	local rarity = UIKit.label(card, "Rarity", "", 12)
	rarity.Position = UDim2.fromOffset(8, 12)
	rarity.Size = UDim2.new(1, -16, 0, 16)

	local name = UIKit.label(card, "ItemName", "", 18)
	name.Position = UDim2.fromOffset(8, 30)
	name.Size = UDim2.new(1, -16, 0, 24)
	name.TextScaled = false
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local desc = UIKit.label(card, "Desc", "", 14, ui.TextDim, false)
	desc.Position = UDim2.fromOffset(10, 58)
	desc.Size = UDim2.new(1, -20, 0, 50)
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top

	local cost = UIKit.label(card, "Cost", "", 18, ui.Gold)
	cost.Position = UDim2.new(0, 0, 1, -34)
	cost.Size = UDim2.new(1, 0, 0, 28)

	card.MouseButton1Click:Connect(function()
		buyEvent:FireServer(slot)
	end)
	cards[slot] = card
end

local reroll = Instance.new("TextButton")
reroll.Name = "Reroll"
reroll.AnchorPoint = Vector2.new(0.5, 1)
reroll.Position = UDim2.new(0.5, 0, 1, -PADDING)
reroll.Size = UDim2.fromOffset(210, 34)
reroll.BackgroundColor3 = ui.NavyLight
reroll.BorderSizePixel = 0
reroll.TextColor3 = ui.Gold
reroll.Font = Enum.Font.GothamBold
reroll.TextSize = 16
reroll.Text = `REROLL  -  {shop.RerollCost} coins`
reroll.Parent = panel
UIKit.corner(reroll, 8)
UIKit.stroke(reroll, ui.Accent, 2, 0.3)
reroll.MouseButton1Click:Connect(function()
	rerollEvent:FireServer()
end)

local function coins(): number
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Coins")
	return value and value.Value or 0
end

local function refresh()
	local secondsLeft = workspace:GetAttribute("BreakSecondsLeft") or 0
	local offered = string.split(player:GetAttribute("ShopOffers") or "", ",")
	gui.Enabled = secondsLeft > 0
	timer.Text = `Next wave in {secondsLeft}s`
	local balance = coins()
	for slot, card in cards do
		local upgrade = byId[offered[slot] or ""]
		local band = card.Band :: Frame
		local stroke = card.UIStroke :: UIStroke
		local affordable = upgrade ~= nil and balance >= upgrade.Cost
		if upgrade then
			local color = shop.RarityColors[upgrade.Rarity]
			band.BackgroundColor3 = color
			stroke.Color = color
			card.Rarity.Text = string.upper(upgrade.Rarity)
			card.Rarity.TextColor3 = color
			card.ItemName.Text = upgrade.Name
			card.Desc.Text = upgrade.Desc
			card.Cost.Text = `{upgrade.Cost} coins`
			card.Cost.TextColor3 = affordable and ui.Gold or ui.HealthLow
		else
			band.BackgroundColor3 = ui.TextDim
			stroke.Color = ui.TextDim
			card.Rarity.Text = ""
			card.ItemName.Text = "SOLD"
			card.Desc.Text = ""
			card.Cost.Text = ""
		end
		card.Active = affordable
		card.AutoButtonColor = affordable
		card.BackgroundTransparency = upgrade and (affordable and 0 or 0.45) or 0.6
	end
	local canReroll = balance >= shop.RerollCost
	reroll.TextTransparency = canReroll and 0 or 0.5
	reroll.AutoButtonColor = canReroll
end

workspace:GetAttributeChangedSignal("BreakSecondsLeft"):Connect(refresh)
player:GetAttributeChangedSignal("ShopOffers"):Connect(refresh)
local function watchCoins()
	local stats = player:WaitForChild("leaderstats")
	stats:WaitForChild("Coins"):GetPropertyChangedSignal("Value"):Connect(refresh)
	refresh()
end
task.spawn(watchCoins)
refresh()
