-- Spawns zombies at the arena edge, chases the nearest player, and applies blade damage.
-- Blades are moved client-side, so hits are computed here from the same shared orbit math.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local BladeConfig = require(Shared.Config).Blades
local Config = require(Shared.Config).Zombies
local BladeMath = require(Shared.BladeMath)
local Remotes = require(Shared.Remotes)
local Coins = require(script.Parent.Coins)
local Shop = require(script.Parent.Shop)

local bladesRoot = workspace:WaitForChild("Blades")

local folder = Instance.new("Folder")
folder.Name = "Zombies"
folder.Parent = workspace

local alive = 0
local unspawned = 0
local lastAttacker: { [Model]: Player } = {}
local lastHit: { [Model]: { [string]: number } } = {}

-- The HUD reads these workspace attributes (they replicate, so no remote is needed).
local function publishZombiesLeft()
	workspace:SetAttribute("ZombiesLeft", unspawned + alive)
end

local function makePart(name: string, size: Vector3, pos: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = pos
	part.Color = Config.Color
	part.Material = Enum.Material.SmoothPlastic
	return part
end

local function award(zombie: Model, position: Vector3)
	local player = lastAttacker[zombie]
	local stats = player and player.Parent and player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local coins = math.round(Config.CoinsPerKill * (1 + (player:GetAttribute("CoinBonus") or 0)))
	Coins.add(player, coins)
	Remotes.CombatFx:FireClient(player, "Coins", position, coins)
	stats.Kills.Value += 1

	local heal = player:GetAttribute("LifeSteal")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if heal and humanoid and humanoid.Health > 0 then
		humanoid.Health += heal -- Humanoid clamps to MaxHealth
	end
end

local function spawnZombie(health: number)
	local angle = math.random() * 2 * math.pi
	-- Square arena: project the random direction onto the square edge.
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local scale = Config.SpawnRadius / math.max(math.abs(dir.X), math.abs(dir.Z))
	local pos = dir * scale + Vector3.new(0, 4, 0)

	local zombie = Instance.new("Model")
	zombie.Name = "Zombie"

	local root = makePart("HumanoidRootPart", Vector3.new(2, 2, 1), pos)
	local head = makePart("Head", Vector3.new(1.5, 1.5, 1.5), pos + Vector3.new(0, 1.75, 0))
	local legs = makePart("Legs", Vector3.new(2, 2, 1), pos - Vector3.new(0, 2, 0))
	for _, part in { head, legs } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	root.Parent = zombie
	head.Parent = zombie
	legs.Parent = zombie

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = Config.WalkSpeed
	humanoid.HipHeight = 2
	-- This rig has no Torso/Neck, so the default RequiresNeck would break the humanoid.
	humanoid.RequiresNeck = false
	humanoid.Parent = zombie

	zombie.PrimaryPart = root
	zombie.Parent = folder
	root:SetNetworkOwner(nil)

	alive += 1
	unspawned -= 1
	publishZombiesLeft()
	lastHit[zombie] = {}
	local finished = false
	local function finish()
		if finished then
			return
		end
		finished = true
		alive -= 1
		publishZombiesLeft()
		lastAttacker[zombie] = nil
		lastHit[zombie] = nil
	end
	-- Zombies removed without dying (e.g. falling out of the world) must still stop counting
	-- as alive, otherwise the wave never ends and the shop never opens.
	zombie.Destroying:Connect(finish)
	humanoid.Died:Connect(function()
		if finished then
			return
		end
		local root = zombie.PrimaryPart
		if root then
			Remotes.CombatFx:FireAllClients("Kill", root.Position)
			award(zombie, root.Position)
		else
			award(zombie, Vector3.zero)
		end
		finish()
		task.delay(1, function()
			zombie:Destroy()
		end)
	end)
end

local function nearestPlayerRoot(from: Vector3): BasePart?
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local dist = (hrp.Position - from).Magnitude
			if dist < bestDist then
				best, bestDist = hrp, dist
			end
		end
	end
	return best
end

-- Game over: every player has a character and all of them are dead.
-- Players still loading in have no character yet and must not trigger a reset.
local function everyoneDead(): boolean
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

-- Waves: spawn the wave's quota (capped by MaxAlive at once), wait for it to be cleared, then break.
-- If everyone dies, the run is cleared and restarts at wave 1.
task.spawn(function()
	local wave = 1
	while true do
		local quota = Config.FirstWaveCount + Config.CountPerWave * (wave - 1)
		local health = Config.Health * (1 + Config.HealthGrowth * (wave - 1))
		local spawned = 0
		local gameOver = false
		unspawned = quota
		workspace:SetAttribute("Wave", wave)
		workspace:SetAttribute("BreakEndsAt", 0)
		publishZombiesLeft()
		while spawned < quota or alive > 0 do
			if everyoneDead() then
				gameOver = true
				break
			end
			if spawned < quota and alive < Config.MaxAlive and #Players:GetPlayers() > 0 then
				spawnZombie(health)
				spawned += 1
			end
			task.wait(Config.SpawnInterval)
		end
		if not gameOver then
			Shop.open()
			workspace:SetAttribute("BreakEndsAt", workspace:GetServerTimeNow() + Config.WaveBreak)
			local breakEnds = os.clock() + Config.WaveBreak
			while os.clock() < breakEnds and not gameOver do
				gameOver = everyoneDead()
				task.wait(0.5)
			end
			Shop.close()
		end
		if gameOver then
			-- Destroying fires each zombie's finish(), which fixes the alive count.
			folder:ClearAllChildren()
			wave = 1
			-- Publish the reset now so the HUD shows wave 1 while players are still dead,
			-- instead of keeping the old wave until someone respawns.
			unspawned = 0
			workspace:SetAttribute("Wave", wave)
			workspace:SetAttribute("BreakEndsAt", 0)
			publishZombiesLeft()
			-- Yield until someone has respawned; otherwise everyoneDead() ends the next wave
			-- instantly and this loop spins without yielding (script timeout).
			repeat
				task.wait(1)
			until not everyoneDead()
		else
			wave += 1
		end
	end
end)

-- Contact damage
RunService.Heartbeat:Connect(function(dt)
	for _, zombie in folder:GetChildren() do
		local humanoid = zombie:FindFirstChildOfClass("Humanoid")
		local root = zombie.PrimaryPart
		if not (humanoid and root) or humanoid.Health <= 0 then
			continue
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 and (hrp.Position - root.Position).Magnitude <= Config.ContactRadius then
				-- Not TakeDamage: it is blocked by ForceFields (e.g. spawn protection).
				hum.Health -= Config.ContactDamage * dt
			end
		end
	end
end)

-- Chasing
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, zombie in folder:GetChildren() do
			local humanoid = zombie:FindFirstChildOfClass("Humanoid")
			local root = zombie.PrimaryPart
			if humanoid and humanoid.Health > 0 and root then
				local target = nearestPlayerRoot(root.Position)
				if target then
					humanoid:MoveTo(target.Position)
				end
			end
		end
	end
end)

