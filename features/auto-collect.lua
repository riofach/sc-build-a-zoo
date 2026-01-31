--[[
  features/auto-collect.lua
  Auto-collect money from animals in Build A Zoo
  
  Usage:
    local AutoCollect = require("features/auto-collect")
    AutoCollect.init()
    AutoCollect.start()  -- starts collection loop
    AutoCollect.stop()   -- stops collection loop
    
  Config (via setConfig):
    cycleInterval: seconds between collection cycles (default: 60)
    delayPerAnimal: seconds between each animal (default: 0.5)
    maxRetries: retry attempts per animal (default: 3)
--]]

-- Dependencies (loaded via pattern matching loader or direct require)
local Discovery = nil
local Timing = nil

-- Try to load dependencies
local function loadDependencies()
    -- Pattern 1: Direct require (if running as module)
    local success1, result1 = pcall(function()
        return require(script.Parent:FindFirstChild("game-discovery"))
    end)
    if success1 and result1 then
        Discovery = result1
    end
    
    -- Pattern 2: Global loader (if loaded via loadstring)
    if not Discovery then
        local success2, result2 = pcall(function()
            -- Check if _G has loader reference
            if _G.loadModule then
                return _G.loadModule("features/game-discovery")
            end
            return nil
        end)
        if success2 and result2 then
            Discovery = result2
        end
    end
    
    -- Pattern 3: Direct loadstring (standalone)
    if not Discovery then
        local success3, result3 = pcall(function()
            local source = game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/features/game-discovery.lua")
            return loadstring(source)()
        end)
        if success3 and result3 then
            Discovery = result3
        end
    end
    
    -- Load Timing module similarly
    local successT1, resultT1 = pcall(function()
        return require(script.Parent.Parent:FindFirstChild("core"):FindFirstChild("timing"))
    end)
    if successT1 and resultT1 then
        Timing = resultT1
    end
    
    if not Timing then
        local successT2, resultT2 = pcall(function()
            if _G.loadModule then
                return _G.loadModule("core/timing")
            end
            return nil
        end)
        if successT2 and resultT2 then
            Timing = resultT2
        end
    end
    
    if not Timing then
        local successT3, resultT3 = pcall(function()
            local source = game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/core/timing.lua")
            return loadstring(source)()
        end)
        if successT3 and resultT3 then
            Timing = resultT3
        end
    end
    
    -- Fallback Timing if still nil (basic implementation)
    if not Timing then
        Timing = {
            wait = function(delay)
                task.wait(delay * (0.8 + math.random() * 0.4)) -- 20% variance
                return delay
            end
        }
    end
    
    return Discovery ~= nil
end

-- Module State
local AutoCollect = {
    _active = false,
    _thread = nil,
    _connections = {},
    _discovery = nil,
    _stats = {
        cyclesCompleted = 0,
        totalCollected = 0,
        totalFailed = 0,
        lastCycleTime = 0,
    },
    _config = {
        cycleInterval = 60,      -- sesuai CONTEXT.md
        delayPerAnimal = 0.5,    -- sesuai CONTEXT.md
        maxRetries = 3,          -- sesuai CONTEXT.md
    },
}

-- ============================================================================
-- init()
-- Initialize the auto-collect module by running game discovery
-- Returns: boolean (success)
-- ============================================================================
function AutoCollect:init()
    print("[AutoCollect] Initializing...")
    
    -- Load dependencies first
    local depsLoaded = loadDependencies()
    if not depsLoaded then
        warn("[AutoCollect] Failed to load Discovery module")
        return false
    end
    
    -- Run game structure discovery
    local success, result = pcall(function()
        return Discovery.discoverGameStructure()
    end)
    
    if not success then
        warn("[AutoCollect] Discovery failed: " .. tostring(result))
        return false
    end
    
    self._discovery = result
    
    -- Validate we found player folder
    if not self._discovery.playerFolder then
        warn("[AutoCollect] Player folder not found - cannot auto-collect")
        return false
    end
    
    print("[AutoCollect] Initialized successfully")
    print("[AutoCollect] - Animals found: " .. (self._discovery.animalCount or 0))
    print("[AutoCollect] - Collect remote: " .. (self._discovery.collectRemote and self._discovery.collectRemote.Name or "NOT FOUND"))
    
    return true
