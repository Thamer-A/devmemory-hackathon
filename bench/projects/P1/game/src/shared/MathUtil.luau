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

function MathUtil.randomPointInPart(part: BasePart): Vector3
	local size = part.Size
	local offset = Vector3.new(
		(math.random() - 0.5) * size.X,
		(math.random() - 0.5) * size.Y,
		(math.random() - 0.5) * size.Z
	)
	return (part.CFrame * CFrame.new(offset)).Position
end

return MathUtil
