local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local S = Config.Shop

-- The server is the only authority on offers, prices and purchases. Clients just send a
-- slot number; offers are replicated to them as player attributes.
-- player -> { offers = { upgradeId }, sold = { boolean } } (only while the shop is open)
local shops = {}

local function isShopOpen(): boolean
	local endsAt = workspace:GetAttribute(Config.Waves.BreakAttribute) or 0
	return endsAt > 0 and workspace:GetServerTimeNow() < endsAt
end

-- Weighted pick of distinct upgrades.
local function rollOffers(): { string }
	local pool = table.clone(S.Upgrades)
	local offers = {}
	for _ = 1, math.min(S.OfferCount, #pool) do
		local total = 0
		for _, def in pool do
			total += S.RarityWeights[def.Rarity]
		end
		local roll = math.random() * total
		local pick = #pool
		for i, def in pool do
			roll -= S.RarityWeights[def.Rarity]
			if roll <= 0 then
				pick = i
				break
			end
		end
		table.insert(offers, table.remove(pool, pick).Id)
	end
	return offers
end

local function publish(player: Player)
	local state = shops[player]
	for slot = 1, S.OfferCount do
		player:SetAttribute(S.OfferAttribute .. slot, state and state.offers[slot] or "")
		player:SetAttribute(S.SoldAttribute .. slot, state and state.sold[slot] or false)
	end
end

local function openShop(player: Player)
	shops[player] = { offers = rollOffers(), sold = {} }
	publish(player)
end

local function closeShop(player: Player)
	shops[player] = nil
	publish(player)
end

local function getCoins(player: Player): IntValue?
	local stats = player:FindFirstChild(Config.Stats.Folder)
	return stats and stats:FindFirstChild(Config.Stats.Coins)
end

-- Deducts `cost` if the player can afford it.
local function spendCoins(player: Player, cost: number): boolean
	local coins = getCoins(player)
	if not coins or coins.Value < cost then
		return false
	end
	coins.Value -= cost
	return true
end

local function applyUpgrade(player: Player, def)
	local attribute = S.LevelAttribute .. def.Id
	player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + 1)

	if def.Id == "Blade" or def.Id == "TwinSpin" then
		local key = Config.Blades.CountAttribute
		player:SetAttribute(key, (player:GetAttribute(key) or 0) + def.Amount)
	elseif def.Id == "Vitality" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.MaxHealth += def.Amount
			humanoid.Health += def.Amount
		end
	end
	-- Damage, Spin, Reach, Greed and Vampiric are read from the level attribute where used.
end

local function purchase(player: Player, slot: any)
	if not isShopOpen() then
		return
	end
	if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > S.OfferCount then
		return
	end
	local state = shops[player]
	if not state or state.sold[slot] then
		return
	end
	local def = Upgrades.byId[state.offers[slot]]
	if not def or not spendCoins(player, def.Cost) then
		return
	end
	state.sold[slot] = true
	applyUpgrade(player, def)
	publish(player)
end

local function reroll(player: Player)
	if not isShopOpen() or not shops[player] then
		return
	end
	if not spendCoins(player, S.RerollCost) then
		return
	end
	openShop(player)
end

Remotes.PurchaseUpgrade.OnServerEvent:Connect(purchase)
Remotes.RerollOffers.OnServerEvent:Connect(reroll)

-- Open for everyone when a break starts, close when it ends.
local function syncShop()
	local open = isShopOpen()
	for _, player in Players:GetPlayers() do
		if open then
			openShop(player)
		else
			closeShop(player)
		end
	end
end

workspace:GetAttributeChangedSignal(Config.Waves.BreakAttribute):Connect(syncShop)

-- Vitality persists across respawns.
local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		local bonus = Upgrades.maxHealthBonus(player)
		humanoid.MaxHealth += bonus
		humanoid.Health = humanoid.MaxHealth
	end
end

local function initPlayer(player: Player)
	publish(player) -- closed state
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	if isShopOpen() then
		openShop(player) -- joined mid-break
	end
end

Players.PlayerAdded:Connect(initPlayer)
for _, player in Players:GetPlayers() do
	initPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	shops[player] = nil
end)
