-- All tunable numbers live here.
local Config = {
	Blades = {
		StartCount = 2,
		OrbitRadius = 7, -- studs from the player's root part
		OrbitSpeed = 2.5, -- radians/sec around the player
		SpinSpeed = 14, -- radians/sec of each blade rolling on its own axis
		HeightOffset = 0.5, -- studs above the root part
		BobAmplitude = 0.6, -- studs of vertical wave
		BobSpeed = 3, -- radians/sec of the vertical wave
		Size = Vector3.new(0.3, 1.2, 4),
		Color = Color3.fromRGB(0, 255, 255), -- neon cyan
		Material = Enum.Material.Neon,
		LightBrightness = 2,
		LightRange = 8,
		TrailLifetime = 0.35,
		TrailWidth = 1.2, -- studs between trail attachments
		HitDamage = 20, -- per blade hit
		HitRadius = 3.5, -- studs from blade center to zombie root that counts as a hit
		HitCooldown = 0.5, -- seconds before the same blade can hit the same zombie again
	},
	Zombies = {
		Health = 60,
		WalkSpeed = 10,
		MaxAlive = 15,
		SpawnInterval = 1.5, -- seconds between spawns
		SpawnEdgeInset = 6, -- studs inside the arena edge
		ArenaHalfSize = 90, -- arena is 180x180 centered on the origin
		Size = Vector3.new(2, 5, 1.5),
		Color = Color3.fromRGB(86, 130, 66),
		CoinsPerKill = 10,
		ContactDamagePerSecond = 10, -- damage to a player touching a zombie
		ContactRadius = 5, -- studs, zombie root to player root
	},
	Waves = {
		FirstWaveZombies = 8,
		ZombiesPerWave = 4, -- added each wave
		BreakSeconds = 20,
		HealthGrowth = 0.1, -- zombie health multiplier grows 10% per wave (compounding)
	},
	Player = {
		BaseMaxHealth = 100,
	},
	UI = {
		Navy = Color3.fromRGB(14, 20, 38), -- panel background
		NavyLight = Color3.fromRGB(26, 36, 62), -- cards, bars, buttons
		Accent = Color3.fromRGB(0, 255, 255), -- cyan
		Gold = Color3.fromRGB(255, 205, 60), -- coins
		Text = Color3.fromRGB(235, 242, 255),
		TextDim = Color3.fromRGB(140, 155, 185),
		HealthGood = Color3.fromRGB(70, 220, 130),
		HealthLow = Color3.fromRGB(255, 80, 80),
		LowHealthFraction = 0.3,
		PanelTransparency = 0.12,
		CornerRadius = 12,
	},
	Effects = {
		DamageNumber = { Color = Color3.fromRGB(255, 240, 200), TextSize = 26, RiseStuds = 4, Seconds = 0.7, Jitter = 1.5 },
		DeathBurst = { Color = Color3.fromRGB(120, 200, 80), Count = 24, Lifetime = 0.6, Speed = 22, Size = 0.7 },
		CoinPopup = { TextSize = 30, RiseStuds = 6, Seconds = 1.1, HeightAbove = 4 }, -- uses Config.UI.Gold
	},
	Arena = {
		-- Graveyard at dusk. Decor is built by src/server/ArenaDecor.server.luau.
		Seed = 1337,
		WallInnerEdge = 90, -- inner face of the walls (walls are 4 thick, centered at 92)
		WallHeight = 8,
		TorchSpacing = 22, -- studs between wall torches
		TorchLightColor = Color3.fromRGB(255, 150, 60),
		TorchBrightness = 2.5,
		TorchRange = 28,
		DecorInnerRadius = 58, -- decor only between this and DecorOuterRadius (square ring, studs from origin); the middle stays clear
		DecorOuterRadius = 86,
		GravestoneCount = 60,
		DeadTreeCount = 26,
		FloorColor = Color3.fromRGB(62, 66, 50), -- dead grass
		StoneColor = Color3.fromRGB(110, 112, 118),
		WoodColor = Color3.fromRGB(60, 44, 34),
		Lighting = {
			ClockTime = 17.6,
			Ambient = Color3.fromRGB(90, 70, 80),
			OutdoorAmbient = Color3.fromRGB(120, 90, 90),
			Brightness = 1.6,
			ColorShiftTop = Color3.fromRGB(255, 160, 90),
			FogColor = Color3.fromRGB(150, 110, 100),
			FogStart = 60,
			FogEnd = 400,
			AtmosphereDensity = 0.45,
			AtmosphereHaze = 1.6,
			AtmosphereColor = Color3.fromRGB(220, 150, 120),
			AtmosphereDecay = Color3.fromRGB(120, 70, 70),
			TintColor = Color3.fromRGB(255, 225, 200),
			Saturation = -0.1,
			Contrast = 0.1,
		},
	},
	Shop = {
		OffersPerPlayer = 3,
		RerollCost = 10, -- coins; replaces all offers with a fresh random set
		RarityWeights = { Common = 65, Rare = 25, Epic = 10 }, -- chance weight when rolling an offer
		RarityColors = {
			Common = Color3.fromRGB(160, 165, 175), -- gray
			Rare = Color3.fromRGB(80, 160, 255), -- blue
			Epic = Color3.fromRGB(175, 90, 255), -- purple
		},
		-- Each upgrade adds `Amount` to the Player attribute `Attribute` (stacks without limit).
		Upgrades = {
			{ Id = "Blade", Name = "+1 Blade", Rarity = "Rare", Cost = 60, Attribute = "BladeCount", Amount = 1, Desc = "One more orbiting blade" },
			{ Id = "Damage", Name = "Sharper Blades", Rarity = "Common", Cost = 30, Attribute = "DamageMult", Amount = 0.25, Desc = "+25% blade damage" },
			{ Id = "Spin", Name = "Faster Spin", Rarity = "Common", Cost = 30, Attribute = "SpinMult", Amount = 0.2, Desc = "+20% spin speed" },
			{ Id = "Reach", Name = "Longer Reach", Rarity = "Common", Cost = 35, Attribute = "ReachBonus", Amount = 2, Desc = "+2 studs orbit radius" },
			{ Id = "Vitality", Name = "Vitality", Rarity = "Common", Cost = 25, Attribute = "MaxHealthBonus", Amount = 25, Desc = "+25 max HP" },
			{ Id = "Vampiric", Name = "Vampiric", Rarity = "Rare", Cost = 55, Attribute = "HealOnKill", Amount = 2, Desc = "Heal 2 HP per kill" },
			{ Id = "Greed", Name = "Greed", Rarity = "Rare", Cost = 50, Attribute = "CoinMult", Amount = 0.25, Desc = "+25% coins from kills" },
			{ Id = "BladeStorm", Name = "Blade Storm", Rarity = "Epic", Cost = 110, Attribute = "BladeCount", Amount = 2, Desc = "Two more orbiting blades" },
			{ Id = "TwinSpin", Name = "Twin Spin", Rarity = "Epic", Cost = 120, Attribute = "BladeCount", Amount = 2, Desc = "Two more orbiting blades" },
			{ Id = "TitanHeart", Name = "Titan Heart", Rarity = "Epic", Cost = 90, Attribute = "MaxHealthBonus", Amount = 75, Desc = "+75 max HP" },
		},
		-- Starting values of the upgrade attributes (BladeCount starts from Config.Blades.StartCount).
		Defaults = { DamageMult = 1, SpinMult = 1, ReachBonus = 0, MaxHealthBonus = 0, HealOnKill = 0, CoinMult = 1 },
	},
}

return Config
