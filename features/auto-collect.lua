--[[
  features/auto-collect.lua
  Auto-collect money from pets in Build A Zoo
  
  ONLY collects from player's OWN pets (UUID names)
  Does NOT teleport to eggs, conveyors, or other areas
--]]

local function debugLog(message)
    print(message)
    if _G.DebugLog then
        pcall(function() _G.DebugLog(message) end)
    end
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AutoCollect = {
    _active = false,
    _thread = nil,
    _playerFolder = nil,
    _stats = { cyclesCompleted = 0, totalCollected = 0, totalFailed = 0 },
    _config = { cycleInterval = 3, delayPerPet = 0.5 },
}

-- Find player's zoo folder
local function findPlayerZooFolder()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    local playerName = player.Name
    local userId = tostring(player.UserId)
    
    debugLog("[AutoCollect] Looking for: " .. playerName)
    
    -- Direct paths
    local direct = Workspace:FindFirstChild(playerName) or Workspace:FindFirstChild(userId)
    if direct then
        debugLog("[AutoCollect] Found: " .. direct:GetFullName())
        return direct
    end
    
    -- Container folders
    for _, name in ipairs({"Zoos", "PlayerZoos", "Players", "PlayerAreas", "Islands"}) do
        local container = Workspace:FindFirstChild(name)
        if container then
            local folder = container:FindFirstChild(playerName) or container:FindFirstChild(userId)
            if folder then
                debugLog("[AutoCollect] Found: " .. folder:GetFullName())
                return folder
            end
        end
    end
    
    -- Nested search
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            local found = child:FindFirstChild(playerName)
            if found then
                debugLog("[AutoCollect] Found: " .. found:GetFullName())
                return found
            end
        end
    end
    
    debugLog("[AutoCollect] Player folder NOT FOUND")
    return nil
end

-- Check if model is a valid pet (UUID name + has $XXX)
local function isValidPetModel(model)
    if not model or not model:IsA("Model") then return false, 0 end
    
    local name = model.Name
    
    -- UUID: 28+ lowercase hex characters
    if not (string.match(name, "^[a-f0-9]+$") and #name >= 28) then
        return false, 0
    end
    
    -- Check for $XXX (not $X/s)
    local moneyAmount = 0
    pcall(function()
        for _, child in ipairs(model:GetDescendants()) do
            if child:IsA("TextLabel") and child.Visible ~= false then
                local text = child.Text or ""
                local amount = string.match(text, "^%$([%d,]+)$")
                if amount then
                    amount = string.gsub(amount, ",", "")
                    local num = tonumber(amount)
                    if num and num > 0 then
                        moneyAmount = num
                        return
                    end
                end
            end
        end
    end)
    
    return moneyAmount > 0, moneyAmount
end

-- Find only player's pets with money
local function findPetsWithMoney()
    local pets = {}
    local player = Players.LocalPlayer
    if not player then return pets end
    
    local playerFolder = AutoCollect._playerFolder or findPlayerZooFolder()
    
    if playerFolder then
        debugLog("[AutoCollect] Scanning: " .. playerFolder.Name)
        
        local success, descendants = pcall(function()
            return playerFolder:GetDescendants()
        end)
        
        if success then
            for _, desc in ipairs(descendants) do
                local isValid, money = isValidPetModel(desc)
                if isValid then
                    table.insert(pets, {model = desc, money = money})
                end
            end
        end
    end
    
    -- Fallback: UUID scan if no pets in player folder
    if #pets == 0 then
        debugLog("[AutoCollect] Fallback: UUID scan...")
        
        local success, descendants = pcall(function()
            return Workspace:GetDescendants()
        end)
        
        if success then
            for _, desc in ipairs(descendants) do
                local isValid, money = isValidPetModel(desc)
                if isValid then
                    table.insert(pets, {model = desc, money = money})
                end
            end
        end
    end
    
    debugLog("[AutoCollect] Found " .. #pets .. " pets")
    for i, item in ipairs(pets) do
        if i <= 3 then
            debugLog("[AutoCollect] -> " .. item.model.Name:sub(1,8) .. "... $" .. item.money)
        end
    end
    
    local result = {}
    for _, item in ipairs(pets) do
        table.insert(result, item.model)
    end
    return result
end

-- Teleport to pet and collect
local function collectFromPet(pet)
    if not pet then return false end
    
    local player = Players.LocalPlayer
    local character = player and player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then return false end
    
    local shortName = pet.Name:sub(1, 8) .. "..."
    
    -- Get pet position
    local petCFrame, petSize
    local success = pcall(function()
        petCFrame, petSize = pet:GetBoundingBox()
    end)
    
    if not success or not petCFrame then
        debugLog("[AutoCollect] No pos: " .. shortName)
        return false
    end
    
    local originalCFrame = rootPart.CFrame
    
    -- Step 1: Teleport ON TOP of pet
    local petTop = petCFrame.Position + Vector3.new(0, (petSize.Y / 2) + 1, 0)
    pcall(function()
        rootPart.CFrame = CFrame.new(petTop)
    end)
    task.wait(0.25)
    
    -- Step 2: Teleport INTO pet center (touch)
    pcall(function()
        rootPart.CFrame = CFrame.new(petCFrame.Position)
    end)
    task.wait(0.25)
    
    debugLog("[AutoCollect] Collected: " .. shortName)
    
    -- Teleport back
    pcall(function()
        rootPart.CFrame = originalCFrame
    end)
    
    return true
end

-- Run one collection cycle
local function collectCycle()
    local pets = findPetsWithMoney()
    if #pets == 0 then return end
    
    local collected = 0
    
    for i, pet in ipairs(pets) do
        if not AutoCollect._active then break end
        
        if collectFromPet(pet) then
            collected = collected + 1
        end
        
        if i < #pets and AutoCollect._active then
            task.wait(AutoCollect._config.delayPerPet)
        end
    end
    
    AutoCollect._stats.cyclesCompleted = AutoCollect._stats.cyclesCompleted + 1
    AutoCollect._stats.totalCollected = AutoCollect._stats.totalCollected + collected
    
    debugLog("[AutoCollect] Done: " .. collected .. "/" .. #pets)
end

-- Public API
function AutoCollect:init()
    debugLog("[AutoCollect] Initializing...")
    self._playerFolder = findPlayerZooFolder()
    debugLog("[AutoCollect] Ready")
    return true
end

function AutoCollect:start()
    if self._active then return false end
    
    self._active = true
    debugLog("[AutoCollect] Started")
    
    self._thread = task.spawn(function()
        while self._active do
            pcall(collectCycle)
            if self._active then
                task.wait(self._config.cycleInterval)
            end
        end
    end)
    
    return true
end

function AutoCollect:stop()
    debugLog("[AutoCollect] Stopping...")
    self._active = false
    if self._thread then
        pcall(function() task.cancel(self._thread) end)
        self._thread = nil
    end
    debugLog("[AutoCollect] Stopped")
end

function AutoCollect:isActive() return self._active end
function AutoCollect:getStats() return self._stats end
function AutoCollect:getConfig() return self._config end
function AutoCollect:setConfig(k, v)
    if self._config[k] ~= nil then
        self._config[k] = v
        return true
    end
    return false
end
function AutoCollect:getDiscovery() return { playerFolder = self._playerFolder } end
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
