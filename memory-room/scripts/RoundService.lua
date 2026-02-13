local RoundService = {}
RoundService.__index = RoundService

type PlayerState = {
	currentRoomId: string?,
	currentCorrectPathIndex: number,
	lastTeleportAt: number,
}

function RoundService.new(deps: {
	config: table,
	registry: any,
	startOverviewRemote: RemoteEvent,
	debugStateRemote: RemoteEvent,
})
	local self = setmetatable({}, RoundService)
	self.config = deps.config
	self.registry = deps.registry
	self.startOverviewRemote = deps.startOverviewRemote
	self.debugStateRemote = deps.debugStateRemote
	self.playerStates = {}
	self.playerClientReady = {}
	self.lastRoundStartAt = {}
	return self
end

function RoundService:ShouldLog(kind: string): boolean
	local logging = self.config.Logging
	if type(logging) ~= "table" then
		return true
	end
	local enabled = logging[kind]
	if type(enabled) == "boolean" then
		return enabled
	end
	return true
end

function RoundService:TeleportToSpawn(character: Model, spawnPart: BasePart)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return
	end
	hrp.CFrame = spawnPart.CFrame + Vector3.new(0, self.config.Teleport.VerticalOffset or 3, 0)
end

function RoundService:FireDebugState(player: Player, state: PlayerState, enteredRoom: Model?)
	local enteredRoomId = enteredRoom and self.registry:GetRoomId(enteredRoom) or nil
	local enteredPathIndex = enteredRoom and self.registry:GetPathIndex(enteredRoom) or nil
	self.debugStateRemote:FireClient(player, {
		CurrentRoomId = state.currentRoomId,
		CurrentCorrectPathIndex = state.currentCorrectPathIndex,
		ExpectedPathIndex = state.currentCorrectPathIndex + 1,
		EnteredRoomId = enteredRoomId,
		EnteredPathIndex = enteredPathIndex,
	})
end

function RoundService:EnsurePlayerState(player: Player): PlayerState
	local startRoom = self.registry:GetStartRoom()
	local state = self.playerStates[player.UserId]
	if state then
		return state
	end
	state = {
		currentRoomId = startRoom and self.registry:GetRoomId(startRoom) or nil,
		currentCorrectPathIndex = 0,
		lastTeleportAt = 0,
	}
	self.playerStates[player.UserId] = state
	return state
end

function RoundService:SetClientReady(player: Player, isReady: boolean)
	self.playerClientReady[player.UserId] = isReady
end

function RoundService:CanStartOverviewFor(player: Player): boolean
	if not self.config.Overview.Enabled then
		return true
	end
	return self.playerClientReady[player.UserId] == true
end

function RoundService:StartRoundForPlayer(player: Player)
	local startRoom = self.registry:GetStartRoom()
	local state = self:EnsurePlayerState(player)
	state.currentCorrectPathIndex = 0
	state.currentRoomId = startRoom and self.registry:GetRoomId(startRoom) or nil
	state.lastTeleportAt = 0

	if self.config.Overview.Enabled then
		self.startOverviewRemote:FireClient(player, self.registry:GetOrderedPathRooms(), self.config.Overview.StepSec or 0.5)
	end

	self:FireDebugState(player, state, nil)
end

function RoundService:TryStartRound(player: Player)
	if not self:CanStartOverviewFor(player) then
		return
	end
	local now = os.clock()
	local userId = player.UserId
	if now - (self.lastRoundStartAt[userId] or 0) < 0.5 then
		return
	end
	self.lastRoundStartAt[userId] = now
	self:StartRoundForPlayer(player)
end

function RoundService:HandleRoomEnter(player: Player, enteredRoom: Model)
	local state = self:EnsurePlayerState(player)
	local enteredRoomId = self.registry:GetRoomId(enteredRoom)
	if enteredRoomId == state.currentRoomId then
		self:FireDebugState(player, state, enteredRoom)
		return
	end

	local now = os.clock()
	if now - state.lastTeleportAt < (self.config.Teleport.CooldownSec or 0.2) then
		return
	end

	local enteredPathIndex = self.registry:GetPathIndex(enteredRoom)
	local expectedPathIndex = state.currentCorrectPathIndex + 1

	if enteredPathIndex == expectedPathIndex then
		local isGoal = enteredRoom:GetAttribute("IsGoal") == true
		if isGoal and self:ShouldLog("Goal") then
			print(string.format("[Goal] %s reached %s", player.Name, enteredRoomId))
		end

		state.currentCorrectPathIndex += 1
		state.currentRoomId = enteredRoomId
		if self:ShouldLog("RoomEnter") then
			print(string.format("[RoomEnter] %s -> %s (PathIndex=%d OK)", player.Name, enteredRoomId, enteredPathIndex))
		end
		self:FireDebugState(player, state, enteredRoom)
		return
	end

	local currentRoom = state.currentRoomId and self.registry:GetRoomById(state.currentRoomId) or self.registry:GetStartRoom()
	if not currentRoom then
		return
	end

	local spawnPart = self.registry:GetRoomSpawn(currentRoom)
	local character = player.Character
	if spawnPart and character then
		state.lastTeleportAt = now
		if self:ShouldLog("Fail") then
			warn(string.format(
				"[RoomEnter] %s -> %s (PathIndex=%d, expected=%d) FAIL, teleport back to %s",
				player.Name,
				enteredRoomId,
				enteredPathIndex,
				expectedPathIndex,
				self.registry:GetRoomId(currentRoom)
			))
		end
		self:TeleportToSpawn(character, spawnPart)
		self:FireDebugState(player, state, enteredRoom)
		return
	end

	if self:ShouldLog("Fail") then
		warn(string.format(
			"[RoomEnter] fail handling skipped (spawn/character missing). currentRoom=%s, spawn=%s, character=%s",
			self.registry:GetRoomId(currentRoom),
			tostring(spawnPart ~= nil),
			tostring(character ~= nil)
		))
	end
end

function RoundService:CleanupPlayer(player: Player)
	self.playerStates[player.UserId] = nil
	self.playerClientReady[player.UserId] = nil
	self.lastRoundStartAt[player.UserId] = nil
end

return RoundService