end

-- ============================================================================
-- start()
-- Start the auto-collection loop
-- Returns: boolean (success)
-- ============================================================================
function AutoCollect:start()
    -- Guard: already active
    if self._active then
        warn("[AutoCollect] Already running")
        return false
    end
    
    -- Guard: init if not done
    if not self._discovery then
        local initSuccess = self:init()
        if not initSuccess then
            warn("[AutoCollect] Cannot start - initialization failed")
            return false
        end
    end
    
    self._active = true
    print("[AutoCollect] Starting collection loop (interval: " .. self._config.cycleInterval .. "s)")
    
    -- Spawn collection loop thread
    self._thread = task.spawn(function()
        while self._active do
            local success, err = pcall(function()
                self:collectCycle()
            end)
            if not success then
                warn("[AutoCollect] Cycle error: " .. tostring(err))
            end
            -- Randomized wait for next cycle
            if self._active then
                Timing.wait(self._config.cycleInterval)
            end
        end
    end)
    
    return true
end

-- ============================================================================
-- stop()
-- Stop the auto-collection loop and clean up
-- Returns: nil
-- ============================================================================
function AutoCollect:stop()
    print("[AutoCollect] Stopping...")
    
    self._active = false
    
    -- Cancel thread if exists
    if self._thread then
        local success, err = pcall(function()
            task.cancel(self._thread)
        end)
        if not success then
            -- Thread may have already completed, that's ok
        end
        self._thread = nil
    end
    
    -- Disconnect all connections
    for i, connection in ipairs(self._connections) do
        local success, err = pcall(function()
            if connection and typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            end
        end)
    end
    self._connections = {}
    
    print("[AutoCollect] Stopped")
end

-- ============================================================================
-- isActive()
-- Check if auto-collect is currently running
-- Returns: boolean
-- ============================================================================
function AutoCollect:isActive()
    return self._active
end

-- ============================================================================
-- getStats()
-- Get current statistics (shallow copy)
-- Returns: table
-- ============================================================================
function AutoCollect:getStats()
    return {
        cyclesCompleted = self._stats.cyclesCompleted,
        totalCollected = self._stats.totalCollected,
        totalFailed = self._stats.totalFailed,
        lastCycleTime = self._stats.lastCycleTime,
    }
end

-- ============================================================================
-- getConfig()
-- Get current configuration (shallow copy)
-- Returns: table
-- ============================================================================
function AutoCollect:getConfig()
    return {
        cycleInterval = self._config.cycleInterval,
        delayPerAnimal = self._config.delayPerAnimal,
        maxRetries = self._config.maxRetries,
    }
end

-- ============================================================================
-- setConfig(key, value)
-- Update a configuration value
-- Returns: boolean (success)
-- ============================================================================
function AutoCollect:setConfig(key, value)
    if self._config[key] ~= nil then
        self._config[key] = value
        print("[AutoCollect] Config updated: " .. key .. " = " .. tostring(value))
        return true
    else
        warn("[AutoCollect] Unknown config key: " .. tostring(key))
        return false
    end
end

-- Placeholder for collection methods (implemented in Task 2)
function AutoCollect:collectCycle()
    -- Will be implemented in Task 2
    print("[AutoCollect] collectCycle placeholder - not yet implemented")
end

function AutoCollect:collectFromAnimal(animal)
    -- Will be implemented in Task 2
    return false
end

-- ============================================================================
-- Module Export
-- ============================================================================
return {
    init = function() return AutoCollect:init() end,
    start = function() return AutoCollect:start() end,
    stop = function() return AutoCollect:stop() end,
    isActive = function() return AutoCollect:isActive() end,
    getStats = function() return AutoCollect:getStats() end,
    getConfig = function() return AutoCollect:getConfig() end,
    setConfig = function(k, v) return AutoCollect:setConfig(k, v) end,
}
