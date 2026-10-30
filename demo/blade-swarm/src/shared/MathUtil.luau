--!strict
local MathUtil = {}

function MathUtil.round(n: number, decimals: number?): number
	local scale = 10 ^ (decimals or 0)
	return math.floor(n * scale + 0.5) / scale
end

function MathUtil.clamp(n: number, min: number, max: number): number
	if min > max then
		min, max = max, min
	end
	return math.max(min, math.min(max, n))
end

function MathUtil.formatNumber(n: number): string
	local formatted = tostring(math.floor(n + 0.5))
	local replaced
	repeat
		formatted, replaced = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until replaced == 0
	return formatted
end

-- Formats seconds as m:ss.
function MathUtil.formatClock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

-- Flat (XZ plane) distance between two points.
function MathUtil.flatDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

return MathUtil
