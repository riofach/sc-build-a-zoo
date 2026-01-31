--[[
  features/egg-buyer.lua
  Auto-buy eggs from conveyor with pre-check anti-detection
  
  Usage:
    local EggBuyer = require("features/egg-buyer")
    EggBuyer.init()
    EggBuyer.start()  -- starts monitoring and auto-buy
    EggBuyer.stop()   -- stops auto-buy
    
  Exports:
    init, start, stop, isHoldingEgg, buyEgg
    
  Anti-detection:
    - ALWAYS pre-check before firing remote
    - Check canAfford before purchase
    - Check not already holding egg
    - Timing variance on remote fires
--]]

-- Dependencies (loaded via pattern matching loader)
local Money = nil
local EggTypes = nil
local Timing = nil
local ConveyorMonitor = nil

-- Try to load dependencies
local function loadDependencies()
    -- Load Money module
    local success1, result1 = pcall(function()
        return require(script.Parent.Parent:FindFirstChild("core"):FindFirstChild("money"))
    end)
    if success1 and result1 then
        Money = result1
    end
    
    if not Money then
        local success2, result2 = pcall(function()
            if _G.loadModule then
                return _G.loadModule("core/money")
            end
            return nil
        end)
        if success2 and result2 then
            Money = result2
        end
    end
    
    -- Load EggTypes module
    local success3, result3 = pcall(function()
        return require(script.Parent.Parent:FindFirstChild("config"):FindFirstChild("egg-types"))
    end)
    if success3 and result3 then
        EggTypes = result3
    end
    
    if not EggTypes then
        local success4, result4 = pcall(function()
            if _G.loadModule then
                return _G.loadModule("config/egg-types")
            end
            return nil
        end)
        if success4 and result4 then
            EggTypes = result4
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
    
    -- Load ConveyorMonitor module
    local successC1, resultC1 = pcall(function()
        return require(script.Parent:FindFirstChild("conveyor-monitor"))
    end)
    if successC1 and resultC1 then
        ConveyorMonitor = resultC1
    end
    
    if not ConveyorMonitor then
        local successC2, resultC2 = pcall(function()
            if _G.loadModule then
                return _G.loadModule("features/conveyor-monitor")
            end
            return nil
        end)
        if successC2 and resultC2 then
            ConveyorMonitor = resultC2
        end
    end
    
    return Money ~= nil and ConveyorMonitor ~= nil
end

-- Get services
local function getServices()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    return {
        Players = Players,
        LocalPlayer = Players.LocalPlayer,
        ReplicatedStorage = ReplicatedStorage,
    }
end

-- Module State
local EggBuyer = {
    _active = false,            -- boolean, is auto-buy active
    _holdingEgg = false,        -- boolean, player currently holding egg
    _buyRemote = nil,           -- Instance, cached RemoteEvent for buy
    _connections = {},          -- table, for cleanup
    _config = {
        targetMutation = nil,   -- string, mutation to auto-buy
        enabled = true,         -- boolean, master enable switch
        buyDelay = 0.5,         -- seconds between buy attempts
    },
    _stats = {
        purchased = 0,
        failed = 0,
        skippedNoMoney = 0,
        skippedHolding = 0,
    },
}

-- Common buy RemoteEvent patterns
local BUY_REMOTE_PATTERNS = {
    "BuyEgg",
    "PurchaseEgg",
    "Buy",
    "Purchase",
    "GetEgg",
    "ClaimEgg",
    "TakeEgg",
    "GrabEgg",
    "EggPurchase",
    "BuyFromConveyor",
    "ConveyorBuy",
    "Remotes.BuyEgg",
    "Remotes.Purchase",
    "Events.BuyEgg",
    "Events.Purchase",
}

