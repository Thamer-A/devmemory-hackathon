local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local MathUtil = require(Shared.MathUtil)

local CurrencyService = require(script.Parent.CurrencyService)
local RoundService = require(script.Parent.RoundService)

local CoinPickupService = {}

local coinFolder: Folder? = nil
local coinCount = 0
local spawning = false

local function getFolder(): Folder
	if coinFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Coins"
		folder.Parent = workspace
		coinFolder = folder
	end
	return coinFolder :: Folder
end

local function playPickupSound(position: Vector3)
	local soundId = Assets.get("CoinSound")
	if soundId == nil then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Parent = anchor
	sound:Play()

	sound.Ended:Once(function()
		anchor:Destroy()
	end)
	-- Safety net in case the sound never finishes loading.
	task.delay(sound.TimeLength + Config.CoinSpawnInterval, function()
		if anchor.Parent then
			anchor:Destroy()
		end
	end)
end

local function spawnPosition(): Vector3?
	local zone = workspace:FindFirstChild(Config.CoinZoneName)
	if zone == nil or not zone:IsA("BasePart") then
		return nil
	end
	local point = MathUtil.randomPointInPart(zone)
	return point + Vector3.new(0, Config.CoinHeightOffset, 0)
end

local function createCoin(position: Vector3): Part
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Config.CoinSize
	coin.Color = Config.CoinColor
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	coin.Parent = getFolder()
	return coin
end

local function removeCoin(coin: Part)
	if coin.Parent then
		coin:Destroy()
		coinCount = math.max(0, coinCount - 1)
	end
end

local function spawnCoin()
	local position = spawnPosition()
	if position == nil then
		Log.warn("CoinPickupService", "coin zone missing:", Config.CoinZoneName)
		return
	end

	local coin = createCoin(position)
	coinCount += 1

	local collected = false
	coin.Touched:Connect(function(other)
		if collected then
			return
		end
		local player = Players:GetPlayerFromCharacter(other.Parent)
		if player == nil then
			return
		end
		collected = true
		CurrencyService.add(player, Config.CoinPickupValue, "pickup")
		playPickupSound(coin.Position)
		removeCoin(coin)
	end)

	coin.AncestryChanged:Connect(function(_, parent)
		if parent == nil and not collected then
			collected = true
			coinCount = math.max(0, coinCount - 1)
		end
	end)
end

local function clearCoins()
	if coinFolder then
		coinFolder:ClearAllChildren()
	end
	coinCount = 0
end

local function startSpawning()
	if spawning then
		return
	end
	spawning = true

	task.spawn(function()
		while RoundService.isPlaying() do
			if coinCount < Config.MaxCoinsInWorld then
				spawnCoin()
			end
			task.wait(Config.CoinSpawnInterval)
		end
		spawning = false
	end)
end

local function startSpinning()
	RunService.Heartbeat:Connect(function(dt)
		if coinFolder == nil then
			return
		end
		local step = CFrame.Angles(0, Config.CoinSpinSpeed * dt, 0)
		for _, coin in coinFolder:GetChildren() do
			if coin:IsA("BasePart") then
				coin.CFrame = coin.CFrame * step
			end
		end
	end)
end

function CoinPickupService.getCoinCount(): number
	return coinCount
end

function CoinPickupService.init()
	RoundService.stateChanged:Connect(function(state)
		if state == "Playing" then
			startSpawning()
		else
			clearCoins()
		end
	end)
end

function CoinPickupService.start()
	getFolder()
	startSpinning()
end

return CoinPickupService
