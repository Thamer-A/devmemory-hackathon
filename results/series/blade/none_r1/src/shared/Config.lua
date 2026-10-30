-- All tunable numbers live here.
local Config = {}

Config.Blades = {
	StartCount = 2,
	OrbitRadius = 7, -- studs from the character's root
	OrbitSpeed = 2.6, -- radians per second
	HeightOffset = 0.5, -- studs above the root part
	BobAmplitude = 0.6, -- vertical wobble, studs
	BobSpeed = 3, -- radians per second
	Size = Vector3.new(0.25, 1.4, 4),
	Color = Color3.fromRGB(0, 255, 255),
	Material = Enum.Material.Neon,
	LightBrightness = 2,
	LightRange = 9,
	TrailLifetime = 0.35,
	TrailWidthScale = 1,
	CountAttribute = "BladeCount", -- Player attribute set by the server
}

Config.Zombies = {
	MaxAlive = 25,
	SpawnInterval = 1.5, -- seconds between spawn attempts
	SpawnInset = 6, -- studs inside the arena edge
	ArenaHalfSize = 90, -- floor is 180x180
	Health = 60,
	BladeDamage = 20,
	HitRadius = 3.5, -- studs from blade centre to zombie root
	HitCooldown = 0.5, -- seconds before the same blade can hit the same zombie again
	WalkSpeed = 10,
	RetargetInterval = 0.25, -- seconds between chase target updates
	CoinsPerKill = 10,
	ContactRadius = 3.5, -- studs between zombie root and player root to deal contact damage
	ContactDps = 10, -- damage per second to a player touching a zombie
	Color = Color3.fromRGB(88, 140, 78),
	HeadColor = Color3.fromRGB(110, 165, 100),
}

Config.Waves = {
	FirstWaveCount = 8,
	CountPerWave = 4, -- extra zombies added each wave
	BreakSeconds = 20,
	HealthGrowth = 0.10, -- compounding health increase per wave
	WaveAttribute = "Wave", -- workspace attribute holding the current wave number
	BreakAttribute = "WaveBreakEndsAt", -- workspace server time the break ends (0 when none)
	ZombiesLeftAttribute = "ZombiesLeft", -- workspace attribute: zombies alive plus still to spawn
}

-- Upgrade shop, open during the break between waves.
-- Amount is the effect per level (levels stack additively):
--   Damage/Spin/Greed: fraction added to the multiplier, Reach: studs, Vitality: max HP,
--   Vampiric: HP healed per kill, Blade/TwinSpin: blades added.
Config.Shop = {
	OfferCount = 3,
	RerollCost = 10,
	OfferAttribute = "ShopOffer", -- Player attribute prefix + slot: offered upgrade id ("" = shop closed)
	SoldAttribute = "ShopSold", -- Player attribute prefix + slot: true once that offer is bought
	LevelAttribute = "Upgrade_", -- Player attribute prefix + upgrade id: levels owned
	RarityWeights = { Common = 3, Rare = 2, Epic = 1 }, -- relative chance of a rarity filling an offer slot
	RarityColors = {
		Common = Color3.fromRGB(190, 190, 200),
		Rare = Color3.fromRGB(80, 160, 255),
		Epic = Color3.fromRGB(170, 90, 255),
	},
	Upgrades = {
		{ Id = "Blade", Name = "+1 Blade", Description = "Adds one more orbiting blade.", Rarity = "Rare", Cost = 60, Amount = 1 },
		{ Id = "Damage", Name = "Sharper Blades", Description = "+25% blade damage.", Rarity = "Common", Cost = 30, Amount = 0.25 },
		{ Id = "Spin", Name = "Faster Spin", Description = "+20% spin speed.", Rarity = "Common", Cost = 30, Amount = 0.2 },
		{ Id = "Reach", Name = "Longer Reach", Description = "+2 studs orbit reach.", Rarity = "Common", Cost = 35, Amount = 2 },
		{ Id = "Vitality", Name = "Vitality", Description = "+25 max HP.", Rarity = "Common", Cost = 25, Amount = 25 },
		{ Id = "Vampiric", Name = "Vampiric", Description = "Heal 2 HP per kill.", Rarity = "Rare", Cost = 55, Amount = 2 },
		{ Id = "Greed", Name = "Greed", Description = "+25% coins from kills.", Rarity = "Rare", Cost = 50, Amount = 0.25 },
		{ Id = "TwinSpin", Name = "Twin Spin", Description = "+2 orbiting blades.", Rarity = "Epic", Cost = 120, Amount = 2 },
	},
}

-- Combat feedback: damage numbers, death burst, coin popup.
Config.Effects = {
	DamageColor = Color3.fromRGB(255, 255, 255),
	DamageLifetime = 0.8, -- seconds a damage number floats before vanishing
	DamageRise = 3.5, -- studs the number floats upward
	DamageSpread = 1.5, -- random horizontal offset, studs
	CoinLifetime = 1.2,
	CoinRise = 5,
	BurstCount = 24,
	BurstLifetime = 0.7,
	BurstSpeed = 18, -- studs per second
	BurstColor = Color3.fromRGB(110, 190, 90),
}

-- Shared look for the HUD and shop.
Config.UI = {
	Panel = Color3.fromRGB(14, 20, 38), -- dark navy
	PanelLight = Color3.fromRGB(24, 33, 58),
	Accent = Color3.fromRGB(0, 230, 255), -- cyan
	Coin = Color3.fromRGB(255, 200, 40), -- gold
	Text = Color3.fromRGB(235, 242, 255),
	TextDim = Color3.fromRGB(140, 155, 185),
	Disabled = Color3.fromRGB(52, 60, 82),
	HealthHigh = Color3.fromRGB(70, 220, 120),
	HealthLow = Color3.fromRGB(235, 70, 70),
	CornerRadius = UDim.new(0, 12),
}

Config.Stats = {
	Folder = "leaderstats",
	Coins = "Coins",
	Kills = "Kills",
}

return Config
