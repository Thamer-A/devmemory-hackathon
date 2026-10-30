local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BladeMath = require(Shared.BladeMath)
local Upgrades = require(Shared.Upgrades)

require(script:WaitForChild("HudUI"))
require(script:WaitForChild("ShopUI"))
require(script:WaitForChild("FxUI"))

local c = Config.Blades
local folder = Instance.new("Folder")
folder.Name = "Blades"
folder.Parent = workspace

-- [player] = { Part, ... }
local rigs = {}

local function makeBlade(): BasePart
	local p = Instance.new("Part")
	p.Size = c.Size
	p.Color = c.Color
	p.Material = c.Material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -c.Size.Z / 2)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, c.Size.Z / 2)
	a1.Parent = p
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = ColorSequence.new(c.Color)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Lifetime = c.TrailLifetime
	trail.LightEmission = 1
	trail.WidthScale = NumberSequence.new(c.TrailWidth)
	trail.Parent = p

	local light = Instance.new("PointLight")
	light.Color = c.Color
	light.Brightness = c.LightBrightness
	light.Range = c.LightRange
	light.Parent = p

	p.Parent = folder
	return p
end

local function syncCount(player: Player)
	local rig = rigs[player]
	if not rig then
		return
	end
	local want = player:GetAttribute("BladeCount") or 0
	while #rig < want do
		table.insert(rig, makeBlade())
	end
	while #rig > want do
		table.remove(rig):Destroy()
	end
end

local function addPlayer(player: Player)
	rigs[player] = {}
	syncCount(player)
	player:GetAttributeChangedSignal("BladeCount"):Connect(function()
		syncCount(player)
	end)
end

local function removePlayer(player: Player)
	for _, part in rigs[player] or {} do
		part:Destroy()
	end
	rigs[player] = nil
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for player, rig in rigs do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		for i, part in rig do
			part.Transparency = root and 0 or 1
			if root then
				local offset, angle = BladeMath.offset(i, #rig, t, player)
				-- face tangent to the orbit, plus a spin about the blade's long axis
				part.CFrame = CFrame.new(root.Position + offset)
					* CFrame.Angles(0, -angle, 0)
					* CFrame.Angles(0, 0, t * c.SpinSpeed * Upgrades.spinMult(player))
			end
		end
	end
end)
