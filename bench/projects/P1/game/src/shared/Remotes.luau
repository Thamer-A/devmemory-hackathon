--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local Remotes = {}

local defined: { [string]: RemoteEvent } = {}

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end
	if RunService:IsServer() then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.define(name: string): RemoteEvent
	if defined[name] then
		return defined[name]
	end

	local folder = getFolder()
	local remote: RemoteEvent
	if RunService:IsServer() then
		local found = folder:FindFirstChild(name)
		if found then
			remote = found :: RemoteEvent
		else
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	else
		remote = folder:WaitForChild(name) :: RemoteEvent
	end

	defined[name] = remote
	return remote
end

function Remotes.get(name: string): RemoteEvent
	local remote = defined[name]
	if not remote then
		error(string.format("Remote '%s' is not defined", name), 2)
	end
	return remote
end

Remotes.define("PurchaseItem")
Remotes.define("CoinsChanged")
Remotes.define("RoundState")
Remotes.define("EquipItem")
Remotes.define("InventoryChanged")
Remotes.define("EnemyHit")

return Remotes
