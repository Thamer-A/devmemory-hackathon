local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Z = Config.Zombies
local W = Config.Waves

local currentHealth = Z.Health -- max health for zombies spawned in the current wave

local folder = Instance.new("Folder")
folder.Name = "Zombies"
folder.Parent = workspace

-- zombie model -> { humanoid, root, lastHit = { [player] = { [bladeIndex] = time } } }
local zombies = {}
local aliveCount = 0
local pendingSpawns = 0 -- current wave's zombies not yet spawned

local function publishRemaining()
	workspace:SetAttribute(W.ZombiesLeftAttribute, aliveCount + pendingSpawns)
end

local function makePart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function makeZombie(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Zombie"

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), Z.Color)
	root.Transparency = 1
	local body = makePart("Body", Vector3.new(2, 3, 1), Z.Color)
	local head = makePart("Head", Vector3.new(1.4, 1.4, 1.4), Z.HeadColor)
	local legs = makePart("Legs", Vector3.new(2, 2, 1), Color3.fromRGB(60, 70, 110))

	-- Root sits at the hip; legs below, body and head stacked above.
	root.CFrame = CFrame.new(position)
	legs.CFrame = root.CFrame * CFrame.new(0, -2, 0)
	body.CFrame = root.CFrame * CFrame.new(0, 0.5, 0)
	head.CFrame = root.CFrame * CFrame.new(0, 2.7, 0)
	for _, part in { legs, body, head } do
		part.Parent = model
		weld(root, part)
	end
	root.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = currentHealth
	humanoid.Health = currentHealth
	humanoid.WalkSpeed = Z.WalkSpeed
	humanoid.HipHeight = 2
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = folder
	root:SetNetworkOwner(nil)
	return model
end

local function randomEdgePosition(): Vector3
	local edge = Z.ArenaHalfSize - Z.SpawnInset
	local along = (math.random() * 2 - 1) * edge
	local side = math.random(1, 4)
	local x, zPos
	if side == 1 then
		x, zPos = along, -edge
	elseif side == 2 then
		x, zPos = along, edge
	elseif side == 3 then
		x, zPos = -edge, along
	else
		x, zPos = edge, along
	end
	return Vector3.new(x, 4, zPos)
end

local function spawnZombie()
	local model = makeZombie(randomEdgePosition())
	zombies[model] = {
		humanoid = model.Humanoid,
		root = model.HumanoidRootPart,
		lastHit = {},
	}
	aliveCount += 1
	publishRemaining()
end

local function removeZombie(model: Model)
	if zombies[model] then
		zombies[model] = nil
		aliveCount -= 1
		publishRemaining()
	end
	model:Destroy()
end

local function addStat(player: Player, name: string, amount: number)
	local stats = player:FindFirstChild(Config.Stats.Folder)
	local value = stats and stats:FindFirstChild(name)
	if value then
		value.Value += amount
	end
end

local function getPlayerRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return character:FindFirstChild("HumanoidRootPart")
	end
	return nil
end

local function nearestPlayerRoot(position: Vector3): BasePart?
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = getPlayerRoot(player)
		if root then
			local dist = (root.Position - position).Magnitude
			if dist < bestDist then
				best, bestDist = root, dist
			end
		end
	end
	return best
end

local function killZombie(model: Model, killer: Player, position: Vector3)
	removeZombie(model)
	local coins = math.floor(Z.CoinsPerKill * Upgrades.coinMultiplier(killer) + 0.5)
	addStat(killer, Config.Stats.Kills, 1)
	addStat(killer, Config.Stats.Coins, coins)
	Remotes.ZombieDied:FireAllClients(position)
	Remotes.CoinReward:FireClient(killer, position, coins)

	local heal = Upgrades.healPerKill(killer)
	if heal > 0 then
		local humanoid = killer.Character and killer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health += heal -- Health clamps to MaxHealth
		end
	end
end

