--[[
  features/egg-hatcher.lua
  Detects ready-to-hatch eggs and executes hatch action
  
  Usage:
    local EggHatcher = require("features/egg-hatcher")
    EggHatcher.init(plotsFolder)
    local readyEggs = EggHatcher.findReadyEggs()
    for _, eggData in ipairs(readyEggs) do
        EggHatcher.hatchEgg(eggData.egg, eggData.prompt)
    end
    
  Exports:
    init, isEggReady, findReadyEggs, hatchEgg, watchForReady
    
  Ready detection methods:
    - GetAttribute("Ready") == true
    - ProximityPrompt "Hatch" enabled
    - BillboardGui with "!" or "ready" text
    - Highlight effect enabled
--]]

-- Get services (cached for security)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module State
local EggHatcher = {
    _hatchRemote = nil,       -- Instance, cached RemoteEvent for hatch
    _connections = {},        -- table, for cleanup
    _plotsFolder = nil,       -- Instance, reference to player plots
}

-- Common hatch RemoteEvent patterns
local HATCH_REMOTE_PATTERNS = {
    "HatchEgg",
    "Hatch",
    "OpenEgg",
    "BreakEgg",
    "Crack",
    "CrackEgg",
    "CollectEgg",
    "ClaimAnimal",
    "GetAnimal",
    "Remotes.HatchEgg",
    "Remotes.Hatch",
    "Events.HatchEgg",
    "Events.Hatch",
}

