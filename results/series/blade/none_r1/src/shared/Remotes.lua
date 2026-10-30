-- Every RemoteEvent in the game is declared here and nowhere else.
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"PurchaseUpgrade", -- client -> server: offer slot (1..OfferCount)
	"RerollOffers", -- client -> server
	"ZombieHit", -- server -> all clients: world position, damage dealt
	"ZombieDied", -- server -> all clients: world position
	"CoinReward", -- server -> killer: world position, coins earned
}

local FOLDER_NAME = "Remotes"
local Remotes = {}

local folder = script:FindFirstChild(FOLDER_NAME)
if RunService:IsServer() then
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = script
	end
	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
else
	folder = folder or script:WaitForChild(FOLDER_NAME)
end

for _, name in EVENT_NAMES do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
