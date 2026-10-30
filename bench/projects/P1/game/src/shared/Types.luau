--!strict
export type PlayerStats = {
	kills: number,
	roundsPlayed: number,
}

export type PlayerData = {
	coins: number,
	inventory: { string },
	equipped: string?,
	stats: PlayerStats,
}

export type RoundState = {
	state: string,
	timeLeft: number,
}

export type EnemyKind = "Grunt" | "Brute"

return {}
