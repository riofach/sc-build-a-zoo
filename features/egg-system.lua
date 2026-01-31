--[[
  features/egg-system.lua
  Main orchestrator for the complete egg loop (buy → place → hatch)
  
  Usage:
    local EggSystem = require("features/egg-system")
    EggSystem.init()
    EggSystem.setTargetMutation("Shiny")
    EggSystem.start()  -- starts complete egg loop
    EggSystem.stop()   -- stops all sub-modules
    
  Exports:
    init, start, stop, setTargetMutation, getStats, getConfig, setConfig
    
  State Machine:
    IDLE → BUYING (via ConveyorMonitor callback)
    BUYING → PLACING (when holdingEgg = true)
    PLACING → IDLE (after egg placed)
    IDLE → HATCHING (when ready eggs found)
    HATCHING → IDLE (after eggs hatched)
--]]

-- Dependencies (loaded via pattern matching loader)
local EggBuyer = nil
local PlotManager = nil
local EggHatcher = nil
local ConveyorMonitor = nil
local Timing = nil

-- Try to load dependencies
local function loadDependencies()
    -- Load EggBuyer module
    local success1, result1 = pcall(function()
        return require(script.Parent:FindFirstChild("egg-buyer"))
    end)
    if success1 and result1 then
        EggBuyer = result1
    end
    
    if not EggBuyer then
        local success2, result2 = pcall(function()
            if _G.loadModule then
                return _G.loadModule("features/egg-buyer")
            end
            return nil
        end)
        if success2 and result2 then
            EggBuyer = result2
        end
    end
    
    -- Load PlotManager module
    local success3, result3 = pcall(function()
        return require(script.Parent:FindFirstChild("plot-manager"))
    end)
    if success3 and result3 then
        PlotManager = result3
    end
    
    if not PlotManager then
        local success4, result4 = pcall(function()
            if _G.loadModule then
                return _G.loadModule("features/plot-manager")
            end
            return nil
        end)
        if success4 and result4 then
            PlotManager = result4
        end
    end
    
    -- Load EggHatcher module
    local success5, result5 = pcall(function()
        return require(script.Parent:FindFirstChild("egg-hatcher"))
    end)
    if success5 and result5 then
        EggHatcher = result5
    end
    
    if not EggHatcher then
        local success6, result6 = pcall(function()
            if _G.loadModule then
                return _G.loadModule("features/egg-hatcher")
            end
            return nil
        end)
        if success6 and result6 then
            EggHatcher = result6
        end
    end
    
    -- Load ConveyorMonitor module
    local success7, result7 = pcall(function()
        return require(script.Parent:FindFirstChild("conveyor-monitor"))
    end)
    if success7 and result7 then
        ConveyorMonitor = result7
    end
    
    if not ConveyorMonitor then
        local success8, result8 = pcall(function()
            if _G.loadModule then
                return _G.loadModule("features/conveyor-monitor")
            end
            return nil
        end)
        if success8 and result8 then
            ConveyorMonitor = result8
        end
    end
    
    -- Load Timing module
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
    
    -- Fallback Timing if still nil
    if not Timing then
        Timing = {
            wait = function(delay)
                task.wait(delay * (0.8 + math.random() * 0.4)) -- 20% variance
                return delay
            end,
            getDelay = function(delay)
                return delay * (0.8 + math.random() * 0.4)
            end
        }
    end
    
    return EggBuyer ~= nil and PlotManager ~= nil and EggHatcher ~= nil
end

-- State constants
local STATE = {
    IDLE = "IDLE",
    BUYING = "BUYING",
    PLACING = "PLACING",
    HATCHING = "HATCHING",
}

