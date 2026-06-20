local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemote = remotes:WaitForChild("CombatAttack") :: RemoteEvent

local comboIndex = 0
local lastComboTime = 0
local lastM2Time = 0
local isAttacking = false
local isBlocking = false
local isChargingMana = false
local isGHeld = false
local isStunned = false
local isDashing = false
local lastDashTime = 0
local currentCharacter: Model? = nil
local currentHumanoid: Humanoid? = nil
local punchTracks: { AnimationTrack } = {}
local m2Track: AnimationTrack? = nil
local dashTrack: AnimationTrack? = nil
local currentAttackTrack: AnimationTrack? = nil

local function requestCancelRun()
	player:SetAttribute("CancelRunRequest", os.clock())
end

local function canFight(): boolean
	return player:GetAttribute("Race") ~= nil
		and currentHumanoid ~= nil
		and currentHumanoid.Health > 0
		and not isAttacking
		and not isBlocking
		and not isStunned
		and not isChargingMana
		and not isDashing
		and not player:GetAttribute("IsStunned")
		and not player:GetAttribute("IsRagdolled")
end

local function canBlock(): boolean
	return player:GetAttribute("Race") ~= nil
		and currentHumanoid ~= nil
		and currentHumanoid.Health > 0
		and not isAttacking
		and not isBlocking
		and not isStunned
		and not isChargingMana
		and not isDashing
		and not player:GetAttribute("IsStunned")
		and not player:GetAttribute("IsRagdolled")
end

local function canChargeMana(): boolean
	local hasRace = player:GetAttribute("Race") ~= nil
	local hasHumanoid = currentHumanoid ~= nil
	local hasHealth = currentHumanoid and currentHumanoid.Health > 0
	local isRunningAttr = player:GetAttribute("IsRunning") == true
	print("[Combat Client] canChargeMana checks: hasRace =", hasRace, "hasHumanoid =", hasHumanoid, "hasHealth =", hasHealth, "isAttacking =", isAttacking, "isBlocking =", isBlocking, "isStunned =", isStunned, "isChargingMana =", isChargingMana, "isRunning =", isRunningAttr, "stunAttr =", player:GetAttribute("IsStunned"), "ragdollAttr =", player:GetAttribute("IsRagdolled"))
	return hasRace
		and currentHumanoid ~= nil
		and currentHumanoid.Health > 0
		and not isAttacking
		and not isBlocking
		and not isStunned
		and not isChargingMana
		and not player:GetAttribute("IsStunned")
		and not player:GetAttribute("IsRagdolled")
end

local function restoreWalkSpeed()
	if not currentHumanoid then
		return
	end

	if isBlocking then
		currentHumanoid.WalkSpeed = CombatConfig.BLOCK_WALK_SPEED
	elseif isChargingMana then
		currentHumanoid.WalkSpeed = CombatConfig.MANA_CHARGE_WALK_SPEED
	else
		currentHumanoid.WalkSpeed = player:GetAttribute("WalkSpeed") or 16
	end
end

local function stopCurrentAttackAnimation()
	if currentAttackTrack and currentAttackTrack.IsPlaying then
		currentAttackTrack:Stop()
	end
	currentAttackTrack = nil
end

local function playAttackAnimation(track: AnimationTrack)
	stopCurrentAttackAnimation()
	currentAttackTrack = track
	track:Play()
end

local function loadCombatAnimations(humanoid: Humanoid)
	punchTracks = {}
	for _, animationId in CombatConfig.PUNCH_ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		local track = humanoid:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		track:AdjustSpeed(CombatConfig.PUNCH_ANIMATION_SPEED)
		table.insert(punchTracks, track)
	end

	local m2Animation = Instance.new("Animation")
	m2Animation.AnimationId = CombatConfig.M2_ANIMATION
	m2Track = humanoid:LoadAnimation(m2Animation)
	m2Track.Priority = Enum.AnimationPriority.Action

	if CombatConfig.DASH_ANIMATION ~= "" and not string.find(CombatConfig.DASH_ANIMATION, "PLACEHOLDER") then
		local dashAnimation = Instance.new("Animation")
		dashAnimation.AnimationId = CombatConfig.DASH_ANIMATION
		dashTrack = humanoid:LoadAnimation(dashAnimation)
		dashTrack.Priority = Enum.AnimationPriority.Action2
	end
end

local function applyComboEndStun()
	if isStunned or not currentHumanoid then
		return
	end

	isStunned = true
	comboIndex = 0
	lastComboTime = 0
	player:SetAttribute("IsStunned", true)
	currentHumanoid.WalkSpeed = CombatConfig.STUN_WALK_SPEED

	task.delay(CombatConfig.COMBO_END_STUN_DURATION, function()
		isStunned = false
		player:SetAttribute("IsStunned", false)
		restoreWalkSpeed()
	end)
