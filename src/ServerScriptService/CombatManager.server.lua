local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CombatHit = require(ReplicatedStorage.Shared.CombatHit)
local BlockAnimation = require(ReplicatedStorage.Shared.BlockAnimation)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local combatRemote = remotesFolder:FindFirstChild("CombatAttack")
if not combatRemote then
	combatRemote = Instance.new("RemoteEvent")
	combatRemote.Name = "CombatAttack"
	combatRemote.Parent = remotesFolder
end

local playerAttackLock: { [Player]: boolean } = {}
local playerStunned: { [Player]: boolean } = {}
local playerBlocking: { [Player]: boolean } = {}
local playerChargingMana: { [Player]: boolean } = {}
local playerManaReachedMax: { [Player]: boolean } = {}
local playerDashing: { [Player]: boolean } = {}
local playerLastDash: { [Player]: number } = {}
local playerBlockCooldown: { [Player]: number } = {} -- timestamp del último golpe bloqueado
local playerLastAttack: { [Player]: number } = {}
local playerLastM2: { [Player]: number } = {}
local playerCombatTracks: { [Player]: { punch: { AnimationTrack }, m2: AnimationTrack, block: AnimationTrack?, dash: AnimationTrack? } } = {}

local function loadCombatAnimations(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local punchTracks: { AnimationTrack } = {}
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
	local m2Track = humanoid:LoadAnimation(m2Animation)
	m2Track.Priority = Enum.AnimationPriority.Action

	local blockTrack: AnimationTrack? = nil
	if CombatConfig.BLOCK_ANIMATION ~= "" then
		local blockAnimation = Instance.new("Animation")
		blockAnimation.AnimationId = CombatConfig.BLOCK_ANIMATION
		blockTrack = humanoid:LoadAnimation(blockAnimation)
		BlockAnimation.configureTrack(blockTrack)
	end

	local dashTrack: AnimationTrack? = nil
	if CombatConfig.DASH_ANIMATION ~= "" and not string.find(CombatConfig.DASH_ANIMATION, "PLACEHOLDER") then
		local dashAnimation = Instance.new("Animation")
		dashAnimation.AnimationId = CombatConfig.DASH_ANIMATION
		dashTrack = humanoid:LoadAnimation(dashAnimation)
		dashTrack.Priority = Enum.AnimationPriority.Action2
	end

	playerCombatTracks[player] = {
		punch = punchTracks,
		m2 = m2Track,
		block = blockTrack,
		dash = dashTrack,
	}
end

local function playCombatAnimation(player: Player, attackType: string, comboIndex: number?)
	local tracks = playerCombatTracks[player]
	if not tracks then
		return
	end

	if attackType == "Punch" and comboIndex then
		local track = tracks.punch[comboIndex]
		if track then
			track:Play()
		end
	elseif attackType == "M2" then
		tracks.m2:Play()
	elseif attackType == "Block" and tracks.block then
		BlockAnimation.play(tracks.block)
	end
end

local function stopBlockAnimation(player: Player)
	local tracks = playerCombatTracks[player]
	if tracks and tracks.block and tracks.block.IsPlaying then
		BlockAnimation.stop(tracks.block)
	end
end

local function setBlockingState(player: Player, isBlocking: boolean)
	local character = player.Character

	if isBlocking then
		playerBlocking[player] = true
		CombatHit.setPlayerBlocking(player, true)
		player:SetAttribute("IsBlocking", true)
		if character then
			character:SetAttribute("IsBlocking", true)
		end
	else
		playerBlocking[player] = nil
		CombatHit.setPlayerBlocking(player, false)
		player:SetAttribute("IsBlocking", false)
		if character then
			character:SetAttribute("IsBlocking", false)
		end
	end
end

local function canBlock(player: Player): boolean
	if playerStunned[player] or playerBlocking[player] then
		return false
	end

	-- Cooldown tras recibir un golpe bloqueado
	local lastBlockHit = playerBlockCooldown[player] or 0
	if (os.clock() - lastBlockHit) < (CombatConfig.BLOCK_COOLDOWN or 0.4) then
		return false
	end

	if player:GetAttribute("IsRagdolled") then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function endBlock(player: Player)
	if not playerBlocking[player] then
		return
	end

	setBlockingState(player, false)
	stopBlockAnimation(player)

	if playerStunned[player] then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = player:GetAttribute("WalkSpeed") or 16
	end
end

local function startBlock(player: Player)
	if not canBlock(player) then
		return
	end

	setBlockingState(player, true)
	playCombatAnimation(player, "Block")

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = CombatConfig.BLOCK_WALK_SPEED
	end
end

local function isValidAttacker(player: Player): boolean
	if not player:GetAttribute("Race") then
		return false
	end

	if player:GetAttribute("IsRagdolled") then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return true
end

local function createManaParticles(character: Model): ParticleEmitter?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local existing = root:FindFirstChild("ManaChargeParticles")
	if existing then
		return existing :: ParticleEmitter
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ManaChargeParticles"
	emitter.Texture = "rbxassetid://258129707"
	emitter.LightEmission = 0.8
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 0)
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(0, 180, 255))
	emitter.Speed = NumberRange.new(2, 4)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.2)
	emitter.Rate = 40
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Parent = root
	return emitter