-- ============================================================================
-- _discoverHatchRemote()
-- Find the RemoteEvent used for hatching eggs
-- Returns: Instance or nil
-- ============================================================================
local function discoverHatchRemote()
    local success, result = pcall(function()
        -- Check common patterns in ReplicatedStorage
        for _, pattern in ipairs(HATCH_REMOTE_PATTERNS) do
            -- Handle nested paths like "Remotes.HatchEgg"
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
                print("[EggHatcher] Found hatch remote at: " .. current:GetFullName())
                return current
            end
        end
        
        -- Fallback: search ReplicatedStorage for any remote containing "hatch" or "crack"
        local function searchFolder(folder)
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    local nameLower = string.lower(child.Name)
                    if string.find(nameLower, "hatch") or 
                       string.find(nameLower, "crack") or
                       string.find(nameLower, "openegg") or
                       string.find(nameLower, "breakegg") then
                        print("[EggHatcher] Found hatch remote via search: " .. child:GetFullName())
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
        warn("[EggHatcher] Remote discovery failed: " .. tostring(result))
        return nil
    end
end

-- ============================================================================
-- init(plotsFolder)
-- Initialize the egg hatcher module
-- plotsFolder: Instance, the player's plots folder (optional, can discover)
-- Returns: boolean (success)
-- ============================================================================
function EggHatcher:init(plotsFolder)
    print("[EggHatcher] Initializing...")
    
    -- Store plots folder reference
    if plotsFolder then
        self._plotsFolder = plotsFolder
    end
    
    -- Discover hatch RemoteEvent
    self._hatchRemote = discoverHatchRemote()
    if not self._hatchRemote then
        warn("[EggHatcher] Hatch remote not found - will retry on hatch attempt")
    end
    
    print("[EggHatcher] Initialized successfully")
    print("[EggHatcher] - Plots folder: " .. (self._plotsFolder and self._plotsFolder.Name or "NOT SET"))
    print("[EggHatcher] - Hatch remote: " .. (self._hatchRemote and self._hatchRemote.Name or "NOT FOUND"))
    
    return true
end

-- ============================================================================
-- setPlotsFolder(plotsFolder)
-- Set the plots folder reference
-- Returns: nil
-- ============================================================================
function EggHatcher:setPlotsFolder(plotsFolder)
    self._plotsFolder = plotsFolder
end

-- ============================================================================
-- isEggReady(egg)
-- Check if an egg is ready to hatch using multiple detection methods
-- egg: Instance, the egg to check
-- Returns: boolean, ProximityPrompt or nil
-- ============================================================================
function EggHatcher:isEggReady(egg)
    local success, ready, prompt = pcall(function()
        if not egg then return false, nil end
        
        -- Method A: Ready attribute
        if egg:GetAttribute("Ready") == true then
            local foundPrompt = egg:FindFirstChildOfClass("ProximityPrompt")
            return true, foundPrompt
        end
        
        -- Check alternative ready attributes
        local canHatch = egg:GetAttribute("CanHatch")
        local isReady = egg:GetAttribute("IsReady")
        local hatchable = egg:GetAttribute("Hatchable")
        
        if canHatch == true or isReady == true or hatchable == true then
            local foundPrompt = egg:FindFirstChildOfClass("ProximityPrompt")
            return true, foundPrompt
        end
        
        -- Method B: ProximityPrompt "Hatch" enabled
        local proximityPrompt = egg:FindFirstChildOfClass("ProximityPrompt")
        if proximityPrompt and proximityPrompt.Enabled then
            local actionText = string.lower(proximityPrompt.ActionText or "")
            local objectText = string.lower(proximityPrompt.ObjectText or "")
            
            if string.find(actionText, "hatch") or 
               string.find(actionText, "open") or
               string.find(actionText, "crack") or
               string.find(objectText, "hatch") then
                return true, proximityPrompt
            end
        end
        
        -- Also check descendants for ProximityPrompt
        for _, desc in ipairs(egg:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local actionText = string.lower(desc.ActionText or "")
                if string.find(actionText, "hatch") or 
                   string.find(actionText, "open") or
                   string.find(actionText, "crack") then
                    return true, desc
                end
            end
        end
        
        -- Method C: BillboardGui with "!" or "ready" text (visual indicator)
        local billboard = egg:FindFirstChildOfClass("BillboardGui")
        if billboard and billboard.Enabled then
            local textLabel = billboard:FindFirstChildOfClass("TextLabel")
            if textLabel then
                local text = textLabel.Text or ""
                if string.find(text, "!") or 
                   string.find(string.lower(text), "ready") or
                   string.find(string.lower(text), "hatch") then
                    local foundPrompt = egg:FindFirstChildOfClass("ProximityPrompt")
                    return true, foundPrompt
                end
            end
            
            -- Check all text elements in billboard
            for _, child in ipairs(billboard:GetDescendants()) do
                if child:IsA("TextLabel") then
                    local text = child.Text or ""
                    if string.find(text, "!") or 
                       string.find(string.lower(text), "ready") or
                       string.find(string.lower(text), "hatch") then
                        local foundPrompt = egg:FindFirstChildOfClass("ProximityPrompt")
                        return true, foundPrompt
                    end
                end
            end
        end
        
        -- Method D: Highlight effect enabled (glow effect indicates ready)
        local highlight = egg:FindFirstChildOfClass("Highlight")
        if highlight and highlight.Enabled then
            local foundPrompt = egg:FindFirstChildOfClass("ProximityPrompt")
            return true, foundPrompt
        end
        
        -- Also check for SelectionBox (alternative highlight)
        local selectionBox = egg:FindFirstChildOfClass("SelectionBox")
        if selectionBox and selectionBox.Visible then
            local foundPrompt = egg:FindFirstChildOfClass("ProximityPrompt")
            return true, foundPrompt
        end
        
        return false, nil
    end)
    
    if success then
        return ready, prompt
    else
        warn("[EggHatcher] isEggReady failed: " .. tostring(ready))
        return false, nil
    end
end

-- ============================================================================
-- findReadyEggs()
-- Find all eggs that are ready to hatch
-- Returns: table of {egg = Instance, plot = Instance, prompt = Instance or nil}
-- ============================================================================
function EggHatcher:findReadyEggs()
    local readyEggs = {}
    
    if not self._plotsFolder then
        warn("[EggHatcher] No plots folder set - cannot find ready eggs")
        return readyEggs
    end
    
    local success, err = pcall(function()
        for _, plot in ipairs(self._plotsFolder:GetChildren()) do
            -- Look for eggs in plot
            local egg = plot:FindFirstChild("Egg") or 
                       plot:FindFirstChild("Incubating") or
                       plot:FindFirstChild("IncubatedEgg")
            
            -- Also search for any model with "egg" in name
            if not egg then
                for _, child in ipairs(plot:GetChildren()) do
                    if child:IsA("Model") and string.find(string.lower(child.Name), "egg") then
                        egg = child
                        break
                    end
                end
            end
            
            -- Search descendants if still not found
            if not egg then
                for _, desc in ipairs(plot:GetDescendants()) do
                    if desc:IsA("Model") and string.find(string.lower(desc.Name), "egg") then
                        egg = desc
                        break
                    end
                end
            end
            
            if egg then
                local ready, prompt = self:isEggReady(egg)
                if ready then
                    table.insert(readyEggs, {
                        egg = egg,
                        plot = plot,
                        prompt = prompt,
                    })
                end
            end
        end
    end)
    
    if not success then
        warn("[EggHatcher] findReadyEggs failed: " .. tostring(err))
    end
    
    return readyEggs
end

-- ============================================================================
-- hatchEgg(egg, prompt)
-- Hatch an egg using available methods
-- egg: Instance, the egg to hatch
-- prompt: ProximityPrompt or nil
-- Returns: boolean success
-- ============================================================================
function EggHatcher:hatchEgg(egg, prompt)
    local success, result = pcall(function()
        -- Method A: Use ProximityPrompt if available
        if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
            if fireproximityprompt then
                fireproximityprompt(prompt)
                print("[EggHatcher] Hatched egg via ProximityPrompt: " .. egg.Name)
                return true
            end
        end
        
        -- Method B: Find ProximityPrompt on egg
        local foundPrompt = egg:FindFirstChildOfClass("ProximityPrompt")
        if foundPrompt and foundPrompt.Enabled and fireproximityprompt then
            fireproximityprompt(foundPrompt)
            print("[EggHatcher] Hatched egg via found ProximityPrompt: " .. egg.Name)
            return true
        end
        
        -- Method C: Use RemoteEvent
        if not self._hatchRemote then
            self._hatchRemote = discoverHatchRemote()
        end
        
        if self._hatchRemote then
            -- Try different argument patterns
            local patterns = {
                -- Pattern 1: Fire with egg instance
                function()
                    if self._hatchRemote:IsA("RemoteEvent") then
                        self._hatchRemote:FireServer(egg)
                    else
                        self._hatchRemote:InvokeServer(egg)
                    end
                    return true
                end,
                -- Pattern 2: Fire with egg name
                function()
                    if self._hatchRemote:IsA("RemoteEvent") then
                        self._hatchRemote:FireServer(egg.Name)
                    else
                        self._hatchRemote:InvokeServer(egg.Name)
                    end
                    return true
                end,
                -- Pattern 3: Fire with egg ID attribute
                function()
                    local eggId = egg:GetAttribute("Id") or egg:GetAttribute("EggId")
                    if eggId then
                        if self._hatchRemote:IsA("RemoteEvent") then
                            self._hatchRemote:FireServer(eggId)
                        else
                            self._hatchRemote:InvokeServer(eggId)
                        end
                        return true
                    end
                    return false
                end,
                -- Pattern 4: Fire without arguments
                function()
                    if self._hatchRemote:IsA("RemoteEvent") then
                        self._hatchRemote:FireServer()
                    else
                        self._hatchRemote:InvokeServer()
                    end
                    return true
                end,
            }
            
            for _, tryPattern in ipairs(patterns) do
                local patternSuccess, patternResult = pcall(tryPattern)
                if patternSuccess and patternResult then
                    print("[EggHatcher] Hatched egg via RemoteEvent: " .. egg.Name)
                    return true
                end
            end
        end
        
        -- Method D: Try touching the egg
        local LocalPlayer = Players.LocalPlayer
        if LocalPlayer and LocalPlayer.Character then
            local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                -- Find a touchable part on the egg
                local touchPart = nil
                for _, child in ipairs(egg:GetDescendants()) do
                    if child:IsA("BasePart") then
                        touchPart = child
                        break
                    end
                end
                
                if touchPart and firetouchinterest then
                    firetouchinterest(rootPart, touchPart, 0)
                    task.wait(0.1)
                    firetouchinterest(rootPart, touchPart, 1)
                    print("[EggHatcher] Hatched egg via touch: " .. egg.Name)
                    return true
                end
            end
        end
        
        return false
    end)
    
    if success then
        return result
    else
        warn("[EggHatcher] hatchEgg failed: " .. tostring(result))
        return false
    end
end

-- ============================================================================
-- watchForReady(egg, callback)
-- Watch for an egg to become ready (event-based)
-- egg: Instance, the egg to watch
-- callback: function(egg, prompt), called when egg becomes ready
-- Returns: RBXScriptConnection for cleanup
-- ============================================================================
function EggHatcher:watchForReady(egg, callback)
    local connections = {}
    
    local success, err = pcall(function()
        -- Watch Ready attribute
        local attrConnection = egg:GetAttributeChangedSignal("Ready"):Connect(function()
            if egg:GetAttribute("Ready") == true then
                local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
                if callback then
                    callback(egg, prompt)
                end
            end
        end)
        table.insert(connections, attrConnection)
        table.insert(self._connections, attrConnection)
        
        -- Watch CanHatch attribute
        local canHatchConnection = egg:GetAttributeChangedSignal("CanHatch"):Connect(function()
            if egg:GetAttribute("CanHatch") == true then
                local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
                if callback then
                    callback(egg, prompt)
                end
            end
        end)
        table.insert(connections, canHatchConnection)
        table.insert(self._connections, canHatchConnection)
        
        -- Watch for ProximityPrompt addition
        local childConnection = egg.ChildAdded:Connect(function(child)
            if child:IsA("ProximityPrompt") then
                -- Small delay to let properties be set
                task.wait(0.1)
                if child.Enabled then
                    local actionText = string.lower(child.ActionText or "")
                    if string.find(actionText, "hatch") or 
                       string.find(actionText, "open") or
                       string.find(actionText, "crack") then
                        if callback then
                            callback(egg, child)
                        end
                    end
                end
            end
        end)
        table.insert(connections, childConnection)
        table.insert(self._connections, childConnection)
        
        -- Watch for Highlight addition (visual ready indicator)
        local highlightConnection = egg.ChildAdded:Connect(function(child)
            if child:IsA("Highlight") then
                task.wait(0.1)
                if child.Enabled then
                    local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
                    if callback then
                        callback(egg, prompt)
                    end
                end
            end
        end)
        table.insert(connections, highlightConnection)
        table.insert(self._connections, highlightConnection)
    end)
    
    if not success then
        warn("[EggHatcher] watchForReady failed: " .. tostring(err))
    end
    
    -- Return a pseudo-connection that disconnects all
    return {
        Disconnect = function()
            for _, conn in ipairs(connections) do
                pcall(function() conn:Disconnect() end)
            end
        end
    }
end

-- ============================================================================
-- getStats()
-- Get hatcher statistics
-- Returns: table with basic stats
-- ============================================================================
function EggHatcher:getStats()
    local readyCount = 0
    local readyEggs = self:findReadyEggs()
    readyCount = #readyEggs
    
    return {
        readyEggs = readyCount,
        hasHatchRemote = self._hatchRemote ~= nil,
        hasPlotsFolder = self._plotsFolder ~= nil,
    }
end

-- ============================================================================
-- cleanup()
-- Full cleanup - resets all state
-- Returns: nil
-- ============================================================================
function EggHatcher:cleanup()
    print("[EggHatcher] Cleaning up...")
    
    -- Disconnect all connections
    for _, connection in ipairs(self._connections) do
        local success, err = pcall(function()
            if connection and typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            end
        end)
    end
    self._connections = {}
    
    -- Reset state
    self._hatchRemote = nil
    self._plotsFolder = nil
    
    print("[EggHatcher] Cleanup complete")
end

-- ============================================================================
-- Module Export
-- ============================================================================
return {
    -- Lifecycle
    init = function(plotsFolder) return EggHatcher:init(plotsFolder) end,
    cleanup = function() return EggHatcher:cleanup() end,
    
    -- Configuration
    setPlotsFolder = function(folder) return EggHatcher:setPlotsFolder(folder) end,
    
    -- Core functions
    isEggReady = function(egg) return EggHatcher:isEggReady(egg) end,
    findReadyEggs = function() return EggHatcher:findReadyEggs() end,
    hatchEgg = function(egg, prompt) return EggHatcher:hatchEgg(egg, prompt) end,
    watchForReady = function(egg, cb) return EggHatcher:watchForReady(egg, cb) end,
    
    -- Status
    getStats = function() return EggHatcher:getStats() end,
}
