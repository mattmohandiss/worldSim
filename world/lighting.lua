---@class Lighting
---@field DAY_LENGTH number Duration of a full day-night cycle in real seconds
---@field hour number Current time in hours (0-24, where 0/24=midnight, 12=noon)
---@field celestial table Celestial bodies information
---@field light table Light intensity and color information
---@field color table Current light color (RGB)
---@field shadow table Shadow characteristics
local lighting = {}

-- Configuration object - populated by configure()
local config = {}
lighting.hour = 12 -- Will be set by configure()

---Configures the lighting system with options
---@param options table Configuration options from options.lua
function lighting.configure(options)
    local opts = options.lighting

    -- Flatten configuration for performance
    config = {
        -- Temporal
        dayLength = opts.temporal.dayLength,
        startHour = opts.temporal.startHour,

        -- Celestial
        sunMaxHeight = opts.celestial.sunMaxHeight,
        sunPathOffset = opts.celestial.sunPathOffset,
        moonMaxHeight = opts.celestial.moonMaxHeight,
        moonPathOffset = opts.celestial.moonPathOffset,
        horizonThreshold = opts.celestial.horizonThreshold,
        moonLightIntensity = opts.celestial.moonLightIntensity,

        -- Intensity
        ambientMin = opts.intensity.ambientMin,
        ambientMax = opts.intensity.ambientMax,
        sunMin = opts.intensity.sunMin,
        sunMax = opts.intensity.sunMax,
        twilightStrength = opts.intensity.twilightStrength,
        horizonBlendRange = opts.intensity.horizonBlendRange,

        -- Transitions
        sunHeightSteepness = opts.transitions.sunHeightSteepness,
        moonHeightSteepness = opts.transitions.moonHeightSteepness,
        shadowTransitionSteepness = opts.transitions.shadowTransitionSteepness,
        sunTransitionMidpoint = opts.transitions.sunTransitionMidpoint,
        moonTransitionMidpoint = opts.transitions.moonTransitionMidpoint,
        shadowTransitionMidpoint = opts.transitions.shadowTransitionMidpoint,

        -- Time bells
        dawnWidth = opts.timeBells.dawnWidth,
        duskWidth = opts.timeBells.duskWidth,
        nightWidth = opts.timeBells.nightWidth,

        -- Color temperature
        tempDawn = opts.colorTemperature.dawn,
        tempMorning = opts.colorTemperature.morning,
        tempNoon = opts.colorTemperature.noon,
        tempAfternoon = opts.colorTemperature.afternoon,
        tempDusk = opts.colorTemperature.dusk,
        tempNight = opts.colorTemperature.night,

        -- Atmosphere
        rayleighRed = opts.atmosphere.rayleighRed,
        rayleighGreen = opts.atmosphere.rayleighGreen,
        rayleighBlue = opts.atmosphere.rayleighBlue,
        scatteringPower = opts.atmosphere.scatteringPower,
        scatteringBase = opts.atmosphere.scatteringBase,
        scatteringRange = opts.atmosphere.scatteringRange,
        scatteringGreenPower = opts.atmosphere.scatteringGreenPower,
        scatteringBlueBase = opts.atmosphere.scatteringBlueBase,
        scatteringBlueRange = opts.atmosphere.scatteringBlueRange,

        -- Color blending
        hueBlendSmoothness = opts.colorBlending.hueBlendSmoothness,
        saturationPreservation = opts.colorBlending.saturationPreservation,
        lightnessGamma = opts.colorBlending.lightnessGamma,
        twilightHueShift = opts.colorBlending.twilightHueShift,
        twilightSaturationBoost = opts.colorBlending.twilightSaturationBoost,
        scatteringInfluence = opts.colorBlending.scatteringInfluence,
        colorBlendingScatteringRange = opts.colorBlending.scatteringRange,

        -- Shadows
        sunShadowScale = opts.shadows.sunShadowScale,
        moonShadowScale = opts.shadows.moonShadowScale,
        sunSoftnessBase = opts.shadows.sunSoftnessBase,
        sunSoftnessRange = opts.shadows.sunSoftnessRange,
        sunSoftnessSteepness = opts.shadows.sunSoftnessSteepness,
        sunSoftnessMidpoint = opts.shadows.sunSoftnessMidpoint,
        moonSoftnessBase = opts.shadows.moonSoftnessBase,
        moonSoftnessRange = opts.shadows.moonSoftnessRange,
        moonSoftnessSteepness = opts.shadows.moonSoftnessSteepness,
        moonSoftnessMidpoint = opts.shadows.moonSoftnessMidpoint,
        dawnDuskSoftnessBoost = opts.shadows.dawnDuskSoftnessBoost,
        dawnDuskWidth = opts.shadows.dawnDuskWidth,

        -- Intensity calculations
        sunLightBase = opts.intensity_calc.sunLightBase,
        sunLightRange = opts.intensity_calc.sunLightRange,
        moonLightBase = opts.intensity_calc.moonLightBase,
        moonLightRange = opts.intensity_calc.moonLightRange,
        colorIntensityBase = opts.intensity_calc.colorIntensityBase,
        colorIntensityRange = opts.intensity_calc.colorIntensityRange,
        totalIntensityLimit = opts.intensity_calc.totalIntensityLimit,
        totalIntensityDamping = opts.intensity_calc.totalIntensityDamping,

        -- Sky brightness
        ambientBase = opts.skyBrightness.ambientBase,
        dayTransitionMidpoint = opts.skyBrightness.dayTransitionMidpoint,
        dayTransitionSteepness = opts.skyBrightness.dayTransitionSteepness,
        moonBrightnessTransitionMidpoint = opts.skyBrightness.moonTransitionMidpoint,
        moonTransitionSteepness = opts.skyBrightness.moonTransitionSteepness,
        softClampThreshold = opts.skyBrightness.softClampThreshold,
        softClampDamping = opts.skyBrightness.softClampDamping
    }

    -- Set starting hour
    lighting.hour = config.startHour
