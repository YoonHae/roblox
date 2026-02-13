local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local memoryRoomFolder = ReplicatedStorage:FindFirstChild("MemoryRoom")
if not memoryRoomFolder then
	memoryRoomFolder = Instance.new("Folder")
	memoryRoomFolder.Name = "MemoryRoom"
	memoryRoomFolder.Parent = ReplicatedStorage
end

local remotesFolder = memoryRoomFolder:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = memoryRoomFolder
end

local startOverviewRemote = remotesFolder:FindFirstChild("StartOverview")
if not startOverviewRemote then
	startOverviewRemote = Instance.new("RemoteEvent")
	startOverviewRemote.Name = "StartOverview"
	startOverviewRemote.Parent = remotesFolder
end

local clientReadyRemote = remotesFolder:FindFirstChild("ClientReady")
if not clientReadyRemote then
	clientReadyRemote = Instance.new("RemoteEvent")
	clientReadyRemote.Name = "ClientReady"
	clientReadyRemote.Parent = remotesFolder
end

local debugStateRemote = remotesFolder:FindFirstChild("DebugState")
if not debugStateRemote then
	debugStateRemote = Instance.new("RemoteEvent")
	debugStateRemote.Name = "DebugState"
	debugStateRemote.Parent = remotesFolder
end

local configModule = memoryRoomFolder:FindFirstChild("Config")
local Config = {
	Debug = { ShowTriggers = false, TriggerTransparency = 0.7 },
	Logging = { RoomEnter = true, Goal = true, Fail = true },
	Teleport = { CooldownSec = 0.2, VerticalOffset = 3 },
	Overview = { Enabled = true, StepSec = 0.5 },
}
if configModule and configModule:IsA("ModuleScript") then
	local ok, loaded = pcall(require, configModule)
	if ok and type(loaded) == "table" then
		Config = loaded
	end
end

local roomRegistryModule = memoryRoomFolder:FindFirstChild("RoomRegistry")
if not (roomRegistryModule and roomRegistryModule:IsA("ModuleScript")) then
	error("MemoryRoom.RoomRegistry ModuleScript is required in ReplicatedStorage/MemoryRoom")
end
local RoomRegistry = require(roomRegistryModule)

local roundServiceModule = memoryRoomFolder:FindFirstChild("RoundService")
if not (roundServiceModule and roundServiceModule:IsA("ModuleScript")) then
	error("MemoryRoom.RoundService ModuleScript is required in ReplicatedStorage/MemoryRoom")
end
local RoundService = require(roundServiceModule)

local doorControllerModule = memoryRoomFolder:FindFirstChild("DoorController")
if not (doorControllerModule and doorControllerModule:IsA("ModuleScript")) then
	error("MemoryRoom.DoorController ModuleScript is required in ReplicatedStorage/MemoryRoom")
end
local DoorController = require(doorControllerModule)

local roomsFolder = workspace:WaitForChild("Rooms")
local roomRegistry = RoomRegistry.new(roomsFolder, Config)
local roundService = RoundService.new({
	config = Config,
	registry = roomRegistry,
	startOverviewRemote = startOverviewRemote,
	debugStateRemote = debugStateRemote,
})
local doorController = DoorController.new(Config)
doorController:RegisterRooms(roomsFolder)

local function getPlayerFromHitPart(hitPart: BasePart): Player?
	local character = hitPart.Parent
	if character then
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			return player
		end
		local parent = character.Parent
		if parent then
			player = Players:GetPlayerFromCharacter(parent)
			if player then
				return player
			end
		end
	end
	return nil
end

for triggerPart, roomModel in pairs(roomRegistry:GetTriggerMap()) do
	triggerPart.Touched:Connect(function(hitPart)
		if not hitPart:IsA("BasePart") then
			return
		end
		local player = getPlayerFromHitPart(hitPart)
		if not player then
			return
		end
		roundService:HandleRoomEnter(player, roomModel)
	end)
end

clientReadyRemote.OnServerEvent:Connect(function(player)
	roundService:SetClientReady(player, true)
	roundService:TryStartRound(player)
end)

Players.PlayerAdded:Connect(function(player)
	roundService:EnsurePlayerState(player)
	roundService:SetClientReady(player, false)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			roundService:TryStartRound(player)
		end)
	end)

	if player.Character then
		task.defer(function()
			roundService:TryStartRound(player)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	roundService:CleanupPlayer(player)
end)
