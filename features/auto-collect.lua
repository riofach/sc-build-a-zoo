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

-- ============================================================================
-- fireRemote(animal)
-- Try to fire the collect RemoteEvent with different argument patterns
-- Returns: boolean (success)
-- ============================================================================
function AutoCollect:fireRemote(animal)
    local remote = self._discovery and self._discovery.collectRemote
    if not remote then
        return false
    end
    
    -- Try different argument patterns
    local patterns = {
        -- Pattern 1: Fire with animal instance
        function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(animal)
            else
                remote:InvokeServer(animal)
            end
            return true
        end,
        -- Pattern 2: Fire with animal ID attribute
        function()
            local animalId = animal:GetAttribute("Id") or animal:GetAttribute("AnimalId")
            if animalId then
                if remote:IsA("RemoteEvent") then
                    remote:FireServer(animalId)
                else
                    remote:InvokeServer(animalId)
                end
                return true
            end
            return false
        end,
        -- Pattern 3: Fire with animal name
        function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(animal.Name)
            else
                remote:InvokeServer(animal.Name)
            end
            return true
        end,
        -- Pattern 4: Fire without arguments (collect all)
        function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer()
            else
                remote:InvokeServer()
            end
            return true
        end,
    }
    
    for i, tryPattern in ipairs(patterns) do
        local success, result = pcall(tryPattern)
        if success and result then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- collectViaTouch(animal)
-- Fallback collection using firetouchinterest
-- Returns: boolean (success)
-- ============================================================================
function AutoCollect:collectViaTouch(animal)
    -- Get player character and HumanoidRootPart
    local success, result = pcall(function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        local character = LocalPlayer.Character
        if not character then
            return false
        end
        
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            return false
        end
        
        -- Find touchable part on animal
        local touchPart = nil
        
        -- Try common touchable part names
        local touchPartNames = {"TouchPart", "HitBox", "CollectPart", "Collect", "Touch", "Handle", "Main"}
        for _, partName in ipairs(touchPartNames) do
            local part = animal:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                touchPart = part
                break
            end
        end
        
        -- Fallback: find any BasePart in animal
        if not touchPart then
            for _, child in ipairs(animal:GetDescendants()) do
                if child:IsA("BasePart") then
                    touchPart = child
                    break
                end
            end
        end
        
        if not touchPart then
            return false
        end
        
        -- Fire touch interest
        if firetouchinterest then
            firetouchinterest(rootPart, touchPart, 0) -- Touch begin
            task.wait(0.1)
            firetouchinterest(rootPart, touchPart, 1) -- Touch end
            return true
        end
        
        return false
    end)
    
    return success and result
end

