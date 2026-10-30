-- Between-wave upgrade shop. All purchase logic is here; clients only send slot numbers.
-- State replicates via attributes: workspace "ShopOpen" (bool), player "ShopOffers" ("Id,Id,Id", sold slot = "").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local S = Config.Shop

local Shop = {}

local isOpen = false
local offers = {} -- [player] = { [slot] = id or false (sold) }

local function coinsValue(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Coins")
end

local function publish(player: Player)
	local list = offers[player]
	local parts = {}
	for slot = 1, S.OfferCount do
		parts[slot] = list and list[slot] or ""
	end
	player:SetAttribute("ShopOffers", if list then table.concat(parts, ",") else "")
end

-- Weighted by rarity; no duplicates within one roll.
local function pickId(taken: { [string]: boolean }): string
	local pool, total = {}, 0
	for _, u in Config.Upgrades do
		if not taken[u.Id] then
			local w = S.RarityWeights[u.Rarity] or 0
			table.insert(pool, { u.Id, w })
			total += w
		end
	end
	local r = math.random() * total
	for _, entry in pool do
		r -= entry[2]
		if r <= 0 then
			return entry[1]
		end
	end
	return pool[#pool][1]
end

local function roll(player: Player)
	local list, taken = {}, {}
	for slot = 1, S.OfferCount do
		local id = pickId(taken)
		taken[id] = true
		list[slot] = id
	end
	offers[player] = list
	publish(player)
end

-- heal == nil: fresh spawn, start full. heal == true: raise current HP by the max-HP gain.
function Shop.applyMaxHealth(player: Player, heal: boolean?)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local old = humanoid.MaxHealth
	local new = Upgrades.maxHealth(player)
	humanoid.MaxHealth = new
	if heal == nil then
		humanoid.Health = new
	elseif heal and new > old and humanoid.Health > 0 then
		humanoid.Health += new - old
	end
end

function Shop.initPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(Shop.applyMaxHealth, player)
	end)
	if isOpen then
		roll(player)
	end
end

function Shop.open()
	if isOpen then
		return
	end
	isOpen = true
	workspace:SetAttribute("ShopOpen", true)
	for _, player in Players:GetPlayers() do
		roll(player)
	end
end

function Shop.close()
	if not isOpen then
		return
	end
	isOpen = false
	workspace:SetAttribute("ShopOpen", false)
	for _, player in Players:GetPlayers() do
		offers[player] = nil
		publish(player)
	end
end

local function apply(player: Player, id: string)
	if id == "Blade" or id == "TwinSpin" then
		player:SetAttribute("BladeCount", (player:GetAttribute("BladeCount") or 0) + Upgrades.byId[id].Amount)
	else
		player:SetAttribute("Up_" .. id, Upgrades.level(player, id) + 1)
		if id == "Vitality" then
			Shop.applyMaxHealth(player, true)
		end
	end
end

local function buy(player: Player, slot: any)
	if not isOpen or typeof(slot) ~= "number" then
		return
	end
	local list = offers[player]
	local id = list and list[slot]
	local coins = coinsValue(player)
	if not id or not coins then
		return
	end
	local upgrade = Upgrades.byId[id]
	if coins.Value < upgrade.Cost then
		return
	end
	coins.Value -= upgrade.Cost
	list[slot] = false
	apply(player, id)
	publish(player)
end

local function reroll(player: Player)
	local coins = coinsValue(player)
	if not isOpen or not coins or coins.Value < S.RerollCost then
		return
	end
	coins.Value -= S.RerollCost
	roll(player)
end

Remotes.BuyOffer.OnServerEvent:Connect(buy)
Remotes.RerollOffers.OnServerEvent:Connect(reroll)

Players.PlayerRemoving:Connect(function(player)
	offers[player] = nil
end)

workspace:SetAttribute("ShopOpen", false)

return Shop
