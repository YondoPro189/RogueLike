local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local BlockAnimation = require(ReplicatedStorage.Shared.BlockAnimation)
local HumanoidHitbox = require(ReplicatedStorage.Shared.HumanoidHitbox)

export type DummyBehavior = "Idle" | "Blocking" | "Attacking" | "AttackingM2"

export type CombatTracks = {
	punch: { AnimationTrack },
	block: AnimationTrack?,
	m2: AnimationTrack?,
}

local TrainingDummy = {}

local DUMMY_MAX_HEALTH = 500

local function colorModel(model: Model, colorName: string)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.BrickColor = BrickColor.new(colorName)
		end
	end
end

function TrainingDummy.loadCombatAnimations(humanoid: Humanoid): CombatTracks
	local punchTracks: { AnimationTrack } = {}
	for _, animationId in CombatConfig.PUNCH_ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		local track = humanoid:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		track:AdjustSpeed(CombatConfig.PUNCH_ANIMATION_SPEED)
		table.insert(punchTracks, track)
	end

	local blockTrack: AnimationTrack? = nil
	if CombatConfig.BLOCK_ANIMATION ~= "" then
		local blockAnimation = Instance.new("Animation")
		blockAnimation.AnimationId = CombatConfig.BLOCK_ANIMATION
		blockTrack = humanoid:LoadAnimation(blockAnimation)
		BlockAnimation.configureTrack(blockTrack)
	end

	local m2Track: AnimationTrack? = nil
	if CombatConfig.M2_ANIMATION ~= "" then
		local m2Animation = Instance.new("Animation")
		m2Animation.AnimationId = CombatConfig.M2_ANIMATION
		m2Track = humanoid:LoadAnimation(m2Animation)
		m2Track.Priority = Enum.AnimationPriority.Action
	end

	return {
		punch = punchTracks,
		block = blockTrack,
		m2 = m2Track,
	}
end

function TrainingDummy.create(name: string, position: Vector3, behavior: DummyBehavior, colorName: string): Model
	local description = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	model.Name = name

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		error("[Rogue2] No se pudo crear el dummy " .. name)
	end

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.MaxHealth = DUMMY_MAX_HEALTH
	humanoid.Health = DUMMY_MAX_HEALTH
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	colorModel(model, colorName)
	HumanoidHitbox.setup(model)

	model:SetAttribute("IsTrainingDummy", true)
	model:SetAttribute("DummyBehavior", behavior)

	local lookAt = Vector3.new(0, position.Y, position.Z - 10)
	model:PivotTo(CFrame.lookAt(position, lookAt))

	return model
end

function TrainingDummy.playPunch(tracks: CombatTracks, comboIndex: number)
	local track = tracks.punch[comboIndex]
	if track then
		track:Play()
	end
end

function TrainingDummy.playBlock(tracks: CombatTracks)
	if tracks.block then
		BlockAnimation.play(tracks.block)
	end
end

function TrainingDummy.playM2(tracks: CombatTracks)
	if tracks.m2 then
		tracks.m2:Play()
	end
end

return TrainingDummy
