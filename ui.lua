---@class UI
local ui = {}

---Renders debug system information in the specified position
---@param x number X position of the debug info
---@param y number Y position of the debug info
---@return nil
function ui.renderDebugInfo(x, y)
    love.graphics.setColor(0, 1, 0) -- Green text for visibility

    local fps = love.timer.getFPS()
    love.graphics.print("FPS: " .. fps, x, y)

    local memoryUsage = collectgarbage("count") / 1024
    love.graphics.print("Memory: " .. string.format("%.2f MB", memoryUsage), x, y + 20)

    local stats = love.graphics.getStats()
    love.graphics.print("Draw Calls: " .. stats.drawcalls, x, y + 40)
    love.graphics.print("Texture Memory: " .. string.format("%.2f MB", stats.texturememory / 1024 / 1024), x, y + 60)
end

---Gets a more accurate description of the day phase based on hour
---@param hour number Hour of day (0-24)
---@return string Description of the current phase of day
local function getDayPhase(hour)
    if hour >= 5 and hour < 8 then
        return "Dawn"
    elseif hour >= 8 and hour < 12 then
        return "Morning"
    elseif hour >= 12 and hour < 14 then
        return "Noon"
    elseif hour >= 14 and hour < 17 then
        return "Afternoon"
    elseif hour >= 17 and hour < 19 then
        return "Sunset"
    elseif hour >= 19 and hour < 21 then
        return "Dusk"
    elseif hour >= 21 or hour < 1 then
        return "Night"
    else
        return "Deep Night"
    end
end

---Renders informational text on the screen
---@param x number X position of the text
---@param y number Y position of the text
---@param seed number World generation seed
---@param timeOfDay number Current time of day (0-1)
---@param hour number? Optional hour of day (0-24) for more precise time display
---@return nil
function ui.renderInfo(x, y, seed, timeOfDay, hour)
    love.graphics.setColor(0.9, 0.5, 0)

    love.graphics.print("Terrain Map (Top-Down View)", x, y)
    love.graphics.print("Seed: " .. seed, x, y + 20)

    local hourDisplay = hour or (timeOfDay * 24) -- Use provided hour if available
    local hours = math.floor(hourDisplay)
    local minutes = math.floor((hourDisplay * 60) % 60)
    local timeString = string.format("%02d:%02d", hours, minutes)

    local dayPhase = ""
    if hour then
        dayPhase = getDayPhase(hour)
    else
        if timeOfDay >= 0.0 and timeOfDay < 0.25 then
            dayPhase = "Morning"
        elseif timeOfDay >= 0.25 and timeOfDay < 0.5 then
            dayPhase = "Afternoon"
        elseif timeOfDay >= 0.5 and timeOfDay < 0.75 then
            dayPhase = "Night"
        else
            dayPhase = "Late Night"
        end
    end

    love.graphics.print("Time: " .. timeString .. " (" .. dayPhase .. ")", x, y + 40)
end

---Renders the sun/moon time indicator
---@param x number X position of the indicator (center point)
---@param y number Y position of the indicator (center point)
---@param timeOfDay number Current time of day (0-1)
---@param hour number? Optional hour (0-24) for more precise positioning
---@return nil
function ui.renderTimeIndicator(x, y, timeOfDay, hour)
    local indicatorRadius = 8
    local trackWidth = 160
    local orbitHeight = 25

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x - trackWidth / 2, y, trackWidth, 4)

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("6PM", x - trackWidth / 2 - 30, y)    -- West (left) - sunset (0.5)
    love.graphics.print("12PM", x - 15, y - orbitHeight - 15) -- Noon (top) (0.25)
    love.graphics.print("6AM", x + trackWidth / 2 + 5, y)     -- East (right) - sunrise (0.0)
    love.graphics.print("12AM", x - 15, y + orbitHeight + 5)  -- Midnight (bottom) (0.75)

    local currentHour = hour or (timeOfDay * 24)

    local isSun = (currentHour >= 6 and currentHour < 18)

    -- Calculate position along the time track to match the lighting system
    local normalizedAngle = (currentHour - 6) / 12 -- 0 at 6AM, 1 at 6PM, 1.5 at midnight
    local angle = -math.pi * normalizedAngle
    local posX = x + math.cos(angle) * (trackWidth / 2)
    local posY = y + math.sin(angle) * orbitHeight

    if isSun then
        local sunR, sunG, sunB = 1, 0.9, 0

        if currentHour < 8 or currentHour > 16 then
            sunR = 1
            sunG = 0.7
            sunB = 0.2
        end

        love.graphics.setColor(sunR, sunG, sunB, 0.3)
        love.graphics.circle("fill", posX, posY, indicatorRadius * 1.5)
        love.graphics.setColor(sunR, sunG, sunB)
        love.graphics.circle("fill", posX, posY, indicatorRadius)
    else
        love.graphics.setColor(0.8, 0.8, 1)
        love.graphics.circle("fill", posX, posY, indicatorRadius)

        love.graphics.setColor(0.6, 0.6, 0.8)
        love.graphics.circle("fill", posX - 2, posY - 1, 2)
        love.graphics.circle("fill", posX + 3, posY + 2, 1.5)
    end
end

return ui
