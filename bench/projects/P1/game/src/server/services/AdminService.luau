local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Log)

local CurrencyService = require(script.Parent.CurrencyService)

local AdminService = {}

local commands: { [string]: { usage: string, run: (admin: Player, args: { string }) -> () } } = {}

local function isAdmin(player: Player): boolean
	return table.find(Config.Admins, player.UserId) ~= nil
end

local function findPlayer(query: string): Player?
	local lowered = string.lower(query)
	local partial: Player? = nil
	for _, player in Players:GetPlayers() do
		local name = string.lower(player.Name)
		if name == lowered then
			return player
		end
		if partial == nil and string.sub(name, 1, #lowered) == lowered then
			partial = player
		end
	end
	return partial
end

local function split(message: string): { string }
	local parts = {}
	for word in string.gmatch(message, "%S+") do
		table.insert(parts, word)
	end
	return parts
end

function AdminService.register(name: string, usage: string, run: (admin: Player, args: { string }) -> ())
	commands[string.lower(name)] = {
		usage = usage,
		run = run,
	}
end

local function dispatch(admin: Player, message: string)
	if string.sub(message, 1, #Config.AdminPrefix) ~= Config.AdminPrefix then
		return
	end

	local parts = split(string.sub(message, #Config.AdminPrefix + 1))
	local name = table.remove(parts, 1)
	if name == nil then
		return
	end

	local command = commands[string.lower(name)]
	if command == nil then
		Log.warn("AdminService", "unknown command", name, "from", admin.Name)
		return
	end

	local ok, err = pcall(command.run, admin, parts)
	if not ok then
		Log.warn("AdminService", "command", name, "failed:", err)
	end
end

local function registerDefaults()
	AdminService.register("coins", "/coins <playerName> <amount>", function(admin, args)
		local target = args[1] and findPlayer(args[1])
		local amount = args[2] and tonumber(args[2])
		if target == nil or amount == nil then
			Log.warn("AdminService", "usage: /coins <playerName> <amount>")
			return
		end
		CurrencyService.add(target, amount, "admin_grant")
		Log.info("AdminService", admin.Name, "granted", amount, "coins to", target.Name)
	end)

	AdminService.register("kick", "/kick <playerName> [reason]", function(admin, args)
		local target = args[1] and findPlayer(args[1])
		if target == nil then
			Log.warn("AdminService", "usage: /kick <playerName> [reason]")
			return
		end
		local reason = table.concat(args, " ", 2)
		if reason == "" then
			reason = "Removed by an administrator."
		end
		Log.info("AdminService", admin.Name, "kicked", target.Name, "-", reason)
		target:Kick(reason)
	end)
end

local function watchPlayer(player: Player)
	if not isAdmin(player) then
		return
	end
	player.Chatted:Connect(function(message)
		dispatch(player, message)
	end)
end

function AdminService.init()
	registerDefaults()
	Players.PlayerAdded:Connect(watchPlayer)
end

function AdminService.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return AdminService
