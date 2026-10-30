local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- Server owns the blade count; clients read the attribute and render the orbit.
local function initPlayer(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = Config.Stats.Folder
	for _, name in { Config.Stats.Coins, Config.Stats.Kills } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player

	player:SetAttribute(Config.Blades.CountAttribute, Config.Blades.StartCount)
end

Players.PlayerAdded:Connect(initPlayer)
for _, player in Players:GetPlayers() do
	initPlayer(player)
end
