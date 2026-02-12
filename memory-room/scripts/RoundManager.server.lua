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
	Teleport = { CooldownSec = 0.2, VerticalOffset = 3 },
	Overview = { Enabled = true, StepSec = 0.5 },
}
if configModule and configModule:IsA("ModuleScript") then
	local ok, loaded = pcall(require, configModule)
	if ok and type(loaded) == "table" then
		Config = loaded
	end
end

local roomsFolder = workspace:WaitForChild("Rooms")

type PlayerState = {
	currentRoomId: string?,
	currentCorrectPathIndex: number,
	lastTeleportAt: number,
}

local playerStates: { [number]: PlayerState } = {}
local playerClientReady: { [number]: boolean } = {}
local lastRoundStartAt: { [number]: number } = {}
local triggerToRoomModel: { [Instance]: Model } = {}
local roomIdToModel: { [string]: Model } = {}
local pathIndexToRoom: { [number]: Model } = {}
local orderedPathRooms: { Model } = {}
local startRoom: Model?

local function getRoomId(roomModel: Model): string
	local roomId = roomModel:GetAttribute("RoomId")
	if type(roomId) == "string" and roomId ~= "" then
		return roomId
	end
	return roomModel.Name
end

local function getPathIndex(roomModel: Model): number
	local idx = roomModel:GetAttribute("PathIndex")
	if type(idx) == "number" then
		return idx
	end
	return -1
end

