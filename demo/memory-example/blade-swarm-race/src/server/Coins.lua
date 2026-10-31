-- The only place coins are changed outside leaderstats setup.
local Coins = {}

local function getValue(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Coins")
end

function Coins.add(player: Player, amount: number)
	local value = getValue(player)
	if value then
		value.Value += amount
	end
end

-- Deducts and returns true only if the player can afford it.
function Coins.trySpend(player: Player, amount: number): boolean
	local value = getValue(player)
	if not value or value.Value < amount then
		return false
	end
	value.Value -= amount
	return true
end

return Coins
