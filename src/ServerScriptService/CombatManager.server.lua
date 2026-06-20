local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local HumanoidHitbox = require(ReplicatedStorage.Shared.HumanoidHitbox)
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
local playerLastAttack: { [Player]: number } = {}
local playerLastM2: { [Player]: number } = {}
local playerCombatTracks: { [Player]: { punch: { AnimationTrack }, m2: AnimationTrack } } = {}

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

	playerCombatTracks[player] = {
		punch = punchTracks,
		m2 = m2Track,
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
	end
end

local function applyComboEndStun(player: Player)
	if playerStunned[player] then
		return
	end

	playerStunned[player] = true
	player:SetAttribute("IsStunned", true)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = CombatConfig.STUN_WALK_SPEED
	end

	task.delay(CombatConfig.COMBO_END_STUN_DURATION, function()
		playerStunned[player] = nil
		player:SetAttribute("IsStunned", false)

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

local function getAttackHitbox(attackerCharacter: Model): (CFrame?, Vector3?)
	local root = attackerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, nil
	end

	local torso = attackerCharacter:FindFirstChild("Torso") or attackerCharacter:FindFirstChild("UpperTorso")
	local yAdjust = if torso and torso:IsA("BasePart") then torso.Position.Y - root.Position.Y else 0

	local size = CombatConfig.HITBOX_SIZE
	local forwardOffset = CombatConfig.HITBOX_OFFSET + size.Z / 2
	local hitboxCFrame = root.CFrame * CFrame.new(0, yAdjust, -forwardOffset)

	return hitboxCFrame, size
end

local function getTargetsInFront(attackerCharacter: Model): { Humanoid }
	local hitboxCFrame, size = getAttackHitbox(attackerCharacter)
	if not hitboxCFrame or not size then
		return {}
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { attackerCharacter }

	local hitHumanoids: { Humanoid } = {}
	local alreadyHit: { [Humanoid]: boolean } = {}

	for _, part in workspace:GetPartBoundsInBox(hitboxCFrame, size, overlapParams) do
		local model = part:FindFirstAncestorOfClass("Model")
		if not model or model == attackerCharacter then
			continue
		end

		if model:FindFirstChild("Left Arm") and not model:FindFirstChild("CombatHitbox_LeftArm") then
			HumanoidHitbox.setup(model)
		end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid or alreadyHit[humanoid] or humanoid.Health <= 0 then
			continue
		end

		alreadyHit[humanoid] = true
		table.insert(hitHumanoids, humanoid)
	end

	return hitHumanoids
end

local function applyDamage(attacker: Player, humanoid: Humanoid, damage: number)
	if damage <= 0 then
		return
	end

	humanoid:TakeDamage(damage)

	local targetModel = humanoid.Parent
	if targetModel then
		local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
		if targetPlayer then
			print("[Rogue2]", attacker.Name, "golpeó a", targetPlayer.Name, "por", damage)
		end
	end
end

local function applyRagdollToTarget(attackerCharacter: Model, targetHumanoid: Humanoid)
	local targetModel = targetHumanoid.Parent
	if not targetModel then
		return
	end

	local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?

	local direction = Vector3.new(0, 0, -1)
	if attackerRoot and targetRoot then
		direction = (targetRoot.Position - attackerRoot.Position).Unit
	end

	Ragdoll.apply(targetModel, CombatConfig.RAGDOLL_DURATION, direction, CombatConfig.RAGDOLL_KNOCKBACK_DISTANCE)
end

local function performHit(attacker: Player, damage: number, shouldRagdoll: boolean?): boolean
	local character = attacker.Character
	if not character then
		return false
	end

	local hitAny = false
	local targets = getTargetsInFront(character)
	for _, humanoid in targets do
		hitAny = true
		applyDamage(attacker, humanoid, damage)

		if shouldRagdoll then
			applyRagdollToTarget(character, humanoid)
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
	if playerAttackLock[player] or playerStunned[player] then
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
				performHit(player, damage, comboIndex == 5)
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
				m2Hit = performHit(player, CombatConfig.M2_DAMAGE, true)
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
	playerLastAttack[player] = nil
	playerLastM2[player] = nil
	playerCombatTracks[player] = nil
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
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
