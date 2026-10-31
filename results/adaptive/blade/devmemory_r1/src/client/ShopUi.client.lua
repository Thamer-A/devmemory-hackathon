-- Displays the server's shop offers during the wave break. Buttons only send slot numbers;
-- the server decides whether a purchase or reroll is allowed.
local Players = game:GetService("Players")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Theme = require(game.ReplicatedStorage.Shared.Config).Ui
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Shop"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = UiKit.panel(gui)
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -20)
panel.Size = UDim2.fromOffset(600, 290)

local title = UiKit.label(panel, "UPGRADE SHOP", 20, Theme.Accent, true)
title.Position = UDim2.fromOffset(18, 10)
title.Size = UDim2.new(1, -36, 0, 28)
title.TextXAlignment = Enum.TextXAlignment.Left

local balanceLabel = UiKit.label(panel, "", 18, Theme.Coin, true)
balanceLabel.Position = UDim2.fromOffset(18, 10)
balanceLabel.Size = UDim2.new(1, -36, 0, 28)
balanceLabel.TextXAlignment = Enum.TextXAlignment.Right

local cards = Instance.new("Frame")
cards.Position = UDim2.fromOffset(18, 48)
cards.Size = UDim2.new(1, -36, 0, 168)
cards.BackgroundTransparency = 1
cards.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 12)
layout.Parent = cards

local reroll = Instance.new("TextButton")
reroll.AnchorPoint = Vector2.new(0.5, 1)
reroll.Position = UDim2.new(0.5, 0, 1, -14)
reroll.Size = UDim2.fromOffset(200, 36)
reroll.BackgroundColor3 = Theme.PanelLight
reroll.Font = Enum.Font.GothamBold
reroll.TextSize = 16
reroll.Parent = panel
UiKit.corner(reroll, 10)
UiKit.stroke(reroll, Theme.Accent, 1.5)
reroll.Activated:Connect(function()
	Remotes.RerollOffers:FireServer()
end)

local function coins(): number
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Coins")
	return value and value.Value or 0
end

local function addLabel(parent: Instance, text: string, y: number, height: number, size: number, color: Color3, bold: boolean?)
	local l = UiKit.label(parent, text, size, color, bold)
	l.Position = UDim2.fromOffset(8, y)
	l.Size = UDim2.new(1, -16, 0, height)
	l.TextWrapped = true
	return l
end

local lastState

local function render(state)
	lastState = state
	gui.Enabled = state.Open
	for _, child in cards:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local count = math.max(#state.Offers, 1)
	local balance = coins()

	for slot, offer in state.Offers do
		local rarityColor = Theme.Rarity[offer.Rarity] or Theme.Rarity.Common
		local card = Instance.new("TextButton")
		-- Scale-based width: AbsoluteSize can still be 0 on the first render after enabling.
		card.Size = UDim2.new(1 / count, -12 * (count - 1) / count, 1, 0)
		card.Text = ""
		card.AutoButtonColor = not offer.Bought
		card.BackgroundColor3 = Theme.PanelLight
		card.BorderSizePixel = 0
		card.Parent = cards
		UiKit.corner(card, 10)
		UiKit.stroke(card, rarityColor, 2, if offer.Bought then 0.7 else 0)

		local banner = Instance.new("Frame")
		banner.Size = UDim2.new(1, 0, 0, 5)
		banner.BackgroundColor3 = rarityColor
		banner.BorderSizePixel = 0
		banner.Parent = card
		UiKit.corner(banner, 10)

		addLabel(card, offer.Name, 14, 24, 17, Theme.Text, true)
		addLabel(card, string.upper(offer.Rarity), 40, 16, 12, rarityColor, true)
		addLabel(card, offer.Description, 62, 52, 14, Theme.TextDim)

		local costColor = if offer.Bought
			then Theme.TextDim
			elseif balance >= offer.Cost then Theme.Coin
			else Theme.Danger
		addLabel(card, offer.Bought and "PURCHASED" or offer.Cost .. " coins", 126, 28, 17, costColor, true)

		card.Activated:Connect(function()
			if not offer.Bought then
				Remotes.BuyOffer:FireServer(slot)
			end
		end)
	end

	reroll.Text = "Reroll (" .. state.RerollCost .. " coins)"
	reroll.TextColor3 = if balance >= state.RerollCost then Theme.Coin else Theme.Danger
	balanceLabel.Text = balance .. " coins"
end

Remotes.ShopUpdate.OnClientEvent:Connect(render)

-- Re-render when coins change so affordability colours stay current.
player:WaitForChild("leaderstats"):WaitForChild("Coins"):GetPropertyChangedSignal("Value"):Connect(function()
	if lastState and lastState.Open then
		render(lastState)
	end
end)

Remotes.ShopSync:FireServer()
