-- Configuración global del juego
return {
	MAX_PLAYERS = 23,

	-- Tiempo antes de reaparecer (segundos). Permadeath real vendrá después.
	RESPAWN_TIME = 5,

	-- Duración de un día in-game (30 minutos reales)
	DAY_LENGTH_SECONDS = 30 * 60,

	-- Rig del personaje (R6 clásico)
	CHARACTER_RIG = "R6",

	-- Correr (doble W): bonus sobre la WalkSpeed de la raza
	RUN_SPEED_BONUS = 16,
	RUN_SPEED_BONUS_NO_MANA = 6,
	RUN_DOUBLE_TAP_WINDOW = 0.35,
	RUN_ANIMATION_ID = "rbxassetid://83344078158284",
}
