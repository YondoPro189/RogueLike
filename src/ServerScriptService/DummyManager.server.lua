local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CombatHit = require(ReplicatedStorage.Shared.CombatHit)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local TrainingDummy = require(ReplicatedStorage.Shared.TrainingDummy)
local BlockAnimation = require(ReplicatedStorage.Shared.BlockAnimation)

local DUMMY_SPAWNS = {
	{
		name = "DummyIdle",
		behavior = "Idle" :: TrainingDummy.DummyBehavior,
		position = Vector3.new(0, 5, 18),
		color = "Medium stone grey",
	},
	{
		name = "DummyBlocking",
		behavior = "Blocking" :: TrainingDummy.DummyBehavior,
		position = Vector3.new(10, 5, 18),
		color = "Bright blue",
	},
	{
		name = "DummyAttacking",
		behavior = "Attacking" :: TrainingDummy.DummyBehavior,
		position = Vector3.new(-10, 5, 18),
		color = "Bright red",
	},
	{
		name = "DummyAttackingM2",
		behavior = "AttackingM2" :: TrainingDummy.DummyBehavior,
		position = Vector3.new(-20, 5, 18),
		color = "Dark orange",
	},
}

local ATTACK_RANGE = 14
local ATTACK_COMBO_INDEX = 1

local dummiesFolder: Folder
local dummyTracks: { [Model]: TrainingDummy.CombatTracks } = {}

local function getDummiesFolder(): Folder
	if dummiesFolder and dummiesFolder.Parent then
		return dummiesFolder
	end

	dummiesFolder = workspace:FindFirstChild("TrainingDummies") :: Folder?
	if not dummiesFolder then
		dummiesFolder = Instance.new("Folder")
		dummiesFolder.Name = "TrainingDummies"
		dummiesFolder.Parent = workspace
	end

	return dummiesFolder
end

local function resetDummy(model: Model, spawnCFrame: CFrame)
	Ragdoll.restore(model)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end

	model:PivotTo(spawnCFrame)
end

local function setupDummyRespawn(model: Model, spawnCFrame: CFrame, behavior: TrainingDummy.DummyBehavior)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.Died:Connect(function()
		task.wait(3)
		if not model.Parent then
			return
		end

		local currentSpawnCFrame = model:GetAttribute("SpawnCFrame") or spawnCFrame
		resetDummy(model, currentSpawnCFrame)

		if behavior == "Blocking" then
			local tracks = dummyTracks[model]
			if tracks then
				setupBlockingDummy(model, tracks)
			end
		end
	end)
end

local function setupBlockingDummy(model: Model, tracks: TrainingDummy.CombatTracks)
	model:SetAttribute("IsBlocking", true)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = CombatConfig.BLOCK_WALK_SPEED
	end

	TrainingDummy.playBlock(tracks)

	if model:GetAttribute("ListenersSetup") then
		return
	end
	model:SetAttribute("ListenersSetup", true)

	model:GetAttributeChangedSignal("IsBlocking"):Connect(function()
		local isBlocking = model:GetAttribute("IsBlocking") == true
		if not isBlocking then
			if tracks.block then
				BlockAnimation.stop(tracks.block)
			end
			if humanoid then
				humanoid.WalkSpeed = 0
			end
		else
			if humanoid then
				humanoid.WalkSpeed = CombatConfig.BLOCK_WALK_SPEED
			end
			TrainingDummy.playBlock(tracks)
		end
	end)

	model:GetAttributeChangedSignal("IsStunned"):Connect(function()
		local isStunned = model:GetAttribute("IsStunned") == true
		if isStunned then
			model:SetAttribute("IsBlocking", false)
		else
			if model.Parent and humanoid and humanoid.Health > 0 then
				model:SetAttribute("IsBlocking", true)
			end
		end
	end)
end

local function getNearestPlayerInRange(origin: Vector3, maxRange: number): Player?
	local nearestPlayer: Player? = nil
	local nearestDistance = maxRange

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if not root or not humanoid or humanoid.Health <= 0 then
			continue
		end

		local distance = (root.Position - origin).Magnitude
		if distance <= nearestDistance then
			nearestDistance = distance
			nearestPlayer = player
		end
	end

	return nearestPlayer
end

local function faceTarget(model: Model, targetPosition: Vector3)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local flatTarget = Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z)
	if (flatTarget - root.Position).Magnitude < 0.1 then
		return
	end

	root.CFrame = CFrame.lookAt(root.Position, flatTarget)
end

local function dummyAttack(model: Model, tracks: TrainingDummy.CombatTracks, damage: number)
	if model:GetAttribute("IsStunned") or model:GetAttribute("IsRagdolled") or Ragdoll.isActive(model) then
		return
	end

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local nearestPlayer = getNearestPlayerInRange(root.Position, ATTACK_RANGE)
	if not nearestPlayer or not nearestPlayer.Character then
		return
	end

	local targetRoot = nearestPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	faceTarget(model, targetRoot.Position)

	local toTarget = (targetRoot.Position - root.Position).Unit
	if root.CFrame.LookVector:Dot(toTarget) < 0.35 then
		return
	end

	TrainingDummy.playPunch(tracks, ATTACK_COMBO_INDEX)

	task.delay(CombatConfig.PUNCH_HIT_DELAY, function()
		if not model.Parent then
			return
		end

		for _, humanoid in CombatHit.getTargetsInFront(model) do
			local targetModel = humanoid.Parent
			if not targetModel or not Players:GetPlayerFromCharacter(targetModel) then
				continue
			end

			CombatHit.applyDamage(model, humanoid, damage, false)
		end
	end)
