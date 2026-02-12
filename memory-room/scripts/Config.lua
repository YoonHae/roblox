local Config = {}

Config.Debug = {
	ShowTriggers = false,
	TriggerTransparency = 0.7,
}

Config.Teleport = {
	CooldownSec = 0.2,
	VerticalOffset = 3,
}

Config.Overview = {
	Enabled = true,
	StepSec = 0.6,
	HeightFactor = 1.5,
	HeightOffset = 80,
	DistanceFactor = 2.8,
	DistanceOffset = 140,
}

Config.Highlight = {
	FillColor = Color3.fromRGB(255, 220, 120),
	OutlineColor = Color3.fromRGB(255, 255, 255),
	FillTransparency = 0.3,
	OutlineTransparency = 0,
}

return Config
