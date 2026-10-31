local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PlayerStats = require(Shared:WaitForChild("PlayerStats"))
local S = Config.Shop
local A = Config.Attributes

-- offers[player] = { [slot] = upgradeId, or false once bought }. Only exists while the shop is open.
local offers = {}

local function isOpen()
	return workspace:GetAttribute(A.Intermission) == true
end

local function sendState(player)
	Remotes.ShopState:FireClient(player, { Open = isOpen(), Offers = offers[player] or {} })
end

local function rollOffers(player)
	local pool = {}
	for _, upgrade in S.Upgrades do
		table.insert(pool, upgrade.Id)
	end
	-- partial Fisher-Yates: the first OfferCount entries are distinct random picks
	local list = {}
	for slot = 1, S.OfferCount do
		local pick = math.random(slot, #pool)
		pool[slot], pool[pick] = pool[pick], pool[slot]
		list[slot] = pool[slot]
	end
	offers[player] = list
end

local function getCoins(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Coins")
end

-- Stat upgrades are stack-count attributes (read via PlayerStats); blades use BladeCount.
local function applyUpgrade(player, upgrade)
	if upgrade.Id == "ExtraBlade" or upgrade.Id == "TwinSpin" then
		local count = player:GetAttribute(A.BladeCount) or 0
		player:SetAttribute(A.BladeCount, count + upgrade.Amount)
		return
	end

	local attr = A.UpgradePrefix .. upgrade.Id
	player:SetAttribute(attr, (player:GetAttribute(attr) or 0) + 1)

	if upgrade.Id == "Vitality" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.MaxHealth = PlayerStats.getMaxHealth(player)
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + upgrade.Amount)
		end
	end
end

-- Rounds ------------------------------------------------------------------

workspace:GetAttributeChangedSignal(A.Intermission):Connect(function()
	for _, player in Players:GetPlayers() do
		if isOpen() then
			rollOffers(player)
		else
			offers[player] = nil
		end
		sendState(player)
	end
end)

-- Purchases (all validation is server-side; the client only sends a slot) -------

Remotes.ShopBuy.OnServerEvent:Connect(function(player, slot)
	local list = offers[player]
	if not isOpen() or not list then
		return
	end
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > S.OfferCount then
		return
	end

	local upgrade = list[slot] and S.ById[list[slot]]
	local coins = getCoins(player)
	if upgrade and coins and coins.Value >= upgrade.Cost then
		coins.Value -= upgrade.Cost
		list[slot] = false
		applyUpgrade(player, upgrade)
	end
	sendState(player) -- always resync, so a rejected request corrects the client too
end)

Remotes.ShopReroll.OnServerEvent:Connect(function(player)
	if not isOpen() or not offers[player] then
		return
	end

	local coins = getCoins(player)
	if coins and coins.Value >= S.RerollCost then
		coins.Value -= S.RerollCost
		rollOffers(player)
	end
	sendState(player)
end)

Remotes.ShopSync.OnServerEvent:Connect(sendState)

-- Players ----------------------------------------------------------------------

local function initPlayer(player)
	if isOpen() then
		rollOffers(player)
	end
	sendState(player)

	-- Vitality persists across respawns
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.MaxHealth = PlayerStats.getMaxHealth(player)
		humanoid.Health = humanoid.MaxHealth
	end)
end

Players.PlayerAdded:Connect(initPlayer)
for _, player in Players:GetPlayers() do
	initPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	offers[player] = nil
end)
