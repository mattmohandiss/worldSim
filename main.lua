local world = require("world")
local ui = require("ui")
local options = require("options")

---@class WorldSettings
---@field size {x: number, y: number, z: number} World dimensions
---@field noise {octaves: number, persistence: number, scale: number} Noise generation parameters
---@field seed number Random seed for terrain generation
---@field tileSize number Size of terrain tiles
---@field batchSize number Batch size for world generation
local worldSettings = {
    size = {
        x = options.world.dimensions.x,
        y = options.world.dimensions.y,
        z = options.world.dimensions.z
    },
    noise = {
        octaves = options.world.noise.octaves,
        persistence = options.world.noise.persistence,
        scale = options.world.noise.scale
    },
    seed = options.world.generation.seed or love.math.random(1, 1000000),
    tileSize = options.world.generation.tileSize,
    batchSize = options.world.generation.batchSize,
}

---LÖVE initialization callback
---@return nil
function love.load()
    love.math.setRandomSeed(os.time())
    world.load(worldSettings, options)
end

---LÖVE update callback
---@param dt number Delta time in seconds
---@return nil
function love.update(dt)
    world.update(dt)
end

---LÖVE draw callback
---@return nil
function love.draw()
    love.graphics.push()
    world.render()
    love.graphics.pop()

    local timeOfDay = world.getTimeOfDay()
    local hour = require("world.lighting").hour

    ui.renderInfo(10, 10, worldSettings.seed, timeOfDay, hour)
    ui.renderTimeIndicator(love.graphics.getWidth() / 2, love.graphics.getHeight() - 50, timeOfDay, hour)
    ui.renderDebugInfo(love.graphics.getWidth() - 175, 10)
end
