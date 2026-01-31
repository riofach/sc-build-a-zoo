--[[
  features/conveyor-monitor.lua
  Monitors conveyor belt for eggs with target mutation types
  
  Usage:
    local ConveyorMonitor = require("features/conveyor-monitor")
    ConveyorMonitor.init()
    ConveyorMonitor.setTargetMutation("Shiny")
    ConveyorMonitor.start(function(egg, mutationName)
        -- egg detected with target mutation
    end)
    ConveyorMonitor.stop()
    
  Exports:
    init, setTargetMutation, start, stop, getConveyorEggs
--]]

-- Dependencies (loaded via pattern matching loader or direct require)
local EggTypes = nil

-- Try to load dependencies
local function loadDependencies()
    -- Pattern 1: Direct require (if running as module)
    local success1, result1 = pcall(function()
        return require(script.Parent.Parent:FindFirstChild("config"):FindFirstChild("egg-types"))
    end)
    if success1 and result1 then
        EggTypes = result1
    end
    
    -- Pattern 2: Global loader (if loaded via loadstring)
    if not EggTypes then
        local success2, result2 = pcall(function()
            if _G.loadModule then
                return _G.loadModule("config/egg-types")
            end
            return nil
        end)
        if success2 and result2 then
            EggTypes = result2
        end
    end
    
    -- Pattern 3: Direct loadstring (standalone)
    if not EggTypes then
        local success3, result3 = pcall(function()
            local source = game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/config/egg-types.lua")
            return loadstring(source)()
        end)
        if success3 and result3 then
            EggTypes = result3
        end
    end
    
    return true -- EggTypes is optional, continue even if nil
end

-- Module State
local ConveyorMonitor = {
    _targetMutation = nil,      -- string, mutation to search for
    _connections = {},          -- table, for cleanup
    _conveyorPath = nil,        -- Instance, path to conveyor area
    _currentEggs = {},          -- table, cache of eggs currently on conveyor
    _active = false,            -- boolean, is monitoring active
    _callback = nil,            -- function, called when target egg found
}

-- Common conveyor paths to try
local CONVEYOR_PATHS = {
    "Conveyor",
    "EggConveyor",
    "ConveyorBelt",
    "Eggs",
    "EggArea",
    "Map.Conveyor",
    "Map.EggConveyor",
    "Map.Eggs",
    "World.Conveyor",
    "World.Eggs",
}

-- ============================================================================
-- _discoverConveyor()
-- Try to find the conveyor area in workspace
-- Returns: Instance or nil
-- ============================================================================
local function discoverConveyor()
    local success, result = pcall(function()
        local workspace = game:GetService("Workspace")
        
        for _, path in ipairs(CONVEYOR_PATHS) do
            -- Handle nested paths like "Map.Conveyor"
            local parts = string.split(path, ".")
            local current = workspace
            
            for _, part in ipairs(parts) do
                local child = current:FindFirstChild(part)
                if child then
                    current = child
                else
                    current = nil
                    break
                end
            end
            
            if current and current ~= workspace then
                print("[ConveyorMonitor] Found conveyor at: " .. current:GetFullName())
                return current
            end
        end
        
        -- Fallback: search for any folder/model containing "conveyor" or "egg"
        for _, child in ipairs(workspace:GetChildren()) do
            local nameLower = string.lower(child.Name)
            if string.find(nameLower, "conveyor") or string.find(nameLower, "egg") then
                print("[ConveyorMonitor] Found conveyor via search: " .. child:GetFullName())
                return child
            end
        end
        
        -- Last resort: try Map folder
        local map = workspace:FindFirstChild("Map")
        if map then
            for _, child in ipairs(map:GetChildren()) do
                local nameLower = string.lower(child.Name)
                if string.find(nameLower, "conveyor") or string.find(nameLower, "egg") then
                    print("[ConveyorMonitor] Found conveyor in Map: " .. child:GetFullName())
                    return child
                end
            end
        end
        
        return nil
    end)
    
    if success then
        return result
    else
        warn("[ConveyorMonitor] Discovery failed: " .. tostring(result))
        return nil
    end
