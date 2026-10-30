--!strict
export type PlayerStats = {
	kills: number,
	roundsPlayed: number,
}

export type PlayerData = {
	coins: number,
	inventory: { number },
	equipped: number?,
	stats: PlayerStats,
}

export type RoundState = {
	state: string,
	timeLeft: number,
}

export type EnemyKind = "Grunt" | "Brute"

return {}
