local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)

local C = Config.Blades

local folder = Instance.new("Folder")
folder.Name = "LocalBlades"
folder.Parent = workspace

local bladesByPlayer = {}

local function makeBlade(): BasePart
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = C.Size
	blade.Color = C.Color
	blade.Material = C.Material
	blade.Anchored = true
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CanTouch = false
	blade.CastShadow = false

	local light = Instance.new("PointLight")
	light.Color = C.Color
	light.Brightness = C.LightBrightness
	light.Range = C.LightRange
	light.Parent = blade

	local top = Instance.new("Attachment")
	top.Name = "Top"
	top.Position = Vector3.new(0, C.Size.Y / 2, 0)
	top.Parent = blade
	local bottom = Instance.new("Attachment")
	bottom.Name = "Bottom"
	bottom.Position = Vector3.new(0, -C.Size.Y / 2, 0)
	bottom.Parent = blade

	-- Ribbon swept between the blade's top and bottom edges as it moves.
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(C.Color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 1
	trail.Lifetime = C.TrailLifetime
	trail.WidthScale = NumberSequence.new(C.TrailWidthScale)
	trail.FaceCamera = true
	trail.Parent = blade

	blade.Parent = folder
	return blade
end

local function setBladeCount(player: Player, count: number)
	local list = bladesByPlayer[player]
	if not list then
		list = {}
		bladesByPlayer[player] = list
	end
	while #list < count do
		table.insert(list, makeBlade())
	end
	while #list > count do
		table.remove(list):Destroy()
	end
end

local function clearPlayer(player: Player)
	local list = bladesByPlayer[player]
	if list then
		for _, blade in list do
			blade:Destroy()
		end
		bladesByPlayer[player] = nil
	end
end

Players.PlayerRemoving:Connect(clearPlayer)

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local count = player:GetAttribute(C.CountAttribute) or 0
			setBladeCount(player, count)
			local spin = Upgrades.spinMultiplier(player)
			local reach = Upgrades.reachBonus(player)
			for i, blade in bladesByPlayer[player] do
				local offset, angle = BladeOrbit.getOffset(i, count, t, spin, reach)
				local pos = root.Position + offset
				-- Blade's long axis (Z) points along the orbit tangent.
				local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
				blade.CFrame = CFrame.lookAt(pos, pos + tangent)
			end
		else
			clearPlayer(player)
		end
	end
end)
