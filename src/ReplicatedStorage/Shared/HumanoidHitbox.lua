local CombatConfig = require(script.Parent.CombatConfig)

local HumanoidHitbox = {}

local R6_ARMS = { "Left Arm", "Right Arm" }

local R6_BODY_PARTS = { "HumanoidRootPart", "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local R15_BODY_PARTS = {
	"HumanoidRootPart",
	"UpperTorso",
	"LowerTorso",
	"Head",
	"LeftUpperArm",
	"RightUpperArm",
	"LeftLowerArm",
	"RightLowerArm",
	"LeftHand",
	"RightHand",
}

function HumanoidHitbox.cleanup(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 13) == "CombatHitbox_" then
			child:Destroy()
		end
	end
end

function HumanoidHitbox.setup(character: Model)
	HumanoidHitbox.cleanup(character)

	local padding = CombatConfig.ARM_HITBOX_PADDING

	for _, armName in R6_ARMS do
		local arm = character:FindFirstChild(armName)
		if not (arm and arm:IsA("BasePart")) then
			continue
		end

		local hitbox = Instance.new("Part")
		hitbox.Name = "CombatHitbox_" .. string.gsub(armName, " ", "")
		hitbox.Size = arm.Size + Vector3.new(padding * 2, padding * 2, padding * 2)
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.CanQuery = true
		hitbox.CanTouch = false
		hitbox.Massless = true
		hitbox.Anchored = false
		hitbox.CFrame = arm.CFrame
		hitbox.Parent = character

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = arm
		weld.Part1 = hitbox
		weld.Parent = hitbox
	end
end

function HumanoidHitbox.getHittableParts(character: Model): { BasePart }
	local partNames = if character:FindFirstChild("UpperTorso") then R15_BODY_PARTS else R6_BODY_PARTS
	local parts: { BasePart } = {}

	for _, name in partNames do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end

	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 13) == "CombatHitbox_" then
			table.insert(parts, child)
		end
	end

	return parts
end

return HumanoidHitbox
