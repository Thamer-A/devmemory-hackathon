--!strict
local Config = require(script.Parent.Config)

export type Stats = {
	BladeCount: number,
	BladeDamage: number,
	BladeRadius: number,
	BladeSpinSpeed: number,
	BladeHitRadius: number,
	BladeScale: number,
	MaxHealth: number,
	WalkSpeed: number,
	Lifesteal: number,
	CoinBonus: number,
}

export type Upgrade = {
	id: string,
	name: string,
	description: string,
	icon: string,
	rarity: string,
	price: number,
	apply: (stats: Stats) -> (),
}

local Upgrades = {}

local pool: { Upgrade } = {
	{
		id = "extra_blade",
		name = "+1 Blade",
		description = "Adds 1 more orbiting blade.",
		icon = "🗡️",
		rarity = "Rare",
		price = 45,
		apply = function(stats: Stats)
			stats.BladeCount += 1
		end,
	},
	{
		id = "sharper_blades",
		name = "Sharper Blades",
		description = "+25% blade damage.",
		icon = "🔪",
		rarity = "Common",
		price = 25,
		apply = function(stats: Stats)
			stats.BladeDamage *= 1.25
		end,
	},
	{
		id = "faster_spin",
		name = "Faster Spin",
		description = "+20% blade spin speed.",
		icon = "🌀",
		rarity = "Common",
		price = 25,
		apply = function(stats: Stats)
			stats.BladeSpinSpeed *= 1.2
		end,
	},
	{
		id = "longer_reach",
		name = "Longer Reach",
		description = "+2 studs blade orbit radius.",
		icon = "📏",
		rarity = "Common",
		price = 20,
		apply = function(stats: Stats)
			stats.BladeRadius += 2
		end,
	},
	{
		id = "vitality",
		name = "Vitality",
		description = "+25 max HP and heal 25 HP.",
		icon = "❤️",
		rarity = "Common",
		price = 25,
		apply = function(stats: Stats)
			stats.MaxHealth += 25
		end,
	},
	{
		id = "swift_feet",
		name = "Swift Feet",
		description = "+2 walk speed.",
		icon = "👟",
		rarity = "Common",
		price = 20,
		apply = function(stats: Stats)
			stats.WalkSpeed += 2
		end,
	},
	{
		id = "vampiric",
		name = "Vampiric",
		description = "Heal 2 HP for every zombie you kill.",
		icon = "🧛",
		rarity = "Rare",
		price = 40,
		apply = function(stats: Stats)
			stats.Lifesteal += 2
		end,
	},
	{
		id = "greed",
		name = "Greed",
		description = "+25% coins from kills.",
		icon = "💰",
		rarity = "Rare",
		price = 35,
		apply = function(stats: Stats)
			stats.CoinBonus += 0.25
		end,
	},
	{
		id = "big_blades",
		name = "Big Blades",
		description = "+0.75 hit radius and bigger blades.",
		icon = "⚔️",
		rarity = "Rare",
		price = 40,
		apply = function(stats: Stats)
			stats.BladeHitRadius += 0.75
			stats.BladeScale += 0.25
		end,
	},
	{
		id = "twin_spin",
		name = "Twin Spin",
		description = "Adds 2 orbiting blades.",
		icon = "🌪️",
		rarity = "Epic",
		price = 85,
		apply = function(stats: Stats)
			stats.BladeCount += 2
		end,
	},
	{
		id = "titan_heart",
		name = "Titan Heart",
		description = "+60 max HP and heal 60 HP.",
		icon = "🫀",
		rarity = "Epic",
		price = 70,
		apply = function(stats: Stats)
			stats.MaxHealth += 60
		end,
	},
}

local byId: { [string]: Upgrade } = {}
for _, upgrade in pool do
	byId[upgrade.id] = upgrade
end

function Upgrades.all(): { Upgrade }
	return pool
end

function Upgrades.getById(id: string): Upgrade?
	return byId[id]
end

function Upgrades.newStats(): Stats
	return table.clone(Config.BasePlayer) :: Stats
end

local function weightOf(upgrade: Upgrade): number
	local weights: { [string]: number } = Config.RarityWeights
	return weights[upgrade.rarity] or 1
end

-- Weighted-by-rarity roll of `count` distinct upgrades.
function Upgrades.roll(rng: Random, count: number, excludeIds: { string }?): { Upgrade }
	local excluded: { [string]: boolean } = {}
	if excludeIds then
		for _, id in excludeIds do
			excluded[id] = true
		end
	end

	local candidates: { Upgrade } = {}
	for _, upgrade in pool do
		if not excluded[upgrade.id] then
			table.insert(candidates, upgrade)
		end
	end

	local picks: { Upgrade } = {}
	for _ = 1, count do
		if #candidates == 0 then
			break
		end
		local total = 0
		for _, upgrade in candidates do
			total += weightOf(upgrade)
		end
		local roll = rng:NextNumber() * total
		local chosenIndex = #candidates
		for index, upgrade in candidates do
			roll -= weightOf(upgrade)
			if roll <= 0 then
				chosenIndex = index
				break
			end
		end
		table.insert(picks, candidates[chosenIndex])
		table.remove(candidates, chosenIndex)
	end
	return picks
end

return Upgrades