end

---Updates the lighting state based on elapsed time
---@param dt number Delta time in seconds
function lighting.update(dt)
    lighting.hour = (lighting.hour + dt * 24 / config.dayLength) % 24
    lighting.calculateProperties()
end

---Converts hour time to normalized time (0-1)
---@return number Normalized time value
function lighting.getNormalizedTime()
    return lighting.hour / 24
end

---Unified transition function using generalized logistic function
---@param x number Input value (typically 0-1)
---@param midpoint number Center point of transition (typically 0-1)
---@param steepness number How steep the transition is (higher = steeper)
---@param min number Minimum output value
---@param max number Maximum output value
---@return number Result between min and max
function lighting.transition(x, midpoint, steepness, min, max)
    return min + (max - min) / (1 + math.exp(-steepness * (x - midpoint)))
end

---Normalized bell curve centered at a specific time
---@param hour number Current time in hours (0-24)
---@param centerHour number Hour at which the curve peaks
---@param width number Width of the bell curve
---@return number Factor between 0-1, with 1 at centerHour
function lighting.timeBell(hour, centerHour, width)
    local hourDiff = (hour - centerHour + 24) % 24
    if hourDiff > 12 then hourDiff = 24 - hourDiff end
    return math.exp(-(hourDiff * hourDiff) / width)
end

---Cyclical function that smoothly varies with time
---@param hour number Current time in hours (0-24)
---@param period number Period in hours
---@param phase number Phase offset in radians
---@param min number Minimum value
---@param max number Maximum value
---@return number Value between min and max
function lighting.cyclical(hour, period, phase, min, max)
    local angle = ((hour / period) * 2 * math.pi) + phase
    local normalized = (math.sin(angle) + 1) / 2
    return min + (max - min) * normalized
end

---Normalize a set of factors to sum to 1.0
---@param factors table Table of numeric factors
---@return table Normalized factors that sum to 1.0
function lighting.normalizeFactors(factors)
    local sum = 0
    for _, value in pairs(factors) do
        sum = sum + value
    end

    local result = {}
    local epsilon = 0.0001

    -- Prevent division by zero
    if sum < epsilon then
        local count = 0
        for _ in pairs(factors) do count = count + 1 end
        for key in pairs(factors) do
            result[key] = 1.0 / count
        end
        return result
    end

    -- Normal case
    for key, value in pairs(factors) do
        result[key] = value / sum
    end

    return result
