--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Log)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local controllers = script.Parent.controllers

-- Theme is a plain module used by the controllers; it has no init/start.
local ORDER = {
	"CameraController",
	"HUDController",
	"ShopController",
	"BladeController",
	"EffectsController",
}

local loaded = {}

for _, name in ORDER do
	local module = controllers:FindFirstChild(name)
	if module == nil then
		Log.warn("Boot", "controller module not found:", name)
		continue
	end
	local ok, controller = pcall(require, module)
	if not ok then
		Log.warn("Boot", "failed to require", name, controller)
		continue
	end
	table.insert(loaded, { name = name, controller = controller })
end

for _, entry in loaded do
	if type(entry.controller.init) == "function" then
		local ok, err = pcall(entry.controller.init)
		if not ok then
			Log.warn("Boot", "init failed for", entry.name, err)
		end
	end
end

for _, entry in loaded do
	if type(entry.controller.start) == "function" then
		local ok, err = pcall(entry.controller.start)
		if not ok then
			Log.warn("Boot", "start failed for", entry.name, err)
		end
	end
end

-- Every handler is connected now; ask the server to resend current state, stats and offers.
Remotes.get("ClientReady"):FireServer()
Log.info("Boot", "Blade Swarm client started with", #loaded, "controllers")
