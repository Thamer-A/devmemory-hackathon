local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local Maid = require(Shared.Maid)
local MathUtil = require(Shared.MathUtil)
local Remotes = require(Shared.Remotes)

local CurrencyService = require(script.Parent.CurrencyService)
local DataService = require(script.Parent.DataService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local RoundService = require(script.Parent.RoundService)

local DAMAGE = { Grunt = 10, Brute = 25 }

local EnemyService = {}
EnemyService.DAMAGE = DAMAGE

local ENEMY_TAG = "CoinRushEnemy"
local KINDS = { "Grunt", "Brute" }

type EnemyRecord = {
	model: Model,
	kind: string,
	humanoid: Humanoid,
	root: BasePart,
	lastHit: { [Player]: number },
	lastAttacker: Player?,
	lastPlayerStrike: { [Player]: number },
	maid: any,
}

local enemies: { [Model]: EnemyRecord } = {}
local enemyFolder: Folder? = nil
local spawnLoopActive = false

local function getFolder(): Folder
	if enemyFolder == nil then
		local folder = Instance.new("Folder")
		folder.Name = "Enemies"
		folder.Parent = workspace
		enemyFolder = folder
	end
	return enemyFolder :: Folder
end

local function buildPlaceholder(kind: string): Model
	local model = Instance.new("Model")
	model.Name = kind

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Config.EnemyPlaceholderSize
	root.Color = Config.EnemyPlaceholderColors[kind]
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

local function loadModel(kind: string): Model
	local assetId = Assets.getNumericId(kind .. "Model")
	if assetId ~= nil then
		local ok, result = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if ok and result then
			local inner = result:FindFirstChildWhichIsA("Model")
			if inner and inner:FindFirstChildOfClass("Humanoid") and inner:FindFirstChild("HumanoidRootPart") then
				inner.Parent = nil
				result:Destroy()
				inner.Name = kind
				inner.PrimaryPart = inner:FindFirstChild("HumanoidRootPart") :: BasePart
				return inner
			end
			result:Destroy()
		else
			Log.warn("EnemyService", "could not load model for", kind, result)
		end
	end
	return buildPlaceholder(kind)
end

local function pickSpawnPosition(): Vector3
	local zone = workspace:FindFirstChild(Config.EnemySpawnZoneName)
	if zone then
		local parts = {}
		for _, child in zone:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(parts, child)
			end
		end
		if #parts > 0 then
			return MathUtil.randomPointInPart(parts[math.random(1, #parts)])
		elseif zone:IsA("BasePart") then
			return MathUtil.randomPointInPart(zone)
		end
	end
	return workspace:GetPivot().Position
end

local function nearestPlayerRoot(position: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = root :: BasePart
			end
		end
	end
	return best
end

local function creditKill(record: EnemyRecord)
	local attacker = record.lastAttacker
	if attacker == nil or attacker.Parent ~= Players then
		return
	end
	CurrencyService.add(attacker, Config.KillReward, "enemy_kill")
	local kills = DataService.incrementStat(attacker, "kills")
	if kills then
		LeaderboardService.set(attacker, "Kills", kills)
	end
end

local function removeEnemy(model: Model)
	local record = enemies[model]
	if record == nil then
		return
	end
	enemies[model] = nil
	record.maid:Clean()
	model:Destroy()
end

local function onEnemyTouched(record: EnemyRecord, other: BasePart)
	local character = other.Parent
	if character == nil then
		return
	end

	-- A player's tool striking the enemy
	local tool = other:FindFirstAncestorWhichIsA("Tool")
	if tool and tool.Parent then
		local owner = Players:GetPlayerFromCharacter(tool.Parent)
		if owner then
			local now = os.clock()
			local last = record.lastPlayerStrike[owner]
			if last == nil or now - last >= Config.PlayerAttackCooldown then
				record.lastPlayerStrike[owner] = now
				record.lastAttacker = owner
				record.humanoid:TakeDamage(Config.PlayerAttackDamage)
			end
			return
		end
	end

	local player = Players:GetPlayerFromCharacter(character)
	if player == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local last = record.lastHit[player]
	if last ~= nil and now - last < Config.EnemyHitCooldown then
		return
	end
	record.lastHit[player] = now

	local damage = DAMAGE[record.kind]
	humanoid:TakeDamage(damage)
	Remotes.get("EnemyHit"):FireClient(player, record.kind, damage)
end

local function spawnEnemy(kind: string)
	local stats = Config.Enemies[kind]
	if stats == nil then
		Log.warn("EnemyService", "no stats for enemy kind", kind)
		return
	end

	local model = loadModel(kind)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model.PrimaryPart :: BasePart

	humanoid.MaxHealth = stats.health
	humanoid.Health = stats.health
	humanoid.WalkSpeed = stats.speed

	model:PivotTo(CFrame.new(pickSpawnPosition()))
	model:SetAttribute("EnemyKind", kind)
	model.Parent = getFolder()
	root:SetNetworkOwner(nil)

	local record: EnemyRecord = {
		model = model,
		kind = kind,
		humanoid = humanoid,
		root = root,
		lastHit = {},
		lastAttacker = nil,
		lastPlayerStrike = {},
		maid = Maid.new(),
	}
	enemies[model] = record

	record.maid:Give(root.Touched:Connect(function(other)
		onEnemyTouched(record, other)
	end))

	record.maid:Give(humanoid.Died:Connect(function()
		creditKill(record)
		task.defer(removeEnemy, model)
	end))

	game:GetService("CollectionService"):AddTag(model, ENEMY_TAG)
end

local function clearEnemies()
	for model in table.clone(enemies) do
		removeEnemy(model)
	end
end

local function countEnemies(): number
	local count = 0
	for _ in enemies do
		count += 1
	end
	return count
end

local function chooseKind(): string
	if math.random() < Config.BruteSpawnChance then
		return KINDS[2]
	end
	return KINDS[1]
end

local function aiStep()
	for _, record in enemies do
		local target = nearestPlayerRoot(record.root.Position)
		if target then
			record.humanoid:MoveTo(target.Position)
		end
	end
end

local function spawnLoop()
	if spawnLoopActive then
		return
	end
	spawnLoopActive = true

	task.spawn(function()
		local sinceSpawn = 0
		while RoundService.isPlaying() do
			task.wait(Config.EnemyAiInterval)
			sinceSpawn += Config.EnemyAiInterval

			if sinceSpawn >= Config.EnemySpawnInterval and countEnemies() < Config.MaxEnemies then
				sinceSpawn = 0
				spawnEnemy(chooseKind())
			end
			aiStep()
		end
		spawnLoopActive = false
	end)
end

function EnemyService.getEnemyCount(): number
	return countEnemies()
end

function EnemyService.init()
	RoundService.stateChanged:Connect(function(state)
		if state == "Playing" then
			spawnLoop()
		else
			clearEnemies()
		end
	end)
end

return EnemyService
