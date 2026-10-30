local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Log = require(Shared.Log)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local FOLDER_NAME = "leaderstats"
local STAT_COINS = "Coins"
local STAT_KILLS = "Kills"

local function ensureFolder(player: Player): Folder
	local folder = player:FindFirstChild(FOLDER_NAME)
	if folder then
		return folder :: Folder
	end

	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for _, statName in { STAT_COINS, STAT_KILLS } do
		local value = Instance.new("IntValue")
		value.Name = statName
		value.Value = 0
		value.Parent = folder
	end

	folder.Parent = player
	return folder
end

function LeaderboardService.set(player: Player, statName: string, value: number)
	local folder = ensureFolder(player)
	local stat = folder:FindFirstChild(statName)
	if stat == nil or not stat:IsA("IntValue") then
		Log.warn("LeaderboardService", "unknown stat", statName)
		return
	end
	stat.Value = math.floor(value)
end

local function syncFromData(player: Player, data)
	LeaderboardService.set(player, STAT_COINS, data.coins)
	LeaderboardService.set(player, STAT_KILLS, data.stats.kills)
end

function LeaderboardService.init()
	Players.PlayerAdded:Connect(ensureFolder)
	DataService.loaded:Connect(syncFromData)
end

function LeaderboardService.start()
	for _, player in Players:GetPlayers() do
		ensureFolder(player)
		local data = DataService.get(player)
		if data then
			syncFromData(player, data)
		end
	end
end

return LeaderboardService
