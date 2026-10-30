local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local UI = require(Shared.UI)
local Theme = Config.Theme

local player = Players.LocalPlayer
local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")

local defs = {}
for _, def in Config.Upgrades do
	defs[def.Id] = def
end

local gui = Instance.new("ScreenGui")
gui.Name = "Shop"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = UI.panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 300),
})

local title = UI.label(panel, {
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -32, 0, 30),
	TextSize = 20,
	TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local coinLabel = UI.label(panel, {
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -32, 0, 30),
	TextSize = 20,
	TextColor3 = Theme.Gold,
	TextXAlignment = Enum.TextXAlignment.Right,
})

local cards = Instance.new("Frame")
cards.Position = UDim2.fromOffset(16, 46)
cards.Size = UDim2.new(1, -32, 0, 190)
cards.BackgroundTransparency = 1
cards.Parent = panel
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 12)
layout.Parent = cards

local reroll = Instance.new("TextButton")
reroll.AnchorPoint = Vector2.new(0.5, 1)
reroll.Position = UDim2.new(0.5, 0, 1, -12)
reroll.Size = UDim2.fromOffset(200, 36)
reroll.Font = Theme.Font
reroll.TextSize = 16
reroll.Text = `Reroll  ● {Config.Shop.RerollCost}`
reroll.BorderSizePixel = 0
reroll.Parent = panel
UI.round(reroll, 10)
local rerollStroke = UI.stroke(reroll, Theme.Accent, 1.5)
reroll.Activated:Connect(function()
	Remotes.ShopReroll:FireServer()
end)

-- Each card: rarity tag, name, description, gold price, rarity-colored outline.
local buttons = {}
for slot = 1, Config.Shop.OffersPerPlayer do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1 / Config.Shop.OffersPerPlayer, -8, 1, 0)
	button.Text = ""
	button.BorderSizePixel = 0
	button.BackgroundColor3 = Theme.PanelLight
	button.Parent = cards
	UI.round(button, 10)

	local card = {
		button = button,
		stroke = UI.stroke(button, Theme.TextDim, 2),
		tag = UI.label(button, {
			Position = UDim2.fromOffset(0, 10),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 12,
		}),
		name = UI.label(button, {
			Position = UDim2.fromOffset(8, 30),
			Size = UDim2.new(1, -16, 0, 40),
			TextSize = 17,
			TextWrapped = true,
		}),
		desc = UI.label(button, {
			Position = UDim2.fromOffset(8, 74),
			Size = UDim2.new(1, -16, 0, 60),
			TextSize = 14,
			Font = Theme.FontBody,
			TextColor3 = Theme.TextDim,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		price = UI.label(button, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -16, 0, 24),
			TextSize = 18,
		}),
	}
	button.Activated:Connect(function()
		Remotes.ShopBuy:FireServer(slot)
	end)
	buttons[slot] = card
end

local current = {}

local function refresh()
	coinLabel.Text = `● {coins.Value}`
	for slot, card in buttons do
		local def = defs[current[slot]]
		if def then
			local rarity = Config.Rarities[def.Rarity]
			local affordable = coins.Value >= def.Cost
			card.tag.Text = string.upper(def.Rarity)
			card.tag.TextColor3 = rarity.Color
			card.name.Text = def.Name
			card.name.TextColor3 = Theme.Text
			card.desc.Text = def.Description
			card.price.Text = `● {def.Cost}`
			card.price.TextColor3 = affordable and Theme.Gold or Theme.HealthLow
			card.stroke.Color = rarity.Color
			card.stroke.Transparency = affordable and 0 or 0.6
			card.button.BackgroundColor3 = affordable and Theme.PanelLight or Theme.Panel
			card.button.AutoButtonColor = affordable
		else
			card.tag.Text = ""
			card.name.Text = current[slot] == false and "SOLD" or ""
			card.name.TextColor3 = Theme.TextDim
			card.desc.Text = ""
			card.price.Text = ""
			card.stroke.Color = Theme.TextDim
			card.stroke.Transparency = 0.6
			card.button.BackgroundColor3 = Theme.Panel
			card.button.AutoButtonColor = false
		end
	end
	local canReroll = coins.Value >= Config.Shop.RerollCost
	reroll.BackgroundColor3 = canReroll and Theme.Accent or Theme.Panel
	reroll.TextColor3 = canReroll and Theme.Panel or Theme.TextDim
	rerollStroke.Transparency = canReroll and 1 or 0.6
end

Remotes.ShopUpdate.OnClientEvent:Connect(function(offers)
	current = offers
	refresh()
end)
coins:GetPropertyChangedSignal("Value"):Connect(refresh)

local function syncOpen()
	gui.Enabled = workspace:GetAttribute("ShopOpen") == true
end
workspace:GetAttributeChangedSignal("ShopOpen"):Connect(syncOpen)
syncOpen()
refresh()

RunService.RenderStepped:Connect(function()
	if gui.Enabled then
		local left = math.max(0, (workspace:GetAttribute("BreakEndsAt") or 0) - workspace:GetServerTimeNow())
		title.Text = `UPGRADE SHOP  ·  {math.ceil(left)}s`
	end
end)
