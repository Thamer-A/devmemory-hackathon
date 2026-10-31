-- Creates the leaderstats (Coins, Kills) shown on the default Roblox leaderboard.
local Players = game:GetService("Players")

local function setup(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	for _, name in { "Coins", "Kills" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end

	stats.Parent = player
end

Players.PlayerAdded:Connect(setup)
for _, player in Players:GetPlayers() do
	setup(player)
end
