-- Renders orbiting blades for every player locally, driven by server time + BladeCount attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)

local c = Config.Blades

local container = Instance.new("Folder")
container.Name = "LocalBlades"
container.Parent = workspace

local blades: { [Player]: { BasePart } } = {}

local function makeBlade(): BasePart
	local part = Instance.new("Part")
	part.Name = "Blade"
	part.Size = c.Size
	part.Color = c.Color
	part.Material = c.Material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Wedge
	mesh.Parent = part

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, c.TrailWidth / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -c.TrailWidth / 2, 0)
	a1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(c.Color)
	trail.LightEmission = 1
	trail.Lifetime = c.TrailLifetime
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = part

	local light = Instance.new("PointLight")
	light.Color = c.Color
	light.Brightness = c.LightBrightness
	light.Range = c.LightRange
	light.Parent = part

	return part
end

local function removeBlades(player: Player)
	local list = blades[player]
	if list then
		for _, b in list do
			b:Destroy()
		end
		blades[player] = nil
	end
end

local function syncCount(player: Player, count: number)
	local list = blades[player] or {}
	blades[player] = list
	while #list < count do
		local b = makeBlade()
		b.Parent = container
		table.insert(list, b)
	end
	while #list > count do
		table.remove(list):Destroy()
	end
end

Players.PlayerRemoving:Connect(removeBlades)

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local count = player:GetAttribute("BladeCount") or 0
		if root and humanoid and humanoid.Health > 0 and count > 0 then
			syncCount(player, count)
			for i, b in blades[player] do
				b.CFrame = BladeOrbit.getCFrame(
					root.Position,
					i,
					count,
					t,
					player:GetAttribute("ReachBonus"),
					player:GetAttribute("SpinMult")
				)
			end
		else
			removeBlades(player)
		end
	end
end)
