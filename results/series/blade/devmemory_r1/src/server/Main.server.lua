local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

-- Server owns the blade count (attribute so late joiners see it); clients render the orbit.
local function setBladeCount(player, count)
	player:SetAttribute("BladeCount", count)
	Remotes.BladeCountChanged:FireAllClients(player.UserId, count)
end

-- Leaderboard stats; Zombies.server.lua increments these.
local function setupPlayer(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Coins", "Kills" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
	stats.Parent = player
	setBladeCount(player, Config.Blades.StartCount)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end
