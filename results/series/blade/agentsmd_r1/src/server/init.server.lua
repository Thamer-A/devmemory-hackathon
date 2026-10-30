local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
require(ReplicatedStorage.Shared.Remotes) -- creates RemoteEvents
local Zombies = require(script.Zombies)
local Shop = require(script.Shop)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("BladeCount", Config.Blades.StartCount)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Coins", "Kills" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	Shop.initPlayer(player)
end)

Zombies.start()