-- Blade hits
RunService.Heartbeat:Connect(function()
	local t = workspace:GetServerTimeNow()
	local now = os.clock()

	for _, bladeFolder in bladesRoot:GetChildren() do
		local player = Players:GetPlayerByUserId(tonumber(bladeFolder.Name) or 0)
		local hrp = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not player or not hrp then
			continue
		end

		local count = #bladeFolder:GetChildren()
		local reach = player:GetAttribute("Reach") or 0
		local damage = BladeConfig.Damage * (1 + (player:GetAttribute("DamageBonus") or 0))
		for index = 1, count do
			local bladePos = hrp.Position + BladeMath.getOffset(index, count, t, reach)
			local key = bladeFolder.Name .. ":" .. index

			for _, zombie in folder:GetChildren() do
				local humanoid = zombie:FindFirstChildOfClass("Humanoid")
				local root = zombie.PrimaryPart
				local hits = lastHit[zombie]
				if not (humanoid and root and hits) or humanoid.Health <= 0 then
					continue
				end
				if (root.Position - bladePos).Magnitude > BladeConfig.HitRadius then
					continue
				end
				if now - (hits[key] or -math.huge) < BladeConfig.HitCooldown then
					continue
				end
				hits[key] = now
				lastAttacker[zombie] = player
				humanoid:TakeDamage(damage)
				Remotes.CombatFx:FireAllClients("Hit", root.Position, damage)
			end
		end
	end
end)
