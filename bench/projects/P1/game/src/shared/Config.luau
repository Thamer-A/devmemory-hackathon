--!strict
-- Central tunables for CoinRush. Services and controllers read from here
-- instead of defining their own numbers.

local Config = {
	-- Economy
	StartingCoins = 50,
	MaxCoins = 100000,
	CoinPickupValue = 5,
	RoundRewardCoins = 25,
	KillReward = 10,
	PurchaseCooldown = 0.5,

	-- Coins in the world
	CoinSpawnInterval = 3,
	MaxCoinsInWorld = 40,
	CoinZoneName = "CoinZone",
	CoinSize = Vector3.new(2, 0.3, 2),
	CoinHeightOffset = 2,
	CoinSpinSpeed = 2,
	CoinColor = Color3.fromRGB(255, 205, 40),

	-- Rounds
	RoundLength = 180,
	IntermissionLength = 20,

	-- Persistence
	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 60,
	DataLoadRetries = 4,
	DataRetryDelay = 2,

	-- Player
	BaseWalkSpeed = 16,
	PlayerAttackDamage = 20,
	PlayerAttackCooldown = 0.6,

	-- Enemies
	Enemies = {
		Grunt = { health = 50, speed = 14, damage = 12 },
		Brute = { health = 200, speed = 8, damage = 25 },
	},
	EnemySpawnInterval = 6,
	MaxEnemies = 8,
	EnemyAiInterval = 0.25,
	EnemyHitCooldown = 1,
	EnemySpawnZoneName = "EnemySpawns",
	BruteSpawnChance = 0.25,
	EnemyPlaceholderSize = Vector3.new(2, 5, 2),
	EnemyPlaceholderColors = {
		Grunt = Color3.fromRGB(90, 160, 80),
		Brute = Color3.fromRGB(170, 60, 60),
	},

	-- Admin
	Admins = { 1234567, 7654321 },
	AdminPrefix = "/",
}

return Config
