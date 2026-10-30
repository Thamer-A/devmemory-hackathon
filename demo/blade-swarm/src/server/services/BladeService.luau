--!nonstrict
-- Server-authoritative blade hit detection.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BladeMath = require(Shared.BladeMath)
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local Remotes = require(Shared.Remotes)

local PlayerStatsService = require(script.Parent.PlayerStatsService)
local ZombieService = require(script.Parent.ZombieService)

local BladeService = {}

-- cooldowns[zombieModel][player] = os.clock() of the last hit. Weak keys so dead zombies vanish.
local cooldowns: { [Model]: { [Player]: number } } = setmetatable({}, { __mode = "k" })

local function tickPlayer(player: Player, serverTime: number, now: number)
	local root = PlayerStatsService.getRoot(player)
	if root == nil then
		return
	end
	local stats = PlayerStatsService.get(player)
	local origin = root.Position + Vector3.new(0, Config.BladeHeightOffset, 0)
	local blades = BladeMath.positions(origin, stats.BladeCount, stats.BladeRadius, stats.BladeSpinSpeed, serverTime)
	local reach = stats.BladeHitRadius + Config.ZombieBodyMargin
	local reachSquared = reach * reach
	local hitRemote = Remotes.get("ZombieHit")

	for model, record in ZombieService.getZombies() do
		local humanoid = record.humanoid
		if record.dead or humanoid.Health <= 0 or record.root.Parent == nil then
			continue
		end

		local perZombie = cooldowns[model]
		if perZombie == nil then
			perZombie = {}
			cooldowns[model] = perZombie
		end
		local last = perZombie[player]
		if last and now - last < Config.BladeHitCooldown then
			continue
		end

		local position = record.root.Position
		local touching = false
		for _, bladePosition in blades do
			local dx = position.X - bladePosition.X
			local dz = position.Z - bladePosition.Z
			if dx * dx + dz * dz <= reachSquared then
				touching = true
				break
			end
		end

		if touching then
			perZombie[player] = now
			model:SetAttribute("LastAttackerUserId", player.UserId)
			humanoid:TakeDamage(stats.BladeDamage)
			hitRemote:FireAllClients(position + Vector3.new(0, 2.5, 0), stats.BladeDamage)
		end
	end
end

function BladeService.init()
	Log.info("BladeService", "init")
end

function BladeService.start()
	task.spawn(function()
		while true do
			task.wait(Config.DamageTickRate)
			local serverTime = workspace:GetServerTimeNow()
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				if PlayerStatsService.isAlive(player) then
					tickPlayer(player, serverTime, now)
				end
			end
		end
	end)
end

return BladeService
