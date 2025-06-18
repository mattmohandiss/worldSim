local terrain = require("world.terrain")
local lighting = require("world.lighting")

---@class World
---@field data table The voxel cubemap data
---@field size table World dimensions {x, y, z}
---@field timeOfDay number Current time of day (0-1)
---@field heightMap table Raw height map data
---@field heightMapTexture love.Image | nil Texture storing terrain height values
---@field colorMapTexture love.Image | nil Texture storing terrain colors
---@field shadowShader love.Shader | nil Shader for shadow calculations
local world = {
    data = {},
    size = {},
    timeOfDay = 0,
    heightMap = {},
    heightMapTexture = nil,
    colorMapTexture = nil,
    shadowShader = nil
}

---Generates a new terrain map
---@param settings {seed: number, size: {x: number, y: number, z: number}, noise: {octaves: number, persistence: number, scale: number}, batchSize: number} World generation settings
---@param options table Configuration options from options.lua
---@return table worldData The generated world data
function world.load(settings, options)
    local seed = settings.seed or os.time()
    love.math.setRandomSeed(seed)
    local seedOffset = love.math.random(1, 1000) * 0.01

    for x = 0, settings.size.x do
        world.heightMap[x] = {}
    end

    local sizeX, sizeY, sizeZ = settings.size.x, settings.size.y, settings.size.z
    local scaleX, scaleZ = 1 / sizeX, 1 / sizeZ
    local octaves, persistence, scale = settings.noise.octaves, settings.noise.persistence, settings.noise.scale

    -- First pass: determine height map using Perlin noise
    for x = 0, sizeX do
        for z = 0, sizeZ do
            local noiseValue = terrain.fractalPerlin(x * scaleX, z * scaleZ, octaves, persistence, scale, seedOffset)
            world.heightMap[x][z] = math.floor(noiseValue * sizeY)
        end
    end

    -- Second pass: fill the 3D world based on height map
    local batchSize = settings.batchSize or 10
    local worldData = {}

    for batchX = 0, sizeX, batchSize do
        -- Process a batch of X coordinates
        local endX = math.min(batchX + batchSize - 1, sizeX)

        for x = batchX, endX do
            worldData[x] = {}

            for y = 0, sizeY do
                -- Only allocate y-level tables when there's actual data
                local hasDataAtY = false
                local yData = {}

                for z = 0, sizeZ do
                    if y <= world.heightMap[x][z] then
                        -- Calculate depth once per voxel
                        local relativeDepth = world.heightMap[x][z] > 0 and (y / world.heightMap[x][z]) or 0

                        -- Get color and store directly (no temporary table)
                        yData[z] = terrain.color(
                            world.heightMap[x][z] / sizeY,
                            relativeDepth,
                            options.terrain.heightThresholds,
                            options.terrain.surfaceColors,
                            options.terrain.undergroundColors,
                            options.terrain.depthDarkening
                        )
                        hasDataAtY = true
                    end
                end

                -- Only store y-level table if it contains data
                if hasDataAtY then
                    worldData[x][y] = yData
                end
            end
        end
    end

    terrain.clearNoiseCache()

    world.data = worldData
    world.size = {
        x = sizeX,
        y = sizeY,
        z = sizeZ
    }

    world.shadowShader = love.graphics.newShader("shaders/shadow.glsl")

    -- Store options for use in rendering
    world.options = options

    -- Configure lighting system
    lighting.configure(options)

    world.createHeightMapTexture()
    world.createColorMapTexture()

    return worldData
end

---Updates world state
---@param dt number Delta time in seconds
function world.update(dt)
    lighting.update(dt)
    world.timeOfDay = lighting.getNormalizedTime()
end

---Gets the current time of day (0-1)
---@return number Time of day (0-1)
function world.getTimeOfDay()
    return world.timeOfDay
end

---Creates a texture containing the terrain height map
---@return love.Image The height map texture
function world.createHeightMapTexture()
    local sizeX, sizeY, sizeZ = world.size.x, world.size.y, world.size.z
    local imgData = love.image.newImageData(sizeX + 1, sizeZ + 1)
    local heightMap = world.heightMap

    for x = 0, sizeX do
        for z = 0, sizeZ do
            local normalizedHeight = heightMap[x][z] / sizeY
            imgData:setPixel(x, z, normalizedHeight, normalizedHeight, normalizedHeight, 1)
        end
    end

    world.heightMapTexture = love.graphics.newImage(imgData)
    world.heightMapTexture:setFilter("nearest", "nearest")

    return world.heightMapTexture
