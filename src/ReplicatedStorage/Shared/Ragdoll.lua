local Players = game:GetService("Players")

export type RagdollData = {
	motors: { Motor6D },
	attachments: { Attachment },
	constraints: { BallSocketConstraint },
	collideStates: { [BasePart]: boolean },
}

local activeRagdolls: { [Model]: RagdollData } = {}

local Ragdoll = {}

local function getPlayerFromCharacter(character: Model): Player?
	return Players:GetPlayerFromCharacter(character)
end

function Ragdoll.isActive(character: Model): boolean
	return activeRagdolls[character] ~= nil
end

function Ragdoll.restore(character: Model)
	local data = activeRagdolls[character]
	if not data then
		return
	end

	for _, constraint in data.constraints do
		constraint:Destroy()
	end

	for _, attachment in data.attachments do
		attachment:Destroy()
	end

	for _, motor in data.motors do
		if motor.Parent then
			motor.Enabled = true
		end
	end

	for part, wasCollidable in data.collideStates do
		if part.Parent then
			part.CanCollide = wasCollidable
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	local player = getPlayerFromCharacter(character)
	if player then
		player:SetAttribute("IsRagdolled", false)
	end

	activeRagdolls[character] = nil
end

local function applyKnockback(root: BasePart, direction: Vector3, distance: number)
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude < 0.001 then
		horizontal = Vector3.new(0, 0, -1)
	else
		horizontal = horizontal.Unit
	end

	local pushDuration = 0.18
	local horizontalSpeed = distance / pushDuration

	local attachment = Instance.new("Attachment")
	attachment.Name = "RagdollKnockbackAttachment"
	attachment.Parent = root

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "RagdollKnockback"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = horizontal * horizontalSpeed + Vector3.new(0, distance * 0.35, 0)
	linearVelocity.MaxForce = math.huge
	linearVelocity.Parent = root

	task.delay(pushDuration, function()
		if linearVelocity.Parent then
			linearVelocity:Destroy()
		end
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
end

function Ragdoll.apply(character: Model, duration: number, knockbackDirection: Vector3?, knockbackDistance: number?)
	if duration <= 0 then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if activeRagdolls[character] then
		Ragdoll.restore(character)
	end

	local data: RagdollData = {
		motors = {},
		attachments = {},
		constraints = {},
		collideStates = {},
	}

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local motor = descendant
			local part0 = motor.Part0
			local part1 = motor.Part1
			if not part0 or not part1 then
				continue
			end

			local attachment0 = Instance.new("Attachment")
			local attachment1 = Instance.new("Attachment")
			attachment0.CFrame = motor.C0
			attachment1.CFrame = motor.C1
			attachment0.Parent = part0
			attachment1.Parent = part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = attachment0
			socket.Attachment1 = attachment1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.Parent = part0

			motor.Enabled = false

			table.insert(data.motors, motor)
			table.insert(data.attachments, attachment0)
			table.insert(data.attachments, attachment1)
			table.insert(data.constraints, socket)
		elseif descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			data.collideStates[descendant] = descendant.CanCollide
			descendant.CanCollide = true
		end
	end

	activeRagdolls[character] = data

	if root and knockbackDirection and knockbackDistance and knockbackDistance > 0 then
		applyKnockback(root, knockbackDirection, knockbackDistance)
	end

	local player = getPlayerFromCharacter(character)
	if player then
		player:SetAttribute("IsRagdolled", true)
	end

	humanoid.Died:Once(function()
		activeRagdolls[character] = nil
		if player then
			player:SetAttribute("IsRagdolled", false)
		end
	end)

	task.delay(duration, function()
		if activeRagdolls[character] then
			Ragdoll.restore(character)
		end
	end)
end

function Ragdoll.cleanupCharacter(character: Model)
	Ragdoll.restore(character)
end

return Ragdoll
