local Config = {
	Blades = {
		StartCount = 2,
		OrbitRadius = 7, -- studs from the character's root
		OrbitSpeed = 2.5, -- radians per second
		SpinSpeed = 12, -- radians per second, roll around the blade's length
		Height = 0.5, -- studs above the root part
		BobAmount = 0.6,
		BobSpeed = 2,
		Size = Vector3.new(0.25, 1.2, 3.4),
		Color = Color3.fromRGB(0, 255, 255),
		Material = Enum.Material.Neon,
		LightBrightness = 2,
		LightRange = 9,
		TrailLifetime = 0.35,
		TrailWidth = 0.9,
		Damage = 20, -- per blade hit
		-- Studs from blade center to zombie root. Must exceed OrbitRadius minus the distance a
		-- zombie stands from the player (~2), or zombies hugging the player can't be hit.
		HitRadius = 5.5,
		HitCooldown = 0.5, -- seconds before the same blade can hit the same zombie again
	},
	Zombies = {
		Health = 60,
		WalkSpeed = 10,
		SpawnInterval = 2,
		MaxAlive = 25,
		SpawnRadius = 82, -- studs from arena center (arena floor is 180x180)
		CoinsPerKill = 10,
		Color = Color3.fromRGB(90, 140, 80),
		FirstWaveCount = 8,
		CountPerWave = 4, -- extra zombies each wave
		WaveBreak = 20, -- seconds between waves
		HealthGrowth = 0.1, -- health multiplier increase per wave
		ContactDamage = 10, -- per second while touching a player
		ContactRadius = 4, -- studs from zombie root to player root
	},
	Player = {
		MaxHealth = 100,
	},
	Graveyard = {
		Seed = 1313, -- same layout every server
		ArenaHalf = 90, -- floor is 180x180
		ClearRadius = 52, -- square half-size kept free of props for fighting
		PropMargin = 6, -- studs kept between props and the wall
		GravestoneCount = 55,
		TreeCount = 16,
		TorchSpacing = 23, -- studs between wall torches
		TorchHeight = 9,
		WallTopHeight = 8, -- matches the wall parts in default.project.json
		StoneColor = Color3.fromRGB(105, 108, 115),
		MossColor = Color3.fromRGB(70, 85, 65),
		WoodColor = Color3.fromRGB(48, 36, 30),
		FireColor = Color3.fromRGB(255, 150, 50),
		TorchLightRange = 28,
		TorchLightBrightness = 1.6,
		FloorColor = Color3.fromRGB(70, 78, 55),
		Lighting = {
			ClockTime = 17.6,
			Ambient = Color3.fromRGB(95, 70, 70),
			OutdoorAmbient = Color3.fromRGB(120, 85, 80),
			Brightness = 1.6,
			FogColor = Color3.fromRGB(190, 130, 100),
			AtmosphereDensity = 0.38,
			AtmosphereHaze = 2.2,
			AtmosphereColor = Color3.fromRGB(215, 160, 130),
			AtmosphereDecay = Color3.fromRGB(120, 70, 70),
			Tint = Color3.fromRGB(255, 225, 200),
			Saturation = -0.1,
			Contrast = 0.1,
			BloomIntensity = 0.5,
			BloomSize = 30,
			BloomThreshold = 1.2,
		},
	},
	Effects = {
		PopupLifetime = 0.8, -- seconds a floating number stays up
		PopupRise = 3, -- studs a floating number drifts upward
		HitColor = Color3.fromRGB(255, 255, 255),
		BurstParticles = 24,
		BurstLifetime = 0.6,
		BurstSpeed = 22, -- studs per second
	},
	Ui = {
		Panel = Color3.fromRGB(14, 20, 38), -- dark navy
		PanelLight = Color3.fromRGB(24, 33, 58),
		Accent = Color3.fromRGB(0, 229, 255), -- cyan
		Text = Color3.fromRGB(235, 240, 250),
		TextDim = Color3.fromRGB(140, 150, 175),
		Coin = Color3.fromRGB(255, 205, 60), -- gold
		Danger = Color3.fromRGB(235, 80, 90),
		Health = Color3.fromRGB(70, 220, 130),
		Corner = 12, -- px
		Rarity = {
			Common = Color3.fromRGB(150, 156, 170),
			Rare = Color3.fromRGB(70, 140, 255),
			Epic = Color3.fromRGB(170, 90, 240),
		},
	},
	Shop = {
		OfferCount = 3, -- random offers per player each break
		RerollCost = 10, -- coins
		RarityWeight = { Common = 3, Rare = 1, Epic = 0.4 }, -- relative odds of being offered
		-- Amount meaning depends on the upgrade; see effects in server/Shop.lua.
		Upgrades = {
			{ Id = "Blade", Name = "+1 Blade", Rarity = "Rare", Cost = 60, Amount = 1, Description = "Adds another orbiting blade." },
			{ Id = "TwinSpin", Name = "Twin Spin", Rarity = "Epic", Cost = 120, Amount = 2, Description = "+2 blades." },
			{ Id = "Damage", Name = "Sharper Blades", Rarity = "Common", Cost = 30, Amount = 0.25, Description = "+25% blade damage." },
			{ Id = "Spin", Name = "Faster Spin", Rarity = "Common", Cost = 30, Amount = 0.2, Description = "+20% spin speed." },
			{ Id = "Reach", Name = "Longer Reach", Rarity = "Common", Cost = 35, Amount = 2, Description = "Blades orbit 2 studs further out." },
			{ Id = "Vitality", Name = "Vitality", Rarity = "Common", Cost = 25, Amount = 25, Description = "+25 max HP." },
			{ Id = "Vampiric", Name = "Vampiric", Rarity = "Rare", Cost = 55, Amount = 2, Description = "Heal 2 HP per kill." },
			{ Id = "Greed", Name = "Greed", Rarity = "Rare", Cost = 50, Amount = 0.25, Description = "+25% coins from kills." },
		},
	},
}

return Config
