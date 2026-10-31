local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(Shared:WaitForChild("Theme"))
local S = Config.Shop

local player = Players.LocalPlayer

local CARD_SIZE = Vector2.new(170, 190)
local CARD_GAP = 12
local PADDING = 16

local state = { Open = false, Offers = {} }

-- UI ----------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Shop"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Theme.panel(gui)
frame.AnchorPoint = Vector2.new(0.5, 1)
frame.Position = UDim2.new(0.5, 0, 1, -20)
frame.Size = UDim2.fromOffset(
	PADDING * 2 + S.OfferCount * CARD_SIZE.X + (S.OfferCount - 1) * CARD_GAP,
	PADDING * 2 + 40 + CARD_SIZE.Y + 62
)

local title = Theme.label(frame, {
	Text = "UPGRADE SHOP",
	TextSize = 20,
	TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(PADDING, PADDING),
	Size = UDim2.new(0.5, -PADDING, 0, 28),
})

local timerLabel = Theme.label(frame, {
	Text = "",
	TextSize = 14,
	Font = Theme.Font,
	TextColor3 = Theme.TextDim,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.new(0.5, 0, 0, PADDING),
	Size = UDim2.new(0.5, -PADDING, 0, 14),
})

local coinsLabel = Theme.label(frame, {
	Text = "",
	TextSize = 18,
	TextColor3 = Theme.Gold,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.new(0.5, 0, 0, PADDING + 14),
	Size = UDim2.new(0.5, -PADDING, 0, 22),
})

-- Each card is a button with child labels so the rarity can be colored and
-- the border can match it.
local cards = {}
for slot = 1, S.OfferCount do
	local button = Instance.new("TextButton")
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.PanelLight
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	button.Position = UDim2.fromOffset(PADDING + (slot - 1) * (CARD_SIZE.X + CARD_GAP), PADDING + 40)
	button.Parent = frame
	Theme.round(button, UDim.new(0, 10))
	local stroke = Theme.stroke(button, Theme.Rarity.Common, 2, 0.1)

	local bar = Instance.new("Frame") -- rarity strip across the top
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Parent = button
	Theme.round(bar, UDim.new(0, 3))

	local name = Theme.label(button, {
		TextSize = 17,
		TextWrapped = true,
		Position = UDim2.fromOffset(10, 14),
		Size = UDim2.new(1, -20, 0, 22),
	})
	local rarity = Theme.label(button, {
		TextSize = 12,
		Position = UDim2.fromOffset(10, 38),
		Size = UDim2.new(1, -20, 0, 14),
	})
	local description = Theme.label(button, {
		Font = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.TextDim,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.new(1, -20, 0, 70),
	})
	local cost = Theme.label(button, {
		TextSize = 18,
		TextColor3 = Theme.Gold,
		Position = UDim2.new(0, 10, 1, -38),
		Size = UDim2.new(1, -20, 0, 28),
	})

	button.Activated:Connect(function()
		Remotes.ShopBuy:FireServer(slot)
	end)
	cards[slot] = {
		button = button,
		stroke = stroke,
		bar = bar,
		name = name,
		rarity = rarity,
		description = description,
		cost = cost,
	}
end

local reroll = Instance.new("TextButton")
reroll.AnchorPoint = Vector2.new(0.5, 1)
reroll.Position = UDim2.new(0.5, 0, 1, -PADDING)
reroll.Size = UDim2.fromOffset(220, 40)
reroll.BackgroundColor3 = Theme.Accent
reroll.AutoButtonColor = true
reroll.Font = Theme.FontBold
reroll.TextSize = 16
reroll.TextColor3 = Theme.Panel
reroll.Text = `REROLL  ●  {S.RerollCost}`
reroll.Parent = frame
Theme.round(reroll, UDim.new(0, 10))
reroll.Activated:Connect(function()
	Remotes.ShopReroll:FireServer()
end)

-- Rendering ---------------------------------------------------------------------

local function getCoins()
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	return coins and coins.Value or 0
end

-- Affordability here is cosmetic only; the server re-checks every purchase.
local function render()
	gui.Enabled = state.Open
	if not state.Open then
		return
	end

	local coins = getCoins()
	coinsLabel.Text = `● {coins}`

	for slot, card in cards do
		local upgrade = S.ById[state.Offers[slot]]
		if upgrade then
			local color = Theme.Rarity[upgrade.Rarity] or Theme.Rarity.Common
			local affordable = coins >= upgrade.Cost
			card.button.Active = true
			card.button.BackgroundTransparency = 0
			card.stroke.Color = color
			card.stroke.Transparency = affordable and 0.1 or 0.6
			card.bar.BackgroundColor3 = color
			card.name.Text = upgrade.Name
			card.name.TextTransparency = affordable and 0 or 0.4
			card.rarity.Text = string.upper(upgrade.Rarity)
			card.rarity.TextColor3 = color
			card.description.Text = upgrade.Description
			card.cost.Text = `● {upgrade.Cost}`
			card.cost.TextColor3 = affordable and Theme.Gold or Theme.Danger
		else
			card.button.Active = false
			card.button.BackgroundTransparency = 0.6
			card.stroke.Color = Theme.TextDim
			card.stroke.Transparency = 0.7
			card.bar.BackgroundColor3 = Theme.TextDim
			card.name.Text = "SOLD"
			card.name.TextTransparency = 0.4
			card.rarity.Text = ""
			card.description.Text = ""
			card.cost.Text = ""
		end
	end
	reroll.BackgroundTransparency = coins >= S.RerollCost and 0 or 0.6
end

Remotes.ShopState.OnClientEvent:Connect(function(newState)
	state = newState
	render()
end)

player:WaitForChild("leaderstats"):WaitForChild("Coins"):GetPropertyChangedSignal("Value"):Connect(render)

RunService.Heartbeat:Connect(function()
	if state.Open then
		local endsAt = workspace:GetAttribute(Config.Attributes.BreakEndsAt) or 0
		local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		timerLabel.Text = `Next wave in {remaining}s`
	end
end)

Remotes.ShopSync:FireServer()
