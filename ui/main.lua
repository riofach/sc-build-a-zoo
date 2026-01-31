--[[
  ui/main.lua
  Rayfield UI implementation for Build A Zoo Auto-Farm
  
  Usage:
    local UI = require("ui/main")
    UI.init({
        Features = Features,  -- table with "auto-collect" and "egg-system" modules
        StatsTracker = StatsTracker  -- optional stats tracker module
    })
    UI.destroy()  -- cleanup when done
    
  Exports:
    init(deps), destroy()
    
  Rayfield Features:
    - ConfigurationSaving for persistent settings
    - 5 tabs: Collect, Eggs, Stats, Settings, About
    - Mobile-friendly toggle/slider/dropdown controls
    - Automatic thread management and cleanup
--]]

-- ============================================================================
-- Prevent Double-Loading (CRITICAL for Rayfield)
-- ============================================================================
if getgenv().BuildAZooLoaded then
    if Rayfield then
        pcall(function()
            Rayfield:Destroy()
        end)
    end
    task.wait(0.5)
end
getgenv().BuildAZooLoaded = true

-- ============================================================================
-- Load Rayfield UI Library
-- ============================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ============================================================================
-- Module State
-- ============================================================================
local UI = {
    _rayfield = Rayfield,
    _window = nil,
    _tabs = {},
    _elements = {},
    _threads = {},
    _features = nil,
    _statsTracker = nil,
}

-- Thread references for cleanup
local autoCollectThread = nil
local eggSystemThread = nil
local statsThread = nil

-- Element references for updates
local MoneyLabel = nil
local EggsLabel = nil
local StatusParagraph = nil

-- ============================================================================
-- Create Main Window
-- ============================================================================
local Window = Rayfield:CreateWindow({
    Name = "Build A Zoo Auto-Farm",
    Icon = 0,
    LoadingTitle = "Build A Zoo Script",
    LoadingSubtitle = "Loading...",
    Theme = "Default",
    ShowText = "☰",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BuildAZoo",
        FileName = "UIConfig"
    },
    KeySystem = false,
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
    Discord = { Enabled = false }
})

UI._window = Window

-- ============================================================================
-- Create 5 Tabs with Lucide Icons
-- ============================================================================
local TabCollect = Window:CreateTab("Collect", "coins")
local TabEggs = Window:CreateTab("Eggs", "egg")
local TabStats = Window:CreateTab("Stats", "bar-chart-2")
local TabSettings = Window:CreateTab("Settings", "settings")
local TabAbout = Window:CreateTab("About", "info")

UI._tabs = {
    Collect = TabCollect,
    Eggs = TabEggs,
    Stats = TabStats,
    Settings = TabSettings,
    About = TabAbout,
}

-- ============================================================================
-- Tab: Collect
-- ============================================================================

-- Auto-Collect Toggle (default ON per CONTEXT.md)
local AutoCollectToggle = TabCollect:CreateToggle({
    Name = "Auto-Collect",
    CurrentValue = true,
    Flag = "AutoCollect",
    Callback = function(Value)
        -- Stop existing thread first
        if autoCollectThread then
            pcall(function()
                task.cancel(autoCollectThread)
            end)
            autoCollectThread = nil
        end
        
        -- Stop feature if available
        if UI._features and UI._features["auto-collect"] then
            pcall(function()
                UI._features["auto-collect"].stop()
            end)
        end
        
        -- Start if toggled on
        if Value then
            if UI._features and UI._features["auto-collect"] then
                autoCollectThread = task.spawn(function()
                    pcall(function()
                        UI._features["auto-collect"].start()
                    end)
                end)
            end
        end
        
        print("[UI] Auto-Collect: " .. (Value and "ON" or "OFF"))
    end
})

UI._elements.AutoCollectToggle = AutoCollectToggle

-- Interval Slider
local IntervalSlider = TabCollect:CreateSlider({
    Name = "Collect Interval",
    Range = {1, 30},
    Increment = 1,
    Suffix = " seconds",
    CurrentValue = 5,
    Flag = "CollectInterval",
    Callback = function(Value)
        if UI._features and UI._features["auto-collect"] then
            pcall(function()
                if UI._features["auto-collect"].setConfig then
                    UI._features["auto-collect"].setConfig("cycleInterval", Value)
                end
            end)
        end
        print("[UI] Collect Interval: " .. Value .. "s")
    end
})

UI._elements.IntervalSlider = IntervalSlider

-- ============================================================================
-- Tab: Eggs
-- ============================================================================

