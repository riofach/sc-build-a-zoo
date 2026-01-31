-- Build A Zoo Script - Loader
-- Entry point for loadstring execution
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/riofach/sc-build-a-zoo/main/loader.lua"))()

local BASE_URL = "https://raw.githubusercontent.com/riofach/sc-build-a-zoo/main/"

local ModuleCache = {}

local function loadModule(path, maxRetries)
    maxRetries = maxRetries or 3
    
    -- Check cache first
    if ModuleCache[path] then
        return ModuleCache[path]
    end
    
    local retries = 0
    local lastError = nil
    
    repeat
        local fetchSuccess, source = pcall(function()
            return game:HttpGet(BASE_URL .. path .. ".lua")
        end)
        
        if fetchSuccess then
            local loadSuccess, module = pcall(function()
                return loadstring(source)()
            end)
            
            if loadSuccess then
                ModuleCache[path] = module
                return module
            else
                lastError = "Parse error: " .. tostring(module)
            end
        else
            lastError = "Fetch error: " .. tostring(source)
        end
        
        retries = retries + 1
        if retries < maxRetries then
            task.wait(2 ^ retries) -- Exponential backoff: 2s, 4s, 8s
        end
    until retries >= maxRetries
    
    warn("[Loader] Failed to load " .. path .. " after " .. maxRetries .. " attempts: " .. lastError)
    return nil
end

-- Load and initialize core modules
print("[Loader] Loading Build A Zoo Script...")

local CoreInit = loadModule("core/init")
local Core = nil

if CoreInit and type(CoreInit) == "function" then
    Core = CoreInit(loadModule)
else
    warn("[Loader] Failed to load core/init")
end

-- Load feature modules (explicit, not lazy)
local AutoCollect = loadModule("features/auto-collect")
local EggSystem = loadModule("features/egg-system")

-- Create Features table untuk UI
local Features = {
    ["auto-collect"] = AutoCollect,
    ["egg-system"] = EggSystem,
}

-- Load UI modules
local StatsTracker = loadModule("ui/stats-tracker")
local UIMain = loadModule("ui/main")

-- Expose StatsTracker globally untuk feature callbacks
_G.StatsTracker = StatsTracker

-- Initialize UI last (after feature modules ready)
local UI = nil
if UIMain and UIMain.init then
    local success, err = pcall(function()
        UIMain.init({
            Features = Features,
            StatsTracker = StatsTracker,
        })
    end)
    if success then
        print("[Loader] UI initialized")
        UI = UIMain
    else
        warn("[Loader] UI init failed: " .. tostring(err))
    end
else
    warn("[Loader] UI module not available")
end

if Core then
    print("[Loader] Build A Zoo Script loaded successfully!")
else
    warn("[Loader] Build A Zoo Script loaded with errors - some features may not work")
end

return {
    Core = Core,
    Features = Features,
    UI = UI,
    loadModule = loadModule
}
