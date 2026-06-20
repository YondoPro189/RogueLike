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
	return blockerRoot.CFrame.LookVector:Dot(toAttacker) > 0
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

	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	if targetPlayer then
		return CombatConfig.BLOCK_DAMAGE_MULTIPLIER
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

	local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
	if targetPlayer then
		return false
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
	ragdollKnockback: number?
)
	local damageMultiplier = CombatHit.getBlockDamageMultiplier(targetHumanoid, attackerCharacter)
	damage = math.floor(damage * damageMultiplier)

	if damage <= 0 then
		return
	end

	targetHumanoid:TakeDamage(damage)

	if shouldRagdoll and CombatHit.shouldRagdollBlockedTarget(targetHumanoid, attackerCharacter) then
		local targetModel = targetHumanoid.Parent
		if not targetModel then
			return
		end

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
	end
end

return CombatHit
