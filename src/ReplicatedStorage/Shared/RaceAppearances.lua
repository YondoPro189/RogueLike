export type BodyColorSet = {
	Head: Color3,
	Torso: Color3,
	LeftArm: Color3,
	RightArm: Color3,
	LeftLeg: Color3,
	RightLeg: Color3,
}

export type HighlightSet = {
	Fill: Color3,
	Outline: Color3,
	FillTransparency: number,
}

export type RaceAppearance = {
	BodyColors: BodyColorSet,
	Highlight: HighlightSet,
}

local APPEARANCES: { [string]: RaceAppearance } = {
	Vaelen = {
		BodyColors = {
			Head = Color3.fromRGB(225, 215, 200),
			Torso = Color3.fromRGB(120, 175, 220),
			LeftArm = Color3.fromRGB(110, 165, 210),
			RightArm = Color3.fromRGB(110, 165, 210),
			LeftLeg = Color3.fromRGB(95, 140, 185),
			RightLeg = Color3.fromRGB(95, 140, 185),
		},
		Highlight = {
			Fill = Color3.fromRGB(100, 180, 255),
			Outline = Color3.fromRGB(160, 220, 255),
			FillTransparency = 0.88,
		},
	},
	Gravelord = {
		BodyColors = {
			Head = Color3.fromRGB(145, 130, 115),
			Torso = Color3.fromRGB(85, 75, 68),
			LeftArm = Color3.fromRGB(100, 88, 78),
			RightArm = Color3.fromRGB(100, 88, 78),
			LeftLeg = Color3.fromRGB(90, 80, 72),
			RightLeg = Color3.fromRGB(90, 80, 72),
		},
		Highlight = {
			Fill = Color3.fromRGB(180, 120, 70),
			Outline = Color3.fromRGB(220, 160, 90),
			FillTransparency = 0.9,
		},
	},
	Ashborn = {
		BodyColors = {
			Head = Color3.fromRGB(180, 175, 185),
			Torso = Color3.fromRGB(70, 65, 80),
			LeftArm = Color3.fromRGB(85, 78, 95),
			RightArm = Color3.fromRGB(85, 78, 95),
			LeftLeg = Color3.fromRGB(75, 70, 88),
			RightLeg = Color3.fromRGB(75, 70, 88),
		},
		Highlight = {
			Fill = Color3.fromRGB(140, 120, 180),
			Outline = Color3.fromRGB(190, 170, 220),
			FillTransparency = 0.88,
		},
	},
}

local COSMETIC_CLASSES = {
	"Accessory",
	"Shirt",
	"Pants",
	"ShirtGraphic",
	"CharacterMesh",
}

local RaceAppearances = {}

function RaceAppearances.get(raceId: string): RaceAppearance?
	return APPEARANCES[raceId]
end

local function clearCosmetics(character: Model)
	for _, child in character:GetChildren() do
		if table.find(COSMETIC_CLASSES, child.ClassName) then
			child:Destroy()
		end
	end
end

local function applyBodyColors(character: Model, colors: BodyColorSet)
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = character
	end

	bodyColors.HeadColor3 = colors.Head
	bodyColors.TorsoColor3 = colors.Torso
	bodyColors.LeftArmColor3 = colors.LeftArm
	bodyColors.RightArmColor3 = colors.RightArm
	bodyColors.LeftLegColor3 = colors.LeftLeg
	bodyColors.RightLegColor3 = colors.RightLeg

	-- R6: aplicar color directo a cada parte del cuerpo
	local partColors = {
		Head = colors.Head,
		Torso = colors.Torso,
		["Left Arm"] = colors.LeftArm,
		["Right Arm"] = colors.RightArm,
		["Left Leg"] = colors.LeftLeg,
		["Right Leg"] = colors.RightLeg,
	}

	for partName, color in partColors do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.Color = color
		end
	end
end

local function applyHighlight(character: Model, highlightData: HighlightSet)
	local existing = character:FindFirstChild("RaceHighlight")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "RaceHighlight"
	highlight.Adornee = character
	highlight.FillColor = highlightData.Fill
	highlight.OutlineColor = highlightData.Outline
	highlight.FillTransparency = highlightData.FillTransparency
	highlight.OutlineTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
end

function RaceAppearances.apply(character: Model, raceId: string)
	local appearance = APPEARANCES[raceId]
	if not appearance then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		warn("[Rogue2] Se esperaba R6, pero el personaje es", humanoid.RigType.Name)
	end

	clearCosmetics(character)
	applyBodyColors(character, appearance.BodyColors)
	applyHighlight(character, appearance.Highlight)

	character:SetAttribute("RaceSkin", raceId)
end

function RaceAppearances.isR6Character(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
end

return RaceAppearances
