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
    
    -- Blacklist names that are NOT pets
    local blacklist = {
        ["Status"] = true, ["GUI"] = true, ["HUD"] = true, ["UI"] = true,
        ["Camera"] = true, ["Terrain"] = true, ["Baseplate"] = true,
        ["SpawnLocation"] = true, ["Part"] = true,
    }
    
    -- AGGRESSIVE: Scan ENTIRE Workspace for models with $ indicator
    debugLog("[AutoCollect] Scanning entire Workspace...")
    
    local allModelsWithMoney = {}
    
    local success, descendants = pcall(function()
        return Workspace:GetDescendants()
    end)
    
    if not success then
        debugLog("[AutoCollect] Failed to scan Workspace")
        return pets
    end
    
    -- Find all models that have TextLabel with $ in them
    for _, desc in ipairs(descendants) do
        if desc:IsA("Model") and not blacklist[desc.Name] then
            local moneyAmount = 0
            
            pcall(function()
                for _, child in ipairs(desc:GetDescendants()) do
                    if child:IsA("TextLabel") and child.Visible ~= false then
                        local text = child.Text or ""
                        -- Look for $XXX pattern (collectible money)
                        local amount = string.match(text, "^%$(%d+)$") -- Exact match like "$604"
                        if not amount then
                            amount = string.match(text, "^%$(%d+)%s") -- "$604 " with space after
                        end
                        if amount then
                            local num = tonumber(amount)
                            if num and num > 0 then
                                moneyAmount = num
                                return
                            end
                        end
                    end
                end
            end)
            
            if moneyAmount > 0 then
                table.insert(allModelsWithMoney, {model = desc, money = moneyAmount})
            end
        end
    end
    
    debugLog("[AutoCollect] Found " .. #allModelsWithMoney .. " models with $")
    
    -- Log what we found
    for i, item in ipairs(allModelsWithMoney) do
        if i <= 5 then -- Only log first 5
            debugLog("[AutoCollect] -> " .. item.model.Name .. " = $" .. item.money)
        end
    end
    
    -- Filter: Only return models with UUID-like names (pets) or models inside player folder
    -- UUID pattern: 32 hex characters
    local filteredPets = {}
    for _, item in ipairs(allModelsWithMoney) do
        local name = item.model.Name
        -- Check if name looks like UUID (32+ hex chars)
        if string.match(name, "^[a-f0-9]+$") and #name >= 20 then
            table.insert(filteredPets, item.model)
            debugLog("[AutoCollect] Pet UUID: " .. name:sub(1, 12) .. "...")
        end
    end
    
    debugLog("[AutoCollect] Filtered to " .. #filteredPets .. " actual pets")
    
    -- If no UUID pets found, return all (fallback)
    if #filteredPets == 0 then
        for _, item in ipairs(allModelsWithMoney) do
            table.insert(filteredPets, item.model)
        end
    end
    
    return filteredPets
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
    
    local petName = pet.Name
    local shortName = #petName > 12 and petName:sub(1, 12) .. "..." or petName
    debugLog("[AutoCollect] Collecting: " .. shortName)
    
    -- Get pet UUID/ID
    local petId = pet.Name -- The name itself is the UUID
    local petIdAttr = pet:GetAttribute("Id") or pet:GetAttribute("PetId") or pet:GetAttribute("UUID") or pet:GetAttribute("id")
    if petIdAttr then
        petId = petIdAttr
    end
    
    -- Method 1: Fire ResourceRE with specific patterns for Build A Zoo
    local success1, result1 = pcall(function()
        local resourceRE = ReplicatedStorage:FindFirstChild("ResourceRE")
        if resourceRE and resourceRE:IsA("RemoteEvent") then
            -- Try various argument patterns
            pcall(function() resourceRE:FireServer("Collect", petId) end)
            pcall(function() resourceRE:FireServer("CollectPet", petId) end)
            pcall(function() resourceRE:FireServer("ClaimPet", petId) end)
            pcall(function() resourceRE:FireServer(petId, "Collect") end)
            pcall(function() resourceRE:FireServer({petId = petId, action = "Collect"}) end)
            pcall(function() resourceRE:FireServer({id = petId}) end)
            return true
        end
        return false
    end)
    
    -- Method 2: Fire PetRE with specific patterns
    local success2, result2 = pcall(function()
        local petRE = ReplicatedStorage:FindFirstChild("PetRE")
        if petRE and petRE:IsA("RemoteEvent") then
            pcall(function() petRE:FireServer("Collect", petId) end)
            pcall(function() petRE:FireServer("CollectMoney", petId) end)
            pcall(function() petRE:FireServer("Claim", petId) end)
            pcall(function() petRE:FireServer(petId) end)
            pcall(function() petRE:FireServer(pet) end)
            pcall(function() petRE:FireServer({petId = petId}) end)
            pcall(function() petRE:FireServer("CollectAll") end)
            return true
        end
        return false
    end)
    
    -- Method 3: Try ALL remotes with "Collect" pattern
    local success3, result3 = pcall(function()
        for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                local name = child.Name:lower()
                if string.find(name, "collect") or string.find(name, "claim") or string.find(name, "money") then
                    pcall(function() child:FireServer(petId) end)
                    pcall(function() child:FireServer(pet) end)
                    debugLog("[AutoCollect] Tried: " .. child.Name)
                end
            end
        end
        return true
    end)
    
    -- Method 4: Fire ProximityPrompt
    local success4, result4 = pcall(function()
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
    if success4 and result4 then return true end
    
    -- Method 5: Fire ClickDetector
    local success5, result5 = pcall(function()
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
    if success5 and result5 then return true end
    
    -- Method 6: Fire touch interest
    if rootPart and firetouchinterest then
        local success6, result6 = pcall(function()
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
        if success6 and result6 then return true end
    end
    
    debugLog("[AutoCollect] All methods failed")
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