end

---Convert color temperature (Kelvin) to RGB color
---@param kelvin number Color temperature in Kelvin (1000-40000)
---@return {r:number, g:number, b:number} RGB color with r,g,b components (0-1)
function lighting.kelvinToRGB(kelvin)
    local temp = math.min(40000, math.max(1000, kelvin)) / 100
    local r, g, b

    -- Red component
    if temp <= 66 then
        r = 255
    else
        r = temp - 60
        r = 329.698727446 * (r ^ -0.1332047592)
        r = math.max(0, math.min(255, r))
    end

    -- Green component
    if temp <= 66 then
        g = temp
        g = 99.4708025861 * math.log(g) - 161.1195681661
    else
        g = temp - 60
        g = 288.1221695283 * (g ^ -0.0755148492)
    end
    g = math.max(0, math.min(255, g))

    -- Blue component
    if temp >= 66 then
        b = 255
    elseif temp <= 19 then
        b = 0
    else
        b = temp - 10
        b = 138.5177312231 * math.log(b) - 305.0447927307
        b = math.max(0, math.min(255, b))
    end

    -- Normalize to 0-1 range
    return { r = r / 255, g = g / 255, b = b / 255 }
end

---Convert RGB to HSL color space
---@param rgb {r:number, g:number, b:number} RGB color with r,g,b components (0-1)
---@return {h:number, s:number, l:number} HSL color with h,s,l components (h: 0-1, s: 0-1, l: 0-1)
function lighting.rgbToHSL(rgb)
    local r, g, b = rgb.r, rgb.g, rgb.b
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, l

    l = (max + min) / 2

    if max == min then
        h, s = 0, 0 -- achromatic
    else
        local d = max - min
        s = l > 0.5 and d / (2 - max - min) or d / (max + min)

        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end

        h = h / 6
    end

    return { h = h, s = s, l = l }
end

---Convert HSL to RGB color space
---@param hsl {h:number, s:number, l:number} HSL color with h,s,l components (h: 0-1, s: 0-1, l: 0-1)
---@return {r:number, g:number, b:number} RGB color with r,g,b components (0-1)
function lighting.hslToRGB(hsl)
    local h, s, l = hsl.h, hsl.s, hsl.l
    local r, g, b

    if s == 0 then
        r, g, b = l, l, l -- achromatic
    else
        local function hue2rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1 / 6 then return p + (q - p) * 6 * t end
            if t < 1 / 2 then return q end
            if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
            return p
        end

        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q

        r = hue2rgb(p, q, h + 1 / 3)
        g = hue2rgb(p, q, h)
        b = hue2rgb(p, q, h - 1 / 3)
    end

    return { r = r, g = g, b = b }
end

---Calculate atmospheric scattering effect based on sun height
---@param sunHeight number Height of sun (-1 to 1)
---@return {r:number, g:number, b:number} Color modifiers for atmospheric scattering
function lighting.atmosphericScattering(sunHeight)
    -- Normalize sun height to 0-1
    local normalizedHeight = (sunHeight + 1) / 2

    -- Rayleigh scattering simulation using config values
    local scattering = {
        r = config.scatteringBase + config.scatteringRange * (1 - normalizedHeight),
        g = config.scatteringBase + 0.3 * (1 - math.pow(normalizedHeight, config.scatteringGreenPower)),
        b = config.scatteringBlueBase + config.scatteringBlueRange * normalizedHeight
    }

    return scattering
end

