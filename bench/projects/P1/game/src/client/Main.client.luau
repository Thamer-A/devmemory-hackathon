local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Log)

local controllers = script.Parent.controllers

local ORDER = {
	"UIController",
	"HUDController",
	"ShopController",
	"InventoryController",
	"InputController",
}

local loaded = {}

for _, name in ORDER do
	local ok, controller = pcall(require, controllers[name])
	if ok then
		table.insert(loaded, { name = name, controller = controller })
	else
		Log.warn("Client", "failed to load", name, controller)
	end
end

for _, entry in loaded do
	if entry.controller.init then
		entry.controller.init()
	end
end

for _, entry in loaded do
	if entry.controller.start then
		entry.controller.start()
	end
end

Log.info("Client", "controllers ready:", #loaded)