-- Get egg types from config module
local EggTypeNames = {"Normal"}  -- Default fallback
local function loadEggTypes()
    local success, result = pcall(function()
        -- Try to load EggTypes module via _G loader
        if _G.loadModule then
            local EggTypes = _G.loadModule("config/egg-types")
            if EggTypes and EggTypes.getNames then
                return EggTypes.getNames()
            end
        end
        return nil
    end)
    
    if success and result and #result > 0 then
        EggTypeNames = result
    else
        -- Fallback: try direct require pattern
        local success2, result2 = pcall(function()
            local EggTypes = require(script.Parent.Parent:FindFirstChild("config"):FindFirstChild("egg-types"))
            if EggTypes and EggTypes.getNames then
                return EggTypes.getNames()
            end
            return nil
        end)
        
        if success2 and result2 and #result2 > 0 then
            EggTypeNames = result2
        else
            -- Hardcoded fallback
            EggTypeNames = {"Normal", "Shiny", "Electric", "Christmas", "Radioactive", "Mythic"}
        end
    end
end

loadEggTypes()

-- Mutation Dropdown (FIRST, before toggle)
local MutationDropdown = TabEggs:CreateDropdown({
    Name = "Mutation Type",
    Options = EggTypeNames,
    CurrentOption = {"Normal"},
    MultipleOptions = false,
    Flag = "MutationType",
    Callback = function(Options)
        local selected = Options[1] or "Normal"
        if UI._features and UI._features["egg-system"] then
            pcall(function()
                if UI._features["egg-system"].setTargetMutation then
                    UI._features["egg-system"].setTargetMutation(selected)
                end
            end)
        end
        print("[UI] Mutation Type: " .. selected)
    end
})

UI._elements.MutationDropdown = MutationDropdown

-- Egg System Toggle (default OFF per CONTEXT.md)
local EggSystemToggle = TabEggs:CreateToggle({
    Name = "Egg System",
    CurrentValue = false,
    Flag = "EggSystem",
    Callback = function(Value)
        -- Stop existing thread first
        if eggSystemThread then
            pcall(function()
                task.cancel(eggSystemThread)
            end)
            eggSystemThread = nil
        end
        
        -- Stop feature if available
        if UI._features and UI._features["egg-system"] then
            pcall(function()
                UI._features["egg-system"].stop()
            end)
        end
        
        -- Start if toggled on
        if Value then
            if UI._features and UI._features["egg-system"] then
                eggSystemThread = task.spawn(function()
                    pcall(function()
                        UI._features["egg-system"].start()
                    end)
                end)
            end
        end
        
        print("[UI] Egg System: " .. (Value and "ON" or "OFF"))
    end
})

UI._elements.EggSystemToggle = EggSystemToggle

-- ============================================================================
-- Tab: Stats
-- ============================================================================

MoneyLabel = TabStats:CreateLabel("Money Collected: 0", "coins")
EggsLabel = TabStats:CreateLabel("Eggs Hatched: 0", "egg")

UI._elements.MoneyLabel = MoneyLabel
UI._elements.EggsLabel = EggsLabel

-- Periodic stats update function
local function startStatsLoop()
    if statsThread then
        pcall(function()
            task.cancel(statsThread)
        end)
        statsThread = nil
    end
    
    statsThread = task.spawn(function()
        while true do
            local success, err = pcall(function()
                -- Get money stats
                local money = "0"
                if UI._statsTracker and UI._statsTracker.getFormattedMoney then
                    money = UI._statsTracker.getFormattedMoney()
                elseif UI._features and UI._features["auto-collect"] then
                    local stats = UI._features["auto-collect"].getStats()
                    if stats then
                        money = tostring(stats.totalCollected or 0)
                    end
                end
                
                -- Get eggs stats
                local eggs = "0"
                if UI._statsTracker and UI._statsTracker.getFormattedEggs then
                    eggs = UI._statsTracker.getFormattedEggs()
                elseif UI._features and UI._features["egg-system"] then
                    local stats = UI._features["egg-system"].getStats()
                    if stats then
                        eggs = tostring(stats.eggsHatched or 0)
                    end
                end
                
                -- Update labels (Labels require manual :Set() per RESEARCH.md)
                if MoneyLabel then
                    MoneyLabel:Set("Money Collected: " .. money, "coins")
                end
                if EggsLabel then
                    EggsLabel:Set("Eggs Hatched: " .. eggs, "egg")
                end
            end)
            
            if not success then
                warn("[UI] Stats update error: " .. tostring(err))
            end
            
            task.wait(3)  -- Update every 3 seconds
        end
    end)
    
    table.insert(UI._threads, statsThread)
end

-- ============================================================================
-- Tab: Settings - Debug Log
-- ============================================================================

-- Debug log storage
local DebugLogs = {}
local MaxLogs = 20

-- Global function to add debug log (accessible from other modules)
local function addDebugLog(message)
    table.insert(DebugLogs, 1, os.date("%H:%M:%S") .. " " .. tostring(message))
    if #DebugLogs > MaxLogs then
        table.remove(DebugLogs)
    end
end

-- Expose globally for other modules
_G.DebugLog = addDebugLog

-- Debug Paragraph
local DebugParagraph = TabSettings:CreateParagraph({
    Title = "Debug Log",
    Content = "Waiting for logs..."
})

UI._elements.DebugParagraph = DebugParagraph

