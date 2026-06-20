local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local isRunning = false
local isWHeld = false
local awaitingDoubleTap = false
local singleTapTimer: thread? = nil
local humanoid: Humanoid? = nil
local runTrack: AnimationTrack? = nil
local runningConnection: RBXScriptConnection? = nil
local jumpConnection: RBXScriptConnection? = nil

local function getBaseWalkSpeed(): number
	return player:GetAttribute("WalkSpeed") or 16
end

local function getRunWalkSpeed(): number
	return getBaseWalkSpeed() + Config.RUN_SPEED_BONUS
end

local function stopRunAnimation()
	if runTrack and runTrack.IsPlaying then
		runTrack:Stop()
	end
end

local function applyMovementSpeed()
	if not humanoid or player:GetAttribute("IsAttacking") or player:GetAttribute("IsStunned") or player:GetAttribute("IsRagdolled") then
		return
	end

	local shouldRun = isRunning and isWHeld
	humanoid.WalkSpeed = shouldRun and getRunWalkSpeed() or getBaseWalkSpeed()
end

local function cancelSingleTapTimer()
	if singleTapTimer then
		task.cancel(singleTapTimer)
		singleTapTimer = nil
	end
end

local function setWalkMode()
	isRunning = false
	stopRunAnimation()
	applyMovementSpeed()
end

local function cancelRunFromAttack()
	isRunning = false
	awaitingDoubleTap = false
	cancelSingleTapTimer()
	stopRunAnimation()

	if humanoid and not player:GetAttribute("IsStunned") and not player:GetAttribute("IsRagdolled") then
		humanoid.WalkSpeed = getBaseWalkSpeed()
	end
end

local function setRunMode()
	if player:GetAttribute("IsAttacking") or player:GetAttribute("IsStunned") or player:GetAttribute("IsRagdolled") then
		return
	end

	isRunning = true
	applyMovementSpeed()
end

local function onWPressed()
	if player:GetAttribute("IsAttacking") then
		return
	end

	if awaitingDoubleTap then
		awaitingDoubleTap = false
		cancelSingleTapTimer()
		setRunMode()
		return
	end

	awaitingDoubleTap = true
	cancelSingleTapTimer()
	singleTapTimer = task.delay(Config.RUN_DOUBLE_TAP_WINDOW, function()
		awaitingDoubleTap = false
		singleTapTimer = nil
		setWalkMode()
	end)
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.KeyCode ~= Enum.KeyCode.W then
		return
	end

	isWHeld = true
	onWPressed()
	applyMovementSpeed()
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean)
	if input.KeyCode ~= Enum.KeyCode.W then
		return
	end

	isWHeld = false
	setWalkMode()
end

local function bindHumanoidSignals()
	if not humanoid then
		return
	end

	if runningConnection then
		runningConnection:Disconnect()
	end
	if jumpConnection then
		jumpConnection:Disconnect()
	end

	runningConnection = humanoid.Running:Connect(function(speed: number)
		if not runTrack then
			return
		end

		if speed >= 10 and isRunning and isWHeld and not player:GetAttribute("IsAttacking") and not runTrack.IsPlaying then
			runTrack:Play()
			applyMovementSpeed()
		elseif speed >= 10 and (not isRunning or not isWHeld or player:GetAttribute("IsAttacking")) and runTrack.IsPlaying then
			stopRunAnimation()
			applyMovementSpeed()
		elseif speed < 10 and runTrack.IsPlaying then
			stopRunAnimation()
		end
	end)

	jumpConnection = humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if humanoid.Jump then
			stopRunAnimation()
		end
	end)
end

local function onCharacterAdded(character: Model)
	isRunning = false
	isWHeld = false
	awaitingDoubleTap = false
	cancelSingleTapTimer()

	if runningConnection then
		runningConnection:Disconnect()
		runningConnection = nil
	end
	if jumpConnection then
		jumpConnection:Disconnect()
		jumpConnection = nil
	end

	humanoid = character:WaitForChild("Humanoid") :: Humanoid

	local runAnimation = Instance.new("Animation")
	runAnimation.AnimationId = Config.RUN_ANIMATION_ID
	runTrack = humanoid:LoadAnimation(runAnimation)

	bindHumanoidSignals()
end

player:GetAttributeChangedSignal("CancelRunRequest"):Connect(function()
	cancelRunFromAttack()
end)

player:GetAttributeChangedSignal("IsAttacking"):Connect(function()
	if player:GetAttribute("IsAttacking") then
		cancelRunFromAttack()
	elseif humanoid then
		applyMovementSpeed()
	end
end)

player:GetAttributeChangedSignal("IsStunned"):Connect(function()
	if player:GetAttribute("IsStunned") then
		setWalkMode()
		if humanoid then
			humanoid.WalkSpeed = 0
		end
	elseif humanoid then
		applyMovementSpeed()
	end
end)

player:GetAttributeChangedSignal("IsRagdolled"):Connect(function()
	if player:GetAttribute("IsRagdolled") then
		setWalkMode()
	elseif humanoid then
		applyMovementSpeed()
	end
end)

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)

if player.Character then
	onCharacterAdded(player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)
