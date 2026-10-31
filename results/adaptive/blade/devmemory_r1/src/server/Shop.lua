-- Between-wave upgrade shop. All state and purchase rules live on the server;
-- clients only display offers and send slot numbers.
local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Coins = require(script.Parent.Coins)

local ShopConfig = Config.Shop

local isOpen = false
local offers: { [Player]: { { Id: string, Bought: boolean } } } = {}

local function bump(player: Player, name: string, amount: number, default: number)
	player:SetAttribute(name, (player:GetAttribute(name) or default) + amount)
end

local function applyMaxHealth(player: Player, heal: number?)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.MaxHealth = Config.Player.MaxHealth + (player:GetAttribute("BonusMaxHealth") or 0)
	if heal then
		humanoid.Health += heal
	end
end

-- Attributes replicate to clients, so visual ones (Reach, SpinMult) need no remote.
local effects = {
	Blade = function(player, amount)
		bump(player, "BladeCount", amount, Config.Blades.StartCount)
	end,
	TwinSpin = function(player, amount)
		bump(player, "BladeCount", amount, Config.Blades.StartCount)
	end,
	Damage = function(player, amount)
		bump(player, "DamageBonus", amount, 0)
	end,
	Spin = function(player, amount)
		bump(player, "SpinMult", amount, 1)
	end,
	Reach = function(player, amount)
		bump(player, "Reach", amount, 0)
	end,
	Vitality = function(player, amount)
		bump(player, "BonusMaxHealth", amount, 0)
		applyMaxHealth(player, amount)
	end,
	Vampiric = function(player, amount)
		bump(player, "LifeSteal", amount, 0)
	end,
	Greed = function(player, amount)
		bump(player, "CoinBonus", amount, 0)
	end,
}

local byId = {}
for _, upgrade in ShopConfig.Upgrades do
	byId[upgrade.Id] = upgrade
end

-- Weighted pick without replacement so a shop never shows the same upgrade twice.
local function roll(): { { Id: string, Bought: boolean } }
	local pool = table.clone(ShopConfig.Upgrades)
	local result = {}
	for _ = 1, math.min(ShopConfig.OfferCount, #pool) do
		local total = 0
		for _, upgrade in pool do
			total += ShopConfig.RarityWeight[upgrade.Rarity]
		end
		local pick = math.random() * total
		for i, upgrade in pool do
			pick -= ShopConfig.RarityWeight[upgrade.Rarity]
			if pick <= 0 or i == #pool then
				table.insert(result, { Id = upgrade.Id, Bought = false })
				table.remove(pool, i)
				break
			end
		end
	end
	return result
end

local function send(player: Player)
	local list = {}
	for _, offer in offers[player] or {} do
		local upgrade = byId[offer.Id]
		table.insert(list, {
			Name = upgrade.Name,
			Rarity = upgrade.Rarity,
			Cost = upgrade.Cost,
			Description = upgrade.Description,
			Bought = offer.Bought,
		})
	end
	Remotes.ShopUpdate:FireClient(player, { Open = isOpen, RerollCost = ShopConfig.RerollCost, Offers = list })
end

local Shop = {}

function Shop.open()
	isOpen = true
	for _, player in Players:GetPlayers() do
		offers[player] = roll()
		send(player)
	end
end

function Shop.close()
	isOpen = false
	for _, player in Players:GetPlayers() do
		send(player)
	end
end

Remotes.ShopSync.OnServerEvent:Connect(function(player)
	if isOpen and not offers[player] then
		offers[player] = roll()
	end
	send(player)
end)

Remotes.BuyOffer.OnServerEvent:Connect(function(player, slot)
	local list = offers[player]
	if not isOpen or not list or type(slot) ~= "number" then
		return
	end
	local offer = list[slot]
	if not offer or offer.Bought then
		return
	end
	local upgrade = byId[offer.Id]
	if not Coins.trySpend(player, upgrade.Cost) then
		return
	end
	offer.Bought = true
	effects[upgrade.Id](player, upgrade.Amount)
	send(player)
end)

Remotes.RerollOffers.OnServerEvent:Connect(function(player)
	if not isOpen or not Coins.trySpend(player, ShopConfig.RerollCost) then
		return
	end
	offers[player] = roll()
	send(player)
end)

local function watchCharacter(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(applyMaxHealth, player)
	end)
end

Players.PlayerAdded:Connect(watchCharacter)
for _, player in Players:GetPlayers() do
	watchCharacter(player)
end

Players.PlayerRemoving:Connect(function(player)
	offers[player] = nil
end)

return Shop
