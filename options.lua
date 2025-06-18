---@class WorldOptions
---@field dimensions {x: number, y: number, z: number} World size in voxels
---@field generation {seed: number?, tileSize: number, batchSize: number} Generation parameters
---@field noise {octaves: number, persistence: number, scale: number} Noise generation settings

---@class LightingOptions
---@field temporal {dayLength: number, startHour: number} Time-related settings
---@field celestial {sunMaxHeight: number, sunPathOffset: number, moonMaxHeight: number, moonPathOffset: number, horizonThreshold: number, moonLightIntensity: number} Celestial body parameters
---@field intensity {ambientMin: number, ambientMax: number, sunMin: number, sunMax: number, twilightStrength: number, horizonBlendRange: number} Light intensity ranges
---@field transitions {sunHeightSteepness: number, moonHeightSteepness: number, shadowTransitionSteepness: number, sunTransitionMidpoint: number, moonTransitionMidpoint: number, shadowTransitionMidpoint: number} Mathematical transition parameters
---@field timeBells {dawnWidth: number, duskWidth: number, nightWidth: number} Bell curve parameters for time effects
---@field colorTemperature {dawn: number, morning: number, noon: number, afternoon: number, dusk: number, night: number} Color temperatures in Kelvin
---@field atmosphere {rayleighRed: number, rayleighGreen: number, rayleighBlue: number, scatteringPower: number} Atmospheric scattering coefficients
---@field colorBlending {hueBlendSmoothness: number, saturationPreservation: number, lightnessGamma: number, twilightHueShift: number, twilightSaturationBoost: number} HSL color blending parameters

---@class TerrainOptions
---@field heightThresholds {deepOcean: number, ocean: number, beach: number, grassland: number, mountain: number} Height breakpoints for terrain types
---@field surfaceColors table<string, {r: number, g: number, b: number}> Surface colors for each terrain type
---@field undergroundColors table<string, {r: number, g: number, b: number}> Underground material colors
---@field depthDarkening number Multiplier for underground color darkening

---@class RenderingOptions
---@field shadows {adaptiveStepFactor: number, stepAcceleration: number, maxStepMultiplier: number, penumbraDistanceScale: number, shadowAccumulationLimit: number, heightDifferenceScale: number, lowAngleThreshold: number, lowAngleTransitionSteepness: number} Shadow ray marching parameters
---@field water {waveFrequencyX: number, waveFrequencyY: number, waveTimeScale: number, waveAmplitude: number, ambientReduction: number} Water rendering effects
---@field terrain {detailFrequency: number, detailAmplitude: number, goldenHourHueShift: number, goldenHourSaturationBoost: number} Terrain detail enhancement

---@class Options
---@field world WorldOptions
---@field lighting LightingOptions
---@field terrain TerrainOptions
---@field rendering RenderingOptions

