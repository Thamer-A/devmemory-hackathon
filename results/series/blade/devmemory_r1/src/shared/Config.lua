local Config = {}

Config.Blades = {
	StartCount = 2,
	OrbitRadius = 7, -- studs
	OrbitSpeed = 2.5, -- radians per second
	HeightOffset = 0, -- studs above HumanoidRootPart
	BobAmplitude = 0.6,
	BobSpeed = 3,
	Size = Vector3.new(0.4, 1.2, 4),
	Color = Color3.fromRGB(0, 255, 255),
	Material = Enum.Material.Neon,
	TrailLifetime = 0.35,
	LightBrightness = 2,
	LightRange = 10,
	SpinSpeed = 8, -- radians per second around the blade's own axis
	FlashDuration = 0.4,
}

Config.Zombies = {
	Health = 60,
	BladeDamage = 20,
	HitRadius = 3.5, -- studs from blade center to zombie root
	HitCooldown = 0.5, -- seconds before the same blade can hit the same zombie again
	WalkSpeed = 10,
	SpawnInterval = 2, -- seconds
	MaxAlive = 25,
	ArenaHalfSize = 88, -- studs from center to the spawn edge
	CoinsPerKill = 10,
	CorpseLifetime = 0.5,
	Color = Color3.fromRGB(90, 140, 80),
	ContactDamagePerSecond = 10,
	ContactRadius = 4, -- studs from zombie root to player root
}

Config.Waves = {
	FirstWaveCount = 8,
	CountPerWave = 4, -- extra zombies each wave
	BreakDuration = 20, -- seconds between waves
	HealthGrowth = 0.1, -- zombie health multiplier increase per wave
}

Config.Effects = {
	PopupLifetime = 0.8, -- seconds a floating number stays up
	PopupRise = 4, -- studs a floating number drifts upward
	PopupSize = UDim2.fromOffset(120, 36),
	DamageColor = Color3.fromRGB(255, 255, 255),
	CoinColor = Color3.fromRGB(255, 205, 60),
	CoinPopupHeight = 5, -- studs above the kill position
	BurstCount = 24,
	BurstColor = Color3.fromRGB(120, 255, 120),
	BurstLifetime = 0.6,
	BurstSpeed = 18,
}

Config.Shop = {
	OffersPerPlayer = 3,
	RerollCost = 10,
	BaseMaxHealth = 100,
}

Config.Rarities = {
	Common = { Weight = 3, Color = Color3.fromRGB(170, 170, 170) },
	Rare = { Weight = 1, Color = Color3.fromRGB(70, 140, 255) },
	Epic = { Weight = 0.5, Color = Color3.fromRGB(165, 80, 235) },}

Config.Theme = {
	Panel = Color3.fromRGB(14, 20, 40), -- dark navy
	PanelLight = Color3.fromRGB(24, 33, 62),
	Accent = Color3.fromRGB(0, 230, 255), -- cyan
	Gold = Color3.fromRGB(255, 205, 60),
	Text = Color3.fromRGB(235, 242, 255),
	TextDim = Color3.fromRGB(150, 165, 195),
	Health = Color3.fromRGB(70, 220, 130),
	HealthLow = Color3.fromRGB(240, 70, 70),
	Font = Enum.Font.GothamBold,
	FontBody = Enum.Font.Gotham,
	CornerRadius = 12,
}

-- Every upgrade stacks. Amount's meaning depends on Id (see Upgrades.lua in the server folder).
Config.Upgrades = {
	{ Id = "Blade", Name = "+1 Blade", Description = "Adds another orbiting blade.", Rarity = "Rare", Cost = 60, Amount = 1 },
	{ Id = "Damage", Name = "Sharper Blades", Description = "+25% blade damage.", Rarity = "Common", Cost = 30, Amount = 0.25 },
	{ Id = "Spin", Name = "Faster Spin", Description = "+20% blade spin speed.", Rarity = "Common", Cost = 30, Amount = 0.2 },
	{ Id = "Reach", Name = "Longer Reach", Description = "+2 studs orbit radius.", Rarity = "Common", Cost = 35, Amount = 2 }, -- studs
	{ Id = "Vitality", Name = "Vitality", Description = "+25 max HP.", Rarity = "Common", Cost = 25, Amount = 25 },
	{ Id = "Vampiric", Name = "Vampiric", Description = "Heal 2 HP per kill.", Rarity = "Rare", Cost = 55, Amount = 2 },
	{ Id = "Greed", Name = "Greed", Description = "+25% coins from kills.", Rarity = "Rare", Cost = 50, Amount = 0.25 },
	{ Id = "TwinSpin", Name = "Twin Spin", Description = "+2 orbiting blades.", Rarity = "Epic", Cost = 120, Amount = 2 },
}

return Config
