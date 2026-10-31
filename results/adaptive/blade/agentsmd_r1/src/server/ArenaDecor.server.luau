-- Builds the graveyard-at-dusk look: lighting, wall torches, gravestones, dead trees.
-- Decor is non-colliding so it never blocks players or zombie pathing. Numbers: Config.Arena.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local A = Config.Arena
local rng = Random.new(A.Seed)

local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = Workspace

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = decor
	return p
end

-- Lighting ------------------------------------------------------------------
local L = A.Lighting
Lighting.ClockTime = L.ClockTime
Lighting.Ambient = L.Ambient
Lighting.OutdoorAmbient = L.OutdoorAmbient
Lighting.Brightness = L.Brightness
Lighting.ColorShift_Top = L.ColorShiftTop
Lighting.FogColor = L.FogColor
Lighting.FogStart = L.FogStart
Lighting.FogEnd = L.FogEnd

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = L.AtmosphereDensity
atmosphere.Haze = L.AtmosphereHaze
atmosphere.Color = L.AtmosphereColor
atmosphere.Decay = L.AtmosphereDecay
atmosphere.Parent = Lighting

local cc = Instance.new("ColorCorrectionEffect")
cc.TintColor = L.TintColor
cc.Saturation = L.Saturation
cc.Contrast = L.Contrast
cc.Parent = Lighting

-- Floor ---------------------------------------------------------------------
local arena = Workspace:FindFirstChild("Arena")
local floor = arena and arena:FindFirstChild("Floor")
if floor then
	floor.Color = A.FloorColor
end

-- Torches on top of the walls, facing the arena -------------------------------
local function torch(pos: Vector3)
	part("TorchPost", Vector3.new(0.6, 3, 0.6), CFrame.new(pos), A.WoodColor, Enum.Material.Wood)
	local bowl = part("TorchHead", Vector3.new(1.2, 0.8, 1.2), CFrame.new(pos + Vector3.new(0, 1.8, 0)), Color3.fromRGB(35, 30, 28), Enum.Material.Metal)
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 150, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Heat = 6
	fire.Size = 4
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Color = A.TorchLightColor
	light.Brightness = A.TorchBrightness
	light.Range = A.TorchRange
	light.Shadows = false
	light.Parent = bowl
end

local edge = A.WallInnerEdge + 1 -- wall center line is 92; keep torches on the wall top, near the inner side
local torchY = A.WallHeight + 1.5
local count = math.floor(edge * 2 / A.TorchSpacing)
for i = 0, count do
	local t = -edge + (edge * 2) * i / count
	torch(Vector3.new(t, torchY, -edge))
	torch(Vector3.new(t, torchY, edge))
	if i > 0 and i < count then
		torch(Vector3.new(-edge, torchY, t))
		torch(Vector3.new(edge, torchY, t))
	end
end

-- Crenellations along the wall tops so the walls read as stone ---------------
local merlon = Vector3.new(4, 2, 2)
local wallCenter = A.WallInnerEdge + 2
local merlonY = A.WallHeight + 1
local merlonCount = count * 2
for i = 0, merlonCount do
	local t = -wallCenter + (wallCenter * 2) * i / merlonCount
	part("Merlon", merlon, CFrame.new(t, merlonY, -wallCenter + 1.5), A.StoneColor, Enum.Material.Cobblestone)
	part("Merlon", merlon, CFrame.new(t, merlonY, wallCenter - 1.5), A.StoneColor, Enum.Material.Cobblestone)
	part("Merlon", merlon, CFrame.new(-wallCenter + 1.5, merlonY, t) * CFrame.Angles(0, math.pi / 2, 0), A.StoneColor, Enum.Material.Cobblestone)
	part("Merlon", merlon, CFrame.new(wallCenter - 1.5, merlonY, t) * CFrame.Angles(0, math.pi / 2, 0), A.StoneColor, Enum.Material.Cobblestone)
end

-- Random position in the square ring between the inner and outer radius ------
local function ringPoint(): Vector3
	while true do
		local x = rng:NextNumber(-A.DecorOuterRadius, A.DecorOuterRadius)
		local z = rng:NextNumber(-A.DecorOuterRadius, A.DecorOuterRadius)
		if math.max(math.abs(x), math.abs(z)) >= A.DecorInnerRadius then
			return Vector3.new(x, 0, z)
		end
	end
end

-- Gravestones ---------------------------------------------------------------
for _ = 1, A.GravestoneCount do
	local pos = ringPoint()
	local yaw = rng:NextNumber(0, math.pi * 2)
	local lean = rng:NextNumber(-0.15, 0.15)
	local h = rng:NextNumber(3, 5)
	local w = rng:NextNumber(2, 3)
	local base = CFrame.new(pos + Vector3.new(0, h / 2 - 0.3, 0)) * CFrame.Angles(0, yaw, lean)
	local shade = rng:NextNumber(0.85, 1.1)
	local color = Color3.new(
		math.clamp(A.StoneColor.R * shade, 0, 1),
		math.clamp(A.StoneColor.G * shade, 0, 1),
		math.clamp(A.StoneColor.B * shade, 0, 1)
	)
	part("Gravestone", Vector3.new(w, h, 0.8), base, color, Enum.Material.Slate)
	if rng:NextNumber() < 0.5 then
		-- rounded top (cylinder axis is X, so roll it onto Z to face the stone's front)
		part("GravestoneTop", Vector3.new(0.8, w, w), base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), color, Enum.Material.Slate, Enum.PartType.Cylinder)
	else
		part("GravestoneCross", Vector3.new(w * 1.4, 0.7, 0.8), base * CFrame.new(0, h * 0.25, 0), color, Enum.Material.Slate)
	end
end

-- Dead trees ----------------------------------------------------------------
local function branch(from: Vector3, dir: Vector3, length: number, thickness: number, depth: number)
	local tip = from + dir * length
	part("Branch", Vector3.new(thickness, thickness, length), CFrame.lookAt(from, tip) * CFrame.new(0, 0, -length / 2), A.WoodColor, Enum.Material.Wood)
	if depth <= 0 then
		return
	end
	for _ = 1, 2 do
		local jitter = Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.1, 0.7), rng:NextNumber(-0.8, 0.8))
		branch(tip, (dir + jitter).Unit, length * 0.7, thickness * 0.65, depth - 1)
	end
end

for _ = 1, A.DeadTreeCount do
	local pos = ringPoint()
	local height = rng:NextNumber(10, 16)
	local trunk = part("Trunk", Vector3.new(1.6, height, 1.6), CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.06, 0.06)), A.WoodColor, Enum.Material.Wood)
	local top = trunk.Position + Vector3.new(0, height / 2, 0)
	for _ = 1, rng:NextInteger(2, 3) do
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(a), rng:NextNumber(0.5, 1.2), math.sin(a)).Unit
		branch(top - Vector3.new(0, rng:NextNumber(0, 3), 0), dir, rng:NextNumber(4, 6), 0.9, 2)
	end
end
