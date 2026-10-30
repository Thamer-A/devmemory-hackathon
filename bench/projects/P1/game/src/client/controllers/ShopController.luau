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
-- Re-enable Buy after this long if the server never answers with InventoryChanged (e.g. the request was rejected).
local BUY_TIMEOUT = 1

local owned: { [number]: boolean } = {}
local buttons: { [number]: TextButton } = {}
-- Item id -> token of the purchase request still waiting on the server.
local pending: { [number]: number } = {}
local requestCount = 0

local function refreshButtons()
	local theme = UIController.getTheme()
	for itemId, button in buttons do
		if owned[itemId] then
			button.Text = "Owned"
			button.Active = false
			button.BackgroundColor3 = Color3.fromRGB(80, 80, 88)
			button.TextColor3 = Color3.fromRGB(160, 160, 170)
		elseif pending[itemId] then
			button.Text = "Buying"
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

local function requestPurchase(itemId: number)
	if owned[itemId] or pending[itemId] then
		return
	end

	requestCount += 1
	local token = requestCount
	pending[itemId] = token
	refreshButtons()
	Remotes.get("BuyItem"):FireServer(itemId)

	task.delay(BUY_TIMEOUT, function()
		if pending[itemId] == token then
			pending[itemId] = nil
			refreshButtons()
		end
	end)
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
		requestPurchase(item.id)
	end)
	button.Position = UDim2.new(1, -108, 0.5, -16)
	buttons[item.id] = button
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
	Remotes.get("InventoryChanged").OnClientEvent:Connect(function(inventory: { number })
		owned = {}
		for _, itemId in inventory do
			owned[itemId] = true
		end
		table.clear(pending)
		refreshButtons()
	end)
end

return ShopController
