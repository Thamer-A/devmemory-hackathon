-- Every RemoteEvent in the game is declared here. Add names to the list.
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"ShopUpdate", -- server -> client: current offers / shop open state
	"ShopSync", -- client -> server: request the current ShopUpdate
	"BuyOffer", -- client -> server: offer slot index
	"RerollOffers", -- client -> server
	"CombatFx", -- server -> client: (kind "Hit" | "Kill" | "Coins", position, amount)
}

-- Must differ from this ModuleScript's name ("Remotes"), or the client's WaitForChild
-- finds the module instead of the folder and never sees any event.
local FOLDER_NAME = "RemoteEvents"
local container

if RunService:IsServer() then
	container = Instance.new("Folder")
	container.Name = FOLDER_NAME
	for _, name in EVENT_NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = container
	end
	container.Parent = script.Parent
else
	container = script.Parent:WaitForChild(FOLDER_NAME)
end

local Remotes = {}
for _, name in EVENT_NAMES do
	Remotes[name] = container:WaitForChild(name)
end

return Remotes
