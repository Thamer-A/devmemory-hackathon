--!strict
-- All gameplay tunables live here. Services and controllers must not hard-code numbers.

local Config = {
	-- Arena ------------------------------------------------------------
	ArenaCenter = Vector3.new(0, 0, 0),
	SpawnRingRadius = 70, -- used when Workspace.ZombieSpawns is missing
	GroundProbeHeight = 150, -- raycast start height above the spawn point
	VoidY = -150, -- zombies below this die (fell out of the world)

	-- Round flow -------------------------------------------------------
	StartDelay = 4, -- seconds between first player spawning and wave 1
	ShopDuration = 20,
	WaveBaseDuration = 40,
	WaveDurationPerWave = 2,
	WaveMaxDuration = 70,
	SpawnWindowFraction = 0.65, -- fraction of the wave over which zombies spawn
	GameOverDuration = 5,
	RoundTickRate = 0.2,
	StateBroadcastInterval = 1,

	-- Zombies ----------------------------------------------------------
	ZombieBaseCount = 6,
	ZombiePerWave = 3, -- count = base + perWave * wave
	MaxZombiesAlive = 40,
	ZombieBaseHealth = 40,
	ZombieHealthPerWave = 12,
	ZombieBaseSpeed = 9,
	ZombieSpeedPerWave = 0.6,
	ZombieMaxSpeed = 15,
	ZombieBaseDps = 10, -- damage per second while in contact
	ZombieDpsPerWave = 1.5,
	ZombieStopDistance = 4, -- minimum distance zombies hold from a player
	ZombieStopInset = 2.5, -- zombies hold this far inside the blade ring (keeps them in the sweep)
	ZombieContactRange = 2, -- extra reach beyond the hold distance in which they can hurt
	ZombieRetargetInterval = 0.4,
	ZombieFadeDelay = 1.2,
	ZombieFadeTime = 0.8,
	ZombieSpawnLift = 0.5, -- studs above the computed ground height
	ZombieWalkAnimationId = "rbxassetid://507777826", -- default R15 walk
	ZombieFolderName = "Zombies",
	ZombieSpawnsName = "ZombieSpawns",
	ZombieTemplateName = "ZombieTemplate",
	ZombieSkinColor = Color3.fromHex("6aa84f"),

	-- Blades -----------------------------------------------------------
	DamageTickRate = 0.1,
	BladeHitCooldown = 0.35, -- per zombie, per player
	ZombieBodyMargin = 2, -- added to the blade hit radius to account for zombie size
	BladeHeightOffset = 0, -- blades orbit at root height + this

	-- Economy ----------------------------------------------------------
	CoinsPerKill = 5,
	CoinsPerWavePerKill = 1, -- extra coins per kill for each wave beyond the first
	RerollBaseCost = 10,
	RerollCostStep = 5,
	ShopOfferCount = 3,
	PriceWaveScale = 0.08, -- price multiplier gains this much per wave beyond the first
	RemoteMinInterval = 0.1, -- per-player rate limit for client -> server remotes

	-- Player base stats (copied per player; upgrades mutate the copy) -----
	BasePlayer = {
		BladeCount = 2,
		BladeDamage = 20,
		BladeRadius = 7,
		BladeSpinSpeed = 4, -- radians per second
		BladeHitRadius = 2.5,
		BladeScale = 1,
		MaxHealth = 100,
		WalkSpeed = 16,
		Lifesteal = 0, -- HP healed per kill
		CoinBonus = 0, -- fraction, 0.25 = +25 percent
	},

	-- Upgrade rarity roll weights ---------------------------------------
	RarityWeights = {
		Common = 60,
		Rare = 30,
		Epic = 10,
	},

	-- Player attributes mirrored for client visuals -----------------------
	VisualAttributes = { "BladeCount", "BladeRadius", "BladeSpinSpeed", "BladeHitRadius", "BladeScale" },

	-- Camera -----------------------------------------------------------
	CameraMinZoom = 25,
	CameraMaxZoom = 45,

	-- Colors -----------------------------------------------------------
	Colors = {
		Panel = Color3.fromHex("141824"),
		PanelLight = Color3.fromHex("1f2535"),
		Accent = Color3.fromHex("22d3ee"),
		AccentOther = Color3.fromHex("ff7ad9"),
		Gold = Color3.fromHex("fbbf24"),
		Good = Color3.fromHex("34d399"),
		Warn = Color3.fromHex("facc15"),
		Danger = Color3.fromHex("ef4444"),
		Text = Color3.fromHex("f1f5f9"),
		TextDim = Color3.fromHex("94a3b8"),
		Common = Color3.fromHex("9aa4b2"),
		Rare = Color3.fromHex("4ea8ff"),
		Epic = Color3.fromHex("b26bff"),
	},
}

return Config
