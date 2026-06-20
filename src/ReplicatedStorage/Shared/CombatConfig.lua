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
	M2_ANIMATIONS = {
		"rbxassetid://113107178491591",
		"rbxassetid://109743750628416",
	},
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
	M2_HIT_DELAY = 0.48,

	PUNCH_ATTACK_DURATION = 0.58,
	PUNCH_ANIMATION_SPEED = 0.7,
	M2_ATTACK_DURATION = 0.75,

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
	BLOCK_BREAK_STUN_DURATION = 1, -- Duración del stun al romper el bloqueo
	BLOCK_ANGLE = 130, -- Ángulo del bloqueo en grados por el frente
	BLOCK_COOLDOWN = 0.4, -- Cooldown en segundos para volver a bloquear tras recibir un golpe bloqueado
	PERFECT_BLOCK_WINDOW = 0.65, -- Ventana (segundos) para hacer perfect block al M2 (parry)
	PERFECT_BLOCK_STUN_DURATION = 1.0, -- Segundos de stun al atacante por perfect block

	-- Maná (mantener G)
	MANA_CHARGE_TIME = 2, -- Segundos para cargar al máximo (100) desde 0
	MANA_DRAIN_TIME = 3, -- Segundos para bajar de máximo a 0
	MAX_MANA = 100,
	MANA_CHARGE_WALK_SPEED = 6,

	-- Dash (tecla Q)
	DASH_COOLDOWN = 1.5, -- Segundos entre dashes
	DASH_DISTANCE = 12, -- Studs que recorre
	DASH_DURATION = 0.25, -- Duración del dash en segundos
	DASH_ANIMATION = "rbxassetid://75611214871700", -- Animación de dash normal
	DASH_ANIMATION_RIGHT = "rbxassetid://132024206838246", -- Flip derecha (shiftlock)
	DASH_ANIMATION_LEFT = "rbxassetid://116542905811911", -- Flip izquierda (shiftlock)
	DASH_ANIMATION_BACK = "rbxassetid://88388053882768", -- Back dash
}