-- Blade hits: the server recomputes each player's blade positions from the shared
-- orbit math and damages any zombie within HitRadius of a blade.
local function processBladeHits(now: number)
	for _, player in Players:GetPlayers() do
		local root = getPlayerRoot(player)
		local count = player:GetAttribute(Config.Blades.CountAttribute) or 0
		if root and count > 0 then
			local spin = Upgrades.spinMultiplier(player)
			local reach = Upgrades.reachBonus(player)
			local damage = Z.BladeDamage * Upgrades.damageMultiplier(player)
			for i = 1, count do
				local offset = BladeOrbit.getOffset(i, count, now, spin, reach)
				local bladePos = root.Position + offset
				for model, zombie in zombies do
					if (zombie.root.Position - bladePos).Magnitude <= Z.HitRadius then
						local hits = zombie.lastHit[player]
						if not hits then
							hits = {}
							zombie.lastHit[player] = hits
						end
						if not hits[i] or now - hits[i] >= Z.HitCooldown then
							hits[i] = now
							zombie.humanoid.Health -= damage
							local zombiePos = zombie.root.Position
							Remotes.ZombieHit:FireAllClients(zombiePos, damage)
							if zombie.humanoid.Health <= 0 then
								killZombie(model, player, zombiePos)
								break
							end
						end
					end
				end
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	for _, zombie in zombies do
		zombie.lastHit[player] = nil
	end
end)

-- Contact damage: players touching a zombie take ContactDps per second.
local function processContactDamage(dt: number)
	for _, player in Players:GetPlayers() do
		local root = getPlayerRoot(player)
		if root then
			local touching = 0
			for _, zombie in zombies do
				if (zombie.root.Position - root.Position).Magnitude <= Z.ContactRadius then
					touching += 1
				end
			end
			if touching > 0 then
				local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
				humanoid:TakeDamage(touching * Z.ContactDps * dt)
			end
		end
	end
end

-- Game over: bumping runId makes the wave loop abandon the current run and start at wave 1.
local runId = 0

-- True when there are players and every one of them has a dead character.
-- A player with no character yet (still loading) does not count as dead.
local function allPlayersDead(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health > 0 then
			return false
		end
	end
	return true
end

local function gameOver()
	runId += 1
	for model in zombies do
		removeZombie(model)
	end
	pendingSpawns = 0
	publishRemaining()
	workspace:SetAttribute(W.BreakAttribute, 0)
end

-- Waves: spawn the wave's zombies (capped by MaxAlive at any moment), wait for them
-- all to die, then break before the next wave.
task.spawn(function()
	local wave = 0
	workspace:SetAttribute(W.BreakAttribute, 0)
	while true do
		while #Players:GetPlayers() == 0 or allPlayersDead() do -- also waits out respawns after a game over
			task.wait(1)
		end

		local myRun = runId
		wave += 1
		workspace:SetAttribute(W.WaveAttribute, wave)
		currentHealth = Z.Health * (1 + W.HealthGrowth) ^ (wave - 1)

		pendingSpawns = W.FirstWaveCount + W.CountPerWave * (wave - 1)
		publishRemaining()
		while pendingSpawns > 0 and runId == myRun do
			if aliveCount < Z.MaxAlive then
				pendingSpawns -= 1
				spawnZombie()
			end
			task.wait(Z.SpawnInterval)
		end

		while aliveCount > 0 and runId == myRun do
			task.wait(0.5)
		end

		if runId == myRun then
			workspace:SetAttribute(W.BreakAttribute, workspace:GetServerTimeNow() + W.BreakSeconds)
			local breakEnd = os.clock() + W.BreakSeconds
			while os.clock() < breakEnd and runId == myRun do
				task.wait(0.5)
			end
			if runId == myRun then
				workspace:SetAttribute(W.BreakAttribute, 0)
			end
		end

		if runId ~= myRun then
			wave = 0 -- run was reset; next iteration begins wave 1
		end
	end
end)

-- Chasing
task.spawn(function()
	while true do
		task.wait(Z.RetargetInterval)
		for _, zombie in zombies do
			local target = nearestPlayerRoot(zombie.root.Position)
			if target then
				zombie.humanoid:MoveTo(target.Position)
			end
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	processBladeHits(workspace:GetServerTimeNow())
	processContactDamage(dt)
	if allPlayersDead() then
		gameOver()
	end
end)
