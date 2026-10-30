local ServerScriptService = game:GetService("ServerScriptService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Log)
require(ReplicatedStorage.Shared.Remotes)

local services = script.Parent.services

-- Order matters: later services depend on earlier ones.
local ORDER = {
	"DataService",
	"LeaderboardService",
	"CurrencyService",
	"ShopService",
	"RoundService",
	"CoinPickupService",
	"EnemyService",
	"AdminService",
}

local loaded = {}

for _, name in ORDER do
	local module = services:FindFirstChild(name)
	if module == nil then
		Log.warn("Boot", "service module not found:", name)
		continue
	end
	local ok, service = pcall(require, module)
	if not ok then
		Log.warn("Boot", "failed to require", name, service)
		continue
	end
	table.insert(loaded, { name = name, service = service })
end

Log.info("Boot", "CoinRush server starting with", #loaded, "services in", ServerScriptService.Name)

for _, entry in loaded do
	if type(entry.service.init) == "function" then
		entry.service.init()
	end
end

for _, entry in loaded do
	if type(entry.service.start) == "function" then
		task.spawn(entry.service.start)
	end
end

Log.info("Boot", "all services started")
