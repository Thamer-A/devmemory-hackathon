-- Spawns zombies at the arena edge, chases the nearest player, applies blade damage, awards coins/kills.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BladeOrbit = require(ReplicatedStorage.Shared.BladeOrbit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local damageNumberRemote = Remotes.get("DamageNumber")
local deathFxRemote = Remotes.get("ZombieDeathFx")
local coinPopupRemote = Remotes.get("CoinPopup")

local zombieFolder = Instance.new("Folder")
zombieFolder.Name = "Zombies"
zombieFolder.Parent = workspace

type ZombieState = { model: Model, humanoid: Humanoid, root: BasePart, lastHit: { [string]: number }, rewarded: boolean?, lastAttacker: Player? }
local killZombie -- defined below
local zombies: { [Model]: ZombieState } = {}
local aliveCount = 0
local unspawned = 0 -- zombies of the current wave not yet spawned

-- Replicated for the HUD: zombies still to kill this wave (alive + not yet spawned).
local function publishZombiesLeft()
	workspace:SetAttribute("ZombiesLeft", aliveCount + unspawned)
end

local function setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Coins", "Kills" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
end

Players.PlayerAdded:Connect(setupLeaderstats)
for _, player in Players:GetPlayers() do
	setupLeaderstats(player)
end

local function randomEdgePosition(): Vector3
	local c = Config.Zombies
	local e = c.ArenaHalfSize - c.SpawnEdgeInset
	local along = (math.random() * 2 - 1) * e
	local side = math.random(1, 4)
	if side == 1 then
		return Vector3.new(along, 3, -e)
	elseif side == 2 then
		return Vector3.new(along, 3, e)
	elseif side == 3 then
		return Vector3.new(e, 3, along)
	end
	return Vector3.new(-e, 3, along)
end

local function spawnZombie(health: number)
	local c = Config.Zombies
	local model = Instance.new("Model")
	model.Name = "Zombie"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = c.Size
	root.Color = c.Color
	root.Material = Enum.Material.SmoothPlastic
	root.CFrame = CFrame.new(randomEdgePosition())
	root.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = c.WalkSpeed
	humanoid.HipHeight = 0.5
	humanoid.RequiresNeck = false -- rig has no Head/Neck; keeps the humanoid from misbehaving
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = zombieFolder
	root:SetNetworkOwner(nil)

	zombies[model] = { model = model, humanoid = humanoid, root = root, lastHit = {} }
	aliveCount += 1
	unspawned -= 1
	publishZombiesLeft()

	-- A zombie that dies or vanishes without a blade kill must still leave the count, or the wave never ends.
	local function forget()
		local state = zombies[model]
		if state and state.lastAttacker and state.humanoid.Health <= 0 then
			killZombie(state, state.lastAttacker) -- reward from the death itself, not only from the hit loop
			return
		end
		if zombies[model] then
			zombies[model] = nil
			aliveCount -= 1
			publishZombiesLeft()
		end
	end
	humanoid.Died:Connect(forget)
	model.Destroying:Connect(forget)
end

function killZombie(state: ZombieState, killer: Player)
	-- Not guarded by `zombies[model]`: the Health change that killed it fires Died first, which already forgets it.
	if state.rewarded then
		return
	end
	state.rewarded = true
	if zombies[state.model] then
		zombies[state.model] = nil
		aliveCount -= 1
		publishZombiesLeft()
	end
	local deathPos = state.root.Position
	-- Reward first, so a failure in the effects below can never cost the player their coins/kill.
	local stats = killer:FindFirstChild("leaderstats")
	if stats then
		stats.Kills.Value += 1
		local coins = math.floor(Config.Zombies.CoinsPerKill * (killer:GetAttribute("CoinMult") or 1) + 0.5)
		stats.Coins.Value += coins
		coinPopupRemote:FireClient(killer, deathPos, coins)
	end
	local heal = killer:GetAttribute("HealOnKill")
	local humanoid = killer.Character and killer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and heal and heal > 0 then
		humanoid.Health = math.min(humanoid.Health + heal, humanoid.MaxHealth)
	end
	state.humanoid.Health = 0
	deathFxRemote:FireAllClients(deathPos)
	task.delay(1, function()
		state.model:Destroy()
	end)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end

-- Chase the nearest living player.
local function updateChasing()
	local roots = {}
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		if root then
			table.insert(roots, root)
		end
	end
	for _, state in zombies do
		local best, bestDist = nil, math.huge
		for _, root in roots do
			local d = (root.Position - state.root.Position).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
		if best then
			state.humanoid:MoveTo(best.Position)
		end
	end
end

-- Server-side blade hit detection using the same deterministic orbit as the clients.
local function updateBladeHits()
	local now = os.clock()
	local t = workspace:GetServerTimeNow()
	local c = Config.Blades
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		local count = player:GetAttribute("BladeCount")
		if root and count then
			local reach, spin, damage = player:GetAttribute("ReachBonus"), player:GetAttribute("SpinMult"), c.HitDamage * (player:GetAttribute("DamageMult") or 1)
			for i = 1, count do
				local bladePos = BladeOrbit.getCFrame(root.Position, i, count, t, reach, spin).Position
				local key = player.UserId .. ":" .. i
				for _, state in zombies do
					if
						(state.root.Position - bladePos).Magnitude <= c.HitRadius
						and now - (state.lastHit[key] or -math.huge) >= c.HitCooldown
					then
						state.lastHit[key] = now
						state.lastAttacker = player
						state.humanoid.Health -= damage
						damageNumberRemote:FireAllClients(state.root.Position, damage)
						if state.humanoid.Health <= 0 then
							killZombie(state, player)
						end
					end
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(updateBladeHits)

-- Zombies touching a living player drain 10 HP/sec.
local function updateContactDamage(dt: number)
	local c = Config.Zombies
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		local humanoid = root and root.Parent:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			for _, state in zombies do
				local offset = state.root.Position - root.Position -- horizontal only: height differences never block contact
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= c.ContactRadius then
					humanoid.Health -= c.ContactDamagePerSecond * dt -- not TakeDamage: a ForceField would block it
				end
			end
		end
	end
end

RunService.Heartbeat:Connect(updateContactDamage)

-- Game over: when every player is dead the run restarts at wave 1.
local gameOver = false

-- Players whose current character has died. Set from Humanoid.Died (reliable even if the character is removed
-- or respawned before a poll sees Health <= 0), cleared when a new character spawns.
local deadPlayers: { [Player]: boolean } = {}

local function trackDeaths(player: Player)
	local function onCharacter(character: Model)
		deadPlayers[player] = nil
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			if humanoid.Health <= 0 then
				deadPlayers[player] = true
			end
			humanoid.Died:Connect(function()
				deadPlayers[player] = true
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(trackDeaths)
for _, player in Players:GetPlayers() do
	trackDeaths(player)
end
Players.PlayerRemoving:Connect(function(player)
	deadPlayers[player] = nil
end)

local function allPlayersDead(): boolean
	local players = Players:GetPlayers()
	if #players == 0 then
		return false
	end
	for _, player in players do
		if not deadPlayers[player] then
			return false
		end
	end
	return true
end

local runGeneration = 0 -- bumped on every reset; the wave loop stops when its generation is stale
local resetRun -- defined below
local resetRunInner -- defined below

RunService.Heartbeat:Connect(function()
	if not gameOver and allPlayersDead() then
		gameOver = true
		task.spawn(resetRun) -- own thread, so a wave loop stuck in a wait can't delay the reset
	end
end)

-- Clears zombies, coins and upgrades, and respawns everyone (the wave loop restarts at wave 1).
function resetRun()
	-- gameOver must always clear, even if something below errors, or the run could never reset again.
	local ok, err = pcall(function()
		resetRunInner()
	end)
	if not ok then
		warn("[ZombieService] resetRun failed: " .. tostring(err))
	end
	gameOver = false
end

function resetRunInner()
	print("[ZombieService] all players dead - resetting to wave 1")
	runGeneration += 1
	for model in zombies do
		model:Destroy()
	end
	table.clear(zombies)
	aliveCount = 0
	unspawned = 0
	publishZombiesLeft()
	workspace:SetAttribute("BreakSecondsLeft", 0)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("BladeCount", Config.Blades.StartCount)
		for name, value in Config.Shop.Defaults do
			player:SetAttribute(name, value)
		end
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			stats.Coins.Value = 0
		end
		deadPlayers[player] = nil
		local loaded, loadErr = pcall(function()
			player:LoadCharacter()
		end)
		if not loaded then
			warn("[ZombieService] LoadCharacter failed: " .. tostring(loadErr))
		end
	end
end

-- Waves: spawn the wave's zombies (at most MaxAlive at once), wait until all are dead, then break.
task.spawn(function()
	local w = Config.Waves
	while true do
		local wave = 0
		local generation = runGeneration
		while generation == runGeneration do
			wave += 1
			workspace:SetAttribute("Wave", wave)
			local total = w.FirstWaveZombies + w.ZombiesPerWave * (wave - 1)
			local health = Config.Zombies.Health * (1 + w.HealthGrowth) ^ (wave - 1)
			local spawned = 0
			unspawned = total
			publishZombiesLeft()
			while generation == runGeneration and (spawned < total or aliveCount > 0) do
				if spawned < total and aliveCount < Config.Zombies.MaxAlive then
					spawnZombie(health)
					spawned += 1
				end
				task.wait(Config.Zombies.SpawnInterval)
			end
			for remaining = w.BreakSeconds, 1, -1 do
				if generation ~= runGeneration then
					break
				end
				workspace:SetAttribute("BreakSecondsLeft", remaining)
				task.wait(1)
			end
			if generation == runGeneration then
				workspace:SetAttribute("BreakSecondsLeft", 0)
			end
		end
		while gameOver do -- reset (respawn) still in progress
			task.wait(0.1)
		end
	end
end)

task.spawn(function()
	while true do
		updateChasing()
		task.wait(0.25)
	end
end)
