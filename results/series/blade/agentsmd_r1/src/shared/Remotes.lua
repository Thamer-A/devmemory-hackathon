-- Single home for every RemoteEvent. Add a name to the list to create it.
-- Server creates them on first require; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	-- blade count / shop state replicate via attributes; these are client -> server requests only
	"BuyOffer", -- (slot: number)
	"RerollOffers",
	-- server -> client cosmetic effects (no gameplay state)
	"HitFx", -- (position: Vector3, damage: number, killed: boolean) to all clients
	"CoinFx", -- (position: Vector3, coins: number) to the killer only
}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENT_NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}
for _, name in EVENT_NAMES do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
