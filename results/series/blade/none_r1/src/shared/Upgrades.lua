-- Upgrade definitions plus stat lookups. The server writes each player's upgrade levels
-- as attributes; both server (gameplay) and client (rendering) derive stats from them.
local Config = require(script.Parent.Config)

local S = Config.Shop

local Upgrades = {}

Upgrades.byId = {}
for _, def in S.Upgrades do
	Upgrades.byId[def.Id] = def
end

function Upgrades.getLevel(player: Player, id: string): number
	return player:GetAttribute(S.LevelAttribute .. id) or 0
end

local function bonus(player: Player, id: string): number
	return Upgrades.getLevel(player, id) * Upgrades.byId[id].Amount
end

function Upgrades.damageMultiplier(player: Player): number
	return 1 + bonus(player, "Damage")
end

function Upgrades.spinMultiplier(player: Player): number
	return 1 + bonus(player, "Spin")
end

function Upgrades.reachBonus(player: Player): number
	return bonus(player, "Reach")
end

function Upgrades.coinMultiplier(player: Player): number
	return 1 + bonus(player, "Greed")
end

function Upgrades.maxHealthBonus(player: Player): number
	return bonus(player, "Vitality")
end

function Upgrades.healPerKill(player: Player): number
	return bonus(player, "Vampiric")
end

return Upgrades