---Blend colors in HSL space for more natural transitions
---@param colors table[] Table of RGB colors
---@param weights number[] Table of weights for each color
---@return {r:number, g:number, b:number} Resulting RGB color
function lighting.blendColorsHSL(colors, weights)
    -- Convert all colors to HSL
    local hslColors = {}
    for i, color in ipairs(colors) do
        hslColors[i] = lighting.rgbToHSL(color)
    end

    -- Blend in HSL space
    local result = { h = 0, s = 0, l = 0 }

    for i, hsl in ipairs(hslColors) do
        result.s = result.s + hsl.s * weights[i]
        result.l = result.l + hsl.l * weights[i]

        -- Special handling for hue to avoid the 0/1 boundary issue
        -- Convert to angle in radians, use sin/cos to blend, then convert back
        local angle = hsl.h * 2 * math.pi
        result.h = result.h + angle * weights[i]
    end

    -- Convert h back from radians to 0-1 range
    result.h = result.h / (2 * math.pi)

    -- Convert back to RGB
    return lighting.hslToRGB(result)
end

---@class CelestialBody
---@field angle number Horizontal angle in radians
---@field height number Vertical position (-1 to 1, where 1 is highest point)
---@field direction {x:number, y:number, z:number} Direction vector

---@class CelestialData
---@field sun CelestialBody Sun position information
---@field moon CelestialBody Moon position information
---@field skyBrightness number Sky brightness value (0-1)

lighting.celestial = {
    sun = {
        angle = 0,
        height = 0,
        direction = { x = 0, y = 0, z = 0 }
    },
    moon = {
        angle = 0,
        height = 0,
        direction = { x = 0, y = 0, z = 0 }
    },
    skyBrightness = 0
}

---Calculates celestial body positions based on current time
---@param hour number Current time in hours (0-24)
function lighting.calculateCelestialPositions(hour)
    -- Convert hour to angle (0-24 maps to 0-2π)
    local dayAngle = (hour / 24) * 2 * math.pi

    -- Calculate sun position using unified cyclical function
    lighting.celestial.sun.angle = dayAngle + config.sunPathOffset

    -- Pure continuous function for sun height using cyclical function
    local sunHeight = lighting.cyclical(
        hour,
        24,
        -math.pi / 2, -- Start at lowest at midnight
        -config.sunMaxHeight,
        config.sunMaxHeight
    )
    lighting.celestial.sun.height = sunHeight

    -- Calculate sun direction vector
    lighting.celestial.sun.direction = {
        x = math.cos(lighting.celestial.sun.angle),
        y = sunHeight,
        z = math.sin(lighting.celestial.sun.angle)
    }

    -- Calculate moon position using unified cyclical function
    lighting.celestial.moon.angle = (dayAngle + math.pi) % (2 * math.pi) + config.moonPathOffset

    -- Pure continuous function for moon height using cyclical function
    local moonHeight = lighting.cyclical(
        (hour + 12) % 24, -- Moon is opposite of sun
        24,
        -math.pi / 2,
        -config.moonMaxHeight,
        config.moonMaxHeight
    )
    lighting.celestial.moon.height = moonHeight

    -- Calculate moon direction vector
    lighting.celestial.moon.direction = {
        x = math.cos(lighting.celestial.moon.angle),
        y = moonHeight,
        z = math.sin(lighting.celestial.moon.angle)
    }

    -- Calculate sky brightness using unified functions
    lighting.celestial.skyBrightness = lighting.calculateSkyBrightness(sunHeight, moonHeight)
end

---Calculates sky brightness based on sun and moon height
---@param sunHeight number Sun height (-1 to 1)
---@param moonHeight number Moon height (-1 to 1)
---@return number Sky brightness (0-1)
function lighting.calculateSkyBrightness(sunHeight, moonHeight)
    -- Convert to normalized ranges for transition function
    local sunNormalized = (sunHeight + 1) / 2
    local moonNormalized = (moonHeight + 1) / 2

    -- Calculate sun and moon brightness using unified transition function
    local dayBrightness = lighting.transition(sunNormalized, config.dayTransitionMidpoint, config.dayTransitionSteepness,
        0, 1)
    local moonBrightness = lighting.transition(moonNormalized, config.moonBrightnessTransitionMidpoint,
        config.moonTransitionSteepness, 0, config.moonLightIntensity)

    -- Minimum ambient light
    local ambientBase = config.ambientBase

    -- Total brightness with soft upper limit
    local totalBrightness = ambientBase + dayBrightness + moonBrightness

    -- Soft clamping for smooth transition near max brightness
    if totalBrightness > config.softClampThreshold then
        totalBrightness = config.softClampThreshold +
        (totalBrightness - config.softClampThreshold) * config.softClampDamping
    end

    return math.min(1.0, totalBrightness)
