-- core/config.lua
-- Configuration management with JSON persistence

local HttpService = game:GetService("HttpService")

local Config = {}

-- File paths
local FOLDER = "BuildAZoo"
local SETTINGS_FILE = FOLDER .. "/settings.json"

-- Default settings (sensible defaults - works out of box)
Config.Defaults = {
    -- Feature toggles (all off by default - user enables via UI)
    AutoCollect = false,
    AutoBuyEgg = false,
    AutoPlaceEgg = false,
    AutoHatch = false,
    
    -- Timing settings
    TimingVariance = 0.2, -- 20% variance (within 10-30% range)
    
    -- Discord webhook
    WebhookURL = "",
    WebhookEnabled = false,
    WebhookInterval = 300, -- 5 minutes
    
    -- Egg preferences (to be populated in Phase 3)
    SelectedEggType = "",
    EggPriority = {}
}

-- Current settings (initialized from defaults)
Config.Settings = {}
for key, value in pairs(Config.Defaults) do
    Config.Settings[key] = value
end

-- Ensure folder exists
local function ensureFolder()
    local success = pcall(function()
        if not isfolder(FOLDER) then
            makefolder(FOLDER)
        end
    end)
    return success
end

-- Save current settings to file
function Config:Save()
    if not ensureFolder() then
        warn("[Config] Failed to create folder")
        return false
    end
    
    local success = pcall(function()
        local encoded = HttpService:JSONEncode(self.Settings)
        writefile(SETTINGS_FILE, encoded)
    end)
    
    if success then
        print("[Config] Settings saved")
    else
        warn("[Config] Failed to save settings")
    end
    
    return success
end

-- Load settings from file (merge with defaults)
function Config:Load()
    -- Check if file exists
    local fileExists = pcall(function()
        return isfile(SETTINGS_FILE)
    end)
    
    if not fileExists or not isfile(SETTINGS_FILE) then
        print("[Config] No settings file found, using defaults")
        self:Save() -- Create default file
        return true
    end
    
    -- Read and parse file
    local readSuccess, content = pcall(readfile, SETTINGS_FILE)
    if not readSuccess then
        warn("[Config] Failed to read settings file")
        return false
    end
    
    local decodeSuccess, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    
    if not decodeSuccess or type(data) ~= "table" then
        warn("[Config] Failed to parse settings file, using defaults")
        return false
    end
    
    -- Merge: load saved values, preserve new defaults
    -- This ensures forward compatibility when we add new settings
    for key, value in pairs(data) do
        if self.Defaults[key] ~= nil then
            -- Only load known keys (ignore obsolete settings)
            self.Settings[key] = value
        end
    end
    
    print("[Config] Settings loaded")
    return true
end

-- Get a setting value
function Config:Get(key)
    return self.Settings[key]
end

-- Set a setting value and optionally save
function Config:Set(key, value, autoSave)
    if self.Defaults[key] == nil then
        warn("[Config] Unknown setting: " .. tostring(key))
        return false
    end
    
    self.Settings[key] = value
    
    if autoSave then
        self:Save()
    end
    
    return true
end

-- Reset to defaults
function Config:Reset()
    for key, value in pairs(self.Defaults) do
        self.Settings[key] = value
    end
    self:Save()
    print("[Config] Settings reset to defaults")
end

return Config
