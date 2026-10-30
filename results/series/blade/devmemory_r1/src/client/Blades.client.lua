local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config).Blades
local Remotes = require(Shared.Remotes)

-- blades[player] = { part1, part2, ... }
local blades = {}

local function makeBlade()
	local part = Instance.new("Part")
	part.Name = "Blade"
	part.Size = Config.Size
	part.Color = Config.Color
	part.Material = Config.Material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Wedge
	mesh.Parent = part

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, Config.Size.Y / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -Config.Size.Y / 2, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Config.Color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 1
	trail.Lifetime = Config.TrailLifetime
	trail.Parent = part

	local light = Instance.new("PointLight")
	light.Color = Config.Color
	light.Brightness = Config.LightBrightness
	light.Range = Config.LightRange
	light.Parent = part

	return part
end

local function setCount(player, count)
	local list = blades[player] or {}
	blades[player] = list
	while #list > count do
		table.remove(list):Destroy()
	end
	while #list < count do
		local blade = makeBlade()
		blade.Parent = workspace
		table.insert(list, blade)
	end
end

local function track(player)
	local function sync()
		setCount(player, player:GetAttribute("BladeCount") or 0)
	end
	player:GetAttributeChangedSignal("BladeCount"):Connect(sync)
	sync()
end

Players.PlayerAdded:Connect(track)
for _, player in Players:GetPlayers() do
	track(player)
end
Players.PlayerRemoving:Connect(function(player)
	setCount(player, 0)
	blades[player] = nil
end)

-- Brief expanding-ring flash under the player when their blade count changes
Remotes.BladeCountChanged.OnClientEvent:Connect(function(userId)
	local player = Players:GetPlayerByUserId(userId)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Cylinder
	flash.Size = Vector3.new(0.2, Config.OrbitRadius * 2, Config.OrbitRadius * 2)
	flash.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
	flash.Color = Config.Color
	flash.Material = Config.Material
	flash.Transparency = 0.5
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Parent = workspace
	Debris:AddItem(flash, Config.FlashDuration)
end)

RunService.RenderStepped:Connect(function()
	-- Server time keeps every client's orbit phase identical (and matches future server hit checks).
	local t = workspace:GetServerTimeNow()
	for player, list in blades do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local n = #list
		local radius = Config.OrbitRadius + (player:GetAttribute("ReachBonus") or 0)
		local spin = Config.SpinSpeed * (player:GetAttribute("SpinMult") or 1)
		for i, blade in list do
			if root then
				local angle = t * Config.OrbitSpeed + (i - 1) * (2 * math.pi / n)
				local bob = math.sin(t * Config.BobSpeed + i) * Config.BobAmplitude
				local offset = Vector3.new(math.cos(angle) * radius, Config.HeightOffset + bob, math.sin(angle) * radius)
				local pos = root.Position + offset
				-- Blade length points along the direction of travel, spinning on its own axis
				local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
				blade.CFrame = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, t * spin)
				blade.Transparency = 0
			else
				blade.Transparency = 1
			end
		end
	end
end)
