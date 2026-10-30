local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemCatalog = require(Shared.ItemCatalog)
local Log = require(Shared.Log)
local Remotes = require(Shared.Remotes)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)

local ShopService = {}

local lastPurchase: { [Player]: number } = {}

local function isOnCooldown(player: Player): boolean
	local last = lastPurchase[player]
	if last == nil then
		return false
	end
	return os.clock() - last < Config.PurchaseCooldown
end

local function applyEquipped(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end

	local speed = Config.BaseWalkSpeed
	local data = DataService.get(player)
	if data and data.equipped then
		local item = ItemCatalog.getById(data.equipped)
		if item and item.stats and item.stats.walkSpeedBonus then
			speed += item.stats.walkSpeedBonus
		end
	end
	humanoid.WalkSpeed = speed
end

local function onBuyItem(player: Player, itemId: any)
	if type(itemId) ~= "number" then
		Log.warn("ShopService", "bad item id from", player.Name)
		return
	end

	if isOnCooldown(player) then
		return
	end
	lastPurchase[player] = os.clock()

	local item = ItemCatalog.getById(itemId)
	if item == nil then
		Log.warn("ShopService", player.Name, "tried to buy unknown item", itemId)
		return
	end

	if DataService.hasItem(player, item.id) then
		return
	end

	if not CurrencyService.canAfford(player, item.price) then
		return
	end

	CurrencyService.add(player, -item.price, "shop_purchase")
	DataService.addItem(player, item.id)
	Log.info("ShopService", player.Name, "bought", item.name)
end

local function onEquipItem(player: Player, itemId: any)
	if itemId == nil then
		DataService.setEquipped(player, nil)
		applyEquipped(player)
		return
	end
	if type(itemId) ~= "number" then
		return
	end

	local item = ItemCatalog.getById(itemId)
	if item == nil or not DataService.hasItem(player, item.id) then
		return
	end

	if DataService.setEquipped(player, item.id) then
		applyEquipped(player)
	end
end

local function onCharacterAdded(player: Player)
	-- Wait a frame so the Humanoid exists before applying stats.
	task.defer(applyEquipped, player)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
end

function ShopService.init()
	Remotes.get("BuyItem").OnServerEvent:Connect(onBuyItem)
	Remotes.get("EquipItem").OnServerEvent:Connect(onEquipItem)

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		lastPurchase[player] = nil
	end)
end

function ShopService.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return ShopService
