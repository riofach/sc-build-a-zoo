--[[
  features/auto-collect.lua
  Auto-collect money from pets in Build A Zoo
  
  Simplified version - directly fires "Collect all pets" remote
  
  Usage:
    local AutoCollect = require("features/auto-collect")
    AutoCollect.init()
    AutoCollect.start()  -- starts collection loop
    AutoCollect.stop()   -- stops collection loop
--]]

-- ============================================================================
-- Helper: Debug log to UI
-- ============================================================================
local function debugLog(message)
    print(message)
    if _G.DebugLog then
        pcall(function()
            _G.DebugLog(message)
        end)
    end
end

-- ============================================================================
-- Services
-- ============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================================
-- Module State
-- ============================================================================
local AutoCollect = {
    _active = false,
    _thread = nil,
    _collectRemote = nil,
    _stats = {
        cyclesCompleted = 0,
        totalCollected = 0,
        totalFailed = 0,
    },
    _config = {
        cycleInterval = 5,  -- collect every 5 seconds
    },
}

-- ============================================================================
-- findCollectRemote()
-- Find the remote for collecting all pets money
-- ============================================================================
local function findCollectRemote()
    debugLog("[AutoCollect] Searching for collect remote...")
    
    -- Common remote names for "Collect all pets" functionality
    local remotePatterns = {
        -- Exact matches first
        "CollectAll", "CollectAllPets", "CollectPets", "CollectMoney",
        "ClaimAll", "ClaimAllPets", "ClaimPets", "ClaimMoney",
        "Collect", "Claim", "GetMoney", "GatherMoney",
        -- Partial matches
        "collect", "claim", "money", "pet", "gold", "cash"
    }
    
    -- Search in ReplicatedStorage
    local locations = {
        ReplicatedStorage,
        ReplicatedStorage:FindFirstChild("Remotes"),
        ReplicatedStorage:FindFirstChild("Events"),
        ReplicatedStorage:FindFirstChild("RemoteEvents"),
        ReplicatedStorage:FindFirstChild("Network"),
    }
    
    for _, location in ipairs(locations) do
        if location then
            local success, descendants = pcall(function()
                return location:GetDescendants()
            end)
            
            if success then
                -- Log all remotes found
                local remoteNames = {}
                for _, desc in ipairs(descendants) do
                    if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
                        table.insert(remoteNames, desc.Name)
                    end
                end
                if #remoteNames > 0 then
                    debugLog("[AutoCollect] Found remotes: " .. table.concat(remoteNames, ", "))
                end
                
                -- Search for matching remote
                for _, pattern in ipairs(remotePatterns) do
                    for _, desc in ipairs(descendants) do
                        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
                            local name = desc.Name:lower()
                            if name == pattern:lower() or string.find(name, pattern:lower()) then
                                debugLog("[AutoCollect] Found remote: " .. desc.Name)
                                return desc
                            end
                        end
                    end
                end
            end
        end
    end
    
    debugLog("[AutoCollect] No collect remote found")
    return nil
end

-- ============================================================================
-- tryCollectViaRemote()
-- Try different ways to fire the collect remote
-- ============================================================================
local function tryCollectViaRemote(remote)
    if not remote then return false end
    
    local patterns = {
        -- Pattern 1: No arguments
        function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer()
            else
                remote:InvokeServer()
            end
            return true
        end,
        -- Pattern 2: "All" argument
        function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer("All")
            else
                remote:InvokeServer("All")
            end
            return true
        end,
        -- Pattern 3: true argument
        function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(true)
            else
                remote:InvokeServer(true)
            end
            return true
        end,
    }
    
    for i, tryPattern in ipairs(patterns) do
        local success = pcall(tryPattern)
        if success then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- tryCollectViaUI()
-- Try to find and click "Collect all pets" button via GUI
-- ============================================================================
local function tryCollectViaUI()
    local player = Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return false end
    
    -- Search for collect button in all GUIs
    local success, result = pcall(function()
        for _, gui in ipairs(playerGui:GetDescendants()) do
            if gui:IsA("TextButton") or gui:IsA("ImageButton") then
                local text = ""
                if gui:IsA("TextButton") then
                    text = gui.Text:lower()
                end
                
                -- Check button text or name
                local name = gui.Name:lower()
                if string.find(text, "collect") or string.find(name, "collect") or
                   string.find(text, "claim") or string.find(name, "claim") then
                    -- Try to fire click
                    if fireclickdetector then
                        local cd = gui:FindFirstChildOfClass("ClickDetector")
                        if cd then
                            fireclickdetector(cd)
                            return true
                        end
                    end
                    
                    -- Try to activate button
                    if gui.Activated then
                        gui.Activated:Fire()
                        return true
                    end
                end
            end
        end
        return false
    end)
    
    return success and result
