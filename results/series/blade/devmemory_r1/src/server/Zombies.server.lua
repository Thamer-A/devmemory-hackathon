local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BladeConfig = Config.Blades
local ZombieConfig = Config.Zombies
local Remotes = require(Shared.Remotes)
local Upgrades = require(script.Parent.Upgrades)

-- zombies[model] = { humanoid, root, lastHit = { [bladeKey] = time }, killer = Player? }
local zombies = {}
local aliveCount = 0
local pendingSpawns = 0

-- Replicated to the HUD: zombies still alive plus those yet to spawn this wave.
local function publishRemaining()
	workspace:SetAttribute("ZombiesLeft", aliveCount + pendingSpawns)
end

local function makeZombie(position, health)
	local model = Instance.new("Model")
	model.Name = "Zombie"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 4, 1)
	root.Color = ZombieConfig.Color
	root.Position = position
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Color = ZombieConfig.Color
	head.CFrame = root.CFrame * CFrame.new(0, 2.8, 0)
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = ZombieConfig.WalkSpeed
	humanoid.HipHeight = 0.5
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = workspace
	root:SetNetworkOwner(nil)

	return model, humanoid, root
end

local function randomEdgePosition()
	local h = ZombieConfig.ArenaHalfSize
	local along = (math.random() * 2 - 1) * h
	local side = math.random(4)
	if side == 1 then
		return Vector3.new(along, 3, -h)
	elseif side == 2 then
		return Vector3.new(along, 3, h)
	elseif side == 3 then
		return Vector3.new(h, 3, along)
	end
	return Vector3.new(-h, 3, along)
end

local function award(player)
	local stats = player and player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local coins = math.round(ZombieConfig.CoinsPerKill * Upgrades.coinMultiplier(player))
	stats.Coins.Value += coins
	stats.Kills.Value += 1

	local heal = Upgrades.healPerKill(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if heal > 0 and hum and hum.Health > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
	end
	return coins
end

local function spawnZombie(health)
	local model, humanoid, root = makeZombie(randomEdgePosition(), health)
	local data = { humanoid = humanoid, root = root, lastHit = {}, killer = nil }
	zombies[model] = data
	aliveCount += 1
	publishRemaining()

	humanoid.Died:Connect(function()
		zombies[model] = nil
		aliveCount -= 1
		publishRemaining()
		Remotes.ZombieKilled:FireAllClients(root.Position)
		local coins = award(data.killer)
		if coins then
			Remotes.CoinsEarned:FireClient(data.killer, root.Position, coins)
		end
		Debris:AddItem(model, ZombieConfig.CorpseLifetime)
	end)
end

local function nearestRoot(position)
	local best, bestDist
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and hum and hum.Health > 0 then
			local dist = (root.Position - position).Magnitude
			if not bestDist or dist < bestDist then
				best, bestDist = root, dist
			end
		end
	end
	return best
end

-- Mirrors the client orbit math in Blades.client.lua so server hits match what players see.
local function bladePositions(player, root, t)
	local count = player:GetAttribute("BladeCount") or 0
	local radius = BladeConfig.OrbitRadius + (player:GetAttribute("ReachBonus") or 0)
	local positions = {}
	for i = 1, count do
		local angle = t * BladeConfig.OrbitSpeed + (i - 1) * (2 * math.pi / count)
		local bob = math.sin(t * BladeConfig.BobSpeed + i) * BladeConfig.BobAmplitude
		positions[i] = root.Position
			+ Vector3.new(math.cos(angle) * radius, BladeConfig.HeightOffset + bob, math.sin(angle) * radius)
	end
	return positions
end

local function checkHits(now)
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			for i, pos in bladePositions(player, root, workspace:GetServerTimeNow()) do
				local key = player.UserId .. ":" .. i
				for _, data in zombies do
					local humanoid = data.humanoid
					if
						humanoid.Health > 0
						and (data.root.Position - pos).Magnitude <= ZombieConfig.HitRadius
						and now - (data.lastHit[key] or -math.huge) >= ZombieConfig.HitCooldown
					then
						data.lastHit[key] = now
						data.killer = player
						local damage = ZombieConfig.BladeDamage * Upgrades.damageMultiplier(player)
						humanoid:TakeDamage(damage)
						Remotes.ZombieHit:FireAllClients(data.root.Position, damage)
					end
				end
			end
		end
	end
end

local function applyContactDamage(dt)
	for _, data in zombies do
		if data.humanoid.Health > 0 then
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if
					root
					and hum
					and hum.Health > 0
					and (root.Position - data.root.Position).Magnitude <= ZombieConfig.ContactRadius
				then
					hum:TakeDamage(ZombieConfig.ContactDamagePerSecond * dt)
				end
			end
		end
	end
end

local chaseTimer = 0
RunService.Heartbeat:Connect(function(dt)
	checkHits(os.clock())
	applyContactDamage(dt)

	chaseTimer += dt
	if chaseTimer >= 0.2 then
		chaseTimer = 0
		for _, data in zombies do
			local target = nearestRoot(data.root.Position)
			if target then
				data.humanoid:MoveTo(target.Position)
			end
		end
	end
end)

local WaveConfig = Config.Waves

-- Bumped on game over so an in-flight wave or break knows it was cancelled.
local runId = 0

local function anyPlayerAlive()
	for _, player in Players:GetPlayers() do
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			return true
		end
	end
	return false
end

-- Every player has a character and all of them are dead (players still loading in don't count).
local function everyoneDead()
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health > 0 then
			return false
		end
	end
	return true
end

local function gameOver()
	runId += 1
	for model in zombies do
		model:Destroy()
	end
	table.clear(zombies)
	aliveCount = 0
	pendingSpawns = 0
	publishRemaining()
	workspace:SetAttribute("ShopOpen", false)
end

local function runWave(wave)
	local id = runId
	local toSpawn = WaveConfig.FirstWaveCount + WaveConfig.CountPerWave * (wave - 1)
	local health = ZombieConfig.Health * (1 + WaveConfig.HealthGrowth) ^ (wave - 1)
	workspace:SetAttribute("Wave", wave)
	pendingSpawns = toSpawn
	publishRemaining()

	while toSpawn > 0 do
		if id ~= runId then
			return
		end
		if aliveCount < ZombieConfig.MaxAlive and #Players:GetPlayers() > 0 then
			toSpawn -= 1
			pendingSpawns = toSpawn
			spawnZombie(health)
		end
		task.wait(ZombieConfig.SpawnInterval)
	end

	while aliveCount > 0 and id == runId do
		task.wait(0.5)
	end
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if everyoneDead() then
			gameOver()
		end
	end
end)

task.spawn(function()
	local wave = 1
	local id = runId
	while true do
		while #Players:GetPlayers() == 0 or not anyPlayerAlive() do
			task.wait(1)
		end
		if id ~= runId then
			id, wave = runId, 1
		end
		runWave(wave)
		if id ~= runId then
			id, wave = runId, 1
			continue
		end
		wave += 1
		workspace:SetAttribute("BreakEndsAt", workspace:GetServerTimeNow() + WaveConfig.BreakDuration)
		workspace:SetAttribute("ShopOpen", true)
		local breakEnd = os.clock() + WaveConfig.BreakDuration
		while os.clock() < breakEnd and id == runId do
			task.wait(0.25)
		end
		workspace:SetAttribute("ShopOpen", false)
	end
end)