-- ============================================================================
-- collectViaClick(animal)
-- Try to collect via ClickDetector or ProximityPrompt
-- Returns: boolean (success)
-- ============================================================================
function AutoCollect:collectViaClick(animal)
    local success, result = pcall(function()
        -- Try ClickDetector
        for _, desc in ipairs(animal:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                if fireclickdetector then
                    fireclickdetector(desc)
                    return true
                end
            end
        end
        
        -- Try ProximityPrompt
        for _, desc in ipairs(animal:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                if fireproximityprompt then
                    fireproximityprompt(desc)
                    return true
                end
            end
        end
        
        return false
    end)
    
    return success and result
end

-- ============================================================================
-- collectFromAnimal(animal)
-- Try to collect money from a single animal
-- Returns: boolean (success)
-- ============================================================================
function AutoCollect:collectFromAnimal(animal)
    if not animal then
        return false
    end
    
    local retries = 0
    local maxRetries = self._config.maxRetries
    
    while retries < maxRetries do
        -- Try ClickDetector/ProximityPrompt first (most common in Build A Zoo)
        local clickSuccess = self:collectViaClick(animal)
        if clickSuccess then
            return true
        end
        
        -- Try RemoteEvent
        local remoteSuccess = self:fireRemote(animal)
        if remoteSuccess then
            return true
        end
        
        -- Fallback to firetouchinterest
        local touchSuccess = self:collectViaTouch(animal)
        if touchSuccess then
            return true
        end
        
        retries = retries + 1
        if retries < maxRetries then
            Timing.wait(0.2) -- Small delay between retries
        end
    end
    
    return false
end

-- ============================================================================
-- collectCycle()
-- Run a single collection cycle through all animals
-- Returns: nil
-- ============================================================================
function AutoCollect:collectCycle()
    local cycleStart = tick()
    local collected = 0
    local failed = 0
    
    -- Refresh animal list each cycle
    local animals = {}
    local success, result = pcall(function()
        return Discovery.findPlayerAnimals()
    end)
    
    if success and result then
        animals = result
    else
        warn("[AutoCollect] Failed to get animals: " .. tostring(result))
        return
    end
    
    print("[AutoCollect] Starting cycle with " .. #animals .. " animals")
    
    for i, animal in ipairs(animals) do
        -- Check if still active
        if not self._active then
            print("[AutoCollect] Cycle interrupted - stopping")
            break
        end
        
        -- Check if money is ready
        local ready, amount = false, 0
        local checkSuccess, checkResult = pcall(function()
            return Discovery.isMoneyReady(animal)
        end)
        
        if checkSuccess then
            ready, amount = checkResult, 0
            -- Handle if isMoneyReady returns two values
            if type(checkResult) == "boolean" then
                ready = checkResult
            end
        end
        
        if ready then
            -- Try to collect
            local collectSuccess = self:collectFromAnimal(animal)
            if collectSuccess then
                collected = collected + 1
            else
                failed = failed + 1
            end
        end
        
        -- Wait between animals
        if i < #animals and self._active then
            Timing.wait(self._config.delayPerAnimal)
        end
    end
    
    -- Update stats
    local cycleTime = tick() - cycleStart
    self._stats.cyclesCompleted = self._stats.cyclesCompleted + 1
    self._stats.totalCollected = self._stats.totalCollected + collected
    self._stats.totalFailed = self._stats.totalFailed + failed
    self._stats.lastCycleTime = cycleTime
    
    -- Log results (error warning only per CONTEXT.md)
    if failed > 0 then
        warn("[AutoCollect] Cycle complete - Collected: " .. collected .. ", Failed: " .. failed)
    else
        print("[AutoCollect] Cycle " .. self._stats.cyclesCompleted .. " complete - Collected: " .. collected .. " (took " .. string.format("%.1f", cycleTime) .. "s)")
    end
end

-- ============================================================================
-- cleanup()
-- Thorough cleanup - stops collection and resets all state
-- Returns: nil
-- ============================================================================
function AutoCollect:cleanup()
    print("[AutoCollect] Cleaning up...")
    
    -- First, stop the collection loop
    self:stop()
    
    -- Reset stats to initial values
    self._stats = {
        cyclesCompleted = 0,
        totalCollected = 0,
        totalFailed = 0,
        lastCycleTime = 0,
    }
    
    -- Clear discovery data
    self._discovery = nil
    
    print("[AutoCollect] Cleanup complete - all state reset")
end

-- ============================================================================
-- getDiscovery()
-- Get the current discovery data (for debugging)
-- Returns: table or nil
-- ============================================================================
function AutoCollect:getDiscovery()
    return self._discovery
end

-- ============================================================================
-- runOnce()
-- Run a single collection cycle manually (for testing)
-- Returns: boolean (success)
-- ============================================================================
function AutoCollect:runOnce()
    -- Initialize if not done
    if not self._discovery then
        local initSuccess = self:init()
        if not initSuccess then
            warn("[AutoCollect] Cannot run - initialization failed")
            return false
        end
    end
    
    -- Temporarily set active to true for the cycle
    local wasActive = self._active
    self._active = true
    
    -- Run single cycle
    local success, err = pcall(function()
        self:collectCycle()
    end)
    
    -- Restore previous active state
    self._active = wasActive
    
    if not success then
        warn("[AutoCollect] runOnce error: " .. tostring(err))
        return false
    end
    
    return true
end

-- ============================================================================
-- Module Export (10 public functions)
-- ============================================================================
return {
    -- Lifecycle
    init = function() return AutoCollect:init() end,
    start = function() return AutoCollect:start() end,
    stop = function() return AutoCollect:stop() end,
    cleanup = function() return AutoCollect:cleanup() end,
    
    -- Status
    isActive = function() return AutoCollect:isActive() end,
    getStats = function() return AutoCollect:getStats() end,
    
    -- Configuration
    getConfig = function() return AutoCollect:getConfig() end,
    setConfig = function(k, v) return AutoCollect:setConfig(k, v) end,
    
    -- Debug/Testing
    getDiscovery = function() return AutoCollect:getDiscovery() end,
    runOnce = function() return AutoCollect:runOnce() end,
}