end

-- ============================================================================
-- collectCycle()
-- Run a single collection cycle
-- ============================================================================
local function collectCycle()
    debugLog("[AutoCollect] Running cycle...")
    
    local collected = false
    
    -- Method 1: Try remote
    if AutoCollect._collectRemote then
        local success = tryCollectViaRemote(AutoCollect._collectRemote)
        if success then
            collected = true
            debugLog("[AutoCollect] Collected via remote")
        end
    end
    
    -- Method 2: Try UI button (fallback)
    if not collected then
        local uiSuccess = tryCollectViaUI()
        if uiSuccess then
            collected = true
            debugLog("[AutoCollect] Collected via UI")
        end
    end
    
    -- Update stats
    AutoCollect._stats.cyclesCompleted = AutoCollect._stats.cyclesCompleted + 1
    if collected then
        AutoCollect._stats.totalCollected = AutoCollect._stats.totalCollected + 1
    else
        AutoCollect._stats.totalFailed = AutoCollect._stats.totalFailed + 1
        debugLog("[AutoCollect] Cycle failed - no method worked")
    end
end

-- ============================================================================
-- init()
-- Initialize the auto-collect module
-- ============================================================================
function AutoCollect:init()
    debugLog("[AutoCollect] Initializing...")
    
    -- Find collect remote
    self._collectRemote = findCollectRemote()
    
    if self._collectRemote then
        debugLog("[AutoCollect] Ready - using remote: " .. self._collectRemote.Name)
    else
        debugLog("[AutoCollect] Ready - will try UI method")
    end
    
    return true
end

-- ============================================================================
-- start()
-- Start the auto-collection loop
-- ============================================================================
function AutoCollect:start()
    if self._active then
        debugLog("[AutoCollect] Already running")
        return false
    end
    
    -- Init if not done
    if not self._collectRemote then
        self:init()
    end
    
    self._active = true
    debugLog("[AutoCollect] Started (interval: " .. self._config.cycleInterval .. "s)")
    
    -- Spawn collection loop
    self._thread = task.spawn(function()
        while self._active do
            local success, err = pcall(collectCycle)
            if not success then
                debugLog("[AutoCollect] Error: " .. tostring(err))
            end
            
            -- Wait for next cycle
            if self._active then
                task.wait(self._config.cycleInterval)
            end
        end
    end)
    
    return true
end

-- ============================================================================
-- stop()
-- Stop the auto-collection loop
-- ============================================================================
function AutoCollect:stop()
    debugLog("[AutoCollect] Stopping...")
    self._active = false
    
    if self._thread then
        pcall(function()
            task.cancel(self._thread)
        end)
        self._thread = nil
    end
    
    debugLog("[AutoCollect] Stopped")
end

-- ============================================================================
-- Other functions
-- ============================================================================
function AutoCollect:isActive()
    return self._active
end

function AutoCollect:getStats()
    return {
        cyclesCompleted = self._stats.cyclesCompleted,
        totalCollected = self._stats.totalCollected,
        totalFailed = self._stats.totalFailed,
    }
end

function AutoCollect:getConfig()
    return {
        cycleInterval = self._config.cycleInterval,
    }
end

function AutoCollect:setConfig(key, value)
    if self._config[key] ~= nil then
        self._config[key] = value
        debugLog("[AutoCollect] Config: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function AutoCollect:getDiscovery()
    return {
        collectRemote = self._collectRemote,
    }
end

function AutoCollect:runOnce()
    if not self._collectRemote then
        self:init()
    end
    collectCycle()
    return true
end

function AutoCollect:cleanup()
    self:stop()
    self._stats = {
        cyclesCompleted = 0,
        totalCollected = 0,
        totalFailed = 0,
    }
    self._collectRemote = nil
end

-- ============================================================================
-- Module Export
-- ============================================================================
return {
    init = function() return AutoCollect:init() end,
    start = function() return AutoCollect:start() end,
    stop = function() return AutoCollect:stop() end,
    cleanup = function() return AutoCollect:cleanup() end,
    isActive = function() return AutoCollect:isActive() end,
    getStats = function() return AutoCollect:getStats() end,
    getConfig = function() return AutoCollect:getConfig() end,
    setConfig = function(k, v) return AutoCollect:setConfig(k, v) end,
    getDiscovery = function() return AutoCollect:getDiscovery() end,
    runOnce = function() return AutoCollect:runOnce() end,
}
