--[[
  features/plot-manager.lua
  Manages player plots - detection of empty plots and egg placement
  
  Usage:
    local PlotManager = require("features/plot-manager")
    PlotManager.init()
    local plot, prompt = PlotManager.findEmptyPlot()
    if plot then
        PlotManager.placeEgg(plot, prompt)
    end
    
  Exports:
    init, findEmptyPlot, placeEgg, getPlotStatus, hasEmptyPlot
    
  Plot detection patterns:
    - workspace.Plots.[PlayerName]
    - workspace.Tycoons.[PlayerName]
    - workspace.[PlayerName].Plots
    - workspace.PlayerZoos.[PlayerName]
--]]

-- Get services (cached for security)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Module State
local PlotManager = {
    _playerPlots = nil,       -- Instance, folder containing player's plots
    _placeRemote = nil,       -- Instance, cached RemoteEvent for place
    _connections = {},        -- table, for cleanup
}

-- Common place RemoteEvent patterns
local PLACE_REMOTE_PATTERNS = {
    "PlaceEgg",
    "Place",
    "AddEgg",
    "Deposit",
    "StartIncubation",
    "IncubateEgg",
    "PlaceOnPlot",
    "PutEgg",
    "SetEgg",
    "Remotes.PlaceEgg",
    "Remotes.Place",
    "Events.PlaceEgg",
    "Events.Place",
}

-- Common plot folder patterns (relative to workspace)
local PLOT_FOLDER_PATTERNS = {
    "Plots.%s",               -- workspace.Plots.[PlayerName]
    "Tycoons.%s",             -- workspace.Tycoons.[PlayerName]
    "%s.Plots",               -- workspace.[PlayerName].Plots
    "PlayerZoos.%s",          -- workspace.PlayerZoos.[PlayerName]
    "Zoo.%s.Plots",           -- workspace.Zoo.[PlayerName].Plots
    "Map.Plots.%s",           -- workspace.Map.Plots.[PlayerName]
    "Map.Tycoons.%s",         -- workspace.Map.Tycoons.[PlayerName]
    "PlayerAreas.%s",         -- workspace.PlayerAreas.[PlayerName]
    "%s",                     -- workspace.[PlayerName] (direct)
}

-- ============================================================================
-- _discoverPlayerPlots()
-- Try to find the player's plots folder in workspace
-- Returns: Instance or nil
-- ============================================================================
local function discoverPlayerPlots()
    local success, result = pcall(function()
        local LocalPlayer = Players.LocalPlayer
        if not LocalPlayer then return nil end
        
        local playerName = LocalPlayer.Name
        local userId = tostring(LocalPlayer.UserId)
        
        -- Try each pattern with both playerName and userId
        local searchTerms = {playerName, userId}
        
        for _, term in ipairs(searchTerms) do
            for _, pattern in ipairs(PLOT_FOLDER_PATTERNS) do
                local path = string.format(pattern, term)
                local parts = string.split(path, ".")
                local current = Workspace
                
                for _, part in ipairs(parts) do
                    local child = current:FindFirstChild(part)
                    if child then
                        current = child
                    else
                        current = nil
                        break
                    end
                end
                
                if current and current ~= Workspace then
                    -- Validate it looks like a plots folder
                    local hasPlotChildren = false
                    for _, child in ipairs(current:GetChildren()) do
                        -- Check if children look like plots
                        if child:IsA("Model") or child:IsA("Part") or child:IsA("BasePart") then
                            hasPlotChildren = true
                            break
                        end
                    end
                    
                    if hasPlotChildren or #current:GetChildren() == 0 then
                        print("[PlotManager] Found player plots at: " .. current:GetFullName())
                        return current
                    end
                end
            end
        end
        
        -- Fallback: search workspace for any folder with player's name
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                if string.find(child.Name, playerName) or string.find(child.Name, userId) then
                    print("[PlotManager] Found player area via search: " .. child:GetFullName())
                    return child
                end
            end
        end
        
        return nil
    end)
    
    if success then
        return result
    else
        warn("[PlotManager] Discovery failed: " .. tostring(result))
        return nil
    end
end

-- ============================================================================
-- _discoverPlaceRemote()
-- Find the RemoteEvent used for placing eggs on plots
-- Returns: Instance or nil
-- ============================================================================
local function discoverPlaceRemote()
    local success, result = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        
        -- Check common patterns in ReplicatedStorage
        for _, pattern in ipairs(PLACE_REMOTE_PATTERNS) do
            -- Handle nested paths like "Remotes.PlaceEgg"
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
                print("[PlotManager] Found place remote at: " .. current:GetFullName())
                return current
            end
        end
        
        -- Fallback: search ReplicatedStorage for any remote containing "place" or "incubat"
        local function searchFolder(folder)
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    local nameLower = string.lower(child.Name)
                    if string.find(nameLower, "place") or 
                       string.find(nameLower, "incubat") or
                       string.find(nameLower, "deposit") or
                       string.find(nameLower, "setegg") then
                        print("[PlotManager] Found place remote via search: " .. child:GetFullName())
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
        warn("[PlotManager] Remote discovery failed: " .. tostring(result))
        return nil
    end
