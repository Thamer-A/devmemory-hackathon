-- Dresses the arena as a graveyard at dusk: wall torches, gravestones, dead trees, warm haze.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config).Graveyard
local rng = Random.new(Config.Seed)

local arena = workspace:WaitForChild("Arena")
local decor = Instance.new("Folder")
decor.Name = "Graveyard"
decor.Parent = arena

local function makePart(name, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false -- decor must not block zombies, blades or spawns
	part.CanQuery = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Random point in the band between the clear middle and the walls (square rings, to match the arena).
local function edgePosition()
	local outer = Config.ArenaHalf - Config.PropMargin
	while true do
		local x = rng:NextNumber(-outer, outer)
		local z = rng:NextNumber(-outer, outer)
		if math.max(math.abs(x), math.abs(z)) > Config.ClearRadius then
			return x, z
		end
	end
end

local function lighting()
	local L = Config.Lighting
	Lighting.ClockTime = L.ClockTime
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient
	Lighting.Brightness = L.Brightness
	Lighting.FogColor = L.FogColor
	Lighting.FogEnd = 600

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = L.AtmosphereDensity
	atmosphere.Haze = L.AtmosphereHaze
	atmosphere.Color = L.AtmosphereColor
	atmosphere.Decay = L.AtmosphereDecay
	atmosphere.Parent = Lighting

	local correction = Instance.new("ColorCorrectionEffect")
	correction.TintColor = L.Tint
	correction.Saturation = L.Saturation
	correction.Contrast = L.Contrast
	correction.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = L.BloomIntensity
	bloom.Size = L.BloomSize
	bloom.Threshold = L.BloomThreshold
	bloom.Parent = Lighting
end

local function floor()
	local part = arena:FindFirstChild("Floor")
	if part then
		part.Color = Config.FloorColor
		part.Material = Enum.Material.Ground
	end
end

local function torch(position, facing)
	local folder = Instance.new("Model")
	folder.Name = "Torch"
	folder.Parent = decor

	makePart("Handle", Vector3.new(0.5, 2.6, 0.5), CFrame.new(position), Config.WoodColor, Enum.Material.Wood, folder)
	local bowl = makePart("Bowl", Vector3.new(1.1, 0.6, 1.1), CFrame.new(position + Vector3.new(0, 1.5, 0)), Config.StoneColor, Enum.Material.Slate, folder)
	bowl.Shape = Enum.PartType.Cylinder
	bowl.CFrame = bowl.CFrame * CFrame.Angles(0, 0, math.rad(90))
	-- Bracket joins the torch to the wall.
	makePart("Bracket", Vector3.new(0.4, 0.4, 1.2), CFrame.lookAt(position - facing * 0.4, position - facing * 2), Config.WoodColor, Enum.Material.Wood, folder)

	local fire = Instance.new("Fire")
	fire.Color = Config.FireColor
	fire.SecondaryColor = Color3.fromRGB(200, 50, 20)
	fire.Heat = 8
	fire.Size = 4
	fire.Parent = bowl

	local light = Instance.new("PointLight")
	light.Color = Config.FireColor
	light.Range = Config.TorchLightRange
	light.Brightness = Config.TorchLightBrightness
	light.Shadows = false
	light.Parent = bowl
end

local function wallTorches()
	local half = Config.ArenaHalf
	local inner = half - 0.5 -- inner face of the 4-stud wall
	local count = math.floor(2 * half / Config.TorchSpacing)
	for i = 0, count - 1 do
		local t = -half + Config.TorchSpacing * (i + 0.5)
		local y = Config.TorchHeight
		torch(Vector3.new(t, y, -inner), Vector3.new(0, 0, 1))
		torch(Vector3.new(t, y, inner), Vector3.new(0, 0, -1))
		torch(Vector3.new(-inner, y, t), Vector3.new(1, 0, 0))
		torch(Vector3.new(inner, y, t), Vector3.new(-1, 0, 0))
	end
end

-- Crenellations along the wall tops so the boundary reads as a stone wall, not a fence.
local function battlements()
	local half = Config.ArenaHalf + 2 -- wall centerline
	local step = 8
	for t = -half + 4, half - 4, step do
		local size = Vector3.new(4, 3, 4)
		local color = Config.StoneColor
		local y = Config.WallTopHeight + 1.5
		makePart("Merlon", size, CFrame.new(t, y, -half), color, Enum.Material.Cobblestone, decor)
		makePart("Merlon", size, CFrame.new(t, y, half), color, Enum.Material.Cobblestone, decor)
		makePart("Merlon", size, CFrame.new(-half, y, t), color, Enum.Material.Cobblestone, decor)
		makePart("Merlon", size, CFrame.new(half, y, t), color, Enum.Material.Cobblestone, decor)
	end
end

local function gravestone()
	local x, z = edgePosition()
	local height = rng:NextNumber(3, 5.5)
	local width = rng:NextNumber(2.2, 3.2)
	local tilt = math.rad(rng:NextNumber(-8, 8))
	local yaw = math.rad(rng:NextNumber(0, 360))
	local color = Config.StoneColor:Lerp(Config.MossColor, rng:NextNumber(0, 0.5))

	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, tilt)
	local model = Instance.new("Model")
	model.Name = "Gravestone"
	model.Parent = decor

	local slab = makePart("Slab", Vector3.new(width, height, 0.8), base * CFrame.new(0, height / 2 - 0.3, 0), color, Enum.Material.Slate, model)
	if rng:NextNumber() < 0.5 then
		-- Rounded top
		local cap = makePart("Cap", Vector3.new(0.8, width, width), base * CFrame.new(0, height - 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Slate, model)
		cap.Shape = Enum.PartType.Cylinder
	else
		-- Cross
		makePart("Arm", Vector3.new(width * 1.6, 0.7, 0.8), base * CFrame.new(0, height * 0.7, 0), color, Enum.Material.Slate, model)
	end
	makePart("Mound", Vector3.new(width, 0.6, 5), base * CFrame.new(0, 0, -3), Config.FloorColor:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Mud, model)
	return slab
end

local function branch(parent, origin, direction, length, thickness, depth)
	local tip = origin + direction * length
	local part = makePart("Branch", Vector3.new(thickness, thickness, length), CFrame.lookAt(origin, tip) * CFrame.new(0, 0, -length / 2), Config.WoodColor, Enum.Material.Wood, parent)
	part.Shape = Enum.PartType.Block
	if depth <= 0 then
		return
	end
	for _ = 1, rng:NextInteger(2, 3) do
		local spread = Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.2, 0.8), rng:NextNumber(-0.8, 0.8))
		branch(parent, tip, (direction + spread).Unit, length * 0.7, thickness * 0.65, depth - 1)
	end
end

local function deadTree()
	local x, z = edgePosition()
	local model = Instance.new("Model")
	model.Name = "DeadTree"
	model.Parent = decor

	local height = rng:NextNumber(9, 14)
	makePart("Trunk", Vector3.new(1.6, height, 1.6), CFrame.new(x, height / 2, z), Config.WoodColor, Enum.Material.Wood, model)
	local top = Vector3.new(x, height, z)
	for _ = 1, 3 do
		local flat = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 0.9), rng:NextNumber(-1, 1))
		branch(model, top - Vector3.new(0, rng:NextNumber(0, 2), 0), flat.Unit, rng:NextNumber(4, 6), 0.8, 2)
	end
end

lighting()
floor()
battlements()
wallTorches()
for _ = 1, Config.GravestoneCount do
	gravestone()
end
for _ = 1, Config.TreeCount do
	deadTree()
end