end

---Creates a texture containing the terrain color map
---@return love.Image The color map texture
function world.createColorMapTexture()
    local sizeX, sizeY, sizeZ = world.size.x, world.size.y, world.size.z
    local imgData = love.image.newImageData(sizeX + 1, sizeZ + 1)
    local heightMap = world.heightMap

    for x = 0, sizeX do
        for z = 0, sizeZ do
            local highestY = heightMap[x][z]
            if world.data[x] and world.data[x][highestY] and world.data[x][highestY][z] then
                local color = world.data[x][highestY][z]
                imgData:setPixel(x, z, color.r, color.g, color.b, 1)
            end
        end
    end

    world.colorMapTexture = love.graphics.newImage(imgData)
    world.colorMapTexture:setFilter("nearest", "nearest")

    return world.colorMapTexture
end

---Renders the world from top-down view
---@return nil
function world.render()
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local scale = math.min(screenWidth / world.size.x, screenHeight / world.size.z)

    local worldScaledWidth = world.size.x * scale
    local worldScaledHeight = world.size.z * scale
    local xOffset = (screenWidth - worldScaledWidth) / 2
    local yOffset = (screenHeight - worldScaledHeight) / 2

    local lightInfo = lighting.getLightingInfo()
    local sunInfo = lighting.getSunInfo()
    local ambientColor = lighting.getAmbientColor()

    local sunDir = lightInfo.sun.direction
    local moonDir = lightInfo.moon.direction

    love.graphics.setShader(world.shadowShader)

    world.shadowShader:send("heightMap", world.heightMapTexture)
    world.shadowShader:send("worldSize", { world.size.x, world.size.z })
    world.shadowShader:send("maxHeight", world.size.y)
    world.shadowShader:send("sunDirection", { sunDir.x, sunDir.y, sunDir.z })
    world.shadowShader:send("moonDirection", { moonDir.x, moonDir.y, moonDir.z })
    world.shadowShader:send("moonIntensity", sunInfo.moonIntensity)
    world.shadowShader:send("ambientColor", { ambientColor.r, ambientColor.g, ambientColor.b, 1 })

    world.shadowShader:send("dayNightBlend", lightInfo.dayNightBlend)
    world.shadowShader:send("twilightFactor", lightInfo.twilightFactor)
    world.shadowShader:send("shadowSoftness", lightInfo.shadow.softness)

    -- Send rendering options to shader
    local renderOpts = world.options.rendering
    world.shadowShader:send("adaptiveStepFactor", renderOpts.shadows.adaptiveStepFactor)
    world.shadowShader:send("stepAcceleration", renderOpts.shadows.stepAcceleration)
    world.shadowShader:send("maxStepMultiplier", renderOpts.shadows.maxStepMultiplier)
    world.shadowShader:send("penumbraDistanceScale", renderOpts.shadows.penumbraDistanceScale)
    world.shadowShader:send("shadowAccumulationLimit", renderOpts.shadows.shadowAccumulationLimit)
    world.shadowShader:send("heightDifferenceScale", renderOpts.shadows.heightDifferenceScale)
    world.shadowShader:send("lowAngleThreshold", renderOpts.shadows.lowAngleThreshold)
    world.shadowShader:send("lowAngleTransitionSteepness", renderOpts.shadows.lowAngleTransitionSteepness)

    world.shadowShader:send("waveFrequencyX", renderOpts.water.waveFrequencyX)
    world.shadowShader:send("waveFrequencyY", renderOpts.water.waveFrequencyY)
    world.shadowShader:send("waveTimeScale", renderOpts.water.waveTimeScale)
    world.shadowShader:send("waveAmplitude", renderOpts.water.waveAmplitude)
    world.shadowShader:send("ambientReduction", renderOpts.water.ambientReduction)

    world.shadowShader:send("detailFrequency", renderOpts.terrain.detailFrequency)
    world.shadowShader:send("detailAmplitude", renderOpts.terrain.detailAmplitude)
    world.shadowShader:send("goldenHourHueShift", renderOpts.terrain.goldenHourHueShift)
    world.shadowShader:send("goldenHourSaturationBoost", renderOpts.terrain.goldenHourSaturationBoost)

    local time = love.timer.getTime()
    world.shadowShader:send("time", time % 1000.0)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(world.colorMapTexture, xOffset, yOffset, 0, scale, scale)

    -- Reset shader
    love.graphics.setShader()
end

return world
