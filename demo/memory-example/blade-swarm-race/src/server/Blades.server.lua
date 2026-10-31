-- Server owns the blade parts (so later hit detection / upgrades live here).
-- The orbit motion itself is animated per-client; see client/BladeOrbit.client.lua.
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config).Blades

local root = Instance.new("Folder")
root.Name = "Blades"
root.Parent = workspace

local function makeBlade(index: number): Part
	local blade = Instance.new("Part")
	blade.Name = "Blade" .. index
	blade.Size = Config.Size
	blade.Color = Config.Color
	blade.Material = Config.Material
	blade.Anchored = true
	blade.CanCollide = false
	blade.CanQuery = false
	blade.CastShadow = false
	blade:SetAttribute("Index", index)

	local light = Instance.new("PointLight")
	light.Color = Config.Color
	light.Brightness = Config.LightBrightness
	light.Range = Config.LightRange
	light.Parent = blade

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -Config.Size.Z / 2)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, Config.Size.Z / 2)
	a1.Parent = blade

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Config.Color, Color3.fromRGB(0, 120, 255))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = Config.TrailLifetime
	trail.LightEmission = 1
	trail.WidthScale = NumberSequence.new(Config.TrailWidth)
	trail.FaceCamera = true
	trail.Parent = blade

	return blade
end

local function setBladeCount(player: Player, count: number)
	local folder = root:FindFirstChild(tostring(player.UserId))
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = tostring(player.UserId)
		folder.Parent = root
	end
	folder:ClearAllChildren()
	for i = 1, count do
		makeBlade(i).Parent = folder
	end
end

local function setup(player: Player)
	player:GetAttributeChangedSignal("BladeCount"):Connect(function()
		setBladeCount(player, player:GetAttribute("BladeCount"))
	end)
	-- Upgrades raise this attribute; the signal above rebuilds the blades.
	player:SetAttribute("BladeCount", Config.StartCount)
end

Players.PlayerAdded:Connect(setup)

Players.PlayerRemoving:Connect(function(player)
	local folder = root:FindFirstChild(tostring(player.UserId))
	if folder then
		folder:Destroy()
	end
end)

for _, player in Players:GetPlayers() do
	setup(player)
end
