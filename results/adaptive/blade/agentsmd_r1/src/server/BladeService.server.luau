-- Server owns each player's blade/upgrade stats (replicated via Player attributes; ShopService changes them).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local function applyMaxHealth(player: Player, healBy: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = Config.Player.BaseMaxHealth + player:GetAttribute("MaxHealthBonus")
		if humanoid.Health > 0 then
			humanoid.Health = math.min(humanoid.Health + healBy, humanoid.MaxHealth)
		end
	end
end

local function init(player: Player)
	player:SetAttribute("BladeCount", Config.Blades.StartCount)
	for name, value in Config.Shop.Defaults do
		player:SetAttribute(name, value)
	end

	local lastBonus = 0
	player:GetAttributeChangedSignal("MaxHealthBonus"):Connect(function()
		local bonus = player:GetAttribute("MaxHealthBonus")
		applyMaxHealth(player, bonus - lastBonus) -- Vitality also heals by the amount gained
		lastBonus = bonus
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		applyMaxHealth(player, math.huge) -- respawn at full (upgraded) health
	end)
end

Players.PlayerAdded:Connect(init)
for _, player in Players:GetPlayers() do
	init(player)
end
