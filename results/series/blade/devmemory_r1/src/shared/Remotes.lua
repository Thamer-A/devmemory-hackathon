-- Single home for every RemoteEvent. Server creates them, client waits for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"BladeCountChanged", -- server -> clients: (userId: number, count: number)
	"ShopUpdate", -- server -> client: ({ [slot]: upgradeId | false }) false = already bought
	"ShopBuy", -- client -> server: (slot: number)
	"ShopReroll", -- client -> server
	"ZombieHit", -- server -> clients: (position: Vector3, damage: number)
	"ZombieKilled", -- server -> clients: (position: Vector3)
	"CoinsEarned", -- server -> killer: (position: Vector3, amount: number)
}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in NAMES do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
