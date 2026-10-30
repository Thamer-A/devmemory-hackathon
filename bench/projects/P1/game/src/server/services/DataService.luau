local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local ItemCatalog = require(Shared.ItemCatalog)
local Log = require(Shared.Log)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)

type PlayerData = Types.PlayerData

local DataService = {}

DataService.loaded = Signal.new()

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local sessions: { [Player]: PlayerData } = {}
local dirty: { [Player]: boolean } = {}

local function defaultData(): PlayerData
	return {
		coins = Config.StartingCoins,
		inventory = {},
		equipped = nil,
		stats = {
			kills = 0,
			roundsPlayed = 0,
		},
	}
end

local function keyFor(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

-- Older saves stored item names instead of ids. 'Speed Coil' was renamed to 'Speed Boots'.
local LEGACY_ITEM_IDS: { [string]: number } = {
	["Speed Coil"] = 1,
}

-- Returns the item id for a saved entry, or nil if it does not match anything in the catalog.
local function migrateItemId(value: any): number?
	if type(value) == "number" then
		return if ItemCatalog.getById(value) then value else nil
	end
	if type(value) == "string" then
		local item = ItemCatalog.getByName(value)
		if item then
			return item.id
		end
		return LEGACY_ITEM_IDS[value]
	end
	return nil
end

local function migrateInventory(saved: { any }): { number }
	local inventory: { number } = {}
	for _, entry in saved do
		local itemId = migrateItemId(entry)
		if itemId == nil then
			Log.warn("DataService", "dropping unknown inventory item", entry)
		elseif not table.find(inventory, itemId) then
			table.insert(inventory, itemId)
		end
	end
	return inventory
end

-- Fill in any fields missing from older saves.
local function reconcile(data: any): PlayerData
	local template = defaultData()
	if type(data) ~= "table" then
		return template
	end
	if type(data.coins) ~= "number" then
		data.coins = template.coins
	end
	if type(data.inventory) ~= "table" then
		data.inventory = template.inventory
	else
		data.inventory = migrateInventory(data.inventory)
	end
	if data.equipped ~= nil then
		local equippedId = migrateItemId(data.equipped)
		if equippedId == nil then
			Log.warn("DataService", "dropping unknown equipped item", data.equipped)
		end
		data.equipped = if equippedId and table.find(data.inventory, equippedId) then equippedId else nil
	end
	if type(data.stats) ~= "table" then
		data.stats = template.stats
	end
	for stat, value in template.stats do
		if type(data.stats[stat]) ~= "number" then
			data.stats[stat] = value
		end
	end
	return data
end

local function loadData(player: Player): PlayerData?
	local key = keyFor(player)
	for attempt = 1, Config.DataLoadRetries do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return reconcile(result)
		end
		Log.warn("DataService", "load failed for", player.Name, "attempt", attempt, result)
		task.wait(Config.DataRetryDelay)
	end
	return nil
end

local function saveData(player: Player): boolean
	local data = sessions[player]
	if data == nil then
		return false
	end
	local key = keyFor(player)
	for attempt = 1, Config.DataLoadRetries do
		local ok, err = pcall(function()
			store:SetAsync(key, data)
		end)
		if ok then
			dirty[player] = nil
			return true
		end
		Log.warn("DataService", "save failed for", player.Name, "attempt", attempt, err)
		task.wait(Config.DataRetryDelay)
	end
	return false
end

local function pushInventory(player: Player)
	local data = sessions[player]
	if data == nil then
		return
	end
	Remotes.get("InventoryChanged"):FireClient(player, data.inventory, data.equipped)
end

local function onPlayerAdded(player: Player)
	local data = loadData(player)
	if data == nil then
		player:Kick("Your data could not be loaded. Please rejoin.")
		return
	end
	if player.Parent == nil then
		return
	end
	sessions[player] = data
	Log.info("DataService", "loaded data for", player.Name)
	DataService.loaded:Fire(player, data)
	pushInventory(player)
end

local function onPlayerRemoving(player: Player)
	if sessions[player] then
		saveData(player)
	end
	sessions[player] = nil
	dirty[player] = nil
end

function DataService.get(player: Player): PlayerData?
	return sessions[player]
end

function DataService.markDirty(player: Player)
	dirty[player] = true
end

function DataService.hasItem(player: Player, itemId: number): boolean
	local data = sessions[player]
	if data == nil then
		return false
	end
	return table.find(data.inventory, itemId) ~= nil
end

function DataService.addItem(player: Player, itemId: number): boolean
	local data = sessions[player]
	if data == nil then
		return false
	end
	if table.find(data.inventory, itemId) then
		return false
	end
	table.insert(data.inventory, itemId)
	dirty[player] = true
	pushInventory(player)
	return true
end

function DataService.setEquipped(player: Player, itemId: number?): boolean
	local data = sessions[player]
	if data == nil then
		return false
	end
	if itemId ~= nil and not table.find(data.inventory, itemId) then
		return false
	end
	data.equipped = itemId
	dirty[player] = true
	pushInventory(player)
	return true
end

function DataService.incrementStat(player: Player, stat: string): number?
	local data = sessions[player]
	if data == nil then
		return nil
	end
	local current = data.stats[stat]
	if type(current) ~= "number" then
		Log.warn("DataService", "unknown stat", stat)
		return nil
	end
	data.stats[stat] = current + 1
	dirty[player] = true
	return data.stats[stat]
end

function DataService.save(player: Player): boolean
	return saveData(player)
end

function DataService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	game:BindToClose(function()
		local pending = {}
		for player in sessions do
			table.insert(pending, player)
		end
		local remaining = #pending
		for _, player in pending do
			task.spawn(function()
				saveData(player)
				remaining -= 1
			end)
		end
		while remaining > 0 do
			task.wait()
		end
	end)
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	while true do
		task.wait(Config.AutosaveInterval)
		for player in sessions do
			if dirty[player] then
				task.spawn(saveData, player)
			end
		end
	end
end

return DataService
