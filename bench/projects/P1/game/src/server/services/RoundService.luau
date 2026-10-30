local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)

local RoundService = {}

RoundService.stateChanged = Signal.new()

local STATE_INTERMISSION = "Intermission"
local STATE_PLAYING = "Playing"

local currentState = STATE_INTERMISSION
local timeLeft = Config.IntermissionLength
local participants: { [Player]: boolean } = {}

local function broadcast()
	Remotes.get("RoundState"):FireAllClients({
		state = currentState,
		timeLeft = timeLeft,
	})
end

local function setState(state: string, duration: number)
	currentState = state
	timeLeft = duration
	RoundService.stateChanged:Fire(state)
	broadcast()
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function beginRound()
	participants = {}
	for _, player in Players:GetPlayers() do
		participants[player] = true
	end
	Log.info("RoundService", "round started with", #Players:GetPlayers(), "players")
	setState(STATE_PLAYING, Config.RoundLength)
end

local function endRound()
	local survivors = 0
	for player in participants do
		if player.Parent == Players then
			DataService.incrementStat(player, "roundsPlayed")
			if isAlive(player) then
				survivors += 1
				CurrencyService.add(player, Config.RoundRewardCoins, "round_reward")
			end
		end
	end
	participants = {}
	Log.info("RoundService", "round ended,", survivors, "survivors")
	setState(STATE_INTERMISSION, Config.IntermissionLength)
end

function RoundService.getState(): string
	return currentState
end

function RoundService.getTimeLeft(): number
	return timeLeft
end

function RoundService.isPlaying(): boolean
	return currentState == STATE_PLAYING
end

function RoundService.init()
	Players.PlayerAdded:Connect(function(player)
		Remotes.get("RoundState"):FireClient(player, {
			state = currentState,
			timeLeft = timeLeft,
		})
	end)
end

function RoundService.start()
	setState(STATE_INTERMISSION, Config.IntermissionLength)

	while true do
		task.wait(1)
		timeLeft -= 1

		if timeLeft <= 0 then
			if currentState == STATE_INTERMISSION then
				beginRound()
			else
				endRound()
			end
		else
			broadcast()
		end
	end
end

return RoundService
