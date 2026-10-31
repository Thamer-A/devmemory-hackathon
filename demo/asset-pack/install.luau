-- Installs the shared asset pack (identical in every build). Run in Edit mode via MCP.
local InsertService = game:GetService("InsertService")
local RS = game:GetService("ReplicatedStorage")
local ASSETS = { Zombie = 72965484066778, Blade = 92341189807026, Tree = 91521038253145, Gravestone = 100937220365904 }
for _, n in ipairs({"SkinAssets", "AssetSkin"}) do local o = RS:FindFirstChild(n); if o then o:Destroy() end end
local folder = Instance.new("Folder"); folder.Name = "SkinAssets"
for name, id in pairs(ASSETS) do
  local model = InsertService:LoadAsset(id)
  local mp = model:FindFirstChildWhichIsA("MeshPart", true)
  assert(mp, "no MeshPart in asset " .. name)
  mp.Name = name
  mp.Anchored = true
  mp.Parent = folder
  model:Destroy()
end
folder.Parent = RS
local mod = Instance.new("ModuleScript"); mod.Name = "AssetSkin"
mod.Source = [====[--!strict
-- Shared visual asset pack, applied identically to all three race builds (demo video only).
-- It never changes game logic: it welds AI-generated meshes (Roblox Studio generate_mesh) onto the
-- zombies and blades each build already creates, hides the original primitive parts, and places the
-- same ring of props at the arena edge. Hit detection, movement and damage are untouched.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = ReplicatedStorage:WaitForChild("SkinAssets")
local M = {}

local function ghost(p: BasePart)
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Anchored = false
end

local function weldTo(part: BasePart, target: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = target
	w.Part1 = part
	w.Parent = part
end

local function skinZombie(model: Model)
	if model:GetAttribute("Skinned") then return end
	local root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not root then return end
	model:SetAttribute("Skinned", true)
	local cf, size = model:GetBoundingBox()
	local mesh = (Assets.Zombie :: MeshPart):Clone()
	local h = math.max(size.Y, 4.5)
	mesh.Size = mesh.Size * (h / mesh.Size.Y)
	local bottom = cf.Position.Y - size.Y / 2
	mesh.CFrame = CFrame.new(root.Position.X, bottom + mesh.Size.Y / 2, root.Position.Z) * root.CFrame.Rotation
	ghost(mesh)
	mesh.Name = "SkinMesh"
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
	weldTo(mesh, root)
	mesh.Parent = model
end

local function skinBlade(blade: BasePart)
	if blade:GetAttribute("Skinned") or blade:IsA("MeshPart") then return end
	blade:SetAttribute("Skinned", true)
	local s = blade.Size
	local long = math.max(s.X, s.Y, s.Z)
	local mesh = (Assets.Blade :: MeshPart):Clone()
	-- the generated blade's long axis is Y; point it along the blade part's longest axis
	local rot = CFrame.new()
	if long == s.X then rot = CFrame.Angles(0, 0, math.rad(90)) elseif long == s.Z then rot = CFrame.Angles(math.rad(90), 0, 0) end
	mesh.Size = mesh.Size * (long * 1.15 / mesh.Size.Y)
	mesh.Material = Enum.Material.Neon
	mesh.Color = Color3.fromRGB(56, 214, 232)
	mesh.TextureID = ""
	mesh.CFrame = blade.CFrame * rot
	ghost(mesh)
	mesh.Name = "SkinMesh"
	local light = Instance.new("PointLight")
	light.Color = mesh.Color
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = mesh
	blade.Transparency = 1
	weldTo(mesh, blade)
	mesh.Parent = blade
end

local function consider(inst: Instance)
	if inst:IsA("Model") and inst.Name == "Zombie" then
		task.delay(0.2, function()
			if inst.Parent and inst:FindFirstChildOfClass("Humanoid") then skinZombie(inst) end
		end)
	elseif inst:IsA("BasePart") and inst.Name:match("^Blade%d*$") then
		task.delay(0.05, function()
			if inst.Parent then skinBlade(inst) end
		end)
	end
end

function M.placeProps()
	local folder = Instance.new("Folder")
	folder.Name = "SkinProps"
	local function put(template: MeshPart, angle: number, radius: number, height: number, turn: number)
		local p = template:Clone()
		p.Size = p.Size * (height / p.Size.Y)
		local pos = Vector3.new(math.cos(angle) * radius, p.Size.Y / 2, math.sin(angle) * radius)
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, turn, 0)
		p.Anchored = true
		p.CanCollide = false
		p.Parent = folder
	end
	for i = 0, 9 do -- dead trees in the corners and along the walls
		put(Assets.Tree :: MeshPart, i / 10 * math.pi * 2 + 0.3, 82, 15, i * 1.7)
	end
	if Assets:FindFirstChild("Gravestone") then
		for i = 0, 23 do
			put(Assets.Gravestone :: MeshPart, i / 24 * math.pi * 2, 72 + (i % 3) * 3, 4, i * 0.9)
		end
	end
	folder.Parent = workspace
end

function M.start()
	for _, d in ipairs(workspace:GetDescendants()) do consider(d) end
	workspace.DescendantAdded:Connect(consider)
	if RunService:IsServer() then M.placeProps() end
end

return M
]====]
mod.Parent = RS
local SSS = game:GetService("ServerScriptService")
local old = SSS:FindFirstChild("AssetSkinServer"); if old then old:Destroy() end
local s = Instance.new("Script"); s.Name = "AssetSkinServer"
s.Source = 'require(game:GetService("ReplicatedStorage"):WaitForChild("AssetSkin")).start()'
s.Parent = SSS
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local oldc = SPS:FindFirstChild("AssetSkinClient"); if oldc then oldc:Destroy() end
local c = Instance.new("LocalScript"); c.Name = "AssetSkinClient"
c.Source = 'require(game:GetService("ReplicatedStorage"):WaitForChild("AssetSkin")).start()'
c.Parent = SPS
for _, ch in ipairs(workspace:GetChildren()) do if ch.Name:match("^Gen_") then ch:Destroy() end end
local names = {}
for _, m in ipairs(folder:GetChildren()) do table.insert(names, m.Name .. " " .. tostring(m.Size)) end
return "installed: " .. table.concat(names, "; ")