end

local function beginAttack(duration: number, stunAfter: boolean?, slowMovement: boolean?)
	if not currentCharacter then
		return
	end

	if slowMovement and currentHumanoid then
		currentHumanoid.WalkSpeed = CombatConfig.ATTACK_WALK_SPEED
	end

	task.delay(duration, function()
		isAttacking = false
		player:SetAttribute("IsAttacking", false)

		if stunAfter then
			applyComboEndStun()
		elseif slowMovement then
			restoreWalkSpeed()
		end
	end)
end

local function startAttack()
	isAttacking = true
	player:SetAttribute("IsAttacking", true)
	requestCancelRun()
end

local function performPunch()
	if not canFight() then
		return
	end

	local now = os.clock()
	if now - lastComboTime > CombatConfig.COMBO_RESET_TIME then
		comboIndex = 0
	end

	comboIndex += 1
	if comboIndex > 5 then
		comboIndex = 1
	end

	lastComboTime = now

	startAttack()

	local track = punchTracks[comboIndex]
	if track then
		playAttackAnimation(track)
	end

	combatRemote:FireServer("Punch", comboIndex)
	local isFinisher = comboIndex == 5
	beginAttack(CombatConfig.PUNCH_ATTACK_DURATION, isFinisher, isFinisher)
end

local function performM2()
	if not canFight() then
		return
	end

	local now = os.clock()
	if now - lastM2Time < CombatConfig.M2_COOLDOWN then
		return
	end

	lastM2Time = now
	comboIndex = 0
	lastComboTime = 0

	startAttack()

	if m2Track then
		playAttackAnimation(m2Track)
	end

	combatRemote:FireServer("M2")
	beginAttack(CombatConfig.M2_ATTACK_DURATION, false, true)
end

local function applyBlockingState(blocking: boolean)
	if blocking then
		if isBlocking then
			return
		end

		isBlocking = true
		stopCurrentAttackAnimation()
		requestCancelRun()

		if currentHumanoid then
			currentHumanoid.WalkSpeed = CombatConfig.BLOCK_WALK_SPEED
		end
	else
		if not isBlocking then
			return
		end

		isBlocking = false

		if currentHumanoid and not isStunned and not isAttacking then
			restoreWalkSpeed()
		end
	end
end

local function stopBlocking()
	combatRemote:FireServer("BlockEnd")
end

local function startBlocking()
	if not canBlock() then
		return
	end

	combatRemote:FireServer("BlockStart")
end

local function applyManaChargingState(charging: boolean)
	if charging then
		if isChargingMana then
			return
		end

		isChargingMana = true
		stopCurrentAttackAnimation()
		requestCancelRun()

		if currentHumanoid then
			currentHumanoid.WalkSpeed = CombatConfig.MANA_CHARGE_WALK_SPEED
		end
	else
		if not isChargingMana then
			return
		end

		isChargingMana = false

		if currentHumanoid and not isStunned and not isAttacking and not isBlocking then
			restoreWalkSpeed()
		end
	end
end

local function stopManaCharging()
	combatRemote:FireServer("ManaChargeEnd")
end

local function startManaCharging()
	print("[Combat Client] startManaCharging called")
	if not canChargeMana() then
		print("[Combat Client] startManaCharging: canChargeMana returned false")
		return
	end

	requestCancelRun() -- Cancel running immediately on client for instant response
	print("[Combat Client] startManaCharging: firing remote ManaChargeStart")
	combatRemote:FireServer("ManaChargeStart")
end

local function canDash(): boolean
	local now = os.clock()
	return player:GetAttribute("Race") ~= nil
		and currentHumanoid ~= nil
		and currentHumanoid.Health > 0
		and not isAttacking
		and not isBlocking
		and not isStunned
		and not isDashing
		and not player:GetAttribute("IsStunned")
		and not player:GetAttribute("IsRagdolled")
		and (now - lastDashTime) >= CombatConfig.DASH_COOLDOWN
end

local function getDashDirection(): string
	local w = UserInputService:IsKeyDown(Enum.KeyCode.W)
	local a = UserInputService:IsKeyDown(Enum.KeyCode.A)
	local s = UserInputService:IsKeyDown(Enum.KeyCode.S)
	local d = UserInputService:IsKeyDown(Enum.KeyCode.D)

	if w and a then return "ForwardLeft" end
	if w and d then return "ForwardRight" end
	if s and a then return "BackLeft" end
	if s and d then return "BackRight" end
	if a then return "Left" end
	if d then return "Right" end
	if s then return "Back" end
	return "Forward" -- default
end

