--!strict
-- Sky, lighting and water presets for each sea of the voyage (design decision: the mood changes by sea).
--   Sea1 "Calm Blues"    bright, saturated midday
--   Sea2 "Golden Route"  warm golden dusk
--   Sea3 "Storm Sea"     dim, stormy and slightly eerie
-- Environment.apply(name) on the server applies one of these.

export type Preset = {
	DisplayName: string,
	Lighting: { [string]: any },
	Atmosphere: { [string]: any },
	Clouds: { [string]: any },
	Water: { [string]: any },
	ColorCorrection: { [string]: any },
	Bloom: { [string]: any },
	SunRays: { [string]: any },
}

local rgb = Color3.fromRGB

local SeaPresets: { [string]: Preset } = {
	Sea1 = {
		DisplayName = "Calm Blues",
		Lighting = {
			ClockTime = 13.2,
			GeographicLatitude = 23,
			Brightness = 3,
			ExposureCompensation = 0.1,
			Ambient = rgb(70, 74, 86),
			OutdoorAmbient = rgb(150, 160, 175),
			ColorShift_Top = rgb(255, 244, 222),
			ColorShift_Bottom = rgb(0, 0, 0),
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.8,
		},
		Atmosphere = {
			Density = 0.24,
			Offset = 0.12,
			Color = rgb(200, 222, 240),
			Decay = rgb(110, 150, 190),
			Glare = 0.25,
			Haze = 0.6,
		},
		Clouds = { Cover = 0.55, Density = 0.55, Color = rgb(255, 255, 255) },
		Water = {
			WaterColor = rgb(22, 110, 186),
			WaterWaveSize = 0.15,
			WaterWaveSpeed = 10,
			WaterReflectance = 0.55,
			WaterTransparency = 0.3,
		},
		ColorCorrection = { Brightness = 0.02, Contrast = 0.06, Saturation = 0.18, TintColor = rgb(255, 252, 245) },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.9 },
		SunRays = { Intensity = 0.06, Spread = 0.6 },
	},

	Sea2 = {
		DisplayName = "Golden Route",
		-- Tuned toward the vibe reference: violet-pink dusk sky, peach clouds, deep indigo water.
		Lighting = {
			ClockTime = 17.35,
			GeographicLatitude = 23,
			Brightness = 2.2,
			ExposureCompensation = 0.05,
			Ambient = rgb(110, 96, 140),
			OutdoorAmbient = rgb(170, 148, 190),
			ColorShift_Top = rgb(255, 190, 160),
			ColorShift_Bottom = rgb(60, 40, 90),
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.9,
		},
		Atmosphere = {
			Density = 0.36,
			Offset = 0.5,
			Color = rgb(232, 172, 196),
			Decay = rgb(160, 120, 190),
			Glare = 0.3,
			Haze = 2.4,
		},
		Clouds = { Cover = 0.5, Density = 0.85, Color = rgb(255, 200, 164) },
		Water = {
			WaterColor = rgb(40, 60, 168),
			WaterWaveSize = 0.2,
			WaterWaveSpeed = 12,
			WaterReflectance = 0.6,
			WaterTransparency = 0.25,
		},
		ColorCorrection = { Brightness = 0.0, Contrast = 0.08, Saturation = 0.1, TintColor = rgb(248, 232, 250) },
		Bloom = { Intensity = 0.7, Size = 28, Threshold = 1.7 },
		SunRays = { Intensity = 0.08, Spread = 0.8 },
	},

	Sea3 = {
		DisplayName = "Storm Sea",
		Lighting = {
			ClockTime = 15.5,
			GeographicLatitude = 23,
			Brightness = 1.1,
			ExposureCompensation = 0,
			Ambient = rgb(60, 66, 72),
			OutdoorAmbient = rgb(100, 110, 118),
			ColorShift_Top = rgb(180, 200, 210),
			ColorShift_Bottom = rgb(0, 0, 0),
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.5,
		},
		Atmosphere = {
			Density = 0.46,
			Offset = 0.05,
			Color = rgb(120, 130, 138),
			Decay = rgb(70, 80, 88),
			Glare = 0,
			Haze = 2.6,
		},
		Clouds = { Cover = 0.93, Density = 0.85, Color = rgb(96, 102, 110) },
		Water = {
			WaterColor = rgb(22, 52, 62),
			WaterWaveSize = 0.5,
			WaterWaveSpeed = 24,
			WaterReflectance = 0.35,
			WaterTransparency = 0.4,
		},
		ColorCorrection = { Brightness = -0.04, Contrast = 0.16, Saturation = -0.35, TintColor = rgb(200, 222, 214) },
		Bloom = { Intensity = 0.3, Size = 20, Threshold = 2.2 },
		SunRays = { Intensity = 0, Spread = 0.5 },
	},
}

return SeaPresets
