local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local playerLastAttack: { [Player]: number } = {}
local playerLastM2: { [Player]: number } = {}
local playerCombatTracks: { [Player]: { punch: { AnimationTrack }, m2: AnimationTrack, block: AnimationTrack? } } = {}

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

	playerCombatTracks[player] = {
		punch = punchTracks,
		m2 = m2Track,
		block = blockTrack,
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

local function applyStun(player: Player, duration: number)
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
				elseif targetModel:GetAttribute("IsTrainingDummy") then
					print("[Rogue2]", attacker.Name, "golpeó a", targetModel.Name, "por", finalDamage)
				end
			end
		end

		if blockBroken then
			if targetModel then
				local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
				if targetPlayer then
					endBlock(targetPlayer)
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
	end

	if playerAttackLock[player] or playerStunned[player] or playerBlocking[player] then
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
	CombatHit.setPlayerBlocking(player, false)
	playerLastAttack[player] = nil
	playerLastM2[player] = nil
	playerCombatTracks[player] = nil
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		endBlock(player)
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

