--!nonstrict
-- Roguelite shop: every player gets their own random offers each shop phase.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local Remotes = require(Shared.Remotes)
local Upgrades = require(Shared.Upgrades)

local PlayerStatsService = require(script.Parent.PlayerStatsService)
local RoundService = require(script.Parent.RoundService)

export type Offer = {
	id: string,
	name: string,
	description: string,
	icon: string,
	rarity: string,
	price: number,
	sold: boolean,
}

type ShopState = {
	offers: { Offer },
	rerolls: number,
	ready: boolean,
}

local ShopService = {}

local rng = Random.new()
local shops: { [Player]: ShopState } = {}
local lastRemote: { [Player]: number } = {}

local function rateLimited(player: Player): boolean
	local now = os.clock()
	local last = lastRemote[player]
	if last and now - last < Config.RemoteMinInterval then
		return true
	end
	lastRemote[player] = now
	return false
end

local function priceFor(upgrade: Upgrades.Upgrade): number
	local multiplier = 1 + Config.PriceWaveScale * (RoundService.getWave() - 1)
	return math.max(1, math.floor(upgrade.price * multiplier + 0.5))
end

local function rollOffers(excludeIds: { string }?): { Offer }
	local offers = {}
	for _, upgrade in Upgrades.roll(rng, Config.ShopOfferCount, excludeIds) do
		table.insert(offers, {
			id = upgrade.id,
			name = upgrade.name,
			description = upgrade.description,
			icon = upgrade.icon,
			rarity = upgrade.rarity,
			price = priceFor(upgrade),
			sold = false,
		})
	end
	return offers
end

local function rerollCost(state: ShopState): number
	return Config.RerollBaseCost + Config.RerollCostStep * state.rerolls
end

local function sendOffers(player: Player)
	local state = shops[player]
	if state == nil then
		return
	end
	Remotes.get("ShopOffers"):FireClient(player, state.offers, rerollCost(state), state.ready)
end

local function ensureShop(player: Player): ShopState
	local state = shops[player]
	if state == nil then
		state = { offers = rollOffers(nil), rerolls = 0, ready = false }
		shops[player] = state
	end
	return state
end

local function checkAllReady()
	if RoundService.getPhase() ~= "Shop" then
		return
	end
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	for _, player in players do
		local state = shops[player]
		if state == nil or not state.ready then
			return
		end
	end
	RoundService.skipShop()
end

local function onShopStarted()
	table.clear(shops)
	for _, player in Players:GetPlayers() do
		ensureShop(player)
		sendOffers(player)
	end
end

local function onBuy(player: Player, index: any)
	if rateLimited(player) then
		return
	end
	if RoundService.getPhase() ~= "Shop" then
		return
	end
	if type(index) ~= "number" or index % 1 ~= 0 then
		return
	end
	local state = shops[player]
	if state == nil then
		return
	end
	local offer = state.offers[index]
	if offer == nil or offer.sold then
		return
	end
	local upgrade = Upgrades.getById(offer.id)
	if upgrade == nil then
		return
	end
	if not PlayerStatsService.spend(player, offer.price, "shop_" .. offer.id) then
		return
	end

	offer.sold = true
	PlayerStatsService.applyUpgrade(player, upgrade)
	Log.info("ShopService", player.Name, "bought", offer.id, "for", offer.price)
	sendOffers(player)
end

local function onReroll(player: Player)
	if rateLimited(player) then
		return
	end
	if RoundService.getPhase() ~= "Shop" then
		return
	end
	local state = shops[player]
	if state == nil or state.ready then
		return
	end
	if not PlayerStatsService.spend(player, rerollCost(state), "shop_reroll") then
		return
	end

	local exclude = {}
	for _, offer in state.offers do
		table.insert(exclude, offer.id)
	end
	state.rerolls += 1
	state.offers = rollOffers(exclude)
	sendOffers(player)
end

local function onReady(player: Player)
	if rateLimited(player) then
		return
	end
	if RoundService.getPhase() ~= "Shop" then
		return
	end
	local state = shops[player]
	if state == nil then
		return
	end
	state.ready = true
	sendOffers(player)
	checkAllReady()
end

function ShopService.init()
	Log.info("ShopService", "init")
end

function ShopService.start()
	RoundService.shopStarted:Connect(onShopStarted)

	Remotes.get("BuyUpgrade").OnServerEvent:Connect(onBuy)
	Remotes.get("Reroll").OnServerEvent:Connect(onReroll)
	Remotes.get("ReadyUp").OnServerEvent:Connect(onReady)

	-- A client that (re)boots mid-shop gets its offers again; late joiners get fresh ones.
	Remotes.get("ClientReady").OnServerEvent:Connect(function(player: Player)
		if RoundService.getPhase() == "Shop" then
			ensureShop(player)
			sendOffers(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		shops[player] = nil
		lastRemote[player] = nil
		checkAllReady()
	end)
end

return ShopService