end

---@class LightProperties
---@field intensity number Overall light intensity (0-1)
---@field ambient number Ambient light level
---@field sunFactor number Sun contribution
---@field moonFactor number Moon contribution
---@field twilightFactor number Twilight contribution (golden hour)
---@field dayNightBlend number Smooth day/night transition blend factor (0-1)

lighting.light = {
    intensity = 0,
    ambient = 0,
    sunFactor = 0,
    moonFactor = 0,
    twilightFactor = 0,
    dayNightBlend = 0
}


---Smooth curve for better transitions
---@param edge0 number Lower edge (usually 0)
---@param edge1 number Upper edge (usually 1)
---@param x number Input value (usually 0-1)
---@return number Smoothed value
function lighting.smoothstep(edge0, edge1, x)
    x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
    return x * x * (3 - 2 * x)
end

---Calculates light properties based on celestial positions
function lighting.calculateLightProperties()
    local sun = lighting.celestial.sun
    local moon = lighting.celestial.moon

    -- Convert sun height to 0-1 range for unified transition functions
    local sunNormalized = (sun.height + 1) / 2

    -- Use unified transition function for sun contribution
    local sunFactor = lighting.transition(sunNormalized, config.sunTransitionMidpoint, config.sunHeightSteepness, 0, 1)

    -- Apply min/max range with smooth interpolation
    sunFactor = config.sunMin + (config.sunMax - config.sunMin) * sunFactor

    -- Convert moon height to 0-1 range for unified transition functions
    local moonNormalized = (moon.height + 1) / 2

    -- Use unified transition function for moon contribution
    local moonFactor = lighting.transition(moonNormalized, config.moonTransitionMidpoint, config.moonHeightSteepness, 0,
            1) *
        config.moonLightIntensity

    -- Calculate twilight factor using the unified bell curve function
    -- This creates a natural golden-hour effect that peaks at sunrise/sunset
    local twilightFactor = lighting.timeBell(lighting.hour, 6, config.dawnWidth) * config.twilightStrength
    -- Add evening twilight
    twilightFactor = twilightFactor + lighting.timeBell(lighting.hour, 18, config.duskWidth) * config.twilightStrength

    -- Ambient light with cyclical variation based on time
    local ambientLight = lighting.cyclical(
        lighting.hour,
        24,
        0,
        config.ambientMin,
        config.ambientMax
    )

    -- Completely smooth day/night transition using unified transition function
    local dayNightBlend = lighting.transition(sunNormalized, 0.5, config.sunHeightSteepness, 0, 1)

    -- Store calculated properties
    lighting.light.sunFactor = sunFactor
    lighting.light.moonFactor = moonFactor
    lighting.light.twilightFactor = twilightFactor
    lighting.light.ambient = ambientLight
    lighting.light.dayNightBlend = dayNightBlend

    -- Total light intensity with smooth blending of all components
    -- Ensure natural light addition without sharp cutoffs
    local totalIntensity = ambientLight + sunFactor + moonFactor + twilightFactor

    -- Soft upper limit to avoid oversaturation
    if totalIntensity > config.totalIntensityLimit then
        totalIntensity = config.totalIntensityLimit +
        (totalIntensity - config.totalIntensityLimit) * config.totalIntensityDamping
    end

    lighting.light.intensity = math.min(1.0, totalIntensity)
end

---@type {r:number, g:number, b:number}
lighting.color = {
    r = 1,
    g = 1,
    b = 1
}

