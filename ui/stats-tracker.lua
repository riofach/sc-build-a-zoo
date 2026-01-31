-- ui/stats-tracker.lua
-- Session stats management untuk UI display

local StatsTracker = {
    moneyCollected = 0,
    eggsHatched = 0,
    errorsCount = 0,
    sessionStart = os.time(),
}

-- Internal helper: Format number dengan thousand separator
-- 1250000 -> "1,250,000"
local function _formatNumber(num)
    local success, result = pcall(function()
        local formatted = tostring(math.floor(num or 0))
        local k
        while true do
            formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
            if k == 0 then break end
        end
        return formatted
    end)
    
    if success then
        return result
    else
        return "0"
    end
end

-- Increment money collected
-- @param amount: number to add (default 1 if nil)
-- @return self for method chaining
function StatsTracker.incrementMoney(amount)
    local success = pcall(function()
        local toAdd = amount or 1
        if type(toAdd) == "number" then
            StatsTracker.moneyCollected = StatsTracker.moneyCollected + toAdd
        end
    end)
    return StatsTracker
end

-- Increment eggs hatched
-- @param count: number to add (default 1 if nil)
-- @return self for method chaining
function StatsTracker.incrementEggs(count)
    local success = pcall(function()
        local toAdd = count or 1
        if type(toAdd) == "number" then
            StatsTracker.eggsHatched = StatsTracker.eggsHatched + toAdd
        end
    end)
    return StatsTracker
end

-- Increment errors count
-- @return self for method chaining
function StatsTracker.incrementErrors()
    local success = pcall(function()
        StatsTracker.errorsCount = StatsTracker.errorsCount + 1
    end)
    return StatsTracker
end

-- Get formatted money with thousand separator
-- @return string like "1,250,000"
function StatsTracker.getFormattedMoney()
    return _formatNumber(StatsTracker.moneyCollected)
end

-- Get formatted eggs with thousand separator
-- @return string like "1,250"
function StatsTracker.getFormattedEggs()
    return _formatNumber(StatsTracker.eggsHatched)
end

-- Get formatted errors with thousand separator
-- @return string like "15"
function StatsTracker.getFormattedErrors()
    return _formatNumber(StatsTracker.errorsCount)
end

-- Get session duration in seconds
-- @return number: seconds since session start
function StatsTracker.getSessionDuration()
    local success, duration = pcall(function()
        return os.time() - StatsTracker.sessionStart
    end)
    
    if success then
        return duration
    else
        return 0
    end
end

-- Get formatted session duration as HH:MM:SS
-- @return string like "01:23:45"
function StatsTracker.getFormattedDuration()
    local success, result = pcall(function()
        local seconds = StatsTracker.getSessionDuration()
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        local secs = seconds % 60
        return string.format("%02d:%02d:%02d", hours, mins, secs)
    end)
    
    if success then
        return result
    else
        return "00:00:00"
    end
end

-- Reset all counters
-- @return self for method chaining
function StatsTracker.reset()
    local success = pcall(function()
        StatsTracker.moneyCollected = 0
        StatsTracker.eggsHatched = 0
        StatsTracker.errorsCount = 0
        StatsTracker.sessionStart = os.time()
    end)
    return StatsTracker
end

-- Get raw stats table
-- @return table with all current stats
function StatsTracker.getStats()
    return {
        moneyCollected = StatsTracker.moneyCollected,
        eggsHatched = StatsTracker.eggsHatched,
        errorsCount = StatsTracker.errorsCount,
        sessionStart = StatsTracker.sessionStart,
        sessionDuration = StatsTracker.getSessionDuration(),
    }
end

return StatsTracker