local DIRECTION_VECTORS = {
	Forward = Vector3.new(0, 0, -1),
	Back = Vector3.new(0, 0, 1),
	Left = Vector3.new(-1, 0, 0),
	Right = Vector3.new(1, 0, 0),
	ForwardLeft = Vector3.new(-1, 0, -1).Unit,
	ForwardRight = Vector3.new(1, 0, -1).Unit,
	BackLeft = Vector3.new(-1, 0, 1).Unit,
	BackRight = Vector3.new(1, 0, 1).Unit,
}

local function performDash()
	if not canDash() then
		return
	end

	if not currentCharacter or not currentHumanoid then
		return
	end

	local rootPart = currentCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local direction = getDashDirection()
	local localDir = DIRECTION_VECTORS[direction] or Vector3.new(0, 0, -1)

	-- Convertir dirección local a dirección mundial basada en la orientación del personaje
	local worldDir = rootPart.CFrame:VectorToWorldSpace(localDir)
	-- Mantener en el plano horizontal
	worldDir = Vector3.new(worldDir.X, 0, worldDir.Z)
	if worldDir.Magnitude > 0 then
		worldDir = worldDir.Unit
	end

	isDashing = true
	lastDashTime = os.clock()
	player:SetAttribute("IsDashing", true)
	requestCancelRun()

	-- Cancelar carga de maná si estaba activa
	if isChargingMana then
		stopManaCharging()
	end

	-- Reproducir animación de dash
	if dashTrack then
		dashTrack:Play()
	end

	-- Notificar al servidor
	combatRemote:FireServer("Dash", direction)

	-- Aplicar velocidad de dash
	local dashSpeed = CombatConfig.DASH_DISTANCE / CombatConfig.DASH_DURATION
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e5, 0, 1e5)
	bodyVelocity.Velocity = worldDir * dashSpeed
	bodyVelocity.P = 1e5
	bodyVelocity.Parent = rootPart

	task.delay(CombatConfig.DASH_DURATION, function()
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end

		isDashing = false
		player:SetAttribute("IsDashing", false)
		restoreWalkSpeed()
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.F then
		if gameProcessed then
			return
		end
		startBlocking()
		return
	elseif input.KeyCode == Enum.KeyCode.G then
		isGHeld = true
		if gameProcessed then
			return
		end
		startManaCharging()
		return
	elseif input.KeyCode == Enum.KeyCode.Q then
		if gameProcessed then
			return
		end
		performDash()
		return
	end

	local isAttackInput = input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2

	if not isAttackInput and gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		performPunch()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		performM2()
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.KeyCode == Enum.KeyCode.F then
		stopBlocking()
	elseif input.KeyCode == Enum.KeyCode.G then
		isGHeld = false
		stopManaCharging()
	end
end)

local function onCharacterAdded(character: Model)
	currentCharacter = character
	currentHumanoid = character:WaitForChild("Humanoid") :: Humanoid
	comboIndex = 0
	lastComboTime = 0
	lastM2Time = 0
	isAttacking = false
	isBlocking = false
	isChargingMana = false
	isGHeld = false
	isStunned = false
	isDashing = false
	stopCurrentAttackAnimation()
	player:SetAttribute("IsAttacking", false)
	player:SetAttribute("IsStunned", false)
	player:SetAttribute("IsRagdolled", false)
	player:SetAttribute("IsDashing", false)
	loadCombatAnimations(currentHumanoid)
end

if player.Character then
	onCharacterAdded(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)

player:GetAttributeChangedSignal("IsStunned"):Connect(function()
	isStunned = player:GetAttribute("IsStunned") == true

	if isStunned then
		stopBlocking()
		stopManaCharging()
	end

	if isStunned and currentHumanoid then
		currentHumanoid.WalkSpeed = CombatConfig.STUN_WALK_SPEED
	elseif currentHumanoid and not isAttacking and not isBlocking and not isChargingMana and not isDashing then
		restoreWalkSpeed()
	end
end)

player:GetAttributeChangedSignal("IsRagdolled"):Connect(function()
	if player:GetAttribute("IsRagdolled") then
		stopBlocking()
		stopManaCharging()
	end
end)

player:GetAttributeChangedSignal("IsBlocking"):Connect(function()
	applyBlockingState(player:GetAttribute("IsBlocking") == true)
end)

player:GetAttributeChangedSignal("IsChargingMana"):Connect(function()
	applyManaChargingState(player:GetAttribute("IsChargingMana") == true)
end)

player:GetAttributeChangedSignal("IsRunning"):Connect(function()
	if player:GetAttribute("IsRunning") == true then
		if isChargingMana then
			stopManaCharging()
		end
	else
		if isGHeld then
			startManaCharging()
		end
	end
end)