---Configuration options for the world simulation
---@type Options
local options = {
    world = {
        dimensions = {
            x = 500,
            y = 50,
            z = 500
        },
        generation = {
            seed = nil, -- nil = random, or specific number like 378613
            tileSize = 15,
            batchSize = 10
        },
        noise = {
            octaves = 9,
            persistence = 0.55,
            scale = 1
        }
    },

    lighting = {
        temporal = {
            dayLength = 10, -- seconds for full day/night cycle
            startHour = 12  -- starting time (0-24)
        },

        celestial = {
            sunMaxHeight = 0.9,
            sunPathOffset = 0.3,
            moonMaxHeight = 0.7,
            moonPathOffset = -0.2,
            horizonThreshold = 0.05,
            moonLightIntensity = 0.35
        },

        intensity = {
            ambientMin = 0.05,
            ambientMax = 0.15,
            sunMin = 0.3,
            sunMax = 1.0,
            twilightStrength = 0.35,
            horizonBlendRange = 0.3
        },

        transitions = {
            sunHeightSteepness = 10.0,
            moonHeightSteepness = 10.0,
            shadowTransitionSteepness = 15.0,
            sunTransitionMidpoint = 0.4,
            moonTransitionMidpoint = 0.4,
            shadowTransitionMidpoint = 0.05
        },

        timeBells = {
            dawnWidth = 0.5,
            duskWidth = 0.5,
            nightWidth = 6.0
        },

        colorTemperature = {
            dawn = 2500,
            morning = 5000,
            noon = 6500,
            afternoon = 5000,
            dusk = 2000,
            night = 10000
        },

        atmosphere = {
            rayleighRed = 0.1,
            rayleighGreen = 0.1,
            rayleighBlue = 0.3,
            scatteringPower = 2.0,
            -- Atmospheric scattering calculation constants
            scatteringBase = 0.1,
            scatteringRange = 0.8,
            scatteringGreenPower = 2.0,
            scatteringBlueBase = 0.3,
            scatteringBlueRange = 0.6
        },

        colorBlending = {
            hueBlendSmoothness = 1.0,
            saturationPreservation = 0.8,
            lightnessGamma = 1.0,
            twilightHueShift = 0.9,
            twilightSaturationBoost = 0.3,
            -- HSL color space blending constants
            scatteringInfluence = 0.8,
            scatteringRange = 0.2
        },

        -- Shadow calculation constants
        shadows = {
            sunShadowScale = 0.8,
            moonShadowScale = 0.3,
            sunSoftnessBase = 1.0,
            sunSoftnessRange = 0.7,
            sunSoftnessSteepness = 8.0,
            sunSoftnessMidpoint = 0.5,
            moonSoftnessBase = 1.0,
            moonSoftnessRange = 0.3,
            moonSoftnessSteepness = 8.0,
            moonSoftnessMidpoint = 0.5,
            dawnDuskSoftnessBoost = 0.2,
            dawnDuskWidth = 1.0
        },

        -- Light intensity calculation constants
        intensity_calc = {
            sunLightBase = 0.3,
            sunLightRange = 0.7,
            moonLightBase = 0.2,
            moonLightRange = 0.3,
            colorIntensityBase = 0.3,
            colorIntensityRange = 0.7,
            totalIntensityLimit = 0.95,
            totalIntensityDamping = 0.5
        },

        -- Sky brightness calculation constants
        skyBrightness = {
            ambientBase = 0.05,
            dayTransitionMidpoint = 0.45,
            dayTransitionSteepness = 10.0,
            moonTransitionMidpoint = 0.45,
            moonTransitionSteepness = 10.0,
            softClampThreshold = 0.95,
            softClampDamping = 0.5
        }
    },

    terrain = {
        heightThresholds = {
            deepOcean = 0.18,
            ocean = 0.3,
            beach = 0.35,
            grassland = 0.6,
            mountain = 0.82
        },

        surfaceColors = {
            deepOcean = { r = 0.0, g = 0.0, b = 0.6 },
            ocean = { r = 0.0, g = 0.2, b = 0.8 },
            beach = { r = 0.8, g = 0.7, b = 0.5 },
            grassland = { r = 0.1, g = 0.6, b = 0.1 },
            mountain = { r = 0.5, g = 0.5, b = 0.5 },
            snow = { r = 1.0, g = 1.0, b = 1.0 }
        },

        undergroundColors = {
            deepOceanSediment = { r = 0.1, g = 0.1, b = 0.4 },
            oceanSediment = { r = 0.2, g = 0.2, b = 0.5 },
            beachSediment = { r = 0.6, g = 0.5, b = 0.3 },
            stone = { r = 0.4, g = 0.3, b = 0.2 }
        },

        depthDarkening = 0.5
    },

    rendering = {
        shadows = {
            adaptiveStepFactor = 0.5,
            stepAcceleration = 0.1,
            maxStepMultiplier = 3.0,
            penumbraDistanceScale = 0.02,
            shadowAccumulationLimit = 3.0,
            heightDifferenceScale = 1.0,
            lowAngleThreshold = 0.05,
            lowAngleTransitionSteepness = 15.0
        },

        water = {
            waveFrequencyX = 20.0,
            waveFrequencyY = 15.0,
            waveTimeScale = 0.5,
            waveAmplitude = 0.05,
            ambientReduction = 0.8
        },

        terrain = {
            detailFrequency = 0.5,
            detailAmplitude = 0.05,
            goldenHourHueShift = 0.2,
            goldenHourSaturationBoost = 0.3
        }
    }
}

return options