---Calculates light color based on time of day using temperature model
---@param hour number Current time in hours (0-24)
---@return {r:number, g:number, b:number} The calculated light color
function lighting.calculateLightColor(hour)
    -- Define time-specific factors using unified bell curves
    local timeFactors = {
        dawn = lighting.timeBell(hour, 6, 2),       -- Centered at 6am
        morning = lighting.timeBell(hour, 9, 4),    -- Centered at 9am
        noon = lighting.timeBell(hour, 12, 6),      -- Centered at noon
        afternoon = lighting.timeBell(hour, 15, 4), -- Centered at 3pm
        dusk = lighting.timeBell(hour, 18, 2),      -- Centered at 6pm
        night = lighting.timeBell(hour, 0, 6)       -- Centered at midnight
    }

    -- Normalize factors to sum to 1.0
    timeFactors = lighting.normalizeFactors(timeFactors)

    -- Define color temperatures (in Kelvin) for each time of day
    local temperatures = {
        dawn = config.tempDawn,
        morning = config.tempMorning,
        noon = config.tempNoon,
        afternoon = config.tempAfternoon,
        dusk = config.tempDusk,
        night = config.tempNight
    }

    -- Calculate blended color temperature
    local temperature = 0
    for time, factor in pairs(timeFactors) do
        temperature = temperature + temperatures[time] * factor
    end

    -- Convert temperature to RGB
    local tempColor = lighting.kelvinToRGB(temperature)

    -- Apply atmospheric scattering based on sun height
    local sunHeight = lighting.celestial.sun.height
    local scattering = lighting.atmosphericScattering(sunHeight)

    -- Blend base temperature color with scattering in HSL space
    local hslTemp = lighting.rgbToHSL(tempColor)

    -- Adjust hue and saturation based on scattering
    -- This simulates the way atmosphere scatters different wavelengths
    hslTemp.s = hslTemp.s * (config.scatteringInfluence + config.scatteringRange * scattering.r)

    -- Apply twilight enhancement (dawn/dusk golden hour)
    local twilightFactor = lighting.light.twilightFactor
    if twilightFactor > 0.01 then
        -- Enhance golden colors during twilight
        hslTemp.h = hslTemp.h * config.twilightHueShift                                              -- Shift toward yellow/gold
        hslTemp.s = math.min(1.0, hslTemp.s * (1 + twilightFactor * config.twilightSaturationBoost)) -- Increase saturation
    end

    -- Convert back to RGB
    local color = lighting.hslToRGB(hslTemp)

    -- Apply light intensity
    local intensity = lighting.light.intensity
    local colorIntensity = config.colorIntensityBase + config.colorIntensityRange * intensity

    -- Store final color
    lighting.color = {
        r = color.r * colorIntensity,
        g = color.g * colorIntensity,
        b = color.b * colorIntensity
    }

    return lighting.color
end

---@class ShadowProperties
---@field strength number Overall shadow intensity
---@field softness number How soft shadows appear (higher = softer)

---@type ShadowProperties
lighting.shadow = {
    strength = 0,
    softness = 0
}

