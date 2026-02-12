local overviewCameraPart = workspace:WaitForChild("OverviewCamera")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local function getCamera()
	local cam = workspace.CurrentCamera
	while not cam do
		task.wait()
		cam = workspace.CurrentCamera
	end
	return cam
end

local memoryRoomFolder = ReplicatedStorage:WaitForChild("MemoryRoom")
local remotesFolder = memoryRoomFolder:WaitForChild("Remotes")
local startOverviewRemote = remotesFolder:WaitForChild("StartOverview")

local Config = require(memoryRoomFolder:WaitForChild("Config"))

local function setMovementLocked(locked: boolean)
	local character = localPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if locked then
		humanoid:SetAttribute("MemoryRoom_OrigWalkSpeed", humanoid.WalkSpeed)
		humanoid:SetAttribute("MemoryRoom_OrigJumpPower", humanoid.JumpPower)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	else
		local ws = humanoid:GetAttribute("MemoryRoom_OrigWalkSpeed")
		local jp = humanoid:GetAttribute("MemoryRoom_OrigJumpPower")
		if typeof(ws) == "number" then
			humanoid.WalkSpeed = ws
		end
		if typeof(jp) == "number" then
			humanoid.JumpPower = jp
		end
	end
end

local function computeBounds(models: { Model })
	local hasAny = false
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, model in ipairs(models) do
		local cf, size = model:GetBoundingBox()
		local half = size * 0.5
		local c = cf.Position
		local modelMin = c - half
		local modelMax = c + half
		minV = Vector3.new(math.min(minV.X, modelMin.X), math.min(minV.Y, modelMin.Y), math.min(minV.Z, modelMin.Z))
		maxV = Vector3.new(math.max(maxV.X, modelMax.X), math.max(maxV.Y, modelMax.Y), math.max(maxV.Z, modelMax.Z))
		hasAny = true
	end

	if not hasAny then
		return Vector3.zero, 50
	end

	local center = (minV + maxV) * 0.5
	local extent = (maxV - minV)
	local radius = math.max(extent.X, extent.Z)
	return center, radius
end

local function createHighlight(target: Instance)
	local h = Instance.new("Highlight")
	h.FillColor = Config.Highlight.FillColor
	h.OutlineColor = Config.Highlight.OutlineColor
	h.FillTransparency = Config.Highlight.FillTransparency
	h.OutlineTransparency = Config.Highlight.OutlineTransparency
	h.Adornee = target
	h.Parent = target
	return h
end

local function playOverview(orderedRooms: { Model }, stepSec: number)
	local cam = getCamera()
	local prevCFrame = cam.CFrame
	local prevType = cam.CameraType

	setMovementLocked(true)

	local center, radius = computeBounds(orderedRooms)
	local distance = radius * (Config.Overview.DistanceFactor or 1.2) + (Config.Overview.DistanceOffset or 40)
	local height = radius * (Config.Overview.HeightFactor or 2.0) + (Config.Overview.HeightOffset or 80)
	--local overviewCFrame = CFrame.new(center + Vector3.new(-distance, height, -distance), center)
	local overviewCFrame = overviewCameraPart.CFrame
	
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = overviewCFrame
	task.wait()

	local connection
	connection = RunService.RenderStepped:Connect(function()
		if cam.CameraType == Enum.CameraType.Scriptable then
			cam.CFrame = overviewCFrame
		else
			if connection then
				connection:Disconnect()
			end
		end
	end)

	for _, roomModel in ipairs(orderedRooms) do
		local highlight = createHighlight(roomModel)
		task.wait(stepSec)
		highlight:Destroy()
	end

	if connection then
		connection:Disconnect()
	end
	cam.CameraType = prevType
	cam.CFrame = prevCFrame
	setMovementLocked(false)
end

startOverviewRemote.OnClientEvent:Connect(function(orderedRooms: { Model }, stepSec: number)
	if type(stepSec) ~= "number" then
		stepSec = Config.Overview.StepSec or 0.5
	end
	playOverview(orderedRooms, stepSec)
end)
