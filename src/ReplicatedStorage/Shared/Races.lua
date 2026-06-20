export type RaceStats = {
	DisplayName: string,
	Description: string,
	MaxHealth: number,
	WalkSpeed: number,
	JumpPower: number,
}

local RACES: { [string]: RaceStats } = {
	Vaelen = {
		DisplayName = "Vaelen",
		Description = "Ágiles y ligeros. Misma resistencia, pero un poco más rápidos.",
		MaxHealth = 100,
		WalkSpeed = 14,
		JumpPower = 48,
	},
	Gravelord = {
		DisplayName = "Gravelord",
		Description = "Robustos y resistentes. Misma velocidad, pero más vida.",
		MaxHealth = 115,
		WalkSpeed = 13,
		JumpPower = 48,
	},
	Ashborn = {
		DisplayName = "Ashborn",
		Description = "Equilibrados. Stats estándar en vida y velocidad.",
		MaxHealth = 100,
		WalkSpeed = 13,
		JumpPower = 48,
	},
}

local RACE_IDS = { "Vaelen", "Gravelord", "Ashborn" }

local Races = {}

function Races.getAll(): { [string]: RaceStats }
	return RACES
end

function Races.get(raceId: string): RaceStats?
	return RACES[raceId]
end

function Races.isValid(raceId: string): boolean
	return RACES[raceId] ~= nil
end

function Races.getRandom(): string
	return RACE_IDS[math.random(1, #RACE_IDS)]
end

return Races
