-- All tunable numbers live here.
local Config = {}

Config.Blades = {
	StartCount = 2,
	OrbitRadius = 7, -- studs from the character's root
	OrbitSpeed = math.rad(180), -- radians/sec (one lap per 2s)
	Height = 0, -- studs above root part
	BobAmplitude = 0.6, -- vertical wobble, studs
	BobSpeed = 3, -- radians/sec
	Size = Vector3.new(0.4, 1.2, 3.5),
	Color = Color3.fromRGB(0, 255, 255),
	Material = Enum.Material.Neon,
	SpinSpeed = math.rad(720), -- each blade spinning around its own axis
	TrailLifetime = 0.35,
	TrailWidth = 0.9,
	LightBrightness = 2,
	LightRange = 10,
}

Config.Zombies = {
	Health = 60,
	BladeDamage = 20, -- per blade hit
	HitRadius = 4, -- studs from blade center to zombie root
	HitCooldown = 0.5, -- seconds before the same blade can hit the same zombie again
	WalkSpeed = 10,
	SpawnInterval = 1.5, -- seconds between spawns
	MaxAlive = 25,
	ArenaHalfSize = 88, -- spawn ring sits on this square edge (walls' inner face is at 90)
	Size = Vector3.new(2, 5, 1.5),
	Color = Color3.fromRGB(90, 140, 70),
	RetargetInterval = 0.25, -- seconds between nearest-player re-targeting
	ContactRadius = 3.5, -- studs, zombie root to player root, for contact damage
	ContactDps = 10, -- damage per second to a player while touching a zombie
}

Config.Waves = {
	FirstWaveCount = 8,
	CountPerWave = 4, -- extra zombies each wave
	HealthMultiplierPerWave = 1.10, -- compounds: wave N health = Health * 1.10^(N-1)
	BreakSeconds = 20,
}

Config.Rewards = {
	CoinsPerKill = 10,
}

Config.Player = {
	BaseMaxHealth = 100,
}

-- Between-wave shop. Offers are rolled per player; weighted by rarity.
Config.Shop = {
	OfferCount = 3,
	RerollCost = 10, -- coins; rerolls all offers (including sold slots)
	RarityWeights = { Common = 70, Rare = 30, Epic = 10 },
	RarityColors = {
		Common = Color3.fromRGB(160, 165, 175),
		Rare = Color3.fromRGB(70, 140, 255),
		Epic = Color3.fromRGB(170, 90, 235),
	},
}

-- HUD / shop UI palette (client only).
Config.UI = {
	Panel = Color3.fromRGB(14, 20, 40), -- dark navy
	PanelLight = Color3.fromRGB(24, 33, 62),
	Accent = Color3.fromRGB(0, 255, 255), -- cyan, matches blades
	Coins = Color3.fromRGB(255, 205, 60), -- gold
	Text = Color3.fromRGB(235, 240, 250),
	TextDim = Color3.fromRGB(140, 150, 175),
	HealthGood = Color3.fromRGB(70, 220, 130),
	HealthLow = Color3.fromRGB(235, 70, 70),
	Corner = 12,
}

-- Floating numbers / death burst / coin popup (client only, cosmetic).
Config.Fx = {
	DamageColor = Color3.fromRGB(255, 255, 255),
	KillColor = Color3.fromRGB(255, 120, 60), -- damage number of the killing blow
	NumberLifetime = 0.7,
	NumberRise = 4, -- studs
	NumberScatter = 1.5, -- random horizontal offset, studs
	CoinLifetime = 1.0,
	CoinRise = 5,
	CoinHeight = 4, -- studs above the zombie's death position
	BurstColor = Color3.fromRGB(120, 200, 80), -- zombie gibs
	BurstSparkColor = Color3.fromRGB(0, 255, 255), -- matches blades
	BurstCount = 24,
	BurstLifetime = 0.6,
}

-- Stackable upgrades. Amount meaning depends on the Id (see shared/Upgrades.lua).
Config.Upgrades = {
	{ Id = "Blade", Name = "+1 Blade", Description = "Adds one orbiting blade.", Rarity = "Rare", Cost = 60, Amount = 1 },
	{ Id = "Damage", Name = "Sharper Blades", Description = "+25% blade damage.", Rarity = "Common", Cost = 30, Amount = 0.25 },
	{ Id = "Spin", Name = "Faster Spin", Description = "+20% blade spin speed.", Rarity = "Common", Cost = 30, Amount = 0.2 },
	{ Id = "Reach", Name = "Longer Reach", Description = "+2 studs blade orbit radius.", Rarity = "Common", Cost = 35, Amount = 2 },
	{ Id = "Vitality", Name = "Vitality", Description = "+25 max HP.", Rarity = "Common", Cost = 25, Amount = 25 },
	{ Id = "Vampiric", Name = "Vampiric", Description = "Heal 2 HP per kill.", Rarity = "Rare", Cost = 55, Amount = 2 },
	{ Id = "Greed", Name = "Greed", Description = "+25% coins from kills.", Rarity = "Rare", Cost = 50, Amount = 0.25 },
	{ Id = "TwinSpin", Name = "Twin Spin", Description = "Adds two orbiting blades.", Rarity = "Epic", Cost = 120, Amount = 2 },
}

return Config