local function getRoomSpawn(roomModel: Model): BasePart?
	local spawnPart = roomModel:FindFirstChild("RoomSpawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart
	end
	local primary = roomModel.PrimaryPart
	if primary and primary:IsA("BasePart") then
		return primary
	end
	return nil
end

local function teleportToSpawn(character: Model, spawnPart: BasePart)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return
	end
	hrp.CFrame = spawnPart.CFrame + Vector3.new(0, Config.Teleport.VerticalOffset or 3, 0)
end

local function fireDebugState(player: Player, state: PlayerState, enteredRoom: Model?)
	local enteredRoomId = enteredRoom and getRoomId(enteredRoom) or nil
	local enteredPathIndex = enteredRoom and getPathIndex(enteredRoom) or nil
	debugStateRemote:FireClient(player, {
		CurrentRoomId = state.currentRoomId,
		CurrentCorrectPathIndex = state.currentCorrectPathIndex,
		ExpectedPathIndex = state.currentCorrectPathIndex + 1,
		EnteredRoomId = enteredRoomId,
		EnteredPathIndex = enteredPathIndex,
	})
end

local function rebuildRoomIndex()
	table.clear(triggerToRoomModel)
	table.clear(roomIdToModel)
	table.clear(pathIndexToRoom)
	table.clear(orderedPathRooms)
	startRoom = nil

	for _, child in roomsFolder:GetChildren() do
		if child:IsA("Model") then
			local roomModel = child
			local roomId = getRoomId(roomModel)
			roomIdToModel[roomId] = roomModel

			local pathIndex = getPathIndex(roomModel)
			if pathIndex >= 0 then
				pathIndexToRoom[pathIndex] = roomModel
			end

			local isStart = roomModel:GetAttribute("IsStart")
			if isStart == true then
				startRoom = roomModel
			end

			local trigger = roomModel:FindFirstChild("RoomEntryTrigger")
			if trigger and trigger:IsA("BasePart") then
				triggerToRoomModel[trigger] = roomModel
				if Config.Debug.ShowTriggers then
					trigger.Transparency = Config.Debug.TriggerTransparency or 0.7
				else
					trigger.Transparency = 1
				end
				trigger.CanCollide = false
				trigger.CanTouch = true
			end
		end
	end

	local maxIndex = -1
	for idx, _ in pairs(pathIndexToRoom) do
		if idx > maxIndex then
			maxIndex = idx
		end
	end

	for idx = 0, maxIndex do
		local room = pathIndexToRoom[idx]
		if room then
			table.insert(orderedPathRooms, room)
		end
	end
end

rebuildRoomIndex()

local function ensurePlayerState(player: Player): PlayerState
	local state = playerStates[player.UserId]
	if state then
		return state
	end
	state = {
		currentRoomId = startRoom and getRoomId(startRoom) or nil,
		currentCorrectPathIndex = 0,
		lastTeleportAt = 0,
	}
	playerStates[player.UserId] = state
	return state
end

local function startRoundForPlayer(player: Player)
	local state = ensurePlayerState(player)
	state.currentCorrectPathIndex = 0
	state.currentRoomId = startRoom and getRoomId(startRoom) or nil
	state.lastTeleportAt = 0

	if Config.Overview.Enabled then
		startOverviewRemote:FireClient(player, orderedPathRooms, Config.Overview.StepSec or 0.5)
	end

	fireDebugState(player, state, nil)
end

local function canStartOverviewFor(player: Player): boolean
	if not Config.Overview.Enabled then
		return true
	end
	return playerClientReady[player.UserId] == true
end

local function tryStartRound(player: Player)
	if not canStartOverviewFor(player) then
		return
	end
	local now = os.clock()
	local userId = player.UserId
	if now - (lastRoundStartAt[userId] or 0) < 0.5 then
		return
	end
	lastRoundStartAt[userId] = now
	startRoundForPlayer(player)
end

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

local function handleRoomEnter(player: Player, enteredRoom: Model)
	local state = ensurePlayerState(player)
	local enteredRoomId = getRoomId(enteredRoom)
	if enteredRoomId == state.currentRoomId then
		fireDebugState(player, state, enteredRoom)
		return
	end

	local now = os.clock()
	if now - state.lastTeleportAt < (Config.Teleport.CooldownSec or 0.2) then
		return
	end

	local enteredPathIndex = getPathIndex(enteredRoom)
	local expectedPathIndex = state.currentCorrectPathIndex + 1

	if enteredPathIndex == expectedPathIndex then
		local isGoal = enteredRoom:GetAttribute("IsGoal") == true
		if isGoal then
			print(string.format("[Goal] %s reached %s", player.Name, enteredRoomId))
		end

		state.currentCorrectPathIndex += 1
		state.currentRoomId = enteredRoomId
		print(string.format("[RoomEnter] %s -> %s (PathIndex=%d OK)", player.Name, enteredRoomId, enteredPathIndex))
		fireDebugState(player, state, enteredRoom)
		return
	end

	local currentRoom = state.currentRoomId and roomIdToModel[state.currentRoomId] or startRoom
	if currentRoom then
		local spawnPart = getRoomSpawn(currentRoom)
		local character = player.Character
		if spawnPart and character then
			state.lastTeleportAt = now
			warn(string.format(
				"[RoomEnter] %s -> %s (PathIndex=%d, expected=%d) FAIL, teleport back to %s",
				player.Name,
				enteredRoomId,
				enteredPathIndex,
				expectedPathIndex,
				getRoomId(currentRoom)
				))
			teleportToSpawn(character, spawnPart)
			fireDebugState(player, state, enteredRoom)
		else
			warn(string.format(
				"[RoomEnter] fail handling skipped (spawn/character missing). currentRoom=%s, spawn=%s, character=%s",
				getRoomId(currentRoom),
				tostring(spawnPart ~= nil),
				tostring(character ~= nil)
			))
		end
	end
end

for triggerPart, roomModel in pairs(triggerToRoomModel) do
	triggerPart.Touched:Connect(function(hitPart)
		if not hitPart:IsA("BasePart") then
			return
		end
		local player = getPlayerFromHitPart(hitPart)
		if not player then
			return
		end
		handleRoomEnter(player, roomModel)
	end)
end

clientReadyRemote.OnServerEvent:Connect(function(player)
	playerClientReady[player.UserId] = true
	tryStartRound(player)
end)

Players.PlayerAdded:Connect(function(player)
	ensurePlayerState(player)
	playerClientReady[player.UserId] = false

	player.CharacterAdded:Connect(function()
		task.defer(function()
			tryStartRound(player)
		end)
	end)

	if player.Character then
		task.defer(function()
			tryStartRound(player)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerStates[player.UserId] = nil
	playerClientReady[player.UserId] = nil
	lastRoundStartAt[player.UserId] = nil
end)