end

local function setupAttackingDummy(model: Model, tracks: TrainingDummy.CombatTracks)
	local damage = CombatConfig.PUNCH_DAMAGE[ATTACK_COMBO_INDEX] or 5

	task.spawn(function()
		while model.Parent do
			task.wait(CombatConfig.PUNCH_COOLDOWN + CombatConfig.PUNCH_ATTACK_DURATION)
			if model.Parent then
				dummyAttack(model, tracks, damage)
			end
		end
	end)
end

local function dummyAttackM2(model: Model, tracks: TrainingDummy.CombatTracks, damage: number)
	if model:GetAttribute("IsStunned") or model:GetAttribute("IsRagdolled") or Ragdoll.isActive(model) then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local nearestPlayer = getNearestPlayerInRange(root.Position, ATTACK_RANGE)
	if not nearestPlayer or not nearestPlayer.Character then
		return
	end

	local targetRoot = nearestPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	faceTarget(model, targetRoot.Position)

	local toTarget = (targetRoot.Position - root.Position).Unit
	if root.CFrame.LookVector:Dot(toTarget) < 0.35 then
		return
	end

	TrainingDummy.playM2(tracks)

	task.delay(CombatConfig.M2_HIT_DELAY, function()
		if not model.Parent or humanoid.Health <= 0 then
			return
		end

		for _, targetHumanoid in CombatHit.getTargetsInFront(model) do
			local targetModel = targetHumanoid.Parent
			if not targetModel or not Players:GetPlayerFromCharacter(targetModel) then
				continue
			end

			CombatHit.applyDamage(
				model,
				targetHumanoid,
				damage,
				true,
				CombatConfig.RAGDOLL_DURATION,
				CombatConfig.RAGDOLL_KNOCKBACK_DISTANCE,
				true
			)
		end
	end)
end

local function setupAttackingM2Dummy(model: Model, tracks: TrainingDummy.CombatTracks)
	local damage = CombatConfig.M2_DAMAGE

	task.spawn(function()
		while model.Parent do
			task.wait(CombatConfig.M2_COOLDOWN + CombatConfig.M2_ATTACK_DURATION)
			if model.Parent then
				dummyAttackM2(model, tracks, damage)
			end
		end
	end)
end

local function spawnDummy(config: typeof(DUMMY_SPAWNS[1]))
	local model = TrainingDummy.create(config.name, config.position, config.behavior, config.color)
	local spawnCFrame = model:GetPivot()
	model.Parent = getDummiesFolder()

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local tracks = TrainingDummy.loadCombatAnimations(humanoid)
	dummyTracks[model] = tracks
	setupDummyRespawn(model, spawnCFrame, config.behavior)

	if config.behavior == "Blocking" then
		setupBlockingDummy(model, tracks)
	elseif config.behavior == "Attacking" then
		setupAttackingDummy(model, tracks)
	elseif config.behavior == "AttackingM2" then
		setupAttackingM2Dummy(model, tracks)
	end

	print("[Rogue2] Dummy de entrenamiento:", config.name, "→", config.behavior)
end

for _, config in DUMMY_SPAWNS do
	spawnDummy(config)
end

local dummiesPositioned = false

local function positionDummiesNearPlayer(character: Model)
	if dummiesPositioned then
		return
	end
	dummiesPositioned = true

	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end

	task.wait(1) -- Wait a brief moment for character to settle

	local playerCF = root.CFrame

	-- Offsets for each dummy behavior relative to player
	local offsets = {
		Idle = CFrame.new(12, 0, -15),
		Blocking = CFrame.new(4, 0, -15),
		Attacking = CFrame.new(-4, 0, -15),
		AttackingM2 = CFrame.new(-12, 0, -15),
	}

	-- Find all dummies in the folder and reposition them
	local folder = getDummiesFolder()
	for _, dummy in folder:GetChildren() do
		if dummy:IsA("Model") then
			local behavior = dummy:GetAttribute("DummyBehavior")
			local offset = offsets[behavior]
			if offset then
				local newCFrame = playerCF * offset
				-- Make the dummy face the player's position
				local targetCFrame = CFrame.lookAt(newCFrame.Position, Vector3.new(playerCF.Position.X, newCFrame.Position.Y, playerCF.Position.Z))
				dummy:SetAttribute("SpawnCFrame", targetCFrame)
				dummy:PivotTo(targetCFrame)
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		positionDummiesNearPlayer(character)
	end)
	if player.Character then
		positionDummiesNearPlayer(player.Character)
	end
end)

for _, player in Players:GetPlayers() do
	if player.Character then
		positionDummiesNearPlayer(player.Character)
	end
end
