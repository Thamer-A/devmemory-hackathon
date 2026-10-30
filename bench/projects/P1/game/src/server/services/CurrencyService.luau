local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local MathUtil = require(Shared.MathUtil)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local CurrencyService = {}

function CurrencyService.get(player: Player): number
	local data = DataService.get(player)
	if data == nil then
		return 0
	end
	return data.coins
end

function CurrencyService.canAfford(player: Player, amount: number): boolean
	return CurrencyService.get(player) >= amount
end

-- Single entry point for every coin change. Negative amounts spend coins.
function CurrencyService.add(player: Player, amount: number, reason: string): number?
	if type(reason) ~= "string" or reason == "" then
		error("CurrencyService.add requires a non-empty reason string", 2)
	end
	if type(amount) ~= "number" or amount ~= amount then
		error("CurrencyService.add requires a numeric amount", 2)
	end

	local data = DataService.get(player)
	if data == nil then
		Log.warn("CurrencyService", "no data for", player.Name, "reason:", reason)
		return nil
	end

	local before = data.coins
	local after = MathUtil.clamp(before + amount, 0, Config.MaxCoins)
	data.coins = after
	DataService.markDirty(player)

	LeaderboardService.set(player, "Coins", after)
	Remotes.get("CoinsChanged"):FireClient(player, after, after - before)

	Log.info("CurrencyService", player.Name, string.format("%+d", after - before), "coins (" .. reason .. ")")
	return after
end

function CurrencyService.init()
	DataService.loaded:Connect(function(player, data)
		Remotes.get("CoinsChanged"):FireClient(player, data.coins, 0)
	end)
end

return CurrencyService
