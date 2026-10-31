-- Deterministic blade placement; server and client use the same function so they agree.
local Config = require(script.Parent.Config)

local BladeOrbit = {}

-- reachBonus (studs added to the orbit radius) and spinMult come from the player's upgrades.
function BladeOrbit.getCFrame(
	center: Vector3,
	index: number,
	count: number,
	t: number,
	reachBonus: number?,
	spinMult: number?
): CFrame
	local c = Config.Blades
	local radius = c.OrbitRadius + (reachBonus or 0)
	local spin = c.SpinSpeed * (spinMult or 1)
	local angle = t * c.OrbitSpeed + (index - 1) * (2 * math.pi / count)
	local bob = math.sin(t * c.BobSpeed + index * 1.7) * c.BobAmplitude
	local offset = Vector3.new(math.cos(angle) * radius, c.HeightOffset + bob, math.sin(angle) * radius)
	local pos = center + offset
	local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	-- point along the direction of travel, roll around that axis
	return CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, t * spin + index)
end

return BladeOrbit
