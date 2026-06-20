local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CombatHit = require(ReplicatedStorage.Shared.CombatHit)
local Ragdoll = require(ReplicatedStorage.Shared.Ragdoll)
local TrainingDummy = require(ReplicatedStorage.Shared.TrainingDummy)

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

		resetDummy(model, spawnCFrame)

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
	end

	print("[Rogue2] Dummy de entrenamiento:", config.name, "→", config.behavior)
end

for _, config in DUMMY_SPAWNS do
	spawnDummy(config)
end
