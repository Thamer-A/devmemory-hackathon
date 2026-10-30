-- Deterministic blade placement so server (hit detection later) and clients agree.
local Config = require(script.Parent.Config)
local Upgrades = require(script.Parent.Upgrades)

local BladeMath = {}

-- Offset from the owner's root for blade `index` of `count` at time `t` (GetServerTimeNow).
-- Also returns the orbit angle. `player` (optional) applies its Reach/Spin upgrades.
function BladeMath.offset(index: number, count: number, t: number, player: Player?): (Vector3, number)
	local c = Config.Blades
	local radius = c.OrbitRadius
	local speed = c.OrbitSpeed
	if player then
		radius += Upgrades.reachBonus(player)
		speed *= Upgrades.spinMult(player)
	end
	local angle = t * speed + (index - 1) * (2 * math.pi / count)
	local bob = math.sin(t * c.BobSpeed + index) * c.BobAmplitude
	return Vector3.new(math.cos(angle) * radius, c.Height + bob, math.sin(angle) * radius), angle
end

return BladeMath
