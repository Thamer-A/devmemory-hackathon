-- Between-wave upgrade shop. All validation and purchasing happens here; clients only send slot/reroll requests.
-- Offers are replicated per player via the "ShopOffers" attribute: comma-separated upgrade Ids, "" = slot already bought.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local shop = Config.Shop

local byId: { [string]: typeof(shop.Upgrades[1]) } = {}
for _, upgrade in shop.Upgrades do
	byId[upgrade.Id] = upgrade
end

local offers: { [Player]: { string } } = {}

local function isOpen(): boolean
	return (workspace:GetAttribute("BreakSecondsLeft") or 0) > 0
end

local function publish(player: Player)
	player:SetAttribute("ShopOffers", table.concat(offers[player] or {}, ","))
end

-- Weighted pick of distinct upgrades.
local function rollOffers(): { string }
	local pool = table.clone(shop.Upgrades)
	local result = {}
	for _ = 1, math.min(shop.OffersPerPlayer, #pool) do
		local total = 0
		for _, u in pool do
			total += shop.RarityWeights[u.Rarity]
		end
		local pick = math.random() * total
		for i, u in pool do
			pick -= shop.RarityWeights[u.Rarity]
			if pick <= 0 or i == #pool then
				table.insert(result, u.Id)
				table.remove(pool, i)
				break
			end
		end
	end
	return result
end

local function getCoins(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Coins") :: IntValue?
end

local function openFor(player: Player)
	offers[player] = rollOffers()
	publish(player)
end

local function clearFor(player: Player)
	offers[player] = nil
	player:SetAttribute("ShopOffers", "")
end

Remotes.get("ShopBuy").OnServerEvent:Connect(function(player, slot)
	local list = offers[player]
	if not isOpen() or not list or typeof(slot) ~= "number" or slot % 1 ~= 0 then
		return
	end
	local upgrade = byId[list[slot] or ""]
	local coins = getCoins(player)
	if not upgrade or not coins or coins.Value < upgrade.Cost then
		return
	end
	coins.Value -= upgrade.Cost
	player:SetAttribute(upgrade.Attribute, player:GetAttribute(upgrade.Attribute) + upgrade.Amount)
	list[slot] = ""
	publish(player)
end)

Remotes.get("ShopReroll").OnServerEvent:Connect(function(player)
	local coins = getCoins(player)
	if not isOpen() or not offers[player] or not coins or coins.Value < shop.RerollCost then
		return
	end
	coins.Value -= shop.RerollCost
	openFor(player)
end)

-- Open/close for everyone when a break starts/ends; players joining mid-break get offers too.
workspace:GetAttributeChangedSignal("BreakSecondsLeft"):Connect(function()
	for _, player in Players:GetPlayers() do
		if isOpen() and not offers[player] then
			openFor(player)
		elseif not isOpen() and offers[player] then
			clearFor(player)
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("ShopOffers", "")
	if isOpen() then
		openFor(player)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	offers[player] = nil
end)
for _, player in Players:GetPlayers() do
	player:SetAttribute("ShopOffers", "")
	if isOpen() then
		openFor(player)
	end
end
