local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local ItemCatalog = require(Shared.ItemCatalog)
local MathUtil = require(Shared.MathUtil)
local Remotes = require(Shared.Remotes)

local UIController = require(script.Parent.UIController)

local ShopController = {}

local PANEL_NAME = "Shop"
local ROW_HEIGHT = 64

local owned: { [string]: boolean } = {}
local buttons: { [string]: TextButton } = {}

local function refreshButtons()
	local theme = UIController.getTheme()
	for name, button in buttons do
		if owned[name] then
			button.Text = "Owned"
			button.Active = false
			button.BackgroundColor3 = Color3.fromRGB(80, 80, 88)
			button.TextColor3 = Color3.fromRGB(160, 160, 170)
		else
			button.Text = "Buy"
			button.Active = true
			button.BackgroundColor3 = theme.button
			button.TextColor3 = theme.text
		end
	end
end

local function buildRow(list: ScrollingFrame, item, order: number)
	local row = Instance.new("Frame")
	row.Name = item.name
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = Color3.fromRGB(40, 43, 56)
	row.BorderSizePixel = 0
	row.Parent = list

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = row

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(48, 48)
	icon.Position = UDim2.new(0, 8, 0.5, -24)
	icon.Image = Assets.get(item.icon) or ""
	icon.Parent = row

	local nameLabel = UIController.createLabel(row, item.name)
	nameLabel.Position = UDim2.fromOffset(64, 6)
	nameLabel.Size = UDim2.new(1, -180, 0, 24)

	local priceLabel = UIController.createLabel(row, MathUtil.formatNumber(item.price) .. " coins")
	priceLabel.Position = UDim2.fromOffset(64, 32)
	priceLabel.Size = UDim2.new(1, -180, 0, 22)
	priceLabel.TextSize = 15
	priceLabel.TextColor3 = Color3.fromRGB(255, 205, 40)

	local button = UIController.createButton(row, "Buy", function()
		Remotes.get("BuyItem"):FireServer(item.id)
	end)
	button.Position = UDim2.new(1, -108, 0.5, -16)
	buttons[item.name] = button
end

local function buildPanel()
	local panel = UIController.createPanel(PANEL_NAME, UDim2.fromOffset(420, 360), UDim2.new(0.5, -210, 0.5, -180))
	panel:SetAttribute("Modal", true)

	local background = Instance.new("ImageLabel")
	background.Name = "Background"
	background.BackgroundTransparency = 1
	background.ImageTransparency = 0.7
	background.Size = UDim2.fromScale(1, 1)
	background.Image = Assets.get("ShopBackground") or ""
	background.ZIndex = 0
	background.Parent = panel

	local title = UIController.createLabel(panel, "Shop")
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 30)
	title.TextSize = 24

	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, 50)
	list.Size = UDim2.new(1, -24, 1, -62)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, item in ItemCatalog.all() do
		buildRow(list, item, index)
	end
end

function ShopController.init()
	buildPanel()
	refreshButtons()
end

function ShopController.start()
	Remotes.get("InventoryChanged").OnClientEvent:Connect(function(inventory: { string })
		owned = {}
		for _, name in inventory do
			owned[name] = true
		end
		refreshButtons()
	end)
end

return ShopController
