local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
	ManaFull = Color3.fromRGB(0, 150, 255),
	ManaCharging = Color3.fromRGB(0, 220, 255),
	ManaBg = Color3.fromRGB(20, 25, 35),
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
bottomBar.Size = UDim2.fromOffset(540, 50)
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

-- Contenedor de estadísticas (centro, HP + Mana)
local statsContainer = Instance.new("Frame")
statsContainer.Name = "StatsContainer"
statsContainer.LayoutOrder = 2
statsContainer.Size = UDim2.fromOffset(260, 36)
statsContainer.BackgroundTransparency = 1
statsContainer.Parent = bottomBar

local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection = Enum.FillDirection.Vertical
statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
statsLayout.Padding = UDim.new(0, 4)
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsContainer

-- Barra de HP (dentro de statsContainer)
local healthContainer = Instance.new("Frame")
healthContainer.Name = "HealthContainer"
healthContainer.LayoutOrder = 1
healthContainer.Size = UDim2.new(1, 0, 0, 16)
healthContainer.BackgroundTransparency = 1
healthContainer.Parent = statsContainer

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
healthText.TextSize = 11
healthText.TextColor3 = THEME.Text
healthText.Text = "100 / 100"
healthText.ZIndex = 2
healthText.Parent = healthContainer

-- Barra de Maná (dentro de statsContainer)
local manaContainer = Instance.new("Frame")
manaContainer.Name = "ManaContainer"
manaContainer.LayoutOrder = 2
manaContainer.Size = UDim2.new(1, 0, 0, 16)
manaContainer.BackgroundTransparency = 1
manaContainer.Parent = statsContainer

local manaBarBg = Instance.new("Frame")
manaBarBg.Name = "ManaBarBg"
manaBarBg.Size = UDim2.new(1, 0, 1, 0)
manaBarBg.BackgroundColor3 = THEME.ManaBg
manaBarBg.BorderSizePixel = 0
manaBarBg.Parent = manaContainer

local manaBarBgCorner = Instance.new("UICorner")
manaBarBgCorner.CornerRadius = UDim.new(0, 4)
manaBarBgCorner.Parent = manaBarBg

local manaBarFill = Instance.new("Frame")
manaBarFill.Name = "ManaBarFill"
manaBarFill.Size = UDim2.new(0, 0, 1, 0)
manaBarFill.BackgroundColor3 = THEME.ManaFull
manaBarFill.BorderSizePixel = 0
manaBarFill.Parent = manaBarBg

local manaBarFillCorner = Instance.new("UICorner")
manaBarFillCorner.CornerRadius = UDim.new(0, 4)
manaBarFillCorner.Parent = manaBarFill

local manaText = Instance.new("TextLabel")
manaText.Name = "ManaText"
manaText.Size = UDim2.new(1, 0, 1, 0)
manaText.BackgroundTransparency = 1
manaText.Font = Enum.Font.GothamBold
manaText.TextSize = 11
manaText.TextColor3 = THEME.Text
manaText.Text = "0 / 100"
manaText.ZIndex = 2
manaText.Parent = manaContainer

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

local manaPulseTween: Tween? = nil

local function updateMana()
	local mana = player:GetAttribute("Mana") or 0
	local maxMana = player:GetAttribute("MaxMana") or 100
	local ratio = maxMana > 0 and (mana / maxMana) or 0

	manaText.Text = string.format("%d / %d", math.floor(mana), math.floor(maxMana))
	manaBarFill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
end

local function updateManaChargingVisuals()
	local isCharging = player:GetAttribute("IsChargingMana") == true
	if isCharging then
		if not manaPulseTween then
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
			manaPulseTween = TweenService:Create(manaBarFill, tweenInfo, {
				BackgroundColor3 = THEME.ManaCharging
			})
			manaPulseTween:Play()
		end
	else
		if manaPulseTween then
			manaPulseTween:Cancel()
			manaPulseTween = nil
		end
		TweenService:Create(manaBarFill, TweenInfo.new(0.2), {
			BackgroundColor3 = THEME.ManaFull
		}):Play()
	end
end

player:GetAttributeChangedSignal("Lives"):Connect(updateLives)
player:GetAttributeChangedSignal("Race"):Connect(refreshDayLabel)
player:GetAttributeChangedSignal("Lineage"):Connect(refreshDayLabel)
player:GetAttributeChangedSignal("Mana"):Connect(updateMana)
player:GetAttributeChangedSignal("MaxMana"):Connect(updateMana)
player:GetAttributeChangedSignal("IsChargingMana"):Connect(updateManaChargingVisuals)

if player.Character then
	onCharacterAdded(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)

task.defer(function()
	updateLives()
	updateMana()
	updateManaChargingVisuals()
	connectDayValue()
end)
