local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local BlockAnimation = {}

local activeClampConnections: { [AnimationTrack]: RBXScriptConnection } = {}

local function disconnectClamp(track: AnimationTrack)
	local connection = activeClampConnections[track]
	if connection then
		connection:Disconnect()
		activeClampConnections[track] = nil
	end
end

function BlockAnimation.configureTrack(track: AnimationTrack)
	track.Priority = CombatConfig.BLOCK_ANIMATION_PRIORITY
	track.Looped = false
end

local function freezeAtHoldFrame(track: AnimationTrack)
	local holdTime = CombatConfig.BLOCK_HOLD_TIME
	if track.Length > 0 then
		holdTime = math.min(holdTime, track.Length - 0.001)
	end

	track.TimePosition = holdTime
	track:AdjustSpeed(0)

	if not track.IsPlaying then
		track:Play(0, 1, 0)
	end
end

function BlockAnimation.play(track: AnimationTrack)
	disconnectClamp(track)

	local holdTime = CombatConfig.BLOCK_HOLD_TIME
	if track.Length > 0 then
		holdTime = math.min(holdTime, track.Length - 0.001)
	end

	track:AdjustSpeed(1)
	track.TimePosition = 0
	track:Play()

	activeClampConnections[track] = RunService.Heartbeat:Connect(function()
		if track.TimePosition >= holdTime then
			freezeAtHoldFrame(track)
			return
		end
	end)
end

function BlockAnimation.stop(track: AnimationTrack)
	disconnectClamp(track)
	track:AdjustSpeed(1)
	track:Stop(0.15)
end

return BlockAnimation
