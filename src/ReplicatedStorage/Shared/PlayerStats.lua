local Races = require(script.Parent.Races)

local BASE_LIVES = 3

local PlayerStats = {}

function PlayerStats.getForRace(raceId: string)
	local race = Races.get(raceId)
	if not race then
		return nil
	end

	return {
		Race = raceId,
		Lineage = race.DisplayName,
		Lives = BASE_LIVES,
		MaxHealth = race.MaxHealth,
		WalkSpeed = race.WalkSpeed,
		JumpPower = race.JumpPower,
	}
end

return PlayerStats