end

-- ============================================================================
-- init()
-- Initialize the plot manager module
-- Returns: boolean (success)
-- ============================================================================
function PlotManager:init()
    print("[PlotManager] Initializing...")
    
    -- Discover player plots folder
    self._playerPlots = discoverPlayerPlots()
    if not self._playerPlots then
        warn("[PlotManager] Player plots folder not found - will retry on demand")
    end
    
    -- Discover place RemoteEvent
    self._placeRemote = discoverPlaceRemote()
    if not self._placeRemote then
        warn("[PlotManager] Place remote not found - will retry on demand")
    end
    
    print("[PlotManager] Initialized successfully")
    print("[PlotManager] - Plots folder: " .. (self._playerPlots and self._playerPlots.Name or "NOT FOUND"))
    print("[PlotManager] - Place remote: " .. (self._placeRemote and self._placeRemote.Name or "NOT FOUND"))
    
    return true
end

-- ============================================================================
-- findEmptyPlot()
-- Find an empty plot that can receive an egg
-- Returns: plot Instance, prompt Instance (or nil, nil)
-- ============================================================================
function PlotManager:findEmptyPlot()
    -- Retry discovery if needed
    if not self._playerPlots then
        self._playerPlots = discoverPlayerPlots()
        if not self._playerPlots then
            return nil, nil
        end
    end
    
    local success, plot, prompt = pcall(function()
        for _, plotObj in ipairs(self._playerPlots:GetChildren()) do
            -- Method A: ProximityPrompt "Place" that is enabled
            local proximityPrompt = plotObj:FindFirstChildOfClass("ProximityPrompt")
            if proximityPrompt and proximityPrompt.Enabled then
                local actionText = string.lower(proximityPrompt.ActionText or "")
                if string.find(actionText, "place") or 
                   string.find(actionText, "incubat") or
                   string.find(actionText, "add") then
                    return plotObj, proximityPrompt
                end
            end
            
            -- Method B: No Egg/Animal child
            local hasEgg = plotObj:FindFirstChild("Egg") or 
                           plotObj:FindFirstChild("Animal") or
                           plotObj:FindFirstChild("Incubating")
            
            if not hasEgg then
                -- Check descendants too
                local hasEggDescendant = false
                for _, desc in ipairs(plotObj:GetDescendants()) do
                    if desc:IsA("Model") then
                        local nameLower = string.lower(desc.Name)
                        if string.find(nameLower, "egg") or string.find(nameLower, "animal") then
                            hasEggDescendant = true
                            break
                        end
                    end
                end
                
                if not hasEggDescendant then
                    -- Method C: Check Occupied attribute
                    local occupied = plotObj:GetAttribute("Occupied")
                    local isEmpty = plotObj:GetAttribute("IsEmpty")
                    local hasEggAttr = plotObj:GetAttribute("HasEgg")
                    
                    -- Plot is empty if: Occupied is false/nil, or IsEmpty is true, or HasEgg is false
                    if occupied == false or occupied == nil then
                        if isEmpty ~= false and hasEggAttr ~= true then
                            -- Found empty plot
                            local foundPrompt = plotObj:FindFirstChildOfClass("ProximityPrompt")
                            return plotObj, foundPrompt
                        end
                    end
                end
            end
        end
        
        return nil, nil
    end)
    
    if success then
        return plot, prompt
    else
        warn("[PlotManager] findEmptyPlot failed: " .. tostring(plot))
        return nil, nil
    end
end