-- Manual Discovery Button
TabSettings:CreateButton({
    Name = "Run Discovery (Debug)",
    Callback = function()
        addDebugLog("Running discovery...")
        
        -- Try to run discovery manually
        local success, result = pcall(function()
            if UI._features and UI._features["auto-collect"] then
                local discovery = UI._features["auto-collect"].getDiscovery()
                if discovery then
                    addDebugLog("Player folder: " .. (discovery.playerFolder and discovery.playerFolder.Name or "NOT FOUND"))
                    addDebugLog("Animals: " .. (discovery.animalCount or 0))
                    addDebugLog("Remote: " .. (discovery.collectRemote and discovery.collectRemote.Name or "NOT FOUND"))
                else
                    addDebugLog("Discovery not run yet, initializing...")
                    UI._features["auto-collect"].init()
                    local disc2 = UI._features["auto-collect"].getDiscovery()
                    if disc2 then
                        addDebugLog("Player folder: " .. (disc2.playerFolder and disc2.playerFolder.Name or "NOT FOUND"))
                        addDebugLog("Animals: " .. (disc2.animalCount or 0))
                        addDebugLog("Remote: " .. (disc2.collectRemote and disc2.collectRemote.Name or "NOT FOUND"))
                    end
                end
            else
                addDebugLog("auto-collect module not loaded")
            end
        end)
        
        if not success then
            addDebugLog("Error: " .. tostring(result))
        end
    end
})

-- Run Once Button
TabSettings:CreateButton({
    Name = "Collect Once (Test)",
    Callback = function()
        addDebugLog("Running single collect cycle...")
        
        local success, result = pcall(function()
            if UI._features and UI._features["auto-collect"] then
                local ok = UI._features["auto-collect"].runOnce()
                if ok then
                    addDebugLog("Collect cycle completed")
                    local stats = UI._features["auto-collect"].getStats()
                    if stats then
                        addDebugLog("Collected: " .. (stats.totalCollected or 0) .. ", Failed: " .. (stats.totalFailed or 0))
                    end
                else
                    addDebugLog("Collect cycle failed")
                end
            else
                addDebugLog("auto-collect module not loaded")
            end
        end)
        
        if not success then
            addDebugLog("Error: " .. tostring(result))
        end
    end
})

-- Debug log update loop
local debugThread = task.spawn(function()
    while true do
        if #DebugLogs > 0 then
            DebugParagraph:Set({
                Title = "Debug Log (" .. #DebugLogs .. ")",
                Content = table.concat(DebugLogs, "\n")
            })
        end
        task.wait(1)
    end
end)
table.insert(UI._threads, debugThread)

-- ============================================================================
-- Tab: About
-- ============================================================================

StatusParagraph = TabAbout:CreateParagraph({
    Title = "Script Status",
    Content = "Running"
})

UI._elements.StatusParagraph = StatusParagraph

TabAbout:CreateParagraph({
    Title = "Version",
    Content = "v1.0.0"
})

TabAbout:CreateParagraph({
    Title = "Credits",
    Content = "Build A Zoo Auto-Farm\nPowered by Rayfield UI"
})

-- ============================================================================
-- init(deps)
-- Initialize UI with feature dependencies
-- deps = { Features = {...}, StatsTracker = {...} }
-- Returns: boolean (success)
-- ============================================================================
function UI.init(deps)
    print("[UI] Initializing...")
    
    -- Store dependencies
    if deps then
        UI._features = deps.Features
        UI._statsTracker = deps.StatsTracker
    end
    
    -- Start stats update loop
    startStatsLoop()
    
    -- Load saved configuration (MUST be at end per RESEARCH.md)
    local success, err = pcall(function()
        Rayfield:LoadConfiguration()
    end)
    
    if not success then
        warn("[UI] Failed to load configuration: " .. tostring(err))
    end
    
    print("[UI] Initialized successfully")
    return true
end

-- ============================================================================
-- destroy()
-- Cleanup UI and all resources
-- Returns: nil
-- ============================================================================
function UI.destroy()
    print("[UI] Destroying...")
    
    -- Cancel all threads
    if autoCollectThread then
        pcall(function()
            task.cancel(autoCollectThread)
        end)
        autoCollectThread = nil
    end
    
    if eggSystemThread then
        pcall(function()
            task.cancel(eggSystemThread)
        end)
        eggSystemThread = nil
    end
    
    if statsThread then
        pcall(function()
            task.cancel(statsThread)
        end)
        statsThread = nil
    end
    
    -- Cancel stored threads
    for _, thread in ipairs(UI._threads) do
        pcall(function()
            task.cancel(thread)
        end)
    end
    UI._threads = {}
    
    -- Destroy Rayfield
    pcall(function()
        Rayfield:Destroy()
    end)
    
    -- Reset loaded flag
    getgenv().BuildAZooLoaded = false
    
    print("[UI] Destroyed")
end

-- ============================================================================
-- Module Export
-- ============================================================================
return {
    init = function(deps) return UI.init(deps) end,
    destroy = function() return UI.destroy() end,
}
