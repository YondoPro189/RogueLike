local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local gameState = ReplicatedStorage:FindFirstChild("GameState")
if not gameState then
	gameState = Instance.new("Folder")
	gameState.Name = "GameState"
	gameState.Parent = ReplicatedStorage
end

local dayValue = gameState:FindFirstChild("Day")
if not dayValue then
	dayValue = Instance.new("IntValue")
	dayValue.Name = "Day"
	dayValue.Value = 1
	dayValue.Parent = gameState
end

while true do
	task.wait(Config.DAY_LENGTH_SECONDS)
	dayValue.Value += 1
	print("[Rogue2] Nuevo día:", dayValue.Value)
end
