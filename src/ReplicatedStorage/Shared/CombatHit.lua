local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local HumanoidHitbox = require(ReplicatedStorage.Shared.HumanoidHitbox)

local CombatHit = {}

local serverBlockingPlayers: { [Player]: boolean } = {}

function CombatHit.setPlayerBlocking(player: Player, isBlocking: boolean)
	if isBlocking then
		serverBlockingPlayers[player] = true
	else
		serverBlockingPlayers[player] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	serverBlockingPlayers[player] = nil
end)

function CombatHit.isBlockingFromFront(blockerCharacter: Model, attackerCharacter: Model): boolean
	local blockerRoot = blockerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not blockerRoot or not attackerRoot then
		return false
	end

	local toAttacker = (attackerRoot.Position - blockerRoot.Position).Unit
	local angleLimitRad = math.rad(CombatConfig.BLOCK_ANGLE / 2)
	local cosLimit = math.cos(angleLimitRad)
	return blockerRoot.CFrame.LookVector:Dot(toAttacker) >= cosLimit
end

function CombatHit.isTargetBlocking(targetModel: Model): boolean
	if targetModel:GetAttribute("IsBlocking") == true then
		return true
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	if targetPlayer then
		return serverBlockingPlayers[targetPlayer] == true
			or targetPlayer:GetAttribute("IsBlocking") == true
	end

	return false
end

function CombatHit.getBlockDamageMultiplier(targetHumanoid: Humanoid, attackerCharacter: Model): number
	local targetModel = targetHumanoid.Parent
	if not targetModel then
		return 1
	end

	if not CombatHit.isTargetBlocking(targetModel) then
		return 1
	end

	if CombatHit.isBlockingFromFront(targetModel, attackerCharacter) then
		return CombatConfig.BLOCK_DAMAGE_MULTIPLIER
	end

	return 1
end

function CombatHit.shouldRagdollBlockedTarget(targetHumanoid: Humanoid, attackerCharacter: Model): boolean
	local targetModel = targetHumanoid.Parent
	if not targetModel then
		return true
	end

	if not CombatHit.isTargetBlocking(targetModel) then
		return true
	end

	return not CombatHit.isBlockingFromFront(targetModel, attackerCharacter)
end

function CombatHit.getAttackHitbox(attackerCharacter: Model): (CFrame?, Vector3?)
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

function CombatHit.getTargetsInFront(attackerCharacter: Model): { Humanoid }
	local hitboxCFrame, size = CombatHit.getAttackHitbox(attackerCharacter)
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

function CombatHit.applyDamage(
	attackerCharacter: Model,
	targetHumanoid: Humanoid,
	damage: number,
	shouldRagdoll: boolean?,
	ragdollDuration: number?,
	ragdollKnockback: number?,
	isM2: boolean?
)
	local targetModel = targetHumanoid.Parent
	if not targetModel then
		return
	end

	local isBlocking = CombatHit.isTargetBlocking(targetModel)
	local isBlockedFromFront = isBlocking and CombatHit.isBlockingFromFront(targetModel, attackerCharacter)
	local blockBroken = false
	local isPerfectBlock = false

	if isM2 and isBlocking and isBlockedFromFront then
		local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
		if targetPlayer then
			local blockStart = targetPlayer:GetAttribute("BlockStartTime")
			local blockAge = os.clock() - (blockStart or -math.huge)
			local window = CombatConfig.PERFECT_BLOCK_WINDOW or 0.4
			if blockAge <= window then
				isPerfectBlock = true
			else
				blockBroken = true
			end
		else
			blockBroken = true
		end
	end

	if isPerfectBlock then
		local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
		if targetPlayer then
			targetPlayer:SetAttribute("PerfectBlockTrigger", os.clock())
		end

		local attackerPlayer = Players:GetPlayerFromCharacter(attackerCharacter)
		if attackerPlayer then
			local bindables = ReplicatedStorage:FindFirstChild("Bindables")
			local breakBlockEvent = bindables and bindables:FindFirstChild("BreakBlockAndStun") :: BindableEvent?
			if breakBlockEvent then
				breakBlockEvent:Fire(attackerPlayer, CombatConfig.PERFECT_BLOCK_STUN_DURATION or 1.0)
			end
		else
			-- Dummy / NPC
			attackerCharacter:SetAttribute("IsStunned", true)
			local attackerHumanoid = attackerCharacter:FindFirstChildOfClass("Humanoid")
			if attackerHumanoid then
				attackerHumanoid.WalkSpeed = CombatConfig.STUN_WALK_SPEED or 0
			end
			task.delay(CombatConfig.PERFECT_BLOCK_STUN_DURATION or 1.0, function()
				if attackerCharacter.Parent then
					attackerCharacter:SetAttribute("IsStunned", false)
				end
			end)
		end
		return
	end

	local multiplier = 1
	if isBlocking and not blockBroken then
		multiplier = CombatHit.getBlockDamageMultiplier(targetHumanoid, attackerCharacter)
	end

	damage = math.floor(damage * multiplier)

	if damage <= 0 then
		return
	end

	targetHumanoid:TakeDamage(damage)

	if blockBroken then
		local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
		if targetPlayer then
			local bindables = ReplicatedStorage:FindFirstChild("Bindables")
			local breakBlockEvent = bindables and bindables:FindFirstChild("BreakBlockAndStun") :: BindableEvent?
			if breakBlockEvent then
				breakBlockEvent:Fire(targetPlayer, CombatConfig.BLOCK_BREAK_STUN_DURATION)
			end
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
	elseif shouldRagdoll and CombatHit.shouldRagdollBlockedTarget(targetHumanoid, attackerCharacter) then
		local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
		local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?

		local direction = Vector3.new(0, 0, -1)
		if attackerRoot and targetRoot then
			direction = (targetRoot.Position - attackerRoot.Position).Unit
		end

		Ragdoll.apply(
			targetModel,
			ragdollDuration or CombatConfig.RAGDOLL_DURATION,
			direction,
			ragdollKnockback or CombatConfig.RAGDOLL_KNOCKBACK_DISTANCE
		)
	else
		-- Si no se bloqueó y no es un golpe con ragdoll final, aplicar hit stun común a los jugadores
		local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
		if targetPlayer and not isBlocking then
			-- El cliente escucha "IsStunned" vía attribute changed. Vamos a setear los atributos para stunear al jugador.
			targetPlayer:SetAttribute("IsStunned", true)
			local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
			if targetHumanoid then
				targetHumanoid.WalkSpeed = CombatConfig.STUN_WALK_SPEED or 0
			end
			task.delay(CombatConfig.HIT_STUN_DURATION or 0.35, function()
				if targetPlayer and targetPlayer.Parent then
					targetPlayer:SetAttribute("IsStunned", false)
					if targetHumanoid and targetHumanoid.Health > 0 then
						targetHumanoid.WalkSpeed = targetPlayer:GetAttribute("WalkSpeed") or 16
					end
				end
			end)
		end
	end
end

return CombatHit
