local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local THEME = {
	Background = Color3.fromRGB(12, 12, 16),
	BackgroundTransparency = 0.25,
	Border = Color3.fromRGB(70, 65, 85),
	Text = Color3.fromRGB(230, 225, 235),
	TextMuted = Color3.fromRGB(150, 145, 160),
	Day = Color3.fromRGB(200, 185, 140),
	HealthFull = Color3.fromRGB(185, 45, 55),
	HealthLow = Color3.fromRGB(255, 85, 45),
	HealthBg = Color3.fromRGB(35, 30, 40),
	Lives = Color3.fromRGB(255, 200, 70),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Barra inferior centrada (estilo Rogue Lineage)
local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.AnchorPoint = Vector2.new(0.5, 1)
bottomBar.Position = UDim2.new(0.5, 0, 1, -16)
bottomBar.Size = UDim2.fromOffset(540, 36)
bottomBar.BackgroundColor3 = THEME.Background
bottomBar.BackgroundTransparency = THEME.BackgroundTransparency
bottomBar.BorderSizePixel = 0
bottomBar.Parent = screenGui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 6)
barCorner.Parent = bottomBar

local barStroke = Instance.new("UIStroke")
barStroke.Color = THEME.Border
barStroke.Thickness = 1
barStroke.Transparency = 0.5
barStroke.Parent = bottomBar

local barPadding = Instance.new("UIPadding")
barPadding.PaddingLeft = UDim.new(0, 14)
barPadding.PaddingRight = UDim.new(0, 14)
barPadding.Parent = bottomBar

local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
barLayout.Padding = UDim.new(0, 14)
barLayout.SortOrder = Enum.SortOrder.LayoutOrder
barLayout.Parent = bottomBar

-- Días (izquierda)
local dayLabel = Instance.new("TextLabel")
dayLabel.Name = "DayLabel"
dayLabel.LayoutOrder = 1
dayLabel.Size = UDim2.fromOffset(140, 24)
dayLabel.BackgroundTransparency = 1
dayLabel.Font = Enum.Font.GothamBold
dayLabel.TextSize = 15
dayLabel.TextColor3 = THEME.Day
dayLabel.TextXAlignment = Enum.TextXAlignment.Left
dayLabel.Text = "Day 1"
dayLabel.Parent = bottomBar

-- Barra de HP (centro)
local healthContainer = Instance.new("Frame")
healthContainer.Name = "HealthContainer"
healthContainer.LayoutOrder = 2
healthContainer.Size = UDim2.fromOffset(260, 18)
healthContainer.BackgroundTransparency = 1
healthContainer.Parent = bottomBar

local healthBarBg = Instance.new("Frame")
healthBarBg.Name = "HealthBarBg"
healthBarBg.Size = UDim2.new(1, 0, 1, 0)
healthBarBg.BackgroundColor3 = THEME.HealthBg
healthBarBg.BorderSizePixel = 0
healthBarBg.Parent = healthContainer

local healthBarBgCorner = Instance.new("UICorner")
healthBarBgCorner.CornerRadius = UDim.new(0, 4)
healthBarBgCorner.Parent = healthBarBg

local healthBarFill = Instance.new("Frame")
healthBarFill.Name = "HealthBarFill"
healthBarFill.Size = UDim2.new(1, 0, 1, 0)
healthBarFill.BackgroundColor3 = THEME.HealthFull
healthBarFill.BorderSizePixel = 0
healthBarFill.Parent = healthBarBg

local healthBarFillCorner = Instance.new("UICorner")
healthBarFillCorner.CornerRadius = UDim.new(0, 4)
healthBarFillCorner.Parent = healthBarFill

local healthText = Instance.new("TextLabel")
healthText.Name = "HealthText"
healthText.Size = UDim2.new(1, 0, 1, 0)
healthText.BackgroundTransparency = 1
healthText.Font = Enum.Font.GothamBold
healthText.TextSize = 12
healthText.TextColor3 = THEME.Text
healthText.Text = "100 / 100"
healthText.ZIndex = 2
healthText.Parent = healthContainer

-- Vidas (derecha)
local livesLabel = Instance.new("TextLabel")
livesLabel.Name = "LivesLabel"
livesLabel.LayoutOrder = 3
livesLabel.Size = UDim2.fromOffset(72, 24)
livesLabel.BackgroundTransparency = 1
livesLabel.Font = Enum.Font.GothamBold
livesLabel.TextSize = 15
livesLabel.TextColor3 = THEME.Lives
livesLabel.TextXAlignment = Enum.TextXAlignment.Right
livesLabel.Text = "♥ ♥ ♥"
livesLabel.Parent = bottomBar

local function updateDay(day: number)
	local raceId = player:GetAttribute("Race")
	if raceId then
		local raceName = player:GetAttribute("Lineage") or raceId
		dayLabel.Text = raceName .. "  ·  Day " .. tostring(day)
	else
		dayLabel.Text = "Day " .. tostring(day)
	end
end

local function updateLives()
	local lives = player:GetAttribute("Lives")
	if lives then
		livesLabel.Text = string.rep("♥ ", lives)
	else
		livesLabel.Text = "--"
	end
end

local function refreshDayLabel()
	local gameState = ReplicatedStorage:FindFirstChild("GameState")
	local dayValue = gameState and gameState:FindFirstChild("Day")
	updateDay(dayValue and dayValue.Value or 1)
end

local function getHealthColor(ratio: number): Color3
	if ratio <= 0.25 then
		return THEME.HealthLow
	end
	return THEME.HealthFull
end

local function updateHealth(humanoid: Humanoid?)
	if not humanoid then
		healthBarFill.Size = UDim2.new(0, 0, 1, 0)
		healthText.Text = "-- / --"
		return
	end

	local health = math.floor(humanoid.Health)
	local maxHealth = math.floor(humanoid.MaxHealth)
	local ratio = maxHealth > 0 and (humanoid.Health / maxHealth) or 0

	healthText.Text = string.format("%d / %d", health, maxHealth)
	healthBarFill.BackgroundColor3 = getHealthColor(ratio)
	healthBarFill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	updateLives()
	updateHealth(humanoid)

	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		updateHealth(humanoid)
	end)

	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		updateHealth(humanoid)
	end)
end

local function connectDayValue()
	local gameState = ReplicatedStorage:WaitForChild("GameState")
	local dayValue = gameState:WaitForChild("Day") :: IntValue

	updateDay(dayValue.Value)
	dayValue.Changed:Connect(updateDay)
end

player:GetAttributeChangedSignal("Lives"):Connect(updateLives)
player:GetAttributeChangedSignal("Race"):Connect(refreshDayLabel)
player:GetAttributeChangedSignal("Lineage"):Connect(refreshDayLabel)

if player.Character then
	onCharacterAdded(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)

task.defer(function()
	updateLives()
	connectDayValue()
end)
