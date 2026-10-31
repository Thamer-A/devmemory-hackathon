-- Orbit math shared by the client (rendering) and the server (hit detection),
-- so both agree on where each blade is at a given time.
local Config = require(script.Parent:WaitForChild("Config"))
local B = Config.Blades

local BladeMath = {}

-- Offset from the character's HumanoidRootPart for blade i of n at time t.
-- Also returns the orbit angle (used by the client to aim the blade).
-- speed and radius default to the base config; pass the player's upgraded values.
function BladeMath.getOffset(i, n, t, speed, radius)
	speed = speed or B.OrbitSpeed
	radius = radius or B.OrbitRadius
	local angle = t * speed + (i - 1) * math.pi * 2 / n
	local bob = math.sin(t * B.BobSpeed + i) * B.BobAmplitude
	local offset = Vector3.new(math.cos(angle) * radius, B.HeightOffset + bob, math.sin(angle) * radius)
	return offset, angle
end

return BladeMath
