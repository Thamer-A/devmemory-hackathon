local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local ItemCatalog = require(Shared.ItemCatalog)
local Remotes = require(Shared.Remotes)

local UIController = require(script.Parent.UIController)

local InventoryController = {}

local PANEL_NAME = "Inventory"
local ROW_HEIGHT = 56

local list: ScrollingFrame
local emptyLabel: TextLabel
local inventory: { number } = {}
local equipped: number? = nil

local function clearRows()
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function buildRow(item, order: number)
	local isEquipped = equipped == item.id

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
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(40, 40)
	icon.Position = UDim2.new(0, 8, 0.5, -20)
	icon.Image = Assets.get(item.icon) or ""
	icon.Parent = row

	local label = UIController.createLabel(row, item.name)
	label.Position = UDim2.fromOffset(56, 16)
	label.Size = UDim2.new(1, -170, 0, 24)

	local button = UIController.createButton(row, if isEquipped then "Unequip" else "Equip", function()
		if isEquipped then
			Remotes.get("EquipItem"):FireServer(nil)
		else
			Remotes.get("EquipItem"):FireServer(item.id)
		end
	end)
	button.Position = UDim2.new(1, -108, 0.5, -16)
end

local function render()
	clearRows()
	emptyLabel.Visible = #inventory == 0

	for index, itemId in inventory do
		local item = ItemCatalog.getById(itemId)
		if item then
			buildRow(item, index)
		end
	end
end

function InventoryController.init()
	local panel = UIController.createPanel(PANEL_NAME, UDim2.fromOffset(380, 320), UDim2.new(0.5, -190, 0.5, -160))
	panel:SetAttribute("Modal", true)

	local title = UIController.createLabel(panel, "Inventory")
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 30)
	title.TextSize = 24

	list = Instance.new("ScrollingFrame")
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

	emptyLabel = UIController.createLabel(panel, "You do not own any items yet.")
	emptyLabel.Position = UDim2.fromOffset(16, 56)
	emptyLabel.Size = UDim2.new(1, -32, 0, 24)
end

function InventoryController.start()
	Remotes.get("InventoryChanged").OnClientEvent:Connect(function(items: { number }, equippedId: number?)
		inventory = items
		equipped = equippedId
		render()
	end)
	render()
end

return InventoryController
