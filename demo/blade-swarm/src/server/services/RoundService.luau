--!nonstrict
-- Game state machine: Waiting -> Wave(n) -> Shop -> Wave(n+1) ... GameOver -> Waiting.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local PlayerStatsService = require(script.Parent.PlayerStatsService)
local ZombieService = require(script.Parent.ZombieService)

local RoundService = {}

RoundService.waveStarted = Signal.new() -- (wave: number)
RoundService.shopStarted = Signal.new() -- (wave: number)

local phase = "Waiting"
local wave = 1
local endsAt = 0
local skipRequested = false
local lastBroadcastRemaining = -1
local lastBroadcastClock = 0

function RoundService.getPhase(): string
	return phase
end

function RoundService.getWave(): number
	return wave
end

function RoundService.skipShop()
	if phase == "Shop" then
		skipRequested = true
	end
end

local function zombiesLeft(): number
	if phase == "Wave" then
		return ZombieService.remaining()
	end
	return 0
end

local function broadcast(target: Player?)
	local left = zombiesLeft()
	local remote = Remotes.get("StateChanged")
	if target then
		remote:FireClient(target, phase, wave, endsAt, left)
	else
		remote:FireAllClients(phase, wave, endsAt, left)
		lastBroadcastRemaining = left
		lastBroadcastClock = os.clock()
	end
end

local function setState(newPhase: string, newWave: number, newEndsAt: number)
	phase = newPhase
	wave = newWave
	endsAt = newEndsAt
	PlayerStatsService.setWaveReached(newWave)
	broadcast(nil)
end

local function anyAlive(): boolean
	for _, player in Players:GetPlayers() do
		if PlayerStatsService.isAlive(player) then
			return true
		end
	end
	return false
end

local function respawn(player: Player)
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		Log.warn("RoundService", "LoadCharacter failed for", player.Name, err)
	end
end

local function waveDuration(n: number): number
	return math.min(Config.WaveBaseDuration + Config.WaveDurationPerWave * (n - 1), Config.WaveMaxDuration)
end

-- Phases ------------------------------------------------------------------

local function waitForPlayers()
	setState("Waiting", 1, 0)
	while not anyAlive() do
		task.wait(Config.RoundTickRate)
	end
	local startAt = workspace:GetServerTimeNow() + Config.StartDelay
	setState("Waiting", 1, startAt)
	task.wait(Config.StartDelay)
end

-- Returns "cleared", "wiped" or "empty".
local function runWave(n: number): string
	local duration = waveDuration(n)
	setState("Wave", n, workspace:GetServerTimeNow() + duration)
	ZombieService.beginWave(n, duration)
	RoundService.waveStarted:Fire(n)
	Log.info("RoundService", "wave", n, "started")

	local deadTicks = 0
	while true do
		task.wait(Config.RoundTickRate)
		if #Players:GetPlayers() == 0 then
			return "empty"
		end
		if anyAlive() then
			deadTicks = 0
		else
			deadTicks += 1
			if deadTicks >= 2 then
				return "wiped"
			end
		end
		if ZombieService.allSpawned() and ZombieService.aliveCount() == 0 then
			return "cleared"
		end
	end
end

local function runShop(n: number)
	ZombieService.clearAll()
	skipRequested = false

	for _, player in Players:GetPlayers() do
		if PlayerStatsService.isAlive(player) then
			PlayerStatsService.heal(player, math.huge)
		else
			task.spawn(respawn, player)
		end
	end

	setState("Shop", n, workspace:GetServerTimeNow() + Config.ShopDuration)
	RoundService.shopStarted:Fire(n)
	Log.info("RoundService", "shop after wave", n)

	while workspace:GetServerTimeNow() < endsAt and not skipRequested and #Players:GetPlayers() > 0 do
		task.wait(Config.RoundTickRate)
	end
end

local function runGameOver(reached: number)
	Log.info("RoundService", "run over at wave", reached)
	ZombieService.clearAll()
	Remotes.get("RunReset"):FireAllClients(reached)
	setState("GameOver", reached, workspace:GetServerTimeNow() + Config.GameOverDuration)
	task.wait(Config.GameOverDuration)

	PlayerStatsService.resetAll()
	for _, player in Players:GetPlayers() do
		task.spawn(respawn, player)
	end
end

local function mainLoop()
	while true do
		waitForPlayers()
		local n = 1
		while true do
			local result = runWave(n)
			if result == "wiped" then
				runGameOver(n)
				break
			elseif result == "empty" then
				ZombieService.clearAll()
				PlayerStatsService.resetAll()
				break
			end
			runShop(n)
			if #Players:GetPlayers() == 0 then
				PlayerStatsService.resetAll()
				break
			end
			n += 1
		end
	end
end

function RoundService.init()
	-- We control respawning: dead players stay down until the shop or the next run.
	Players.CharacterAutoLoads = false
	Log.info("RoundService", "init")
end

function RoundService.start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			if player.Character == nil then
				respawn(player)
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		if player.Character == nil then
			task.spawn(respawn, player)
		end
	end

	Remotes.get("ClientReady").OnServerEvent:Connect(function(player: Player)
		broadcast(player)
	end)

	-- Keep clients in sync even if they joined late or missed an event.
	task.spawn(function()
		while true do
			task.wait(Config.RoundTickRate)
			local changed = zombiesLeft() ~= lastBroadcastRemaining
			if changed or os.clock() - lastBroadcastClock >= Config.StateBroadcastInterval then
				broadcast(nil)
			end
		end
	end)

	task.spawn(mainLoop)
end

return RoundService
