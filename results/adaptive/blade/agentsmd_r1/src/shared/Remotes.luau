-- Single home for every RemoteEvent. Add names to the list; get them with Remotes.get(name).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES: { string } = {
	"ShopBuy", -- client -> server: (slot: number) buy the offer in that slot
	"ShopReroll", -- client -> server: reroll all offers
	"DamageNumber", -- server -> all clients: (position: Vector3, damage: number) a blade hit landed
	"ZombieDeathFx", -- server -> all clients: (position: Vector3) a zombie died
	"CoinPopup", -- server -> killer only: (position: Vector3, coins: number)
}

local Remotes = {}

local folder: Folder
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

function Remotes.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
