local DoorController = {}
DoorController.__index = DoorController

function DoorController.new(config: table)
	local self = setmetatable({}, DoorController)
	self.config = config
	self.registeredPrompts = {}
	self.doorVersion = {}
	return self
end

function DoorController:GetPromptDistance(prompt: ProximityPrompt): number
	local attr = prompt:GetAttribute("MaxActivationDistance")
	if type(attr) == "number" and attr > 0 then
		return attr
	end
	local doorCfg = self.config.Door
	if type(doorCfg) == "table" and type(doorCfg.PromptDistance) == "number" and doorCfg.PromptDistance > 0 then
		return doorCfg.PromptDistance
	end
	return 12
end

function DoorController:GetAutoCloseSec(doorPart: BasePart): number
	local attr = doorPart:GetAttribute("AutoCloseSec")
	if type(attr) == "number" and attr >= 0 then
		return attr
	end
	local doorCfg = self.config.Door
	if type(doorCfg) == "table" and type(doorCfg.AutoCloseSec) == "number" then
		return doorCfg.AutoCloseSec
	end
	return 1.5
end

function DoorController:IsDoorPart(part: Instance): boolean
	if not part:IsA("BasePart") then
		return false
	end
	if part:GetAttribute("IsDoor") == true then
		return true
	end
	local name = string.lower(part.Name)
	return string.find(name, "door", 1, true) ~= nil
end

function DoorController:SetDoorOpen(doorPart: BasePart, isOpen: boolean)
	doorPart.CanCollide = not isOpen
	doorPart:SetAttribute("DoorOpen", isOpen)

	local openTransparency = doorPart:GetAttribute("OpenTransparency")
	local closedTransparency = doorPart:GetAttribute("ClosedTransparency")
	if type(openTransparency) ~= "number" then
		openTransparency = 0.6
	end
	if type(closedTransparency) ~= "number" then
		closedTransparency = 0
	end
	doorPart.Transparency = isOpen and openTransparency or closedTransparency
end

function DoorController:OpenDoor(doorPart: BasePart)
	local nextVersion = (self.doorVersion[doorPart] or 0) + 1
	self.doorVersion[doorPart] = nextVersion
	self:SetDoorOpen(doorPart, true)

	local autoCloseSec = self:GetAutoCloseSec(doorPart)
	if autoCloseSec <= 0 or doorPart:GetAttribute("StayOpen") == true then
		return
	end

	task.delay(autoCloseSec, function()
		if self.doorVersion[doorPart] ~= nextVersion then
			return
		end
		if doorPart.Parent then
			self:SetDoorOpen(doorPart, false)
		end
	end)
end

function DoorController:RegisterPrompt(prompt: ProximityPrompt, doorPart: BasePart)
	if self.registeredPrompts[prompt] then
		return
	end
	self.registeredPrompts[prompt] = true

	-- Make prompt display less angle/occlusion-sensitive in tight room layouts.
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = self:GetPromptDistance(prompt)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Enabled = true

	prompt.Triggered:Connect(function()
		self:OpenDoor(doorPart)
	end)
end

function DoorController:ResolveDoorPartFromPrompt(prompt: ProximityPrompt, roomModel: Model): BasePart?
	local node: Instance? = prompt.Parent
	while node and node ~= roomModel do
		if node:IsA("BasePart") and self:IsDoorPart(node) then
			return node
		end
		node = node.Parent
	end
	return nil
end

function DoorController:RegisterRoom(roomModel: Model)
	for _, descendant in roomModel:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			local doorPart = self:ResolveDoorPartFromPrompt(descendant, roomModel)
			if doorPart then
				self:RegisterPrompt(descendant, doorPart)
			end
		end
	end
end

function DoorController:RegisterRooms(roomsFolder: Folder)
	for _, child in roomsFolder:GetChildren() do
		if child:IsA("Model") then
			self:RegisterRoom(child)
		end
	end
end

return DoorController
