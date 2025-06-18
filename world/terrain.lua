---@class Terrain
local terrain = {}

---@type table<string, number>
local noiseCache = {}

---Generates fractal Perlin noise using LÖVE's `love.math.noise`.
---@param x number X-coordinate to sample
---@param y number Y-coordinate to sample
---@param octaves number Number of noise layers (more = more detail)
---@param persistence number Amplitude falloff per octave (lower = smoother)
---@param scale number Base frequency (higher = zoomed-in noise)
---@param seedOffset number? Optional offset to apply to coordinates for varied noise patterns
---@return number Normalized noise value [0, 1]
function terrain.fractalPerlin(x, y, octaves, persistence, scale, seedOffset)
    seedOffset = seedOffset or 0

    local cacheKey = string.format("%.3f:%.3f:%d:%.3f:%.3f:%.3f",
        x, y, octaves, persistence, scale, seedOffset)

    if noiseCache[cacheKey] then
        return noiseCache[cacheKey]
    end

    local total = 0
    local frequency = scale or 1
    local amplitude = 1
    local maxAmplitude = 0

    local freqX, freqY = x + seedOffset, y + seedOffset

    if octaves <= 4 then
        total = total + love.math.noise(freqX * frequency, freqY * frequency) * amplitude
        maxAmplitude = maxAmplitude + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2

        if octaves >= 2 then
            total = total + love.math.noise(freqX * frequency, freqY * frequency) * amplitude
            maxAmplitude = maxAmplitude + amplitude
            amplitude = amplitude * persistence
            frequency = frequency * 2

            if octaves >= 3 then
                total = total + love.math.noise(freqX * frequency, freqY * frequency) * amplitude
                maxAmplitude = maxAmplitude + amplitude
                amplitude = amplitude * persistence
                frequency = frequency * 2

                if octaves >= 4 then
                    total = total + love.math.noise(freqX * frequency, freqY * frequency) * amplitude
                    maxAmplitude = maxAmplitude + amplitude
                    amplitude = amplitude * persistence
                    frequency = frequency * 2
                end
            end
        end
    end

    for i = 5, octaves do
        total = total + love.math.noise(freqX * frequency, freqY * frequency) * amplitude
        maxAmplitude = maxAmplitude + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end

    local result = total / maxAmplitude
    noiseCache[cacheKey] = result
    return result
end

---Clears the noise cache to free memory after terrain generation
---@return number Number of entries cleared from cache
function terrain.clearNoiseCache()
    local cacheSize = 0
    for _ in pairs(noiseCache) do
        cacheSize = cacheSize + 1
    end

    noiseCache = {}
    return cacheSize
end

---Sets the color of a block at a certain position
---@param surfaceHeight number Normalized height of the surface (0-1)
---@param depth number Relative depth from surface (0-1, where 1 is at surface)
---@param thresholds {deepOcean: number, ocean: number, beach: number, grassland: number, mountain: number} Height thresholds
---@param surfaceColors table<string, {r: number, g: number, b: number}> Surface colors for each terrain type
---@param undergroundColors table<string, {r: number, g: number, b: number}> Underground colors for each terrain type
---@param depthDarkening number Depth darkening multiplier
---@return {r:number, g:number, b:number} Color table with r, g, b components
function terrain.color(surfaceHeight, depth, thresholds, surfaceColors, undergroundColors, depthDarkening)
    if depth > 0.9 then
        -- Surface terrain
        if surfaceHeight < thresholds.deepOcean then
            return surfaceColors.deepOcean
        elseif surfaceHeight < thresholds.ocean then
            return surfaceColors.ocean
        elseif surfaceHeight < thresholds.beach then
            return surfaceColors.beach
        elseif surfaceHeight < thresholds.grassland then
            return surfaceColors.grassland
        elseif surfaceHeight < thresholds.mountain then
            return surfaceColors.mountain
        else
            return surfaceColors.snow
        end
    else
        -- Underground terrain
        local darkening = depth * depthDarkening

        if surfaceHeight < thresholds.deepOcean then
            local color = undergroundColors.deepOceanSediment
            return { r = color.r * darkening, g = color.g * darkening, b = color.b * darkening }
        elseif surfaceHeight < thresholds.ocean then
            local color = undergroundColors.oceanSediment
            return { r = color.r * darkening, g = color.g * darkening, b = color.b * darkening }
        elseif surfaceHeight < thresholds.beach then
            local color = undergroundColors.beachSediment
            return { r = color.r * darkening, g = color.g * darkening, b = color.b * darkening }
        else
            local color = undergroundColors.stone
            return { r = color.r * darkening, g = color.g * darkening, b = color.b * darkening }
        end
    end
end

return terrain