-- ============================================================================
-- _discoverBuyRemote()
-- Find the RemoteEvent used for purchasing eggs
-- Returns: Instance or nil
-- ============================================================================
local function discoverBuyRemote()
    local success, result = pcall(function()
        local Services = getServices()
        local ReplicatedStorage = Services.ReplicatedStorage
        
        -- Check common patterns in ReplicatedStorage
        for _, pattern in ipairs(BUY_REMOTE_PATTERNS) do
            -- Handle nested paths like "Remotes.BuyEgg"
            local parts = string.split(pattern, ".")
            local current = ReplicatedStorage
            
            for _, part in ipairs(parts) do
                local child = current:FindFirstChild(part)
                if child then
                    current = child
                else
                    current = nil
                    break
                end
            end
            
            if current and (current:IsA("RemoteEvent") or current:IsA("RemoteFunction")) then
                print("[EggBuyer] Found buy remote at: " .. current:GetFullName())
                return current
            end
        end
        
        -- Fallback: search ReplicatedStorage for any remote containing "egg" or "buy"
        local function searchFolder(folder)
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    local nameLower = string.lower(child.Name)
                    if string.find(nameLower, "egg") or 
                       string.find(nameLower, "buy") or 
                       string.find(nameLower, "purchase") then
                        print("[EggBuyer] Found buy remote via search: " .. child:GetFullName())
                        return child
                    end
                elseif child:IsA("Folder") then
                    local found = searchFolder(child)
                    if found then return found end
                end
            end
            return nil
        end
        
        return searchFolder(ReplicatedStorage)
    end)
    
    if success then
        return result
    else
        warn("[EggBuyer] Remote discovery failed: " .. tostring(result))
        return nil
    end
end

-- ============================================================================
-- _detectHoldingEgg()
-- Check if player is currently holding an egg
-- Returns: boolean
-- ============================================================================
function EggBuyer:_detectHoldingEgg()
    local success, result = pcall(function()
        local Services = getServices()
        local player = Services.LocalPlayer
        if not player then return false end
        
        local character = player.Character
        if not character then return false end
        
        -- Method 1: Check Character children for Egg model
        local eggInCharacter = character:FindFirstChild("Egg") or 
                               character:FindFirstChild("HeldEgg") or
                               character:FindFirstChild("CarriedEgg")
        if eggInCharacter then
            return true
        end
        
        -- Method 2: Check for any model with "Egg" in name in character
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Model") and string.find(string.lower(child.Name), "egg") then
                return true
            end
        end
        
        -- Method 3: Check Player attributes
        local holdingAttr = player:GetAttribute("HoldingEgg") or 
                           player:GetAttribute("IsHoldingEgg") or
                           player:GetAttribute("HasEgg")
        if holdingAttr == true then
            return true
        end
        
        -- Method 4: Check PlayerGui for holding indicator
        local playerGui = player:FindFirstChild("PlayerGui")
        if playerGui then
            -- Look for any UI element indicating holding
            for _, gui in ipairs(playerGui:GetDescendants()) do
                if gui:IsA("TextLabel") then
                    local text = string.lower(gui.Text)
                    if string.find(text, "holding egg") or string.find(text, "carrying egg") then
                        return true
                    end
                end
            end
        end
        
        return false
    end)
    
    if success then
        return result
    else
        return false -- Assume not holding on error
    end
end

-- ============================================================================
-- init()
-- Initialize the egg buyer module
-- Returns: boolean (success)
-- ============================================================================
function EggBuyer:init()
    print("[EggBuyer] Initializing...")
    
    -- Load dependencies
    local depsLoaded = loadDependencies()
    if not depsLoaded then
        warn("[EggBuyer] Some dependencies not loaded - functionality may be limited")
    end
    
    -- Discover buy RemoteEvent
    self._buyRemote = discoverBuyRemote()
    if not self._buyRemote then
        warn("[EggBuyer] Buy remote not found - will retry on buy attempt")
    end
    
    -- Initial holding check
    self._holdingEgg = self:_detectHoldingEgg()
    
    -- Initialize ConveyorMonitor if loaded
    if ConveyorMonitor then
        local initSuccess = ConveyorMonitor.init()
        if not initSuccess then
            warn("[EggBuyer] ConveyorMonitor init failed")
        end
    end
    
    print("[EggBuyer] Initialized successfully")
    print("[EggBuyer] - Buy remote: " .. (self._buyRemote and self._buyRemote.Name or "NOT FOUND"))
    print("[EggBuyer] - Money module: " .. (Money and "loaded" or "NOT LOADED"))
    print("[EggBuyer] - EggTypes module: " .. (EggTypes and "loaded" or "NOT LOADED"))
    
    return true
end

-- ============================================================================
-- isHoldingEgg()
-- Check if player is holding an egg (refreshes detection)
-- Returns: boolean
-- ============================================================================
function EggBuyer:isHoldingEgg()
    self._holdingEgg = self:_detectHoldingEgg()
    return self._holdingEgg
