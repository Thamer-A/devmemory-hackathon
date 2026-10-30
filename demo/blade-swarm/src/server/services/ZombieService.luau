--!nonstrict
-- Spawns, steers and rewards zombies.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local Maid = require(Shared.Maid)
local MathUtil = require(Shared.MathUtil)
local Remotes = require(Shared.Remotes)

local PlayerStatsService = require(script.Parent.PlayerStatsService)

export type ZombieRecord = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	dead: boolean,
	maid: any,
}

local ZombieService = {}

local rng = Random.new()
local zombies: { [Model]: ZombieRecord } = {}
local aliveTotal = 0
local zombieFolder: Folder? = nil
local cachedTemplate: Model? = nil

local generation = 0
local currentWave = 1
local waveTotal = 0
local waveSpawned = 0

-- Template --------------------------------------------------------------

local function buildBlockZombie(): Model
	local model = Instance.new("Model")
	model.Name = "Zombie"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 3, 1)
	body.Color = Config.ZombieSkinColor
	body.Parent = model
	body.CFrame = root.CFrame * CFrame.new(0, -0.5, 0)

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = Config.ZombieSkinColor
	head.Parent = model
	head.CFrame = root.CFrame * CFrame.new(0, 1.9, 0)

	for _, part in { body, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = root
		part.CanCollide = false
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 1.5
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

local function buildDescriptionZombie(): Model?
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = Config.ZombieSkinColor
		description.HeadColor = skin
		description.TorsoColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.LeftLegColor = Color3.fromHex("3b4a6b")
		description.RightLegColor = Color3.fromHex("3b4a6b")
		description.Shirt = 0
		description.Pants = 0
		description.GraphicTShirt = 0
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		result.Name = "Zombie"
		return result
	end
	Log.warn("ZombieService", "CreateHumanoidModelFromDescription failed:", result)
	return nil
end

local function getTemplate(): Model
	if cachedTemplate then
		return cachedTemplate
	end

	local found = ServerStorage:FindFirstChild(Config.ZombieTemplateName)
	if found and found:IsA("Model") then
		cachedTemplate = found
		Log.info("ZombieService", "using ServerStorage." .. Config.ZombieTemplateName)
		return found
	end

	Log.info("ZombieService", "no ZombieTemplate in ServerStorage, building fallback")
	cachedTemplate = buildDescriptionZombie() or buildBlockZombie()
	return cachedTemplate
end

-- Spawn positions -------------------------------------------------------

local function getFolder(): Folder
	if zombieFolder == nil or zombieFolder.Parent == nil then
		local existing = workspace:FindFirstChild(Config.ZombieFolderName)
		if existing and existing:IsA("Folder") then
			zombieFolder = existing
		else
			local folder = Instance.new("Folder")
			folder.Name = Config.ZombieFolderName
			folder.Parent = workspace
			zombieFolder = folder
		end
	end
	return zombieFolder
end

local function groundHeight(x: number, z: number, startY: number): number?
	local ignore = { getFolder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -(startY + 500), 0), params)
	if result then
		return result.Position.Y
	end
	return nil
end

