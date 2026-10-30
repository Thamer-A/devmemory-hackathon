--!nonstrict
-- Renders the spinning blades (and reach ring) for every player's character.
-- Positions come from BladeMath fed with server time, the same inputs the server uses for hits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local BladeMath = require(Shared.BladeMath)
local Config = require(Shared.Config)
local Maid = require(Shared.Maid)

local Theme = require(script.Parent.Theme)

local BladeController = {}

local localPlayer = Players.LocalPlayer

local BLADE_SIZE = Vector3.new(0.25, 0.9, 3.4)
local RING_THICKNESS = 0.15
local RING_TRANSPARENCY = 0.88
local TRAIL_LIFETIME = 0.25

type Entry = {
	maid: any,
	folder: Folder,
	blades: { Part },
	ring: Part?,
	key: string,
}

local entries: { [Player]: Entry } = {}
local visualsFolder: Folder

local function readAttribute(player: Player, name: string): number
	local value = player:GetAttribute(name)
	if type(value) == "number" then
		return value
	end
	return Config.BasePlayer[name]
end

local function bladeColor(player: Player): Color3
	if player == localPlayer then
		return Theme.Colors.Accent
	end
	return Theme.Colors.AccentOther
end

local function createBlade(parent: Instance, scale: number, color: Color3): Part
	local size = BLADE_SIZE * scale
	local blade = Theme.new("Part", {
		Name = "Blade",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color,
		Size = size,
	})

	local top = Theme.new("Attachment", { Name = "TrailTop", Position = Vector3.new(0, size.Y * 0.5, 0) }, blade)
	local bottom = Theme.new("Attachment", { Name = "TrailBottom", Position = Vector3.new(0, -size.Y * 0.5, 0) }, blade)
	Theme.new("Trail", {
		Attachment0 = top,
		Attachment1 = bottom,
		Lifetime = TRAIL_LIFETIME,
		MinLength = 0.05,
		FaceCamera = true,
		LightEmission = 1,
		Color = ColorSequence.new(color),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, blade)

	blade.Parent = parent
	return blade
end

local function createRing(parent: Instance, radius: number, color: Color3): Part
	return Theme.new("Part", {
		Name = "ReachRing",
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = RING_TRANSPARENCY,
		Size = Vector3.new(RING_THICKNESS, radius * 2, radius * 2),
	}, parent)
end

local function clearVisuals(entry: Entry)
	entry.folder:ClearAllChildren()
	entry.blades = {}
	entry.ring = nil
	entry.key = ""
end

local function rebuild(player: Player, entry: Entry, count: number, scale: number, radius: number)
	clearVisuals(entry)
	local color = bladeColor(player)
	for index = 1, count do
		entry.blades[index] = createBlade(entry.folder, scale, color)
	end
	entry.ring = createRing(entry.folder, radius, color)
	entry.key = string.format("%d|%.2f|%.2f", count, scale, radius)
end

local function update(player: Player, entry: Entry, serverTime: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or humanoid.Health <= 0 then
		if entry.key ~= "" then
			clearVisuals(entry)
		end
		return
	end

	local count = math.floor(readAttribute(player, "BladeCount"))
	local radius = readAttribute(player, "BladeRadius")
	local spin = readAttribute(player, "BladeSpinSpeed")
	local scale = readAttribute(player, "BladeScale")

	local key = string.format("%d|%.2f|%.2f", count, scale, radius)
	if key ~= entry.key then
		rebuild(player, entry, count, scale, radius)
	end

	local rootPosition = root.Position
	local origin = rootPosition + Vector3.new(0, Config.BladeHeightOffset, 0)
	local positions = BladeMath.positions(origin, count, radius, spin, serverTime)
	for index, position in positions do
		local blade = entry.blades[index]
		if blade then
			local tangent = Vector3.new(-(position.Z - origin.Z), 0, position.X - origin.X)
			blade.CFrame = CFrame.lookAt(position, position + tangent)
		end
	end

	local ring = entry.ring
	if ring then
		local feet = rootPosition.Y - (humanoid.HipHeight + root.Size.Y / 2) + RING_THICKNESS
		ring.CFrame = CFrame.new(rootPosition.X, feet, rootPosition.Z) * CFrame.Angles(0, 0, math.pi / 2)
	end
end

local function track(player: Player)
	if entries[player] then
		return
	end
	local maid = Maid.new()
	local folder = Instance.new("Folder")
	folder.Name = "Blades_" .. player.Name
	folder.Parent = visualsFolder
	maid:Give(folder)

	local entry: Entry = { maid = maid, folder = folder, blades = {}, ring = nil, key = "" }
	entries[player] = entry

	maid:Give(player.CharacterRemoving:Connect(function()
		clearVisuals(entry)
	end))
end

local function untrack(player: Player)
	local entry = entries[player]
	if entry then
		entry.maid:Clean()
		entries[player] = nil
	end
end

function BladeController.init()
	visualsFolder = Instance.new("Folder")
	visualsFolder.Name = "BladeVisuals"
	visualsFolder.Parent = workspace
end

function BladeController.start()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	for _, player in Players:GetPlayers() do
		track(player)
	end

	RunService.RenderStepped:Connect(function()
		local serverTime = workspace:GetServerTimeNow()
		for player, entry in entries do
			update(player, entry, serverTime)
		end
	end)
end

return BladeController