end

-- ============================================================================
-- _checkEgg(obj, callback)
-- Check if an object is an egg with target mutation
-- Called via task.spawn for async handling with StreamingEnabled
-- ============================================================================
function ConveyorMonitor:_checkEgg(obj, callback)
    if not obj:IsA("Model") then return end
    
    task.spawn(function()
        local success, err = pcall(function()
            -- Wait for BillboardGui (StreamingEnabled compatibility)
            local billboard = obj:WaitForChild("BillboardGui", 3)
            if not billboard then 
                -- Also try common alternative names
                billboard = obj:FindFirstChild("EggLabel") or obj:FindFirstChild("Label")
                if not billboard then return end
            end
            
            local textLabel = billboard:FindFirstChildOfClass("TextLabel")
            if not textLabel then
                -- Try to find any text element
                for _, child in ipairs(billboard:GetDescendants()) do
                    if child:IsA("TextLabel") then
                        textLabel = child
                        break
                    end
                end
                if not textLabel then return end
            end
            
            local mutationName = textLabel.Text
            if not mutationName or mutationName == "" then return end
            
            -- Add to current eggs cache
            self._currentEggs[obj] = mutationName
            
            -- Check match (case-insensitive)
            if self._targetMutation and 
               string.lower(mutationName):find(string.lower(self._targetMutation)) then
                print("[ConveyorMonitor] Target egg detected: " .. mutationName)
                if callback then
                    callback(obj, mutationName)
                end
            end
        end)
        
        if not success then
            -- Silent fail - object may have been destroyed
        end
    end)
end

-- ============================================================================
-- _scanExistingEggs(callback)
-- Scan all existing eggs in conveyor area
-- ============================================================================
function ConveyorMonitor:_scanExistingEggs(callback)
    if not self._conveyorPath then return end
    
    local success, err = pcall(function()
        for _, child in ipairs(self._conveyorPath:GetDescendants()) do
            if child:IsA("Model") then
                self:_checkEgg(child, callback)
            end
        end
    end)
    
    if not success then
        warn("[ConveyorMonitor] Scan failed: " .. tostring(err))
    end
end

-- ============================================================================
-- init(conveyorPath)
-- Initialize the conveyor monitor
-- conveyorPath: optional Instance, auto-discovers if nil
-- Returns: boolean (success)
-- ============================================================================
function ConveyorMonitor:init(conveyorPath)
    print("[ConveyorMonitor] Initializing...")
    
    -- Load dependencies
    loadDependencies()
    
    -- Set or discover conveyor path
    if conveyorPath then
        self._conveyorPath = conveyorPath
    else
        self._conveyorPath = discoverConveyor()
    end
    
    if not self._conveyorPath then
        warn("[ConveyorMonitor] No conveyor path found - will retry on start")
        return true -- Allow init to succeed, will retry discovery on start
    end
    
    print("[ConveyorMonitor] Initialized with conveyor: " .. self._conveyorPath:GetFullName())
    return true
end

-- ============================================================================
-- setTargetMutation(mutationName)
-- Set the mutation type to search for
-- mutationName: string
-- Returns: boolean (success)
-- ============================================================================
function ConveyorMonitor:setTargetMutation(mutationName)
    local success, err = pcall(function()
        if not mutationName or type(mutationName) ~= "string" then
            error("Invalid mutation name")
        end
        
        -- Store lowercase for case-insensitive matching
        self._targetMutation = mutationName
        
        -- Validate with EggTypes if available
        if EggTypes and EggTypes.isValid then
            if not EggTypes.isValid(mutationName) then
                warn("[ConveyorMonitor] Warning: '" .. mutationName .. "' not in known egg types")
            end
        end
        
        print("[ConveyorMonitor] Target mutation set: " .. mutationName)
    end)
    
    if not success then
        warn("[ConveyorMonitor] setTargetMutation failed: " .. tostring(err))
        return false
    end
    return true
end

