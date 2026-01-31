--[[
  features/auto-collect.lua
  Auto-collect money from pets in Build A Zoo
  
  Method: Touch/click pets that have money ready ($ indicator above them)
  
  Usage:
    local AutoCollect = require("features/auto-collect")
    AutoCollect.init()
    AutoCollect.start()
    AutoCollect.stop()
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
local Workspace = game:GetService("Workspace")

-- ============================================================================
-- Module State
-- ============================================================================
local AutoCollect = {
    _active = false,
    _thread = nil,
    _playerFolder = nil,
    _stats = {
        cyclesCompleted = 0,
        totalCollected = 0,
        totalFailed = 0,
    },
    _config = {
        cycleInterval = 3,  -- collect every 3 seconds
        delayPerPet = 0.3,  -- delay between pets
    },
}

-- ============================================================================
-- findPlayerFolder()
-- Find the player's zoo/pets folder in Workspace
-- ============================================================================
local function findPlayerFolder()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    local playerName = player.Name
    local userId = tostring(player.UserId)
    
    debugLog("[AutoCollect] Looking for player folder: " .. playerName)
    
    -- Search patterns
    local searchLocations = {
        -- Direct in Workspace
        {parent = Workspace, name = playerName},
        {parent = Workspace, name = userId},
        -- Common folder structures
        {parent = Workspace, child = "Zoos", name = playerName},
        {parent = Workspace, child = "Zoos", name = userId},
        {parent = Workspace, child = "PlayerZoos", name = playerName},
        {parent = Workspace, child = "Players", name = playerName},
        {parent = Workspace, child = "PlayerAreas", name = playerName},
    }
    
    for _, loc in ipairs(searchLocations) do
        local success, result = pcall(function()
            local searchIn = loc.parent
            if loc.child then
                searchIn = loc.parent:FindFirstChild(loc.child)
                if not searchIn then return nil end
            end
            return searchIn:FindFirstChild(loc.name)
        end)
        
        if success and result then
            debugLog("[AutoCollect] Found player folder: " .. result:GetFullName())
            return result
        end
    end
    
    -- Fallback: search all folders in Workspace for player name
    local success, result = pcall(function()
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                local playerFolder = child:FindFirstChild(playerName)
                if playerFolder then
                    return playerFolder
                end
            end
        end
        return nil
    end)
    
    if success and result then
        debugLog("[AutoCollect] Found player folder (fallback): " .. result:GetFullName())
        return result
    end
    
    debugLog("[AutoCollect] Player folder NOT FOUND")
    return nil
end

-- ============================================================================
-- findPetsWithMoney()
-- Find all pets that have money ready to collect
-- ============================================================================
local function findPetsWithMoney()
    local pets = {}
    local player = Players.LocalPlayer
    if not player then return pets end
    
    -- Search locations
    local searchLocations = {}
    
    -- Add player folder
    if AutoCollect._playerFolder then
        table.insert(searchLocations, AutoCollect._playerFolder)
    end
    
    -- Add Pets folder (from log: there's a "Pets" folder in Workspace)
    local petsFolder = Workspace:FindFirstChild("Pets")
    if petsFolder then
        table.insert(searchLocations, petsFolder)
        
        -- Also check player subfolder in Pets
        local playerPetsFolder = petsFolder:FindFirstChild(player.Name)
        if playerPetsFolder then
            table.insert(searchLocations, playerPetsFolder)
            debugLog("[AutoCollect] Found Pets/" .. player.Name)
        end
    end
    
    -- Debug: Log what we're searching
    debugLog("[AutoCollect] Searching " .. #searchLocations .. " locations")
    
    local allModels = {}
    
    for _, location in ipairs(searchLocations) do
        local success, children = pcall(function()
            return location:GetChildren()
        end)
        
        if success then
            for _, child in ipairs(children) do
                if child:IsA("Model") then
                    table.insert(allModels, child)
                end
            end
        end
    end
    
    debugLog("[AutoCollect] Found " .. #allModels .. " models total")
    
    -- Check each model for money
    for _, model in ipairs(allModels) do
        local hasMoney = false
        local moneyText = ""
        
        -- Method 1: Check BillboardGui for $ text
        pcall(function()
            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("BillboardGui") then
                    for _, guiChild in ipairs(desc:GetDescendants()) do
                        if guiChild:IsA("TextLabel") then
                            local text = guiChild.Text or ""
                            if string.find(text, "%$%d") then -- $460, $4/s, etc
                                hasMoney = true
                                moneyText = text
                                return
                            end
                        end
                    end
                end
            end
        end)
        
        -- Method 2: Check for "Money" or "Gold" attribute/value
        if not hasMoney then
            pcall(function()
                local moneyVal = model:FindFirstChild("Money") or model:FindFirstChild("Gold") or model:FindFirstChild("Cash")
                if moneyVal and moneyVal:IsA("NumberValue") or moneyVal:IsA("IntValue") then
                    if moneyVal.Value > 0 then
                        hasMoney = true
                        moneyText = "$" .. moneyVal.Value
                    end
                end
            end)
        end
        
        -- Method 3: Check attributes
        if not hasMoney then
            pcall(function()
                local money = model:GetAttribute("Money") or model:GetAttribute("Gold") or model:GetAttribute("CollectableMoney")
                if money and type(money) == "number" and money > 0 then
                    hasMoney = true
                    moneyText = "$" .. money
                end
            end)
        end
        
        if hasMoney then
            table.insert(pets, model)
        end
    end
    
    -- If no pets found with money indicator, try to collect ALL pets (brute force)
    if #pets == 0 and #allModels > 0 then
        debugLog("[AutoCollect] No $ found, trying all " .. #allModels .. " models")
        pets = allModels
    end
    
    return pets
end

-- ============================================================================
-- collectFromPet(pet)
-- Try to collect money from a pet by touching/clicking it
-- ============================================================================
local function collectFromPet(pet)
    if not pet then return false end
    
    local player = Players.LocalPlayer
    local character = player and player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    -- Method 1: Fire ProximityPrompt
    local success1, result1 = pcall(function()
        for _, desc in ipairs(pet:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                if fireproximityprompt then
                    fireproximityprompt(desc)
                    return true
                end
            end
        end
        return false
    end)
    if success1 and result1 then return true end
    
    -- Method 2: Fire ClickDetector
    local success2, result2 = pcall(function()
        for _, desc in ipairs(pet:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                if fireclickdetector then
                    fireclickdetector(desc)
                    return true
                end
            end
        end
        return false
    end)
    if success2 and result2 then return true end
    
    -- Method 3: Fire touch interest on pet's parts
    if rootPart and firetouchinterest then
        local success3, result3 = pcall(function()
            for _, desc in ipairs(pet:GetDescendants()) do
                if desc:IsA("BasePart") then
                    firetouchinterest(rootPart, desc, 0) -- Touch begin
                    task.wait(0.05)
                    firetouchinterest(rootPart, desc, 1) -- Touch end
                    return true
                end
            end
            return false
        end)
        if success3 and result3 then return true end
    end
    
    -- Method 4: Try to click on pet's PrimaryPart
    local success4, result4 = pcall(function()
        local primary = pet.PrimaryPart or pet:FindFirstChildWhichIsA("BasePart")
        if primary and rootPart and firetouchinterest then
            firetouchinterest(rootPart, primary, 0)
            task.wait(0.05)
            firetouchinterest(rootPart, primary, 1)
            return true
        end
        return false
    end)
    if success4 and result4 then return true end
    
    return false
end

-- ============================================================================
-- collectCycle()
-- Run a single collection cycle
-- ============================================================================
local function collectCycle()
    local pets = findPetsWithMoney()
    local collected = 0
    local failed = 0
    
    debugLog("[AutoCollect] Found " .. #pets .. " pets with $")
    
    for i, pet in ipairs(pets) do
        if not AutoCollect._active then break end
        
        local success = collectFromPet(pet)
        if success then
            collected = collected + 1
        else
            failed = failed + 1
        end
        
        -- Small delay between pets
        if i < #pets and AutoCollect._active then
            task.wait(AutoCollect._config.delayPerPet)
        end
    end
    
    AutoCollect._stats.cyclesCompleted = AutoCollect._stats.cyclesCompleted + 1
    AutoCollect._stats.totalCollected = AutoCollect._stats.totalCollected + collected
    AutoCollect._stats.totalFailed = AutoCollect._stats.totalFailed + failed
    
    if #pets > 0 then
        debugLog("[AutoCollect] Collected: " .. collected .. "/" .. #pets)
    end
end

-- ============================================================================
-- init()
-- ============================================================================
function AutoCollect:init()
    debugLog("[AutoCollect] Initializing...")
    
    -- Find player folder
    self._playerFolder = findPlayerFolder()
    
    -- Log workspace structure for debugging
    local folderNames = {}
    pcall(function()
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                table.insert(folderNames, child.Name)
            end
        end
    end)
    
    if #folderNames > 0 then
        debugLog("[AutoCollect] Workspace folders: " .. table.concat(folderNames, ", "))
    end
    
    debugLog("[AutoCollect] Ready")
    return true
end

-- ============================================================================
-- start()
-- ============================================================================
function AutoCollect:start()
    if self._active then
        debugLog("[AutoCollect] Already running")
        return false
    end
    
    self._active = true
    debugLog("[AutoCollect] Started (interval: " .. self._config.cycleInterval .. "s)")
    
    self._thread = task.spawn(function()
        while self._active do
            local success, err = pcall(collectCycle)
            if not success then
                debugLog("[AutoCollect] Error: " .. tostring(err))
            end
            
            if self._active then
                task.wait(self._config.cycleInterval)
            end
        end
    end)
    
    return true
end

-- ============================================================================
-- stop()
-- ============================================================================
function AutoCollect:stop()
    debugLog("[AutoCollect] Stopping...")
    self._active = false
    
    if self._thread then
        pcall(function() task.cancel(self._thread) end)
        self._thread = nil
    end
    
    debugLog("[AutoCollect] Stopped")
end

-- ============================================================================
-- Other functions
-- ============================================================================
function AutoCollect:isActive() return self._active end

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
        delayPerPet = self._config.delayPerPet,
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
        playerFolder = self._playerFolder,
    }
end

function AutoCollect:runOnce()
    self:init()
    collectCycle()
    return true
end

function AutoCollect:cleanup()
    self:stop()
    self._stats = { cyclesCompleted = 0, totalCollected = 0, totalFailed = 0 }
    self._playerFolder = nil
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
