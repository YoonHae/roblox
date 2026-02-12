local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local memoryRoomFolder = ReplicatedStorage:WaitForChild("MemoryRoom")
local remotesFolder = memoryRoomFolder:WaitForChild("Remotes")
local debugStateRemote = remotesFolder:WaitForChild("DebugState")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MemoryRoom_DebugHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(520, 120)
label.Position = UDim2.fromOffset(12, 12)
label.BackgroundTransparency = 0.3
label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Font = Enum.Font.Code
label.TextSize = 16
label.Text = "MemoryRoom DebugHud\n(waiting for state...)"
label.Parent = screenGui

debugStateRemote.OnClientEvent:Connect(function(state)
	if typeof(state) ~= "table" then
		return
	end
	label.Text = string.format(
		"MemoryRoom DebugHud\nCurrentRoomId: %s\nCurrentCorrectPathIndex: %s\nExpectedPathIndex: %s\nEnteredRoomId: %s\nEnteredPathIndex: %s",
		tostring(state.CurrentRoomId),
		tostring(state.CurrentCorrectPathIndex),
		tostring(state.ExpectedPathIndex),
		tostring(state.EnteredRoomId),
		tostring(state.EnteredPathIndex)
	)
end)

