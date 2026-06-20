return {
	-- Daño por golpe del combo (M1 x5)
	PUNCH_DAMAGE = { 5, 5, 6, 6, 10 },

	-- Daño del golpe pesado (M2 / click derecho)
	M2_DAMAGE = 14,

	-- Animaciones de puños (combo M1 x5 + M2)
	PUNCH_ANIMATIONS = {
		"rbxassetid://119372313692643", -- PunchOne
		"rbxassetid://123886960033319", -- PunchTwo
		"rbxassetid://119372313692643", -- PunchThree
		"rbxassetid://123886960033319", -- PunchFour
		"rbxassetid://71798242330100", -- PunchFive
	},
	M2_ANIMATION = "rbxassetid://84370025539876",
	BLOCK_ANIMATION = "rbxassetid://77309514167712",
	BLOCK_ANIMATION_PRIORITY = Enum.AnimationPriority.Action2,
	BLOCK_HOLD_TIME = 0.18, -- frame donde ya está la pose de bloqueo (antes de que bajen los brazos)

	-- Hitbox de golpe (igual para M1 y M2, al frente del torso)
	HITBOX_OFFSET = 1,
	HITBOX_SIZE = Vector3.new(5, 6, 5.3), -- ancho, alto, profundidad hacia adelante

	-- Hitbox extra en los brazos del humanoid (objetivo)
	ARM_HITBOX_PADDING = 1,

	-- Tiempos (segundos)
	COMBO_RESET_TIME = 2,
	PUNCH_COOLDOWN = 0.5,
	M2_COOLDOWN = 4,
	PUNCH_HIT_DELAY = 0.28,
	M2_HIT_DELAY = 0.28,

	PUNCH_ATTACK_DURATION = 0.58,
	PUNCH_ANIMATION_SPEED = 0.7,
	M2_ATTACK_DURATION = 0.55,

	-- Stun al completar el combo de 5 golpes o M2 (segundos)
	COMBO_END_STUN_DURATION = 0.65,
	STUN_WALK_SPEED = 0,

	-- Ragdoll al conectar golpe final (M1 x5) o M2
	RAGDOLL_DURATION = 2,
	RAGDOLL_KNOCKBACK_DISTANCE = 5, -- studs horizontales aproximados

	-- Velocidad reducida mientras atacas
	ATTACK_WALK_SPEED = 4,

	-- Bloqueo (mantener F)
	BLOCK_WALK_SPEED = 5,
	BLOCK_DAMAGE_MULTIPLIER = 0, -- 0 = inmunidad al bloquear (jugadores: siempre; dummies: desde el frente)
}
