-- Spawns zombies on the arena edge, chases the nearest player, applies blade hits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BladeMath = require(ReplicatedStorage.Shared.BladeMath)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Shop = require(script.Parent.Shop)

local Z = Config.Zombies

local Zombies = {}

local folder = Instance.new("Folder")
folder.Name = "Zombies"
folder.Parent = workspace

-- [model] = { humanoid, root, lastHit = {[hitKey] = time}, nextRetarget }
local alive = {}
local aliveCount = 0

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return character:FindFirstChild("HumanoidRootPart")
	end
	return nil
end

local function randomEdgePosition(): Vector3
	local h = Z.ArenaHalfSize
	local along = (math.random() * 2 - 1) * h
	local side = math.random(1, 4)
	local y = Z.Size.Y / 2 + 1
	if side == 1 then
		return Vector3.new(along, y, -h)
	elseif side == 2 then
		return Vector3.new(along, y, h)
	elseif side == 3 then
		return Vector3.new(-h, y, along)
	end
	return Vector3.new(h, y, along)
end

local function spawnZombie(health: number)
	local model = Instance.new("Model")
	model.Name = "Zombie"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Z.Size
	root.Color = Z.Color
	root.Material = Enum.Material.SmoothPlastic
	root.CFrame = CFrame.new(randomEdgePosition())
	root.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = Z.WalkSpeed
	humanoid.HipHeight = 0
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = folder
	root:SetNetworkOwner(nil)

	alive[model] = { humanoid = humanoid, root = root, lastHit = {}, nextRetarget = 0 }
	aliveCount += 1

	humanoid.Died:Connect(function()
		if alive[model] then
			alive[model] = nil
			aliveCount -= 1
		end
		task.delay(0.5, function()
			model:Destroy()
		end)
	end)
end

local function addStat(player: Player, name: string, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	if value then
		value.Value += amount
	end
end

local function nearestPlayerRoot(position: Vector3): BasePart?
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local d = (root.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best
end

local function damage(data, amount: number, attacker: Player)
	if data.humanoid.Health <= 0 then
		return
	end
	data.humanoid.Health -= amount
	local killed = data.humanoid.Health <= 0
	Remotes.HitFx:FireAllClients(data.root.Position, amount, killed)
	if killed then
		local coins = math.round(Config.Rewards.CoinsPerKill * Upgrades.coinMult(attacker))
		addStat(attacker, "Kills", 1)
		addStat(attacker, "Coins", coins)
		Remotes.CoinFx:FireClient(attacker, data.root.Position, coins)
		local heal = Upgrades.healPerKill(attacker)
		local humanoid = heal > 0 and attacker.Character and attacker.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + heal)
		end
	end
end

local function processBladeHits(now: number)
	local serverTime = workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local count = player:GetAttribute("BladeCount")
		if root and count and count > 0 then
			for index = 1, count do
				local offset = BladeMath.offset(index, count, serverTime, player)
				local bladePos = root.Position + offset
				local key = player.UserId .. ":" .. index
				for _, data in alive do
					if
						data.humanoid.Health > 0
						and (data.root.Position - bladePos).Magnitude <= Z.HitRadius
						and now - (data.lastHit[key] or -math.huge) >= Z.HitCooldown
					then
						data.lastHit[key] = now
						damage(data, Z.BladeDamage * Upgrades.damageMult(player), player)
					end
				end
			end
		end
	end
end

local function processContactDamage(dt: number)
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local humanoid = root and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			for _, data in alive do
				if
					data.humanoid.Health > 0
					and (data.root.Position - root.Position).Magnitude <= Z.ContactRadius
				then
					humanoid:TakeDamage(Z.ContactDps * dt)
				end
			end
		end
	end
end

local function anyPlayerAlive(): boolean
	for _, player in Players:GetPlayers() do
		if rootOf(player) then
			return true
		end
	end
	return false
end

function Zombies.start()
	local W = Config.Waves
	local wave = 0
	local toSpawn = 0
	local waveHealth = Z.Health
	local breakLeft = 0 -- counts down between waves; wave 1 starts as soon as a player is in
	local spawnTimer = 0
	local breakStarted = false
	local resetting = false
	workspace:SetAttribute("Wave", 0)
	workspace:SetAttribute("ZombiesLeft", 0)
	workspace:SetAttribute("NextWaveAt", 0)

	-- Game over: wipe zombies, upgrades, blades, coins and kills, respawn everyone, back to wave 1.
	local function resetRun()
		resetting = true
		Shop.close()
		for model in alive do
			model:Destroy()
		end
		table.clear(alive)
		aliveCount = 0
		wave, toSpawn, spawnTimer, breakLeft, breakStarted = 0, 0, 0, 0, false
		waveHealth = Z.Health
		workspace:SetAttribute("Wave", 0)
		workspace:SetAttribute("ZombiesLeft", 0)
		workspace:SetAttribute("NextWaveAt", 0)

		local players = Players:GetPlayers()
		for _, player in players do
			for _, u in Config.Upgrades do
				player:SetAttribute("Up_" .. u.Id, nil)
			end
			player:SetAttribute("BladeCount", Config.Blades.StartCount)
			addStat(player, "Coins", -(player.leaderstats.Coins.Value))
			addStat(player, "Kills", -(player.leaderstats.Kills.Value))
		end
		task.spawn(function()
			for _, player in players do
				if player.Parent then
					player:LoadCharacter()
				end
			end
			resetting = false
		end)
	end

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()

		if resetting then
			return
		end
		if wave > 0 and #Players:GetPlayers() > 0 and not anyPlayerAlive() then
			resetRun()
			return
		end

		if #Players:GetPlayers() > 0 then
			if toSpawn == 0 and aliveCount == 0 then
				if wave > 0 then
					Shop.open()
				end
					if wave > 0 and not breakStarted then
						breakStarted = true
						workspace:SetAttribute("NextWaveAt", workspace:GetServerTimeNow() + breakLeft)
					end
					breakLeft -= dt
				if breakLeft <= 0 then
					Shop.close()
					wave += 1
					toSpawn = W.FirstWaveCount + W.CountPerWave * (wave - 1)
					waveHealth = Z.Health * W.HealthMultiplierPerWave ^ (wave - 1)
					breakLeft = W.BreakSeconds
					breakStarted = false
					workspace:SetAttribute("NextWaveAt", 0)
					workspace:SetAttribute("Wave", wave)
				end
			elseif toSpawn > 0 then
				spawnTimer += dt
				if spawnTimer >= Z.SpawnInterval and aliveCount < Z.MaxAlive then
					spawnTimer = 0
					toSpawn -= 1
					spawnZombie(waveHealth)
				end
			end
		end

		workspace:SetAttribute("ZombiesLeft", toSpawn + aliveCount)

		processContactDamage(dt)

		for _, data in alive do
			if now >= data.nextRetarget then
				data.nextRetarget = now + Z.RetargetInterval
				local target = nearestPlayerRoot(data.root.Position)
				if target then
					data.humanoid:MoveTo(target.Position)
				end
			end
		end

		processBladeHits(now)
	end)
end

return Zombies
