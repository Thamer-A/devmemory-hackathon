local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BladeMath = require(Shared:WaitForChild("BladeMath"))
local PlayerStats = require(Shared:WaitForChild("PlayerStats"))
local B = Config.Blades
local COUNT_ATTR = Config.Attributes.BladeCount

-- rigs[player] = { folder = Folder, blades = array of Part }
local rigs = {}

local function makeBlade()
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = B.Size
	blade.Color = B.Color
	blade.Material = B.Material
	blade.Anchored = true
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.CastShadow = false

	local light = Instance.new("PointLight")
	light.Color = B.Color
	light.Brightness = B.LightBrightness
	light.Range = B.LightRange
	light.Parent = blade

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, B.Size.Y / 2, 0)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -B.Size.Y / 2, 0)
	a1.Parent = blade

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(B.Color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = B.TrailLifetime
	trail.LightEmission = 1
	trail.WidthScale = NumberSequence.new(B.TrailWidth, 0)
	trail.Parent = blade

	return blade
end

local function setBladeCount(player, count)
	local rig = rigs[player]
	if not rig then
		return
	end
	for _, blade in rig.blades do
		blade:Destroy()
	end
	table.clear(rig.blades)
	for _ = 1, count do
		local blade = makeBlade()
		blade.Parent = rig.folder
		table.insert(rig.blades, blade)
	end
end

local function addPlayer(player)
	local folder = Instance.new("Folder")
	folder.Name = "Blades_" .. player.UserId
	folder.Parent = workspace
	rigs[player] = { folder = folder, blades = {} }

	setBladeCount(player, player:GetAttribute(COUNT_ATTR) or 0)
	player:GetAttributeChangedSignal(COUNT_ATTR):Connect(function()
		setBladeCount(player, player:GetAttribute(COUNT_ATTR) or 0)
	end)
end

local function removePlayer(player)
	local rig = rigs[player]
	if rig then
		rig.folder:Destroy()
		rigs[player] = nil
	end
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow() -- same clock the server uses for hit detection
	for player, rig in rigs do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local n = #rig.blades
		local speed = PlayerStats.getOrbitSpeed(player)
		local radius = PlayerStats.getOrbitRadius(player)
		for i, blade in rig.blades do
			if root then
				local offset, angle = BladeMath.getOffset(i, n, t, speed, radius)
				local pos = root.Position + offset
				-- long axis (Z) points along the direction of travel
				local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
				blade.CFrame = CFrame.lookAt(pos, pos + tangent)
				blade.Transparency = 0
			else
				blade.Transparency = 1
			end
		end
	end
end)