-- ============================================================================
-- start(onEggCallback)
-- Start monitoring the conveyor for eggs
-- onEggCallback: function(egg, mutationName) called when target egg found
-- Returns: boolean (success)
-- ============================================================================
function ConveyorMonitor:start(onEggCallback)
    -- Guard: already active
    if self._active then
        warn("[ConveyorMonitor] Already running")
        return false
    end
    
    -- Retry conveyor discovery if not found during init
    if not self._conveyorPath then
        self._conveyorPath = discoverConveyor()
        if not self._conveyorPath then
            warn("[ConveyorMonitor] Cannot start - no conveyor path found")
            return false
        end
    end
    
    self._active = true
    self._callback = onEggCallback
    
    print("[ConveyorMonitor] Starting monitoring...")
    
    -- Scan existing eggs
    self:_scanExistingEggs(onEggCallback)
    
    -- Setup DescendantAdded listener for new eggs
    local success, connection = pcall(function()
        return self._conveyorPath.DescendantAdded:Connect(function(descendant)
            if self._active and descendant:IsA("Model") then
                self:_checkEgg(descendant, onEggCallback)
            end
        end)
    end)
    
    if success and connection then
        table.insert(self._connections, connection)
    end
    
    -- Setup DescendantRemoving listener to clean cache
    local success2, connection2 = pcall(function()
        return self._conveyorPath.DescendantRemoving:Connect(function(descendant)
            if self._currentEggs[descendant] then
                self._currentEggs[descendant] = nil
            end
        end)
    end)
    
    if success2 and connection2 then
        table.insert(self._connections, connection2)
    end
    
    print("[ConveyorMonitor] Monitoring started - listening for DescendantAdded events")
    return true
end

-- ============================================================================
-- stop()
-- Stop monitoring and clean up
-- Returns: nil
-- ============================================================================
function ConveyorMonitor:stop()
    print("[ConveyorMonitor] Stopping...")
    
    self._active = false
    self._callback = nil
    
    -- Disconnect all connections
    for _, connection in ipairs(self._connections) do
        local success, err = pcall(function()
            if connection and typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            end
        end)
    end
    self._connections = {}
    
    -- Clear eggs cache
    self._currentEggs = {}
    
    print("[ConveyorMonitor] Stopped")
end

-- ============================================================================
-- getConveyorEggs()
-- Get all eggs currently tracked on conveyor
-- Returns: table (shallow copy of {egg = mutationName})
-- ============================================================================
function ConveyorMonitor:getConveyorEggs()
    local copy = {}
    for egg, mutation in pairs(self._currentEggs) do
        copy[egg] = mutation
    end
    return copy
end

-- ============================================================================
-- isActive()
-- Check if monitoring is active
-- Returns: boolean
-- ============================================================================
function ConveyorMonitor:isActive()
    return self._active
end

-- ============================================================================
-- getTargetMutation()
-- Get the current target mutation
-- Returns: string or nil
-- ============================================================================
function ConveyorMonitor:getTargetMutation()
    return self._targetMutation
end

-- ============================================================================
-- cleanup()
-- Full cleanup - stops monitoring and resets all state
-- Returns: nil
-- ============================================================================
function ConveyorMonitor:cleanup()
    print("[ConveyorMonitor] Cleaning up...")
    
    self:stop()
    
    -- Reset all state
    self._targetMutation = nil
    self._conveyorPath = nil
    
    print("[ConveyorMonitor] Cleanup complete")
end

-- ============================================================================
-- Module Export
-- ============================================================================
return {
    -- Lifecycle
    init = function(path) return ConveyorMonitor:init(path) end,
    start = function(cb) return ConveyorMonitor:start(cb) end,
    stop = function() return ConveyorMonitor:stop() end,
    cleanup = function() return ConveyorMonitor:cleanup() end,
    
    -- Configuration
    setTargetMutation = function(name) return ConveyorMonitor:setTargetMutation(name) end,
    getTargetMutation = function() return ConveyorMonitor:getTargetMutation() end,
    
    -- Status
    isActive = function() return ConveyorMonitor:isActive() end,
    getConveyorEggs = function() return ConveyorMonitor:getConveyorEggs() end,
}
