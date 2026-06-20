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
local isStunned = false
local currentCharacter: Model? = nil
local currentHumanoid: Humanoid? = nil
local punchTracks: { AnimationTrack } = {}
local m2Track: AnimationTrack? = nil
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
		and not player:GetAttribute("IsStunned")
		and not player:GetAttribute("IsRagdolled")
end

local function restoreWalkSpeed()
	if not currentHumanoid then
		return
	end

	currentHumanoid.WalkSpeed = player:GetAttribute("WalkSpeed") or 16
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

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.F then
		if gameProcessed then
			return
		end
		startBlocking()
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
	isStunned = false
	stopCurrentAttackAnimation()
	player:SetAttribute("IsAttacking", false)
	player:SetAttribute("IsStunned", false)
	player:SetAttribute("IsRagdolled", false)
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
	end

	if isStunned and currentHumanoid then
		currentHumanoid.WalkSpeed = CombatConfig.STUN_WALK_SPEED
	elseif currentHumanoid and not isAttacking and not isBlocking then
		restoreWalkSpeed()
	end
end)

player:GetAttributeChangedSignal("IsRagdolled"):Connect(function()
	if player:GetAttribute("IsRagdolled") then
		stopBlocking()
	end
end)

player:GetAttributeChangedSignal("IsBlocking"):Connect(function()
	applyBlockingState(player:GetAttribute("IsBlocking") == true)
end)