-- Module State
local EggSystem = {
    _active = false,           -- boolean, is system running
    _thread = nil,             -- coroutine for main loop
    _connections = {},         -- table, for cleanup
    _state = STATE.IDLE,       -- current state
    _holdingEgg = false,       -- boolean, player currently holding egg
    _config = {
        targetMutation = nil,  -- string, mutation to auto-buy
        cycleDelay = 1.0,      -- seconds between state checks
        hatchDelay = 0.5,      -- seconds between hatch attempts
        placeDelay = 0.3,      -- seconds after placing
        enabled = true,        -- boolean, master enable switch
    },
    _stats = {
        eggsHatched = 0,
        eggsBought = 0,
        eggsPlaced = 0,
        cyclesCompleted = 0,
        lastState = STATE.IDLE,
        errors = 0,
    },
}

-- ============================================================================
-- _onEggBought(success, message)
-- Callback from EggBuyer when egg is purchased
-- ============================================================================
function EggSystem:_onEggBought(success, message)
    if success then
        self._holdingEgg = true
        self._stats.eggsBought = self._stats.eggsBought + 1
        self._state = STATE.PLACING
        print("[EggSystem] Egg bought, transitioning to PLACING state")
    else
        print("[EggSystem] Buy failed: " .. tostring(message))
        self._state = STATE.IDLE
    end
end

-- ============================================================================
-- _doPlaceEgg()
-- Execute egg placement logic
-- Returns: boolean success
-- ============================================================================
function EggSystem:_doPlaceEgg()
    if not PlotManager then
        warn("[EggSystem] PlotManager not available")
        return false
    end
    
    local success, result = pcall(function()
        -- Find empty plot
        local plot, prompt = PlotManager.findEmptyPlot()
        if not plot then
            print("[EggSystem] No empty plot available")
            return false
        end
        
        -- Place egg
        local placeSuccess = PlotManager.placeEgg(plot, prompt)
        if placeSuccess then
            self._holdingEgg = false
            self._stats.eggsPlaced = self._stats.eggsPlaced + 1
            print("[EggSystem] Egg placed on: " .. plot.Name)
            return true
        else
            print("[EggSystem] Failed to place egg on: " .. plot.Name)
            return false
        end
    end)
    
    if success then
        return result
    else
        warn("[EggSystem] _doPlaceEgg error: " .. tostring(result))
        self._stats.errors = self._stats.errors + 1
        return false
    end
end