end

-- ============================================================================
-- buyEgg(egg, mutationName)
-- Attempt to purchase an egg with pre-checks
-- CRITICAL: Pre-checks are MANDATORY for anti-detection
-- Returns: boolean, string (success, message)
-- ============================================================================
function EggBuyer:buyEgg(egg, mutationName)
    -- PRE-CHECK 1: Check not already holding egg
    if self:isHoldingEgg() then
        self._stats.skippedHolding = self._stats.skippedHolding + 1
        return false, "already_holding_egg"
    end
    
    -- PRE-CHECK 2: Check can afford
    local price = 0
    if EggTypes and EggTypes.getPrice then
        price = EggTypes.getPrice(mutationName)
    end
    
    if Money and Money.canAfford then
        if not Money.canAfford(price) then
            self._stats.skippedNoMoney = self._stats.skippedNoMoney + 1
            return false, "cannot_afford"
        end
    end
    
    -- PRE-CHECK 3: Validate remote exists
    if not self._buyRemote then
        self._buyRemote = discoverBuyRemote()
        if not self._buyRemote then
            return false, "no_buy_remote"
        end
    end
    
    -- Add timing variance before fire (anti-detection)
    local delay = Timing.getDelay and Timing.getDelay(0.1) or 0.1
    task.wait(delay)
    
    -- Try different argument patterns (from RESEARCH.md)
    local patterns = {
        -- Pattern 1: Fire with egg instance
        function()
            if self._buyRemote:IsA("RemoteEvent") then
                self._buyRemote:FireServer(egg)
            else
                return self._buyRemote:InvokeServer(egg)
            end
            return true
        end,
        -- Pattern 2: Fire with mutation name
        function()
            if self._buyRemote:IsA("RemoteEvent") then
                self._buyRemote:FireServer(mutationName)
            else
                return self._buyRemote:InvokeServer(mutationName)
            end
            return true
        end,
        -- Pattern 3: Fire with egg instance and mutation
        function()
            if self._buyRemote:IsA("RemoteEvent") then
                self._buyRemote:FireServer(egg, mutationName)
            else
                return self._buyRemote:InvokeServer(egg, mutationName)
            end
            return true
        end,
        -- Pattern 4: Fire without arguments
        function()
            if self._buyRemote:IsA("RemoteEvent") then
                self._buyRemote:FireServer()
            else
                return self._buyRemote:InvokeServer()
            end
            return true
        end,
    }
    
    for i, tryPattern in ipairs(patterns) do
        local success, result = pcall(tryPattern)
        if success then
            -- Assume success if no error
            self._holdingEgg = true
            self._stats.purchased = self._stats.purchased + 1
            print("[EggBuyer] Purchased egg: " .. tostring(mutationName))
            return true, "success"
        end
    end
    
    self._stats.failed = self._stats.failed + 1
    return false, "remote_fire_failed"
end

-- ============================================================================
-- _onTargetEggFound(egg, mutationName)
-- Internal callback when ConveyorMonitor finds target egg
-- ============================================================================
function EggBuyer:_onTargetEggFound(egg, mutationName)
    -- Guard: check still active
    if not self._active then return end
    
    -- Guard: check enabled
    if not self._config.enabled then return end
    
    print("[EggBuyer] Target egg found: " .. tostring(mutationName))
    
    -- Add small delay before buy (anti-detection)
    Timing.wait(self._config.buyDelay)
    
    -- Attempt purchase
    local success, message = self:buyEgg(egg, mutationName)
    
    if not success then
        print("[EggBuyer] Buy skipped: " .. tostring(message))
    end
end

-- ============================================================================
-- start()
-- Start auto-buy monitoring
-- Returns: boolean (success)
-- ============================================================================
function EggBuyer:start()
    -- Guard: already active
    if self._active then
        warn("[EggBuyer] Already running")
        return false
    end
    
    -- Init if not done
    if not self._buyRemote and not ConveyorMonitor then
        local initSuccess = self:init()
        if not initSuccess then
            warn("[EggBuyer] Cannot start - initialization failed")
            return false
        end
    end
    
    self._active = true
    
    print("[EggBuyer] Starting auto-buy...")
    
    -- Set target mutation on ConveyorMonitor if configured
    if ConveyorMonitor and self._config.targetMutation then
        ConveyorMonitor.setTargetMutation(self._config.targetMutation)
    end
    
    -- Start ConveyorMonitor with callback
    if ConveyorMonitor then
        local startSuccess = ConveyorMonitor.start(function(egg, mutationName)
            self:_onTargetEggFound(egg, mutationName)
        end)
        
        if not startSuccess then
            warn("[EggBuyer] ConveyorMonitor failed to start")
            self._active = false
            return false
        end
    else
        warn("[EggBuyer] ConveyorMonitor not available - manual buyEgg only")
    end
    
    print("[EggBuyer] Auto-buy started")
    return true