-- ============================================================================
-- placeEgg(plot, prompt)
-- Place an egg onto the specified plot
-- Returns: boolean success
-- ============================================================================
function PlotManager:placeEgg(plot, prompt)
    local success, result = pcall(function()
        -- Method A: Use ProximityPrompt if available
        if prompt and prompt:IsA("ProximityPrompt") then
            if fireproximityprompt then
                fireproximityprompt(prompt)
                print("[PlotManager] Placed egg via ProximityPrompt on: " .. plot.Name)
                return true
            end
        end
        
        -- Method B: Use RemoteEvent
        if not self._placeRemote then
            self._placeRemote = discoverPlaceRemote()
        end
        
        if self._placeRemote then
            -- Try different argument patterns
            local patterns = {
                -- Pattern 1: Fire with plot instance
                function()
                    if self._placeRemote:IsA("RemoteEvent") then
                        self._placeRemote:FireServer(plot)
                    else
                        self._placeRemote:InvokeServer(plot)
                    end
                    return true
                end,
                -- Pattern 2: Fire with plot name
                function()
                    if self._placeRemote:IsA("RemoteEvent") then
                        self._placeRemote:FireServer(plot.Name)
                    else
                        self._placeRemote:InvokeServer(plot.Name)
                    end
                    return true
                end,
                -- Pattern 3: Fire with plot ID attribute
                function()
                    local plotId = plot:GetAttribute("Id") or plot:GetAttribute("PlotId")
                    if plotId then
                        if self._placeRemote:IsA("RemoteEvent") then
                            self._placeRemote:FireServer(plotId)
                        else
                            self._placeRemote:InvokeServer(plotId)
                        end
                        return true
                    end
                    return false
                end,
                -- Pattern 4: Fire without arguments
                function()
                    if self._placeRemote:IsA("RemoteEvent") then
                        self._placeRemote:FireServer()
                    else
                        self._placeRemote:InvokeServer()
                    end
                    return true
                end,
            }
            
            for _, tryPattern in ipairs(patterns) do
                local patternSuccess, patternResult = pcall(tryPattern)
                if patternSuccess and patternResult then
                    print("[PlotManager] Placed egg via RemoteEvent on: " .. plot.Name)
                    return true
                end
            end
        end
        
        -- Method C: Try touching the plot (some games use touch to place)
        local LocalPlayer = Players.LocalPlayer
        if LocalPlayer and LocalPlayer.Character then
            local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                -- Find a touchable part on the plot
                local touchPart = nil
                for _, child in ipairs(plot:GetDescendants()) do
                    if child:IsA("BasePart") then
                        touchPart = child
                        break
                    end
                end
                
                if touchPart and firetouchinterest then
                    firetouchinterest(rootPart, touchPart, 0)
                    task.wait(0.1)
                    firetouchinterest(rootPart, touchPart, 1)
                    print("[PlotManager] Placed egg via touch on: " .. plot.Name)
                    return true
                end
            end
        end
        
        return false
    end)
    
    if success then
        return result
    else
        warn("[PlotManager] placeEgg failed: " .. tostring(result))
        return false
    end
end

-- ============================================================================
-- getPlotStatus()
-- Get status of all plots
-- Returns: table {total, empty, occupied}
-- ============================================================================
function PlotManager:getPlotStatus()
    local status = {
        total = 0,
        empty = 0,
        occupied = 0,
    }
    
    -- Retry discovery if needed
    if not self._playerPlots then
        self._playerPlots = discoverPlayerPlots()
        if not self._playerPlots then
            return status
        end
    end
    
    local success, result = pcall(function()
        for _, plotObj in ipairs(self._playerPlots:GetChildren()) do
            status.total = status.total + 1
            
            -- Check if occupied
            local hasEgg = plotObj:FindFirstChild("Egg") or 
                           plotObj:FindFirstChild("Animal") or
                           plotObj:FindFirstChild("Incubating")
            
            local occupied = plotObj:GetAttribute("Occupied")
            local hasEggAttr = plotObj:GetAttribute("HasEgg")
            
            if hasEgg or occupied == true or hasEggAttr == true then
                status.occupied = status.occupied + 1
            else
                -- Check for egg in descendants
                local hasEggDescendant = false
                for _, desc in ipairs(plotObj:GetDescendants()) do
                    if desc:IsA("Model") then
                        local nameLower = string.lower(desc.Name)
                        if string.find(nameLower, "egg") or string.find(nameLower, "animal") then
                            hasEggDescendant = true
                            break
                        end
                    end
                end
                
                if hasEggDescendant then
                    status.occupied = status.occupied + 1
                else
                    status.empty = status.empty + 1
                end
            end
        end
    end)
    
    if not success then
        warn("[PlotManager] getPlotStatus failed: " .. tostring(result))
    end
    
    return status
end

-- ============================================================================
-- hasEmptyPlot()
-- Quick check if any empty plot is available
-- Returns: boolean
-- ============================================================================
function PlotManager:hasEmptyPlot()
    local plot, _ = self:findEmptyPlot()
    return plot ~= nil
end

-- ============================================================================
-- cleanup()
-- Full cleanup - resets all state
-- Returns: nil
-- ============================================================================
function PlotManager:cleanup()
    print("[PlotManager] Cleaning up...")
    
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
    self._playerPlots = nil
    self._placeRemote = nil
    
    print("[PlotManager] Cleanup complete")
end

-- ============================================================================
-- Module Export
-- ============================================================================
return {
    -- Lifecycle
    init = function() return PlotManager:init() end,
    cleanup = function() return PlotManager:cleanup() end,
    
    -- Core functions
    findEmptyPlot = function() return PlotManager:findEmptyPlot() end,
    placeEgg = function(plot, prompt) return PlotManager:placeEgg(plot, prompt) end,
    
    -- Status
    getPlotStatus = function() return PlotManager:getPlotStatus() end,
    hasEmptyPlot = function() return PlotManager:hasEmptyPlot() end,
}
