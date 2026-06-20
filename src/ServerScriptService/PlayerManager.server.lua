local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)
local Races = require(ReplicatedStorage.Shared.Races)
local RaceAppearances = require(ReplicatedStorage.Shared.RaceAppearances)
local HumanoidHitbox = require(ReplicatedStorage.Shared.HumanoidHitbox)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensurePlayerData(player: Player)
	local data = player:FindFirstChild("PlayerData")
	if not data then
		data = Instance.new("Folder")
		data.Name = "PlayerData"
		data.Parent = player
	end
	return data
end

local function applyRaceStats(player: Player, character: Model, raceId: string)
	local stats = PlayerStats.getForRace(raceId)
	if not stats then
		return
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	humanoid.MaxHealth = stats.MaxHealth
	humanoid.Health = stats.MaxHealth
	humanoid.WalkSpeed = stats.WalkSpeed
	humanoid.JumpPower = stats.JumpPower

	player:SetAttribute("Race", raceId)
	player:SetAttribute("Lineage", stats.Lineage)
	player:SetAttribute("Lives", stats.Lives)
	player:SetAttribute("MaxHealth", stats.MaxHealth)
	player:SetAttribute("WalkSpeed", stats.WalkSpeed)
	player:SetAttribute("MaxMana", CombatConfig.MAX_MANA)
	player:SetAttribute("Mana", 0)
	player:SetAttribute("IsChargingMana", false)

	RaceAppearances.apply(character, raceId)
	ensurePlayerData(player)

	print("[Rogue2]", player.Name, "→", stats.Lineage, "| HP:", stats.MaxHealth, "| Walk:", stats.WalkSpeed)
end

local function applyStatsToCharacter(player: Player, character: Model)
	local raceId = player:GetAttribute("Race") or Races.getRandom()
	applyRaceStats(player, character, raceId)
end

local function onCharacterAdded(player: Player, character: Model)
	applyStatsToCharacter(player, character)
	HumanoidHitbox.setup(character)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

if #Players:GetPlayers() > Config.MAX_PLAYERS then
	warn("[Rogue2] Hay más jugadores conectados que el máximo configurado (" .. Config.MAX_PLAYERS .. ")")
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