end

-- ============================================================================
-- stop()
-- Stop auto-buy monitoring
-- Returns: nil
-- ============================================================================
function EggBuyer:stop()
    print("[EggBuyer] Stopping...")
    
    self._active = false
    
    -- Stop ConveyorMonitor
    if ConveyorMonitor then
        ConveyorMonitor.stop()
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
    
    print("[EggBuyer] Stopped")
end

-- ============================================================================
-- setTargetMutation(mutationName)
-- Set the target mutation to auto-buy
-- Returns: boolean (success)
-- ============================================================================
function EggBuyer:setTargetMutation(mutationName)
    self._config.targetMutation = mutationName
    
    -- Update ConveyorMonitor if active
    if ConveyorMonitor and self._active then
        ConveyorMonitor.setTargetMutation(mutationName)
    end
    
    print("[EggBuyer] Target mutation set: " .. tostring(mutationName))
    return true
end

-- ============================================================================
-- getStats()
-- Get current statistics
-- Returns: table (shallow copy)
-- ============================================================================
function EggBuyer:getStats()
    return {
        purchased = self._stats.purchased,
        failed = self._stats.failed,
        skippedNoMoney = self._stats.skippedNoMoney,
        skippedHolding = self._stats.skippedHolding,
    }
end

-- ============================================================================
-- getConfig()
-- Get current configuration
-- Returns: table (shallow copy)
-- ============================================================================
function EggBuyer:getConfig()
    return {
        targetMutation = self._config.targetMutation,
        enabled = self._config.enabled,
        buyDelay = self._config.buyDelay,
    }
end

-- ============================================================================
-- setConfig(key, value)
-- Update configuration value
-- Returns: boolean (success)
-- ============================================================================
function EggBuyer:setConfig(key, value)
    if self._config[key] ~= nil then
        self._config[key] = value
        print("[EggBuyer] Config updated: " .. key .. " = " .. tostring(value))
        return true
    else
        warn("[EggBuyer] Unknown config key: " .. tostring(key))
        return false
    end
end

-- ============================================================================
-- isActive()
-- Check if auto-buy is active
-- Returns: boolean
-- ============================================================================
function EggBuyer:isActive()
    return self._active
end

-- ============================================================================
-- cleanup()
-- Full cleanup - stops and resets all state
-- Returns: nil
-- ============================================================================
function EggBuyer:cleanup()
    print("[EggBuyer] Cleaning up...")
    
    self:stop()
    
    -- Reset stats
    self._stats = {
        purchased = 0,
        failed = 0,
        skippedNoMoney = 0,
        skippedHolding = 0,
    }
    
    -- Reset state
    self._holdingEgg = false
    self._buyRemote = nil
    
    -- Cleanup ConveyorMonitor
    if ConveyorMonitor then
        ConveyorMonitor.cleanup()
    end
    
    print("[EggBuyer] Cleanup complete")
end

-- ============================================================================
-- Module Export
-- ============================================================================
return {
    -- Lifecycle
    init = function() return EggBuyer:init() end,
    start = function() return EggBuyer:start() end,
    stop = function() return EggBuyer:stop() end,
    cleanup = function() return EggBuyer:cleanup() end,
    
    -- Core functions
    buyEgg = function(egg, mut) return EggBuyer:buyEgg(egg, mut) end,
    isHoldingEgg = function() return EggBuyer:isHoldingEgg() end,
    
    -- Configuration
    setTargetMutation = function(name) return EggBuyer:setTargetMutation(name) end,
    getConfig = function() return EggBuyer:getConfig() end,
    setConfig = function(k, v) return EggBuyer:setConfig(k, v) end,
    
    -- Status
    isActive = function() return EggBuyer:isActive() end,
    getStats = function() return EggBuyer:getStats() end,
}
