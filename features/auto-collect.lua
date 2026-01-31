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
    
    local allModels = {}
    
    -- Method 1: Search in player folder and its descendants
    if AutoCollect._playerFolder then
        local success, descendants = pcall(function()
            return AutoCollect._playerFolder:GetDescendants()
        end)
        if success then
            for _, desc in ipairs(descendants) do
                if desc:IsA("Model") then
                    table.insert(allModels, desc)
                end
            end
        end
        debugLog("[AutoCollect] Player folder models: " .. #allModels)
    end
    
    -- Method 2: Search in Pets folder
    local petsFolder = Workspace:FindFirstChild("Pets")
    if petsFolder then
        -- Check player subfolder
        local playerPets = petsFolder:FindFirstChild(player.Name)
        if playerPets then
            local success, descendants = pcall(function()
                return playerPets:GetDescendants()
            end)
            if success then
                for _, desc in ipairs(descendants) do
                    if desc:IsA("Model") then
                        table.insert(allModels, desc)
                    end
                end
            end
            debugLog("[AutoCollect] Pets/" .. player.Name .. " models: " .. #allModels)
        else
            -- Search all in Pets folder
            local success, children = pcall(function()
                return petsFolder:GetChildren()
            end)
            if success then
                for _, child in ipairs(children) do
                    if child:IsA("Model") then
                        table.insert(allModels, child)
                    end
                end
            end
        end
    end
    
    -- Method 3: If still no models, search ENTIRE Workspace for models with BillboardGui containing $
    if #allModels == 0 then
        debugLog("[AutoCollect] No models in expected locations, scanning Workspace...")
        
        local success, descendants = pcall(function()
            return Workspace:GetDescendants()
        end)
        
        if success then
            for _, desc in ipairs(descendants) do
                if desc:IsA("Model") and desc.Parent and desc.Parent.Parent then
                    -- Check if this model has a BillboardGui with $ text
                    local hasBillboard = false
                    pcall(function()
                        for _, child in ipairs(desc:GetChildren()) do
                            if child:IsA("BillboardGui") then
                                hasBillboard = true
                                return
                            end
                        end
                    end)
                    
                    if hasBillboard then
                        table.insert(allModels, desc)
                    end
                end
            end
        end
        debugLog("[AutoCollect] Found " .. #allModels .. " models with BillboardGui")
    end
    
    debugLog("[AutoCollect] Total models to check: " .. #allModels)
    
    -- Check each model for money indicator
    for _, model in ipairs(allModels) do
        local hasMoney = false
        
        -- Check BillboardGui for $ text
        pcall(function()
            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("TextLabel") then
                    local text = desc.Text or ""
                    if string.find(text, "%$%d") then -- $76, $4/s, etc
                        hasMoney = true
                        return
                    end
                end
            end
        end)
        
        if hasMoney then
            table.insert(pets, model)
        end
    end
    
    debugLog("[AutoCollect] Pets with $: " .. #pets)
    
    -- Fallback: if no $ detected but we have models, try them all
    if #pets == 0 and #allModels > 0 then
        debugLog("[AutoCollect] Trying all " .. #allModels .. " models")
        return allModels
    end
    
    return pets
end

-- ============================================================================
-- collectFromPet(pet)
-- Try to collect money from a pet by various methods
-- ============================================================================
local function collectFromPet(pet)
    if not pet then return false end
    
    local player = Players.LocalPlayer
    local character = player and player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    debugLog("[AutoCollect] Trying to collect from: " .. pet.Name)
    
    -- Method 1: Fire PetRE or ResourceRE with pet info
    local success1, result1 = pcall(function()
        local remotes = {
            ReplicatedStorage:FindFirstChild("PetRE"),
            ReplicatedStorage:FindFirstChild("ResourceRE"),
        }
        
        -- Also search in subfolders
        for _, child in ipairs(ReplicatedStorage:GetChildren()) do
            if child:IsA("Folder") then
                local petRE = child:FindFirstChild("PetRE")
                local resRE = child:FindFirstChild("ResourceRE")
                if petRE then table.insert(remotes, petRE) end
                if resRE then table.insert(remotes, resRE) end
            end
        end
        
        for _, remote in ipairs(remotes) do
            if remote and remote:IsA("RemoteEvent") then
                -- Try different argument patterns
                -- Pattern 1: "Collect" action with pet
                pcall(function() remote:FireServer("Collect", pet) end)
                pcall(function() remote:FireServer("CollectMoney", pet) end)
                pcall(function() remote:FireServer("Claim", pet) end)
                
                -- Pattern 2: Just pet reference
                pcall(function() remote:FireServer(pet) end)
                
                -- Pattern 3: Pet name or ID
                pcall(function() remote:FireServer(pet.Name) end)
                local petId = pet:GetAttribute("Id") or pet:GetAttribute("PetId") or pet:GetAttribute("UUID")
                if petId then
                    pcall(function() remote:FireServer(petId) end)
                    pcall(function() remote:FireServer("Collect", petId) end)
                end
                
                return true
            end
        end
        return false
    end)
    if success1 and result1 then 
        debugLog("[AutoCollect] Fired remote for: " .. pet.Name)
        return true 
    end
    
    -- Method 2: Fire ProximityPrompt
    local success2, result2 = pcall(function()
        for _, desc in ipairs(pet:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                if fireproximityprompt then
                    fireproximityprompt(desc)
                    debugLog("[AutoCollect] Fired ProximityPrompt")
                    return true
                end
            end
        end
        return false
    end)
    if success2 and result2 then return true end
    
    -- Method 3: Fire ClickDetector
    local success3, result3 = pcall(function()
        for _, desc in ipairs(pet:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                if fireclickdetector then
                    fireclickdetector(desc)
                    debugLog("[AutoCollect] Fired ClickDetector")
                    return true
                end
            end
        end
        return false
    end)
    if success3 and result3 then return true end
    
    -- Method 4: Fire touch interest
    if rootPart and firetouchinterest then
        local success4, result4 = pcall(function()
            for _, desc in ipairs(pet:GetDescendants()) do
                if desc:IsA("BasePart") then
                    firetouchinterest(rootPart, desc, 0)
                    task.wait(0.05)
                    firetouchinterest(rootPart, desc, 1)
                    debugLog("[AutoCollect] Fired touch on: " .. desc.Name)
                    return true
                end
            end
            return false
        end)
        if success4 and result4 then return true end
    end
    
    debugLog("[AutoCollect] All methods failed for: " .. pet.Name)
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