---Calculates shadow properties based on sun and moon positions
function lighting.calculateShadowProperties()
    local sun = lighting.celestial.sun
    local moon = lighting.celestial.moon

    -- Convert to normalized range for sigmoid functions
    local sunNormalized = (sun.height + 1) / 2   -- 0 to 1 range
    local moonNormalized = (moon.height + 1) / 2 -- 0 to 1 range

    -- Continuous sigmoid shadow strength function for sun
    -- Creates a perfect S-curve with no cutoffs or thresholds
    local sunShadowStrength = 1 /
    (1 + math.exp(-config.shadowTransitionSteepness * (sunNormalized - config.shadowTransitionMidpoint)))
    sunShadowStrength = sunShadowStrength * config.sunShadowScale

    -- Continuous sigmoid shadow strength function for moon
    -- Creates a perfect S-curve with no cutoffs or thresholds
    local moonShadowStrength = 1 /
    (1 + math.exp(-config.shadowTransitionSteepness * (moonNormalized - config.shadowTransitionMidpoint)))
    moonShadowStrength = moonShadowStrength * config.moonShadowScale

    -- Continuous shadow softness function using sigmoid for perfect smoothness
    -- Higher values when sun is low, lower (sharper shadows) when sun is high
    local sunShadowSoftness = config.sunSoftnessBase -
    config.sunSoftnessRange / (1 + math.exp(-config.sunSoftnessSteepness * (sunNormalized - config.sunSoftnessMidpoint)))

    -- Continuous shadow softness function for moon using sigmoid
    -- Moon shadows are always softer than sun shadows
    local moonShadowSoftness = config.moonSoftnessBase -
    config.moonSoftnessRange /
    (1 + math.exp(-config.moonSoftnessSteepness * (moonNormalized - config.moonSoftnessMidpoint)))

    -- Calculate influence with continuously varying weights
    -- Add small epsilon to avoid division by zero
    local totalStrength = sunShadowStrength + moonShadowStrength + 0.0001
    local sunInfluence = sunShadowStrength / totalStrength
    local moonInfluence = moonShadowStrength / totalStrength

    -- Special handling for dawn/dusk transitions
    -- Calculate proximity to dawn or dusk (6am or 6pm)
    local hourSinceSix = (lighting.hour % 12) - 6 -- -6 to 6 range, 0 at 6am/6pm
    local dawnDuskFactor = math.exp(-(hourSinceSix * hourSinceSix) / config.dawnDuskWidth)

    -- During dawn/dusk, slightly increase shadow softness for artistic effect
    local dawnDuskSoftnessBoost = dawnDuskFactor * config.dawnDuskSoftnessBoost

    -- Blend shadow properties with continuous weighting
    lighting.shadow.strength = sunShadowStrength * sunInfluence + moonShadowStrength * moonInfluence
    lighting.shadow.softness = (sunShadowSoftness * sunInfluence +
            moonShadowSoftness * moonInfluence) +
        dawnDuskSoftnessBoost
end

---Calculates all lighting properties based on current time
function lighting.calculateProperties()
    -- Calculate in sequence as each step may depend on the previous
    lighting.calculateCelestialPositions(lighting.hour)
    lighting.calculateLightProperties()
    lighting.calculateLightColor(lighting.hour)
    lighting.calculateShadowProperties()
end

---Gets comprehensive information about the lighting state
---@return {hour:number, normalizedTime:number, sun:CelestialBody, moon:CelestialBody, intensity:number, sunFactor:number, moonFactor:number, twilightFactor:number, dayNightBlend:number, color:{r:number, g:number, b:number}, shadow:ShadowProperties} Lighting information for rendering
function lighting.getLightingInfo()
    return {
        -- Time information
        hour = lighting.hour,
        normalizedTime = lighting.getNormalizedTime(),

        -- Celestial information
        sun = {
            angle = lighting.celestial.sun.angle,
            height = lighting.celestial.sun.height,
            direction = lighting.celestial.sun.direction
        },
        moon = {
            angle = lighting.celestial.moon.angle,
            height = lighting.celestial.moon.height,
            direction = lighting.celestial.moon.direction
        },

        -- Light properties
        intensity = lighting.light.intensity,
        sunFactor = lighting.light.sunFactor,
        moonFactor = lighting.light.moonFactor,
        twilightFactor = lighting.light.twilightFactor,
        dayNightBlend = lighting.light.dayNightBlend,

        -- Color
        color = lighting.color,

        -- Shadow
        shadow = lighting.shadow
    }
end

---Gets the ambient light color based on time of day
---@return {r:number, g:number, b:number} RGB color values (0-1)
function lighting.getAmbientColor()
    return lighting.color
end

---Gets the current sun/moon information
---@return {angle:number, height:number, intensity:number, moonAngle:number, moonHeight:number, moonIntensity:number, dayNightBlend:number, twilightFactor:number} Celestial information for shaders
function lighting.getSunInfo()
    return {
        -- Sun info
        angle = lighting.celestial.sun.angle,
        height = lighting.celestial.sun.height,
        intensity = lighting.light.intensity,

        -- Moon info
        moonAngle = lighting.celestial.moon.angle,
        moonHeight = lighting.celestial.moon.height,
        moonIntensity = lighting.light.moonFactor,

        -- Transition info for shader
        dayNightBlend = lighting.light.dayNightBlend,
        twilightFactor = lighting.light.twilightFactor
    }
end

-- Note: lighting system will be initialized when configure() is called

return lighting
