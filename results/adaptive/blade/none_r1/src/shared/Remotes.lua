-- Every RemoteEvent in the game is declared here. Add names to the list;
-- the server creates them, clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"ShopState", -- server -> client: { Open = bool, Offers = { [slot] = upgradeId | false } }
	"ShopBuy", -- client -> server: slot number
	"ShopReroll", -- client -> server
	"ShopSync", -- client -> server: ask for the current ShopState (sent once the UI is ready)
	"GameOver", -- server -> client: { Wave = wave reached, Restart = seconds until wave 1 begins }
}

local FOLDER_NAME = "Remotes"
local Remotes = {}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	for _, name in EVENT_NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

for _, name in EVENT_NAMES do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
