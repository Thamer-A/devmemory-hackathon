local Config = {}

Config.Blades = {
	StartCount = 2,
	OrbitRadius = 7, -- studs from the character
	OrbitSpeed = 2.5, -- radians per second
	HeightOffset = 0.5, -- studs above HumanoidRootPart
	BobAmplitude = 0.6, -- studs of vertical wobble
	BobSpeed = 3, -- radians per second
	Size = Vector3.new(0.3, 1.4, 4),
	Color = Color3.fromRGB(0, 255, 255),
	Material = Enum.Material.Neon,
	LightBrightness = 2,
	LightRange = 8,
	TrailLifetime = 0.35,
	TrailWidth = 1.2,
	Damage = 30, -- per blade hit (two hits kill a wave-1 zombie)
	HitRadius = 3.5, -- minimum studs from blade center to zombie center that still counts as a hit
	InnerReach = 1.5, -- closest a zombie can stand to the player; blades must reach this far in, or the ring has a safe hole
	HitCooldown = 0.35, -- seconds before the same blade can hit the same zombie again
}

Config.Zombies = {
	Health = 60,
	WalkSpeed = 10,
	CoinsPerKill = 10,
	SpawnInterval = 2, -- seconds between spawns within a wave
	MaxAlive = 20,
	ContactRadius = 4, -- studs between zombie and player root centers
	ContactDPS = 5, -- damage per second to a player in contact
	ArenaHalfSize = 90, -- floor is 180x180
	SpawnInset = 6, -- studs in from the walls
	RetargetInterval = 0.25, -- seconds between nearest-player lookups
	Color = Color3.fromRGB(91, 140, 80),
}

Config.Waves = {
	FirstWaveCount = 8,
	CountPerWave = 4, -- extra zombies each wave
	HealthGrowth = 1.1, -- health multiplier per wave
	BreakDuration = 20, -- seconds between waves
}

Config.Player = {
	BaseMaxHealth = 100,
}

Config.Attributes = {
	BladeCount = "BladeCount", -- Player attribute, set by server, read by clients
	Wave = "Wave", -- Workspace attribute: current wave number
	Intermission = "Intermission", -- Workspace attribute: true while the shop is open (break between waves)
	WaveStartedAt = "WaveStartedAt", -- Workspace attribute: server time the current wave started
	BreakEndsAt ="BreakEndsAt", -- Workspace attribute: server time the current break ends
	ZombiesLeft = "ZombiesLeft", -- Workspace attribute: zombies alive plus those still to spawn this wave
	UpgradePrefix = "Upgrade_", -- Player attributes "Upgrade_<Id>" hold the stack count of each stat upgrade
}

-- Upgrade shop. Amount is the per-stack effect (see PlayerStats for how each is applied).
Config.Shop = {
	OfferCount = 3,
	RerollCost = 10,
	Upgrades = {
		{ Id = "ExtraBlade", Name = "+1 Blade", Rarity = "Rare", Cost = 60, Amount = 1, Description = "Adds one orbiting blade." },
		{ Id = "TwinSpin", Name = "Twin Spin", Rarity = "Epic", Cost = 120, Amount = 2, Description = "Adds two orbiting blades." },
		{ Id = "SharperBlades", Name = "Sharper Blades", Rarity = "Common", Cost = 30, Amount = 0.25, Description = "+25% blade damage." },
		{ Id = "FasterSpin", Name = "Faster Spin", Rarity = "Common", Cost = 30, Amount = 0.2, Description = "+20% spin speed." },
		{ Id = "LongerReach", Name = "Longer Reach", Rarity = "Common", Cost = 35, Amount = 2, Description = "Blades orbit 2 studs farther out." },
		{ Id = "Vitality", Name = "Vitality", Rarity = "Common", Cost = 25, Amount = 25, Description = "+25 max HP." },
		{ Id = "Vampiric", Name = "Vampiric", Rarity = "Rare", Cost = 55, Amount = 2, Description = "Heal 2 HP per kill." },
		{ Id = "Greed", Name = "Greed", Rarity = "Rare", Cost = 50, Amount = 0.25, Description = "+25% coins from kills." },
	},
	ById = {}, -- filled below
}

for _, upgrade in Config.Shop.Upgrades do
	Config.Shop.ById[upgrade.Id] = upgrade
end

return Config
