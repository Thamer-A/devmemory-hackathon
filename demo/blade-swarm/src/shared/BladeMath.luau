--!strict
-- Pure blade geometry. The server uses it for hit detection and clients use it for visuals,
-- both fed with workspace:GetServerTimeNow(), so they always agree on where the blades are.

local BladeMath = {}

local TAU = math.pi * 2

-- Angle (radians) of blade `index` (1-based) at server time `t`.
function BladeMath.angle(index: number, count: number, spinSpeed: number, t: number): number
	return t * spinSpeed + (index - 1) * TAU / count
end

function BladeMath.positions(rootPos: Vector3, count: number, radius: number, spinSpeed: number, t: number): { Vector3 }
	local result: { Vector3 } = {}
	if count < 1 then
		return result
	end
	for i = 1, count do
		local a = BladeMath.angle(i, count, spinSpeed, t)
		result[i] = rootPos + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
	end
	return result
end

return BladeMath
