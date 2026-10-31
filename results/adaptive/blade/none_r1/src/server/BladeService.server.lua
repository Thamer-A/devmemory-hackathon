local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
require(Shared:WaitForChild("Remotes")) -- creates the RemoteEvents

-- Server owns the blade count; clients render the orbit from this attribute.
local function initPlayer(player)
	player:SetAttribute(Config.Attributes.BladeCount, Config.Blades.StartCount)
end

Players.PlayerAdded:Connect(initPlayer)
for _, player in Players:GetPlayers() do
	initPlayer(player)
end
