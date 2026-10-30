-- Shop panel shown while workspace attribute ShopOpen is true. Purely a view: clicks fire remotes,
-- the server validates and updates the "ShopOffers" attribute / Coins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Upgrades = require(Shared.Upgrades)
local UIKit = require(script.Parent.UIKit)

local S = Config.Shop
local U = Config.UI
local player = Players.LocalPlayer

local CARD_W, CARD_H, GAP, PAD = 170, 150, 12, 14

local gui = Instance.new("ScreenGui")
gui.Name = "Shop"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = UIKit.panel(gui)
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -70) -- above the health/coin HUD
panel.Size = UDim2.fromOffset(PAD * 2 + S.OfferCount * CARD_W + (S.OfferCount - 1) * GAP, 276)

local title = UIKit.label(panel, "UPGRADE SHOP", 20, U.Accent)
title.Position = UDim2.fromOffset(0, 8)
title.Size = UDim2.new(1, 0, 0, 28)

local cards = {}
for slot = 1, S.OfferCount do
	local card = Instance.new("TextButton")
	card.Position = UDim2.fromOffset(PAD + (slot - 1) * (CARD_W + GAP), 44)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.BackgroundColor3 = U.PanelLight
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.Parent = panel
	UIKit.corner(card, 10)
	local stroke = UIKit.stroke(card, S.RarityColors.Common, 2)

	local name = UIKit.label(card, "", 17, U.Text)
	name.Position = UDim2.fromOffset(8, 8)
	name.Size = UDim2.new(1, -16, 0, 22)

	local rarity = UIKit.label(card, "", 12, U.Text)
	rarity.Position = UDim2.fromOffset(8, 30)
	rarity.Size = UDim2.new(1, -16, 0, 16)

	local desc = UIKit.label(card, "", 14, U.TextDim, Enum.Font.Gotham)
	desc.Position = UDim2.fromOffset(8, 52)
	desc.Size = UDim2.new(1, -16, 0, 56)
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top

	local cost = UIKit.label(card, "", 17, U.Coins)
	cost.AnchorPoint = Vector2.new(0, 1)
	cost.Position = UDim2.new(0, 8, 1, -8)
	cost.Size = UDim2.new(1, -16, 0, 22)

	card.Activated:Connect(function()
		Remotes.BuyOffer:FireServer(slot)
	end)
	cards[slot] = { button = card, stroke = stroke, name = name, rarity = rarity, desc = desc, cost = cost }
end

local reroll = Instance.new("TextButton")
reroll.AnchorPoint = Vector2.new(0.5, 1)
reroll.Position = UDim2.new(0.5, 0, 1, -12)
reroll.Size = UDim2.fromOffset(220, 34)
reroll.BackgroundColor3 = U.Accent
reroll.BorderSizePixel = 0
reroll.Font = Enum.Font.GothamBold
reroll.TextSize = 16
reroll.TextColor3 = U.Panel
reroll.Text = `REROLL  ({S.RerollCost} coins)`
reroll.Parent = panel
UIKit.corner(reroll, 10)
reroll.Activated:Connect(function()
	Remotes.RerollOffers:FireServer()
end)

local function refresh()
	gui.Enabled = workspace:GetAttribute("ShopOpen") == true
	local ids = string.split(player:GetAttribute("ShopOffers") or "", ",")
	for slot, card in cards do
		local upgrade = Upgrades.byId[ids[slot] or ""]
		card.button.Active = upgrade ~= nil
		card.button.BackgroundTransparency = if upgrade then 0 else 0.6
		if upgrade then
			local color = S.RarityColors[upgrade.Rarity]
			card.stroke.Color = color
			card.name.Text = upgrade.Name
			card.rarity.Text = string.upper(upgrade.Rarity)
			card.rarity.TextColor3 = color
			card.desc.Text = upgrade.Description
			card.cost.Text = `{upgrade.Cost} coins`
		else
			card.stroke.Color = U.TextDim
			card.name.Text = "SOLD"
			card.name.TextColor3 = U.TextDim
			card.rarity.Text = ""
			card.desc.Text = ""
			card.cost.Text = ""
		end
		if upgrade then
			card.name.TextColor3 = U.Text
		end
	end
end

workspace:GetAttributeChangedSignal("ShopOpen"):Connect(refresh)
player:GetAttributeChangedSignal("ShopOffers"):Connect(refresh)
refresh()
