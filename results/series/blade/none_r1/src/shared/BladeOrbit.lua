-- Pure orbit math, shared so the server can reuse it later for hit detection.
local Config = require(script.Parent.Config)

local BladeOrbit = {}

-- Offset from the root part's position (world axes) for blade `index` of `count`,
-- plus the blade's current orbit angle. spinMult scales orbit speed, reachBonus adds
-- studs to the orbit radius (both come from the player's upgrades).
function BladeOrbit.getOffset(
	index: number,
	count: number,
	t: number,
	spinMult: number?,
	reachBonus: number?
): (Vector3, number)
	local c = Config.Blades
	local radius = c.OrbitRadius + (reachBonus or 0)
	local angle = t * c.OrbitSpeed * (spinMult or 1) + (index - 1) * (2 * math.pi / count)
	local bob = math.sin(t * c.BobSpeed + index) * c.BobAmplitude
	return Vector3.new(math.cos(angle) * radius, c.HeightOffset + bob, math.sin(angle) * radius), angle
end

return BladeOrbit