-- ============================================================================
-- _doHatchEggs()
-- Execute egg hatching logic
-- Returns: number of eggs hatched
-- ============================================================================
function EggSystem:_doHatchEggs()
    if not EggHatcher then
        warn("[EggSystem] EggHatcher not available")
        return 0
    end
    
    local hatched = 0
    
    local success, result = pcall(function()
        -- Find ready eggs
        local readyEggs = EggHatcher.findReadyEggs()
        if #readyEggs == 0 then
            return 0
        end
        
        print("[EggSystem] Found " .. #readyEggs .. " ready eggs to hatch")
        
        -- Hatch each egg with delay
        for i, eggData in ipairs(readyEggs) do
            -- Check if still active
            if not self._active then
                break
            end
            
            local hatchSuccess = EggHatcher.hatchEgg(eggData.egg, eggData.prompt)
            if hatchSuccess then
                hatched = hatched + 1
                self._stats.eggsHatched = self._stats.eggsHatched + 1
            end
            
            -- Delay between hatches
            if i < #readyEggs and self._active then
                Timing.wait(self._config.hatchDelay)
            end
        end
        
        return hatched
    end)
    
    if success then
        return result
    else
        warn("[EggSystem] _doHatchEggs error: " .. tostring(result))
        self._stats.errors = self._stats.errors + 1
        return hatched
    end
end

-- ============================================================================
-- _mainLoop()
-- Main state machine loop
-- ============================================================================
function EggSystem:_mainLoop()
    print("[EggSystem] Main loop started")
    
    while self._active do
        local success, err = pcall(function()
            self._stats.lastState = self._state
            
            -- State machine
            if self._state == STATE.IDLE then
                -- Check for ready eggs first (priority)
                if EggHatcher then
                    local readyEggs = EggHatcher.findReadyEggs()
                    if #readyEggs > 0 then
                        self._state = STATE.HATCHING
                        return
                    end
                end
                
                -- Check if holding egg (need to place)
                if self._holdingEgg then
                    self._state = STATE.PLACING
                    return
                end
                
                -- Check EggBuyer holding status (in case we missed a buy)
                if EggBuyer and EggBuyer.isHoldingEgg and EggBuyer.isHoldingEgg() then
                    self._holdingEgg = true
                    self._state = STATE.PLACING
                    return
                end
                
                -- Buying is handled by ConveyorMonitor/EggBuyer callback
                -- Stay in IDLE
                
            elseif self._state == STATE.BUYING then
                -- This state is transient, handled by callback
                -- If we're stuck here, check holding status
                if EggBuyer and EggBuyer.isHoldingEgg and EggBuyer.isHoldingEgg() then
                    self._holdingEgg = true
                    self._state = STATE.PLACING
                else
                    -- Go back to IDLE if not holding
                    self._state = STATE.IDLE
                end
                
            elseif self._state == STATE.PLACING then
                -- Place the egg
                local placed = self:_doPlaceEgg()
                
                if placed then
                    Timing.wait(self._config.placeDelay)
                end
                
                -- Always go back to IDLE
                self._state = STATE.IDLE
                
            elseif self._state == STATE.HATCHING then
                -- Hatch ready eggs
                local hatched = self:_doHatchEggs()
                
                if hatched > 0 then
                    print("[EggSystem] Hatched " .. hatched .. " eggs this cycle")
                end
                
                -- Go back to IDLE
                self._state = STATE.IDLE
            end
            
            self._stats.cyclesCompleted = self._stats.cyclesCompleted + 1
        end)
        
        if not success then
            warn("[EggSystem] Main loop error: " .. tostring(err))
            self._stats.errors = self._stats.errors + 1
            self._state = STATE.IDLE
        end
        
        -- Wait before next cycle
        if self._active then
            Timing.wait(self._config.cycleDelay)
        end
    end
    
    print("[EggSystem] Main loop stopped")
end

-- ============================================================================
-- init()
-- Initialize the egg system and all sub-modules
-- Returns: boolean (success)
-- ============================================================================
function EggSystem:init()
    print("[EggSystem] Initializing...")
    
    -- Load dependencies
    local depsLoaded = loadDependencies()
    if not depsLoaded then
        warn("[EggSystem] Some dependencies not loaded - functionality may be limited")
    end
    
    -- Initialize PlotManager
    if PlotManager then
        local plotSuccess = PlotManager.init()
        if plotSuccess then
            print("[EggSystem] PlotManager initialized")
        else
            warn("[EggSystem] PlotManager init failed")
        end
    end
    
    -- Initialize EggHatcher with plots folder from PlotManager
    if EggHatcher then
        -- Try to get plots folder from PlotManager internal state
        -- Note: This is a bit hacky, ideally PlotManager would expose getPlotsFolder()
        local hatchSuccess = EggHatcher.init()
        if hatchSuccess then
            print("[EggSystem] EggHatcher initialized")
        else
            warn("[EggSystem] EggHatcher init failed")
        end
    end
    
    -- Initialize EggBuyer (which also initializes ConveyorMonitor)
    if EggBuyer then
        local buyerSuccess = EggBuyer.init()
        if buyerSuccess then
            print("[EggSystem] EggBuyer initialized")
        else
            warn("[EggSystem] EggBuyer init failed")
        end
    end
    
    -- Validate minimal setup
    if not PlotManager then
        warn("[EggSystem] PlotManager required for egg placement")
    end
    
    print("[EggSystem] Initialized successfully")
    print("[EggSystem] - EggBuyer: " .. (EggBuyer and "loaded" or "NOT LOADED"))
    print("[EggSystem] - PlotManager: " .. (PlotManager and "loaded" or "NOT LOADED"))
    print("[EggSystem] - EggHatcher: " .. (EggHatcher and "loaded" or "NOT LOADED"))
    print("[EggSystem] - ConveyorMonitor: " .. (ConveyorMonitor and "loaded" or "NOT LOADED"))
    
    return true
end

-- ============================================================================
-- start()
-- Start the complete egg loop
-- Returns: boolean (success)
-- ============================================================================
function EggSystem:start()
    -- Guard: already active
    if self._active then
        warn("[EggSystem] Already running")
        return false
    end
    
    -- Init if not done
    if not EggBuyer and not PlotManager then
        local initSuccess = self:init()
        if not initSuccess then
            warn("[EggSystem] Cannot start - initialization failed")
            return false
        end
    end
    
    self._active = true
    self._state = STATE.IDLE
    
    print("[EggSystem] Starting egg system...")
    
    -- Set target mutation on EggBuyer if configured
    if EggBuyer and self._config.targetMutation then
        EggBuyer.setTargetMutation(self._config.targetMutation)
    end
    
    -- Start EggBuyer (which starts ConveyorMonitor)
    if EggBuyer then
        local buyerStarted = EggBuyer.start()
        if buyerStarted then
            print("[EggSystem] EggBuyer started")
        else
            warn("[EggSystem] EggBuyer failed to start")
        end
    end
    
    -- Spawn main loop thread
    self._thread = task.spawn(function()
        self:_mainLoop()
    end)
    
    print("[EggSystem] Egg system started")
    return true
end

-- ============================================================================
-- stop()
-- Stop the complete egg loop and all sub-modules
-- Returns: nil
-- ============================================================================
function EggSystem:stop()
    print("[EggSystem] Stopping...")
    
    self._active = false
    self._state = STATE.IDLE
    
    -- Cancel main loop thread
    if self._thread then
        local success, err = pcall(function()
            task.cancel(self._thread)
        end)
        self._thread = nil
    end
    
    -- Stop EggBuyer (which stops ConveyorMonitor)
    if EggBuyer then
        EggBuyer.stop()
        print("[EggSystem] EggBuyer stopped")
    end
    
    -- Disconnect all connections
    for _, connection in ipairs(self._connections) do
        local success, err = pcall(function()
            if connection and typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            end
        end)
    end
    self._connections = {}
    
    print("[EggSystem] Stopped")
end

-- ============================================================================
-- setTargetMutation(mutation)
-- Set the target mutation to auto-buy
-- Returns: boolean (success)
-- ============================================================================
function EggSystem:setTargetMutation(mutation)
    self._config.targetMutation = mutation
    
    -- Update EggBuyer if active
    if EggBuyer and self._active then
        EggBuyer.setTargetMutation(mutation)
    end
    
    print("[EggSystem] Target mutation set: " .. tostring(mutation))
    return true
end

-- ============================================================================
-- getStats()
-- Get current statistics (shallow copy)
-- Returns: table
-- ============================================================================
function EggSystem:getStats()
    local stats = {
        eggsHatched = self._stats.eggsHatched,
        eggsBought = self._stats.eggsBought,
        eggsPlaced = self._stats.eggsPlaced,
        cyclesCompleted = self._stats.cyclesCompleted,
        currentState = self._state,
        lastState = self._stats.lastState,
        errors = self._stats.errors,
        isActive = self._active,
    }
    
    -- Include sub-module stats if available
    if EggBuyer and EggBuyer.getStats then
        stats.buyer = EggBuyer.getStats()
    end
    
    if PlotManager and PlotManager.getPlotStatus then
        stats.plots = PlotManager.getPlotStatus()
    end
    
    if EggHatcher and EggHatcher.getStats then
        stats.hatcher = EggHatcher.getStats()
    end
    
    return stats
end

-- ============================================================================
-- getConfig()
-- Get current configuration (shallow copy)
-- Returns: table
-- ============================================================================
function EggSystem:getConfig()
    return {
        targetMutation = self._config.targetMutation,
        cycleDelay = self._config.cycleDelay,
        hatchDelay = self._config.hatchDelay,
        placeDelay = self._config.placeDelay,
        enabled = self._config.enabled,
    }
end

-- ============================================================================
-- setConfig(key, value)
-- Update a configuration value
-- Returns: boolean (success)
-- ============================================================================
function EggSystem:setConfig(key, value)
    if self._config[key] ~= nil then
        self._config[key] = value
        print("[EggSystem] Config updated: " .. key .. " = " .. tostring(value))
        return true
    else
        warn("[EggSystem] Unknown config key: " .. tostring(key))
        return false
    end
end

-- ============================================================================
-- isActive()
-- Check if egg system is running
-- Returns: boolean
-- ============================================================================
function EggSystem:isActive()
    return self._active
end

-- ============================================================================
-- getState()
-- Get current state machine state
-- Returns: string
-- ============================================================================
function EggSystem:getState()
    return self._state
end

-- ============================================================================
-- cleanup()
-- Full cleanup - stops everything and resets all state
-- Returns: nil
-- ============================================================================
function EggSystem:cleanup()
    print("[EggSystem] Cleaning up...")
    
    -- Stop first
    self:stop()
    
    -- Reset stats
    self._stats = {
        eggsHatched = 0,
        eggsBought = 0,
        eggsPlaced = 0,
        cyclesCompleted = 0,
        lastState = STATE.IDLE,
        errors = 0,
    }
    
    -- Reset state
    self._holdingEgg = false
    self._state = STATE.IDLE
    
    -- Cleanup sub-modules
    if EggBuyer and EggBuyer.cleanup then
        EggBuyer.cleanup()
    end
    
    if PlotManager and PlotManager.cleanup then
        PlotManager.cleanup()
    end
    
    if EggHatcher and EggHatcher.cleanup then
        EggHatcher.cleanup()
    end
    
    print("[EggSystem] Cleanup complete")
end

-- ============================================================================
-- runOnce()
-- Run a single check cycle manually (for testing)
-- Returns: boolean (success)
-- ============================================================================
function EggSystem:runOnce()
    -- Initialize if not done
    if not PlotManager then
        local initSuccess = self:init()
        if not initSuccess then
            warn("[EggSystem] Cannot run - initialization failed")
            return false
        end
    end
    
    local wasActive = self._active
    self._active = true
    
    local success, err = pcall(function()
        -- Check for ready eggs
        if EggHatcher then
            local readyEggs = EggHatcher.findReadyEggs()
            if #readyEggs > 0 then
                print("[EggSystem] runOnce: Found " .. #readyEggs .. " ready eggs")
                self:_doHatchEggs()
            end
        end
        
        -- Check plot status
        if PlotManager then
            local status = PlotManager.getPlotStatus()
            print("[EggSystem] runOnce: Plot status - Total: " .. status.total .. 
                  ", Empty: " .. status.empty .. ", Occupied: " .. status.occupied)
        end
    end)
    
    self._active = wasActive
    
    if not success then
        warn("[EggSystem] runOnce error: " .. tostring(err))
        return false
    end
    
    return true
end

-- ============================================================================
-- Module Export (follows auto-collect.lua pattern)
-- ============================================================================
return {
    -- Lifecycle
    init = function() return EggSystem:init() end,
    start = function() return EggSystem:start() end,
    stop = function() return EggSystem:stop() end,
    cleanup = function() return EggSystem:cleanup() end,
    
    -- Configuration
    setTargetMutation = function(mut) return EggSystem:setTargetMutation(mut) end,
    getConfig = function() return EggSystem:getConfig() end,
    setConfig = function(k, v) return EggSystem:setConfig(k, v) end,
    
    -- Status
    isActive = function() return EggSystem:isActive() end,
    getState = function() return EggSystem:getState() end,
    getStats = function() return EggSystem:getStats() end,
    
    -- Debug/Testing
    runOnce = function() return EggSystem:runOnce() end,
}
