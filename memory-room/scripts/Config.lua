local Config = {}

Config.Debug = {
	ShowTriggers = false,
	TriggerTransparency = 0.7,
}

Config.Logging = {
	RoomEnter = true,
	Goal = true,
	Fail = true,
}

Config.Teleport = {
	CooldownSec = 0.2,
	VerticalOffset = 3,
}

Config.Overview = {
	Enabled = true,
	StepSec = 0.6,
	CameraPartName = "OverviewCamera",
	UseCameraPart = true,
	HeightFactor = 2.0,
	HeightOffset = 80,
	DistanceFactor = 1.2,
	DistanceOffset = 40,
}

Config.Highlight = {
	FillColor = Color3.fromRGB(255, 220, 120),
	OutlineColor = Color3.fromRGB(255, 255, 255),
	FillTransparency = 0.3,
	OutlineTransparency = 0,
}

return Config
