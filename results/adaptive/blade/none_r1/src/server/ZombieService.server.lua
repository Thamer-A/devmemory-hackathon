local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BladeMath = require(Shared:WaitForChild("BladeMath"))
local PlayerStats = require(Shared:WaitForChild("PlayerStats"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local B = Config.Blades
local Z = Config.Zombies
local W = Config.Waves

local ROOT_SIZE = Vector3.new(2, 2, 1)
local HIP_HEIGHT = 2

local zombieFolder = Instance.new("Folder")
zombieFolder.Name = "Zombies"
zombieFolder.Parent = workspace

-- zombies[model] = { humanoid, root, target = Player?, nextRetarget, lastHit = { [key] = time } }
local zombies = {}
local aliveCount = 0

-- Leaderboard ---------------------------------------------------------------

local function initLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats

	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = stats

	stats.Parent = player
end

Players.PlayerAdded:Connect(initLeaderstats)
for _, player in Players:GetPlayers() do
	initLeaderstats(player)
end

local function awardKill(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	stats.Kills.Value += 1
	stats.Coins.Value += math.round(Z.CoinsPerKill * PlayerStats.getCoinMultiplier(player))

	local heal = PlayerStats.getKillHeal(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if heal > 0 and humanoid and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
	end
end

-- Zombies -------------------------------------------------------------------

local function makePart(name, size, color, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.Massless = true
	if shape then
		part.Shape = shape
	end
	return part
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function buildZombie(position, health)
	local model = Instance.new("Model")
	model.Name = "Zombie"

	local root = makePart("HumanoidRootPart", ROOT_SIZE, Z.Color)
	root.CanCollide = true
	root.Massless = false
	root.Position = position
	root.Parent = model

	local torso = makePart("Torso", Vector3.new(2, 2, 1), Z.Color)
	torso.CFrame = root.CFrame * CFrame.new(0, 2, 0)
	torso.Parent = model
	weld(root, torso)

	local head = makePart("Head", Vector3.new(1.6, 1.6, 1.6), Z.Color)
	head.CFrame = root.CFrame * CFrame.new(0, 3.8, 0)
	head.Parent = model
	weld(root, head)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = Z.WalkSpeed
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.RequiresNeck = false -- parts are welded, not Motor6D-jointed; otherwise the zombie dies on spawn
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	return model, humanoid, root
end

local function randomEdgePosition()
	local e = Z.ArenaHalfSize - Z.SpawnInset
	local along = (math.random() * 2 - 1) * e
	local side = math.random(1, 4)
	local x, zc
	if side == 1 then
		x, zc = along, -e
	elseif side == 2 then
		x, zc = along, e
	elseif side == 3 then
		x, zc = -e, along
	else
		x, zc = e, along
	end
	return Vector3.new(x, HIP_HEIGHT + ROOT_SIZE.Y / 2, zc)
end

local function spawnZombie(health)
	local model, humanoid, root = buildZombie(randomEdgePosition(), health)
	model.Parent = zombieFolder
	root:SetNetworkOwner(nil) -- server simulates movement

	zombies[model] = {
		humanoid = humanoid,
		root = root,
		target = nil,
		nextRetarget = 0,
		lastHit = {},
	}
	aliveCount += 1

	-- A zombie that dies any way other than a blade kill must still leave the count,
	-- or the wave can never finish.
	-- Deferred so a blade kill (which awards coins in killZombie) wins the race.
	humanoid.Died:Once(function()
		task.defer(function()
			if zombies[model] then
				model:Destroy()
			end
		end)
	end)

	model.Destroying:Once(function()
		if zombies[model] then
			zombies[model] = nil
			aliveCount -= 1
		end
	end)
end

local function getPlayerRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function findNearestPlayerRoot(position)
	local bestRoot, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = getPlayerRoot(player)
		if root then
			local dist = (root.Position - position).Magnitude
			if dist < bestDist then
				bestRoot, bestDist = root, dist
			end
		end
	end
	return bestRoot
end

local function killZombie(model, killer)
	if not zombies[model] then
		return
	end
	awardKill(killer)
	zombies[model] = nil
	aliveCount -= 1
	model:Destroy()
end

local function updateChasing(now)
	for _, zombie in zombies do
		if now >= zombie.nextRetarget then
			zombie.nextRetarget = now + Z.RetargetInterval
			local targetRoot = findNearestPlayerRoot(zombie.root.Position)
			if targetRoot then
				zombie.humanoid:MoveTo(targetRoot.Position)
			else
				zombie.humanoid:MoveTo(zombie.root.Position) -- stand still
			end
		end
	end
end

local function updateBladeHits(now)
	for _, player in Players:GetPlayers() do
		local root = getPlayerRoot(player)
		local n = player:GetAttribute(Config.Attributes.BladeCount) or 0
		if root and n > 0 then
			local rootPos = root.Position
			local damage = PlayerStats.getDamage(player)
			local speed = PlayerStats.getOrbitSpeed(player)
			local radius = PlayerStats.getOrbitRadius(player)
			local hitRadius = PlayerStats.getHitRadius(player)
			for i = 1, n do
				local offset = BladeMath.getOffset(i, n, now, speed, radius)
				local bladePos = rootPos + offset
				for model, zombie in zombies do
					local key = player.UserId * 100 + i
					local last = zombie.lastHit[key]
					if
						(not last or now - last >= B.HitCooldown)
						and (zombie.root.Position - bladePos).Magnitude <= hitRadius
					then
						zombie.lastHit[key] = now
						zombie.humanoid:TakeDamage(damage)
						if zombie.humanoid.Health <= 0 then
							killZombie(model, player)
						end
					end
				end
			end
		end
	end
end

local function updateContactDamage(dt)
	for _, player in Players:GetPlayers() do
		local root = getPlayerRoot(player)
		if root then
			local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
			for _, zombie in zombies do
				if (zombie.root.Position - root.Position).Magnitude <= Z.ContactRadius then
					humanoid:TakeDamage(Z.ContactDPS * dt)
					if humanoid.Health <= 0 then
						break
					end
				end
			end
		end
	end
end

-- Waves ---------------------------------------------------------------------

local wave = 0
local waveActive = false
local toSpawn = 0 -- zombies in the current wave not yet spawned
local nextWaveAt = os.clock() -- first wave starts as soon as a player is present

local function waveHealth(n)
	return Z.Health * W.HealthGrowth ^ (n - 1)
end

local function startWave(n)
	print(`[Waves] starting wave {n}`)
	wave = n
	waveActive = true
	toSpawn = W.FirstWaveCount + W.CountPerWave * (n - 1)
	workspace:SetAttribute(Config.Attributes.Intermission, false)
	workspace:SetAttribute(Config.Attributes.WaveStartedAt, workspace:GetServerTimeNow())
	workspace:SetAttribute(Config.Attributes.Wave, n)
end

local function startBreak()
	print(`[Waves] wave {wave} cleared, opening shop`)
	waveActive = false
	nextWaveAt = os.clock() + W.BreakDuration
	workspace:SetAttribute(Config.Attributes.BreakEndsAt, workspace:GetServerTimeNow() + W.BreakDuration)
	workspace:SetAttribute(Config.Attributes.Intermission, true) -- opens the shop
end

workspace:SetAttribute(Config.Attributes.Intermission, false)

local spawnTimer = 0

-- true when there are players and every one of them has a dead character
local function allPlayersDead()
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

-- Back to a fresh run: coins, kills, upgrades and extra blades are all lost.
local function resetPlayerProgress(player)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Coins.Value = 0
		stats.Kills.Value = 0
	end
	local prefix = Config.Attributes.UpgradePrefix
	for name in player:GetAttributes() do
		if string.sub(name, 1, #prefix) == prefix then
			player:SetAttribute(name, nil)
		end
	end
	player:SetAttribute(Config.Attributes.BladeCount, B.StartCount)
end

local function gameOver()
	Remotes.GameOver:FireAllClients({ Wave = wave, Restart = W.BreakDuration })
	for model in zombies do
		model:Destroy() -- Destroying handler clears the entry and aliveCount
	end
	for _, player in Players:GetPlayers() do
		resetPlayerProgress(player)
	end
	wave = 0
	toSpawn = 0
	spawnTimer = 0
	waveActive = false
	nextWaveAt = os.clock() + W.BreakDuration
	workspace:SetAttribute(Config.Attributes.Wave, 0)
	workspace:SetAttribute(Config.Attributes.Intermission, false)
end

-- Main loop -----------------------------------------------------------------

RunService.Heartbeat:Connect(function(dt)
	local hasPlayers = #Players:GetPlayers() > 0

	if (waveActive or workspace:GetAttribute(Config.Attributes.Intermission)) and allPlayersDead() then
		gameOver()
		return
	end

	-- Derive the count from the table itself so a missed decrement can never stall a wave.
	local actual = 0
	for model, zombie in zombies do
		if not model.Parent or zombie.humanoid.Health <= 0 then
			zombies[model] = nil
			if model.Parent then
				model:Destroy()
			end
		else
			actual += 1
		end
	end
	if actual ~= aliveCount then
		warn(`aliveCount drifted ({aliveCount} vs {actual} real zombies); corrected`)
		aliveCount = actual
	end

	if waveActive then
		spawnTimer += dt
		if spawnTimer >= Z.SpawnInterval and toSpawn > 0 then
			if aliveCount < Z.MaxAlive and hasPlayers then
				spawnTimer = 0
				toSpawn -= 1
				spawnZombie(waveHealth(wave))
			end
		end
		if toSpawn == 0 and aliveCount == 0 then
			startBreak()
		end
	elseif hasPlayers and os.clock() >= nextWaveAt then
		startWave(wave + 1)
	end

	workspace:SetAttribute(Config.Attributes.ZombiesLeft, waveActive and aliveCount + toSpawn or 0)

	updateContactDamage(dt)

	-- same clock the clients use to place the blades
	local now = workspace:GetServerTimeNow()
	updateChasing(now)
	updateBladeHits(now)
end)
