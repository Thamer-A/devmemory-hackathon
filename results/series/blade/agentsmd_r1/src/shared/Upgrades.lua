-- Upgrade lookup + derived stats. Stack counts live in player attributes "Up_<Id>" (server writes).
-- (The "Blade" and "TwinSpin" upgrades just bump the BladeCount attribute, so they have no Up_ entry.)
local Config = require(script.Parent.Config)

local Upgrades = {}

Upgrades.byId = {}
for _, u in Config.Upgrades do
	Upgrades.byId[u.Id] = u
end

function Upgrades.level(player: Player, id: string): number
	return player:GetAttribute("Up_" .. id) or 0
end

local function amount(player: Player, id: string): number
	return Upgrades.byId[id].Amount * Upgrades.level(player, id)
end

function Upgrades.damageMult(player: Player): number
	return 1 + amount(player, "Damage")
end

function Upgrades.spinMult(player: Player): number
	return 1 + amount(player, "Spin")
end

function Upgrades.reachBonus(player: Player): number
	return amount(player, "Reach")
end

function Upgrades.maxHealth(player: Player): number
	return Config.Player.BaseMaxHealth + amount(player, "Vitality")
end

function Upgrades.healPerKill(player: Player): number
	return amount(player, "Vampiric")
end

function Upgrades.coinMult(player: Player): number
	return 1 + amount(player, "Greed")
end

return Upgrades