local function pickSpawnPoint(): Vector3
	local spawns = workspace:FindFirstChild(Config.ZombieSpawnsName)
	if spawns then
		local parts = {}
		for _, child in spawns:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		if #parts > 0 then
			local part = parts[rng:NextInteger(1, #parts)]
			local local_ = Vector3.new(
				(rng:NextNumber() - 0.5) * part.Size.X * 0.8,
				0,
				(rng:NextNumber() - 0.5) * part.Size.Z * 0.8
			)
			local world = part.CFrame:PointToWorldSpace(local_)
			local y = groundHeight(world.X, world.Z, part.Position.Y + part.Size.Y / 2 + 25)
			return Vector3.new(world.X, y or (part.Position.Y + part.Size.Y / 2), world.Z)
		end
	end

	local angle = rng:NextNumber() * math.pi * 2
	local center = Config.ArenaCenter
	local x = center.X + math.cos(angle) * Config.SpawnRingRadius
	local z = center.Z + math.sin(angle) * Config.SpawnRingRadius
	local y = groundHeight(x, z, center.Y + Config.GroundProbeHeight)
	return Vector3.new(x, y or center.Y, z)
end

-- Animation -------------------------------------------------------------

local function needsWalkAnimation(model: Model): boolean
	local animate = model:FindFirstChild("Animate")
	if animate == nil then
		return true
	end
	-- a LocalScript Animate never runs on the server, so we drive the animation ourselves
	return not (animate:IsA("Script") and not animate.Disabled)
end

local function setupWalkAnimation(record: ZombieRecord)
	if not needsWalkAnimation(record.model) then
		return
	end
	local ok, err = pcall(function()
		local humanoid = record.humanoid
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator == nil then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = Config.ZombieWalkAnimationId
		local track = animator:LoadAnimation(animation)
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Movement
		record.maid:Give(humanoid.Running:Connect(function(speed: number)
			if speed > 0.5 then
				if not track.IsPlaying then
					track:Play(0.2)
				end
				track:AdjustSpeed(math.clamp(speed / 12, 0.5, 1.6))
			elseif track.IsPlaying then
				track:Stop(0.2)
			end
		end))
	end)
	if not ok then
		Log.warn("ZombieService", "walk animation setup failed:", err)
	end
end

-- Death -----------------------------------------------------------------

local function fadeOut(model: Model)
	local info = TweenInfo.new(
		Config.ZombieFadeTime,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In,
		0,
		false,
		Config.ZombieFadeDelay
	)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant, info, { Transparency = 1 }):Play()
		elseif descendant:IsA("Decal") then
			TweenService:Create(descendant, info, { Transparency = 1 }):Play()
		end
	end
	Debris:AddItem(model, Config.ZombieFadeDelay + Config.ZombieFadeTime + 0.5)
end

local function onZombieDied(record: ZombieRecord)
	if record.dead then
		return
	end
	record.dead = true
	zombies[record.model] = nil
	aliveTotal = math.max(0, aliveTotal - 1)

	local position = record.root.Position
	local attackerId = record.model:GetAttribute("LastAttackerUserId")
	local killer = if type(attackerId) == "number" then Players:GetPlayerByUserId(attackerId) else nil

	local coins = 0
	if killer and killer.Parent == Players then
		local stats = PlayerStatsService.get(killer)
		local base = Config.CoinsPerKill + Config.CoinsPerWavePerKill * (currentWave - 1)
		coins = math.max(1, math.floor(base * (1 + stats.CoinBonus) + 0.5))
		PlayerStatsService.addCoins(killer, coins, "zombie_kill")
		PlayerStatsService.addKill(killer)
		if stats.Lifesteal > 0 then
			PlayerStatsService.heal(killer, stats.Lifesteal)
		end
	end

	Remotes.get("ZombieKilled"):FireAllClients(position, coins, killer and killer.UserId or 0)

	record.maid:Clean()
	fadeOut(record.model)
end

-- Spawning --------------------------------------------------------------

local function spawnZombie(wave: number)
	local template = getTemplate()
	local model = template:Clone()
	model.Name = "Zombie"

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		Log.warn("ZombieService", "template is missing Humanoid or HumanoidRootPart")
		model:Destroy()
		waveSpawned += 1 -- count it so the wave can still finish
		return
	end
	if model.PrimaryPart == nil then
		model.PrimaryPart = root
	end

	local health = Config.ZombieBaseHealth + Config.ZombieHealthPerWave * (wave - 1)
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = math.min(Config.ZombieBaseSpeed + Config.ZombieSpeedPerWave * (wave - 1), Config.ZombieMaxSpeed)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.AutoJumpEnabled = false
	humanoid.JumpPower = 0

	local point = pickSpawnPoint()
	local lift = humanoid.HipHeight + root.Size.Y / 2 + Config.ZombieSpawnLift
	model:PivotTo(CFrame.new(point + Vector3.new(0, lift, 0)))
	model.Parent = getFolder()

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local record: ZombieRecord = {
		model = model,
		humanoid = humanoid,
		root = root,
		dead = false,
		maid = Maid.new(),
	}
	zombies[model] = record
	aliveTotal += 1
	waveSpawned += 1

	record.maid:Give(humanoid.Died:Connect(function()
		onZombieDied(record)
	end))
	setupWalkAnimation(record)
end

function ZombieService.beginWave(wave: number, duration: number)
	generation += 1
	local myGeneration = generation
	currentWave = wave
	waveTotal = Config.ZombieBaseCount + Config.ZombiePerWave * wave
	waveSpawned = 0

	local interval = (duration * Config.SpawnWindowFraction) / waveTotal
	task.spawn(function()
		while waveSpawned < waveTotal do
			if generation ~= myGeneration then
				return
			end
			if aliveTotal < Config.MaxZombiesAlive then
				spawnZombie(wave)
				task.wait(interval)
			else
				task.wait(0.25)
			end
		end
	end)
end

function ZombieService.clearAll()
	generation += 1
	for model, record in zombies do
		record.dead = true
		record.maid:Clean()
		model:Destroy()
	end
	zombies = {}
	aliveTotal = 0
	waveTotal = 0
	waveSpawned = 0
end

function ZombieService.aliveCount(): number
	return aliveTotal
end

function ZombieService.allSpawned(): boolean
	return waveSpawned >= waveTotal
end

-- Alive plus not yet spawned, for the HUD counter.
function ZombieService.remaining(): number
	return math.max(0, waveTotal - waveSpawned) + aliveTotal
end

function ZombieService.getZombies(): { [Model]: ZombieRecord }
	return zombies
end

-- Steering and contact damage --------------------------------------------

local function gatherTargets()
	local targets = {}
	for _, player in Players:GetPlayers() do
		if PlayerStatsService.isAlive(player) then
			local root = PlayerStatsService.getRoot(player)
			local humanoid = PlayerStatsService.getHumanoid(player)
			local stats = PlayerStatsService.get(player)
			table.insert(targets, {
				position = root.Position,
				humanoid = humanoid,
				hold = math.max(Config.ZombieStopDistance, stats.BladeRadius - Config.ZombieStopInset),
			})
		end
	end
	return targets
end

local function step(dt: number, retarget: boolean)
	local targets = gatherTargets()
	local dps = Config.ZombieBaseDps + Config.ZombieDpsPerWave * (currentWave - 1)

	for _, record in zombies do
		local humanoid = record.humanoid
		local root = record.root
		if record.dead or root.Parent == nil then
			continue
		end
		if root.Position.Y < Config.VoidY then
			humanoid.Health = 0
			continue
		end
		if humanoid.Health <= 0 or #targets == 0 then
			continue
		end

		local position = root.Position
		local nearest = nil
		local nearestDistance = math.huge
		for _, target in targets do
			local distance = MathUtil.flatDistance(position, target.position)
			if distance < nearestDistance then
				nearest = target
				nearestDistance = distance
			end
		end

		if retarget then
			local away = Vector3.new(position.X - nearest.position.X, 0, position.Z - nearest.position.Z)
			local direction = if away.Magnitude > 0.01 then away.Unit else Vector3.xAxis
			local goal = nearest.position + direction * nearest.hold
			humanoid:MoveTo(Vector3.new(goal.X, position.Y, goal.Z))
		end

		if nearestDistance <= nearest.hold + Config.ZombieContactRange then
			nearest.humanoid:TakeDamage(dps * dt)
		end
	end
end

function ZombieService.init()
	getFolder()
	Log.info("ZombieService", "init")
end

function ZombieService.start()
	task.spawn(function()
		-- Build the template up front so the first wave does not hitch.
		getTemplate()

		local sinceRetarget = 0
		while true do
			local dt = task.wait(Config.DamageTickRate)
			sinceRetarget += dt
			local retarget = sinceRetarget >= Config.ZombieRetargetInterval
			if retarget then
				sinceRetarget = 0
			end
			step(dt, retarget)
		end
	end)
end

return ZombieService
