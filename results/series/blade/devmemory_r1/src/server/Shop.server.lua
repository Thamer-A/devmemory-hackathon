-- Break-time upgrade shop. The client only sends slot numbers; every check happens here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Upgrades = require(script.Parent.Upgrades)

local ShopConfig = Config.Shop

-- offers[player] = { [slot] = upgradeId | false (bought) }
local offers = {}

local function isOpen()
	return workspace:GetAttribute("ShopOpen") == true
end

local function rollOffers()
	local pool = table.clone(Config.Upgrades)
	local result = {}
	for slot = 1, math.min(ShopConfig.OffersPerPlayer, #pool) do
		local total = 0
		for _, def in pool do
			total += Config.Rarities[def.Rarity].Weight
		end
		local pick = math.random() * total
		for i, def in pool do
			pick -= Config.Rarities[def.Rarity].Weight
			if pick <= 0 or i == #pool then
				result[slot] = def.Id
				table.remove(pool, i)
				break
			end
		end
	end
	return result
end

local function sendOffers(player)
	Remotes.ShopUpdate:FireClient(player, offers[player] or {})
end

local function newOffers(player)
	offers[player] = rollOffers()
	sendOffers(player)
end

local function coinsOf(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Coins")
end

workspace:GetAttributeChangedSignal("ShopOpen"):Connect(function()
	if isOpen() then
		for _, player in Players:GetPlayers() do
			newOffers(player)
		end
	else
		table.clear(offers)
		for _, player in Players:GetPlayers() do
			sendOffers(player)
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	if isOpen() then
		newOffers(player)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	offers[player] = nil
end)

Remotes.ShopBuy.OnServerEvent:Connect(function(player, slot)
	if not isOpen() or type(slot) ~= "number" then
		return
	end
	local current = offers[player]
	local id = current and current[slot]
	local def = id and Upgrades.get(id)
	local coins = coinsOf(player)
	if not def or not coins or coins.Value < def.Cost then
		return
	end
	coins.Value -= def.Cost
	current[slot] = false
	Upgrades.apply(player, id)
	sendOffers(player)
end)

Remotes.ShopReroll.OnServerEvent:Connect(function(player)
	local coins = coinsOf(player)
	if not isOpen() or not coins or coins.Value < ShopConfig.RerollCost then
		return
	end
	coins.Value -= ShopConfig.RerollCost
	newOffers(player)
end)
