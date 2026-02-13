local RoomRegistry = {}
RoomRegistry.__index = RoomRegistry

function RoomRegistry.new(roomsFolder: Folder, config: table)
	local self = setmetatable({}, RoomRegistry)
	self.roomsFolder = roomsFolder
	self.config = config
	self.triggerToRoomModel = {}
	self.roomIdToModel = {}
	self.pathIndexToRoom = {}
	self.orderedPathRooms = {}
	self.startRoom = nil
	self:Rebuild()
	return self
end

function RoomRegistry:GetRoomId(roomModel: Model): string
	local roomId = roomModel:GetAttribute("RoomId")
	if type(roomId) == "string" and roomId ~= "" then
		return roomId
	end
	return roomModel.Name
end

function RoomRegistry:GetPathIndex(roomModel: Model): number
	local idx = roomModel:GetAttribute("PathIndex")
	if type(idx) == "number" then
		return idx
	end
	return -1
end

function RoomRegistry:GetRoomSpawn(roomModel: Model): BasePart?
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

function RoomRegistry:GetRoomById(roomId: string): Model?
	return self.roomIdToModel[roomId]
end

function RoomRegistry:GetStartRoom(): Model?
	return self.startRoom
end

function RoomRegistry:GetOrderedPathRooms(): { Model }
	return self.orderedPathRooms
end

function RoomRegistry:GetTriggerMap(): { [Instance]: Model }
	return self.triggerToRoomModel
end

function RoomRegistry:Rebuild()
	table.clear(self.triggerToRoomModel)
	table.clear(self.roomIdToModel)
	table.clear(self.pathIndexToRoom)
	table.clear(self.orderedPathRooms)
	self.startRoom = nil

	for _, child in self.roomsFolder:GetChildren() do
		if child:IsA("Model") then
			local roomModel = child
			local roomId = self:GetRoomId(roomModel)
			self.roomIdToModel[roomId] = roomModel

			local pathIndex = self:GetPathIndex(roomModel)
			if pathIndex >= 0 then
				self.pathIndexToRoom[pathIndex] = roomModel
			end

			if roomModel:GetAttribute("IsStart") == true then
				self.startRoom = roomModel
			end

			local trigger = roomModel:FindFirstChild("RoomEntryTrigger")
			if trigger and trigger:IsA("BasePart") then
				self.triggerToRoomModel[trigger] = roomModel
				if self.config.Debug.ShowTriggers then
					trigger.Transparency = self.config.Debug.TriggerTransparency or 0.7
				else
					trigger.Transparency = 1
				end
				trigger.CanCollide = false
				trigger.CanTouch = true
			end
		end
	end

	local maxIndex = -1
	for idx, _ in pairs(self.pathIndexToRoom) do
		if idx > maxIndex then
			maxIndex = idx
		end
	end

	for idx = 0, maxIndex do
		local room = self.pathIndexToRoom[idx]
		if room then
			table.insert(self.orderedPathRooms, room)
		end
	end
end

return RoomRegistry
