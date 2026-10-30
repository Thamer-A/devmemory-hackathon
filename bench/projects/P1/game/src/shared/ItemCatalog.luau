--!strict
export type Item = {
	id: number,
	name: string,
	price: number,
	icon: string,
	description: string,
	cosmetic: boolean?,
	stats: { [string]: number }?,
}

local items: { [number]: Item } = {
	[1] = {
		id = 1,
		name = "Speed Boots",
		price = 100,
		icon = "SpeedBootsIcon",
		description = "Run faster through the arena.",
		stats = { walkSpeedBonus = 6 },
	},
	[2] = {
		id = 2,
		name = "Shield",
		price = 250,
		icon = "ShieldIcon",
		description = "A sturdy shield that helps you survive longer.",
	},
	[3] = {
		id = 3,
		name = "Double Jump",
		price = 400,
		icon = "DoubleJumpIcon",
		description = "Jump a second time in mid-air.",
	},
	[4] = {
		id = 4,
		name = "Neon Trail",
		price = 75,
		icon = "TrailIcon",
		description = "Leave a glowing trail behind you.",
		cosmetic = true,
	},
}

local byName: { [string]: Item } = {}
for _, item in items do
	byName[item.name] = item
end

local sorted: { Item } = {}
for _, item in items do
	table.insert(sorted, item)
end
table.sort(sorted, function(a, b)
	return a.id < b.id
end)

local ItemCatalog = {}

function ItemCatalog.getById(id: number): Item?
	return items[id]
end

function ItemCatalog.getByName(name: string): Item?
	return byName[name]
end

function ItemCatalog.all(): { Item }
	return table.clone(sorted)
end

return ItemCatalog
