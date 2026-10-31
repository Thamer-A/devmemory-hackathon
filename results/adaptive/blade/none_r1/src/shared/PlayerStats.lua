-- Derived player stats. Upgrades live as "Upgrade_<Id>" stack counts in player
-- attributes (set only by the server), so the server (combat) and the client
-- (rendering, UI) compute identical numbers from the same source.
local Config = require(script.Parent:WaitForChild("Config"))
local B = Config.Blades
local U = Config.Shop.ById

local PlayerStats = {}

local function stacks(player, id)
	return player:GetAttribute(Config.Attributes.UpgradePrefix .. id) or 0
end

function PlayerStats.getDamage(player)
	return B.Damage * (1 + U.SharperBlades.Amount * stacks(player, "SharperBlades"))
end

function PlayerStats.getOrbitSpeed(player)
	return B.OrbitSpeed * (1 + U.FasterSpin.Amount * stacks(player, "FasterSpin"))
end

function PlayerStats.getOrbitRadius(player)
	return B.OrbitRadius + U.LongerReach.Amount * stacks(player, "LongerReach")
end

-- Grows with the orbit radius so zombies hugging the player stay reachable.
function PlayerStats.getHitRadius(player)
	return math.max(B.HitRadius, PlayerStats.getOrbitRadius(player) - B.InnerReach)
end

function PlayerStats.getMaxHealth(player)
	return Config.Player.BaseMaxHealth + U.Vitality.Amount * stacks(player, "Vitality")
end

function PlayerStats.getKillHeal(player)
	return U.Vampiric.Amount * stacks(player, "Vampiric")
end

function PlayerStats.getCoinMultiplier(player)
	return 1 + U.Greed.Amount * stacks(player, "Greed")
end

return PlayerStats
