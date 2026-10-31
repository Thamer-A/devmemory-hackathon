-- Single source of truth for where a blade is, so client visuals and server hit detection agree.
local Config = require(script.Parent.Config).Blades

local BladeMath = {}

function BladeMath.getOffset(index: number, count: number, t: number, reach: number?): Vector3
	local angle = t * Config.OrbitSpeed + (index - 1) * (2 * math.pi / count)
	local bob = math.sin(t * Config.BobSpeed + index) * Config.BobAmount
	local radius = Config.OrbitRadius + (reach or 0)
	return Vector3.new(math.cos(angle) * radius, Config.Height + bob, math.sin(angle) * radius), angle
end

return BladeMath
