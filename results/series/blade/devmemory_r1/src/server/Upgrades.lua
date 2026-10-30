-- Server-side upgrade state. levels[player][id] = times purchased.
-- Stats that clients need to render (reach, spin) are mirrored to player attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Upgrades = {}

local byId = {}
for _, def in Config.Upgrades do
	byId[def.Id] = def
end

local levels = {}

function Upgrades.get(id)
	return byId[id]
end

local function level(player, id)
	return levels[player] and levels[player][id] or 0
end

local function amount(player, id)
	return level(player, id) * byId[id].Amount
end

function Upgrades.damageMultiplier(player)
	return 1 + amount(player, "Damage")
end

function Upgrades.coinMultiplier(player)
	return 1 + amount(player, "Greed")
end

function Upgrades.healPerKill(player)
	return amount(player, "Vampiric")
end

local function applyMaxHealth(player, healBy)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	hum.MaxHealth = Config.Shop.BaseMaxHealth + amount(player, "Vitality")
	if healBy and hum.Health > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + healBy)
	end
end

function Upgrades.apply(player, id)
	levels[player] = levels[player] or {}
	levels[player][id] = level(player, id) + 1

	if id == "Blade" or id == "TwinSpin" then
		local count = (player:GetAttribute("BladeCount") or 0) + byId[id].Amount
		player:SetAttribute("BladeCount", count)
		Remotes.BladeCountChanged:FireAllClients(player.UserId, count)
	elseif id == "Spin" then
		player:SetAttribute("SpinMult", 1 + amount(player, "Spin"))
	elseif id == "Reach" then
		player:SetAttribute("ReachBonus", amount(player, "Reach"))
	elseif id == "Vitality" then
		applyMaxHealth(player, byId.Vitality.Amount)
	end
end

local function track(player)
	player.CharacterAdded:Connect(function()
		task.defer(applyMaxHealth, player)
	end)
end

Players.PlayerAdded:Connect(track)
for _, player in Players:GetPlayers() do
	track(player)
end
Players.PlayerRemoving:Connect(function(player)
	levels[player] = nil
end)

return Upgrades