end

local function removeManaParticles(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local emitter = root:FindFirstChild("ManaChargeParticles")
	if emitter then
		emitter.Enabled = false
		emitter.Name = "ManaChargeParticles_Draining"
		task.delay(1.5, function()
			if emitter and emitter.Parent then
				emitter:Destroy()
			end
		end)
	end
end

local function stopManaCharge(player: Player)
	if not playerChargingMana[player] then
		return
	end

	playerChargingMana[player] = nil
	playerManaReachedMax[player] = nil
	player:SetAttribute("IsChargingMana", false)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if playerBlocking[player] then
			humanoid.WalkSpeed = CombatConfig.BLOCK_WALK_SPEED
		else
			humanoid.WalkSpeed = player:GetAttribute("WalkSpeed") or 16
		end
	end

	if character then
		removeManaParticles(character)
		character:SetAttribute("IsChargingMana", false)
	end
end

local function startManaCharge(player: Player)
	print("Server: startManaCharge for player", player.Name)
	if playerChargingMana[player] then
		print("Server: player is already charging")
		return
	end

	if playerStunned[player] or playerBlocking[player] then
		print("Server: player is stunned or blocking. playerStunned =", playerStunned[player], "playerBlocking =", playerBlocking[player])
		return
	end

	if not isValidAttacker(player) then
		print("Server: player is not a valid attacker (check stats / health / attributes)")
		return
	end

	print("Server: player started charging successfully!")
	playerChargingMana[player] = true
	playerManaReachedMax[player] = false
	player:SetAttribute("IsChargingMana", true)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = CombatConfig.MANA_CHARGE_WALK_SPEED
	end

	if character then
		createManaParticles(character)
		character:SetAttribute("IsChargingMana", true)
	end
end

local function applyStun(player: Player, duration: number)
	if playerChargingMana[player] then
		stopManaCharge(player)
	end

	if playerStunned[player] then
		return
	end

	playerStunned[player] = true
	player:SetAttribute("IsStunned", true)

	local character = player.Character
	if character then
		character:SetAttribute("IsStunned", true)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = CombatConfig.STUN_WALK_SPEED
		end
	end

	task.delay(duration, function()
		playerStunned[player] = nil
		player:SetAttribute("IsStunned", false)

		local currentCharacter = player.Character
		if currentCharacter then
			currentCharacter:SetAttribute("IsStunned", false)
		end

		if not isValidAttacker(player) then
			return
		end

		local currentCharacter = player.Character
		local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")
		if currentHumanoid then
			currentHumanoid.WalkSpeed = player:GetAttribute("WalkSpeed") or 16
		end
	end)
end

local function applyComboEndStun(player: Player)
	applyStun(player, CombatConfig.COMBO_END_STUN_DURATION)
end

local function performHit(attacker: Player, damage: number, shouldRagdoll: boolean?, isM2: boolean?): boolean
	local character = attacker.Character
	if not character then
		return false
	end

	local hitAny = false
	local targets = CombatHit.getTargetsInFront(character)
	for _, humanoid in targets do
		hitAny = true

		local targetModel = humanoid.Parent
		local isBlocking = targetModel and CombatHit.isTargetBlocking(targetModel) or false
		local isBlockedFromFront = (isBlocking and targetModel) and CombatHit.isBlockingFromFront(targetModel, character) or false
		local blockBroken = false

		if isM2 and isBlocking and isBlockedFromFront then
			blockBroken = true
		end

		local multiplier = 1
		if isBlocking and not blockBroken then
			multiplier = CombatHit.getBlockDamageMultiplier(humanoid, character)
		end

		local finalDamage = math.floor(damage * multiplier)
		if finalDamage > 0 then
			humanoid:TakeDamage(finalDamage)

			if targetModel then
				local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
				if targetPlayer then
					print("[Rogue2]", attacker.Name, "golpeó a", targetPlayer.Name, "por", finalDamage)
					if playerBlocking[targetPlayer] then
						endBlock(targetPlayer)
						playerBlockCooldown[targetPlayer] = os.clock()
					end
				elseif targetModel:GetAttribute("IsTrainingDummy") then
					print("[Rogue2]", attacker.Name, "golpeó a", targetModel.Name, "por", finalDamage)
					if targetModel:GetAttribute("IsBlocking") then
						targetModel:SetAttribute("IsBlocking", false)
					end
				end
			end
		end

		if blockBroken then
			-- M2 rompe el bloqueo: stun completo
			if targetModel then
				local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
				if targetPlayer then
					endBlock(targetPlayer)
					playerBlockCooldown[targetPlayer] = os.clock()
					applyStun(targetPlayer, CombatConfig.BLOCK_BREAK_STUN_DURATION)
				else
					-- Dummy / NPC
					targetModel:SetAttribute("IsStunned", true)
					targetModel:SetAttribute("IsBlocking", false)

					local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
					if targetHumanoid then
						targetHumanoid.WalkSpeed = CombatConfig.STUN_WALK_SPEED
					end

					task.delay(CombatConfig.BLOCK_BREAK_STUN_DURATION, function()
						targetModel:SetAttribute("IsStunned", false)
					end)
				end
			end
		elseif isBlockedFromFront and not isM2 then
			-- Golpe normal bloqueado desde el frente: romper bloqueo + cooldown corto
			if targetModel then
				local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
				if targetPlayer then
					endBlock(targetPlayer)
					playerBlockCooldown[targetPlayer] = os.clock()
				else
					targetModel:SetAttribute("IsBlocking", false)
				end
			end
		elseif shouldRagdoll and CombatHit.shouldRagdollBlockedTarget(humanoid, character) then
			if targetModel then
				local attackerRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?

				local direction = Vector3.new(0, 0, -1)
				if attackerRoot and targetRoot then
					direction = (targetRoot.Position - attackerRoot.Position).Unit
				end

				Ragdoll.apply(targetModel, CombatConfig.RAGDOLL_DURATION, direction, CombatConfig.RAGDOLL_KNOCKBACK_DISTANCE)
			end
		end
	end

	return hitAny
end

local function canPunch(player: Player): boolean
	local now = os.clock()
	local last = playerLastAttack[player] or 0
	return now - last >= CombatConfig.PUNCH_COOLDOWN
end

local function canM2(player: Player): boolean
	local now = os.clock()
	local last = playerLastM2[player] or 0
	return now - last >= CombatConfig.M2_COOLDOWN
end

combatRemote.OnServerEvent:Connect(function(player: Player, attackType: string, comboIndex: number?)
	if attackType == "BlockStart" then
		startBlock(player)
		return
	elseif attackType == "BlockEnd" then
		endBlock(player)
		return
	elseif attackType == "ManaChargeStart" then
		print("Server: received ManaChargeStart from", player.Name)
		startManaCharge(player)
		return
	elseif attackType == "ManaChargeEnd" then
		print("Server: received ManaChargeEnd from", player.Name)
		stopManaCharge(player)
		return
	elseif attackType == "Dash" then
		-- Validar dash
		if playerDashing[player] or playerStunned[player] or playerBlocking[player]
			or playerAttackLock[player] then
			return
		end

		if player:GetAttribute("IsRagdolled") then
			return
		end

		if not isValidAttacker(player) then
			return
		end

		local now = os.clock()
		local lastDash = playerLastDash[player] or 0
		if (now - lastDash) < CombatConfig.DASH_COOLDOWN then
			return
		end

		playerDashing[player] = true
		playerLastDash[player] = now
		player:SetAttribute("IsDashing", true)

		-- Cancelar carga de maná si estaba activa
		if playerChargingMana[player] then
			stopManaCharge(player)
		end

		local character = player.Character
		if character then
			character:SetAttribute("IsDashing", true)
		end

		-- Reproducir animación de dash para replicación
		local tracks = playerCombatTracks[player]
		if tracks and tracks.dash then
			tracks.dash:Play()
		end

		task.delay(CombatConfig.DASH_DURATION, function()
			playerDashing[player] = nil
			player:SetAttribute("IsDashing", false)

			local currentCharacter = player.Character
			if currentCharacter then
				currentCharacter:SetAttribute("IsDashing", false)
			end
		end)
		return
	end

	if playerAttackLock[player] or playerStunned[player] or playerBlocking[player] or playerDashing[player] then
		return
	end

	if not isValidAttacker(player) then
		return
	end

	if attackType == "Punch" then
		if typeof(comboIndex) ~= "number" then
			return
		end

		comboIndex = math.clamp(math.floor(comboIndex), 1, 5)

		if not canPunch(player) then
			return
		end

		local damage = CombatConfig.PUNCH_DAMAGE[comboIndex]
		if not damage then
			return
		end

		playerAttackLock[player] = true
		playerLastAttack[player] = os.clock()

		playCombatAnimation(player, "Punch", comboIndex)

		task.delay(CombatConfig.PUNCH_HIT_DELAY, function()
			if isValidAttacker(player) then
				performHit(player, damage, comboIndex == 5, false)
			end
		end)

		task.delay(CombatConfig.PUNCH_ATTACK_DURATION, function()
			playerAttackLock[player] = nil
			if comboIndex == 5 then
				applyComboEndStun(player)
			end
		end)
	elseif attackType == "M2" then
		if not canM2(player) then
			return
		end

		playerAttackLock[player] = true
		playerLastM2[player] = os.clock()
		playerLastAttack[player] = os.clock()

		playCombatAnimation(player, "M2")

		local m2Hit = false

		task.delay(CombatConfig.M2_HIT_DELAY, function()
			if isValidAttacker(player) then
				m2Hit = performHit(player, CombatConfig.M2_DAMAGE, true, true)
			end
		end)

		task.delay(CombatConfig.M2_ATTACK_DURATION, function()
			playerAttackLock[player] = nil
			if not m2Hit then
				applyComboEndStun(player)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerAttackLock[player] = nil
	playerStunned[player] = nil
	playerBlocking[player] = nil
	playerChargingMana[player] = nil
	playerManaReachedMax[player] = nil
	playerBlockCooldown[player] = nil
	playerDashing[player] = nil
	playerLastDash[player] = nil
	CombatHit.setPlayerBlocking(player, false)
	playerLastAttack[player] = nil
	playerLastM2[player] = nil
	playerCombatTracks[player] = nil
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		endBlock(player)
		stopManaCharge(player)
		loadCombatAnimations(player, character)
		Ragdoll.cleanupCharacter(character)
	end)

	if player.Character then
		loadCombatAnimations(player, player.Character)
	end
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

local bindablesFolder = ReplicatedStorage:FindFirstChild("Bindables")
if not bindablesFolder then
	bindablesFolder = Instance.new("Folder")
	bindablesFolder.Name = "Bindables"
	bindablesFolder.Parent = ReplicatedStorage
end

local breakBlockEvent = bindablesFolder:FindFirstChild("BreakBlockAndStun")
if not breakBlockEvent then
	breakBlockEvent = Instance.new("BindableEvent")
	breakBlockEvent.Name = "BreakBlockAndStun"
	breakBlockEvent.Parent = bindablesFolder
end

breakBlockEvent.Event:Connect(function(targetPlayer: Player, duration: number)
	endBlock(targetPlayer)
	applyStun(targetPlayer, duration)
end)

RunService.Heartbeat:Connect(function(dt)
	for _, player in Players:GetPlayers() do
		local maxMana = player:GetAttribute("MaxMana") or CombatConfig.MAX_MANA or 100
		local currentMana = player:GetAttribute("Mana") or 0
		local isCharging = playerChargingMana[player] == true

		-- Validate if they can actually charge
		if isCharging then
			if not isValidAttacker(player) or playerBlocking[player] then
				stopManaCharge(player)
				isCharging = false
			end
		end

		if isCharging then
			if playerManaReachedMax[player] then
				-- Max reached, drain mana
				currentMana = math.max(0, currentMana - dt * (maxMana / CombatConfig.MANA_DRAIN_TIME))
			else
				-- Charge mana
				currentMana = currentMana + dt * (maxMana / CombatConfig.MANA_CHARGE_TIME)
				if currentMana >= maxMana then
					currentMana = maxMana
					playerManaReachedMax[player] = true
				end
			end
			player:SetAttribute("Mana", currentMana)
		else
			-- Not charging, drain mana
			if currentMana > 0 then
				currentMana = math.max(0, currentMana - dt * (maxMana / CombatConfig.MANA_DRAIN_TIME))
				player:SetAttribute("Mana", currentMana)
			end
		end
	end
end)

