--!nonstrict
-- Per-player stats, coins and kills. Source of truth for everything upgrades change.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local Maid = require(Shared.Maid)
local Remotes = require(Shared.Remotes)
local Upgrades = require(Shared.Upgrades)

type PlayerState = {
	stats: Upgrades.Stats,
	coins: number,
	kills: number,
	maid: any,
	values: { Coins: IntValue, Kills: IntValue, Wave: IntValue },
}

local PlayerStatsService = {}

local states: { [Player]: PlayerState } = {}

local function createLeaderstats(player: Player): { Coins: IntValue, Kills: IntValue, Wave: IntValue }
	local folder = player:FindFirstChild("leaderstats")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end

	local function value(name: string): IntValue
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing
		end
		local intValue = Instance.new("IntValue")
		intValue.Name = name
		intValue.Value = 0
		intValue.Parent = folder
		return intValue
	end

	return { Coins = value("Coins"), Kills = value("Kills"), Wave = value("Wave") }
end

local function getState(player: Player): PlayerState
	local state = states[player]
	if state == nil then
		state = {
			stats = Upgrades.newStats(),
			coins = 0,
			kills = 0,
			maid = Maid.new(),
			values = createLeaderstats(player),
		}
		state.values.Wave.Value = 1
		states[player] = state
	end
	return state
end

function PlayerStatsService.getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function PlayerStatsService.getRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function PlayerStatsService.isAlive(player: Player): boolean
	if player.Parent ~= Players then
		return false
	end
	local humanoid = PlayerStatsService.getHumanoid(player)
	return humanoid ~= nil and humanoid.Health > 0 and PlayerStatsService.getRoot(player) ~= nil
end

function PlayerStatsService.get(player: Player): Upgrades.Stats
	return getState(player).stats
end

function PlayerStatsService.getCoins(player: Player): number
	return getState(player).coins
end

local function publishAttributes(player: Player, stats: Upgrades.Stats)
	for _, key in Config.VisualAttributes do
		player:SetAttribute(key, stats[key])
	end
end

local function pushToClient(player: Player)
	local state = getState(player)
	Remotes.get("StatsChanged"):FireClient(player, table.clone(state.stats), state.coins)
end

local function applyToCharacter(player: Player, healFull: boolean)
	local humanoid = PlayerStatsService.getHumanoid(player)
	if humanoid == nil then
		return
	end
	local stats = getState(player).stats
	humanoid.MaxHealth = stats.MaxHealth
	humanoid.WalkSpeed = stats.WalkSpeed
	if healFull then
		humanoid.Health = stats.MaxHealth
	end
end

local function refresh(player: Player, healFull: boolean)
	local state = getState(player)
	publishAttributes(player, state.stats)
	applyToCharacter(player, healFull)
	pushToClient(player)
end

function PlayerStatsService.addCoins(player: Player, amount: number, reason: string)
	if amount == 0 then
		return
	end
	local state = getState(player)
	state.coins = math.max(0, state.coins + amount)
	state.values.Coins.Value = state.coins
	pushToClient(player)
	if reason ~= "zombie_kill" then
		Log.info("Coins", player.Name, amount, reason)
	end
end

function PlayerStatsService.spend(player: Player, amount: number, reason: string): boolean
	local state = getState(player)
	if amount < 0 or state.coins < amount then
		return false
	end
	state.coins -= amount
	state.values.Coins.Value = state.coins
	pushToClient(player)
	Log.info("Coins", player.Name, -amount, reason)
	return true
end

function PlayerStatsService.applyUpgrade(player: Player, upgrade: Upgrades.Upgrade)
	local state = getState(player)
	local oldMax = state.stats.MaxHealth
	upgrade.apply(state.stats)
	refresh(player, false)

	local gained = state.stats.MaxHealth - oldMax
	if gained > 0 then
		PlayerStatsService.heal(player, gained)
	end
end

function PlayerStatsService.heal(player: Player, amount: number)
	local humanoid = PlayerStatsService.getHumanoid(player)
	if humanoid == nil or humanoid.Health <= 0 or amount <= 0 then
		return
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
end

function PlayerStatsService.addKill(player: Player)
	local state = getState(player)
	state.kills += 1
	state.values.Kills.Value = state.kills
end

function PlayerStatsService.setWaveReached(wave: number)
	for _, state in states do
		state.values.Wave.Value = wave
	end
end

function PlayerStatsService.sendTo(player: Player)
	pushToClient(player)
end

-- New run: everyone back to base stats, no coins, no kills. Characters are reloaded by RoundService.
function PlayerStatsService.resetAll()
	for player, state in states do
		state.stats = Upgrades.newStats()
		state.coins = 0
		state.kills = 0
		state.values.Coins.Value = 0
		state.values.Kills.Value = 0
		state.values.Wave.Value = 1
		refresh(player, false)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or player.Character ~= character then
		return
	end
	applyToCharacter(player, true)
	pushToClient(player)
end

local function track(player: Player)
	local state = getState(player)
	state.maid:Give(player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, player, character)
	end))
	publishAttributes(player, state.stats)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function untrack(player: Player)
	local state = states[player]
	if state then
		state.maid:Clean()
		states[player] = nil
	end
end

function PlayerStatsService.init()
	Log.info("PlayerStatsService", "init")
end

function PlayerStatsService.start()
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(untrack)
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Remotes.get("ClientReady").OnServerEvent:Connect(function(player: Player)
		if states[player] then
			pushToClient(player)
		end
	end)
end

return PlayerStatsService
