-- Blade Swarm arena dressing. Run once in Studio (Edit mode) via the command bar or the Studio MCP.
-- Idempotent: rebuilds Workspace.Arena and the lighting setup each time it runs.
-- Theme: graveyard arena at dusk, cyan blades pop against warm torchlight and purple haze.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local rng = Random.new(7)
local ARENA = 180
local HALF = ARENA / 2

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- Lighting: dusk, warm sun, purple haze, soft bloom
for _, c in ipairs(Lighting:GetChildren()) do
	if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
		c:Destroy()
	end
end
Lighting.ClockTime = 18.2
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(60, 52, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(105, 92, 130)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true
Lighting.Technology = Enum.Technology.Future

local atmo = Instance.new("Atmosphere")
atmo.Density = 0.32
atmo.Offset = 0.12
atmo.Color = Color3.fromRGB(176, 150, 200)
atmo.Decay = Color3.fromRGB(92, 66, 118)
atmo.Glare = 0.4
atmo.Haze = 1.6
atmo.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.7
bloom.Size = 28
bloom.Threshold = 1.6
bloom.Parent = Lighting

local cc = Instance.new("ColorCorrectionEffect")
cc.Contrast = 0.12
cc.Saturation = 0.12
cc.TintColor = Color3.fromRGB(255, 244, 236)
cc.Parent = Lighting

local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.06
rays.Spread = 0.7
rays.Parent = Lighting

-- Arena: rebuild
local old = Workspace:FindFirstChild("Arena")
if old then
	old:Destroy()
end
local arena = Instance.new("Folder")
arena.Name = "Arena"

-- floor: grass with a darker inner fighting circle and stone path ring
part({Name = "Floor", Size = Vector3.new(ARENA, 4, ARENA), Position = Vector3.new(0, -2, 0),
	Material = Enum.Material.Grass, Color = Color3.fromRGB(74, 112, 58), Parent = arena})
local ring = part({Name = "StoneRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 120, 120),
	CFrame = CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Cobblestone,
	Color = Color3.fromRGB(92, 88, 96), Parent = arena})
ring.CanCollide = false
local inner = part({Name = "InnerField", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 110, 110),
	CFrame = CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Grass,
	Color = Color3.fromRGB(62, 96, 50), Parent = arena})
inner.CanCollide = false

-- walls: stone with crenellations and torches
local wallColor = Color3.fromRGB(78, 76, 86)
local sides = {
	{pos = Vector3.new(0, 4, -HALF - 2), size = Vector3.new(ARENA + 8, 8, 4), along = Vector3.xAxis},
	{pos = Vector3.new(0, 4, HALF + 2), size = Vector3.new(ARENA + 8, 8, 4), along = Vector3.xAxis},
	{pos = Vector3.new(HALF + 2, 4, 0), size = Vector3.new(4, 8, ARENA + 8), along = Vector3.zAxis},
	{pos = Vector3.new(-HALF - 2, 4, 0), size = Vector3.new(4, 8, ARENA + 8), along = Vector3.zAxis},
}
for i, s in ipairs(sides) do
	part({Name = "Wall" .. i, Size = s.size, Position = s.pos, Material = Enum.Material.Brick, Color = wallColor, Parent = arena})
	for t = -HALF, HALF, 12 do
		local p = s.pos + s.along * t + Vector3.new(0, 5, 0)
		part({Name = "Merlon", Size = Vector3.new(4, 2, 4), Position = p, Material = Enum.Material.Brick,
			Color = wallColor, Parent = arena})
	end
	for t = -HALF + 18, HALF - 18, 36 do
		local base = s.pos + s.along * t + Vector3.new(0, 7.5, 0)
		local torch = part({Name = "Torch", Size = Vector3.new(0.6, 2.4, 0.6), Position = base,
			Material = Enum.Material.Wood, Color = Color3.fromRGB(90, 62, 40), Parent = arena})
		local flame = part({Name = "Flame", Size = Vector3.new(0.8, 0.8, 0.8), Position = base + Vector3.new(0, 1.5, 0),
			Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 150, 60), Parent = torch})
		flame.CanCollide = false
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Color = Color3.fromRGB(255, 140, 50)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 120)
		fire.Parent = flame
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 2.2
		light.Color = Color3.fromRGB(255, 170, 90)
		light.Shadows = true
		light.Parent = flame
	end
end

-- graveyard props in the outer band (kept out of the inner fighting circle)
local props = Instance.new("Folder")
props.Name = "Props"
props.Parent = arena
local function spot(minR, maxR)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(minR, maxR)
	return Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
end
for _ = 1, 26 do
	local p = spot(62, 84)
	if math.abs(p.X) < HALF - 4 and math.abs(p.Z) < HALF - 4 then
		local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-8, 8)))
		local stone = part({Name = "Gravestone", Size = Vector3.new(2.6, 3.4, 0.7),
			CFrame = CFrame.new(p + Vector3.new(0, 1.6, 0)) * yaw, Material = Enum.Material.Slate,
			Color = Color3.fromRGB(120, 118, 128), Parent = props})
		local top = part({Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 2.6, 2.6),
			CFrame = stone.CFrame * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, math.rad(90), 0),
			Material = Enum.Material.Slate, Color = stone.Color, Parent = props})
		top.CanCollide = false
	end
end
for _ = 1, 9 do
	local p = spot(64, 82)
	if math.abs(p.X) < HALF - 6 and math.abs(p.Z) < HALF - 6 then
		local trunk = part({Name = "DeadTree", Size = Vector3.new(1.4, 12, 1.4), Position = p + Vector3.new(0, 6, 0),
			Material = Enum.Material.Wood, Color = Color3.fromRGB(64, 50, 44), Parent = props})
		for b = 1, 4 do
			local yaw = rng:NextNumber(0, math.pi * 2)
			local branch = part({Name = "Branch", Size = Vector3.new(0.6, 5, 0.6),
				CFrame = CFrame.new(trunk.Position + Vector3.new(0, rng:NextNumber(1, 5), 0))
					* CFrame.Angles(0, yaw, math.rad(rng:NextNumber(35, 60))) * CFrame.new(0, 2.2, 0),
				Material = Enum.Material.Wood, Color = trunk.Color, Parent = props})
			branch.CanCollide = false
		end
	end
end

-- glowing spawn pad
local spawnPad = Workspace:FindFirstChild("SpawnLocation")
if spawnPad then
	spawnPad.Material = Enum.Material.Neon
	spawnPad.Color = Color3.fromRGB(70, 220, 255)
	spawnPad.Transparency = 0.25
	spawnPad.Size = Vector3.new(10, 0.4, 10)
	spawnPad.Position = Vector3.new(0, 0.2, 0)
	local decal = spawnPad:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

arena.Parent = Workspace
return "arena built"
