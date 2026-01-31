-- Build A Zoo Script - Loader
-- Entry point for loadstring execution
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/loader.lua"))()

-- UPDATE THIS to your actual GitHub repository URL
local BASE_URL = "https://raw.githubusercontent.com/USER/REPO/main/"

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

-- Load core modules upfront (order matters)
print("[Loader] Loading core modules...")
local Services = loadModule("core/services")

-- Placeholder for Config and Timing (Plan 02)
-- local Config = loadModule("core/config")
-- local Timing = loadModule("core/timing")

-- Lazy-load features via metatable (prevents timeout)
local Features = setmetatable({}, {
    __index = function(t, key)
        print("[Loader] Lazy loading feature: " .. key)
        local module = loadModule("features/" .. key)
        t[key] = module
        return module
    end
})

-- Placeholder for UI module (Phase 4)
-- local UI = loadModule("ui/main")

print("[Loader] Build A Zoo Script loaded successfully!")

return {
    Services = Services,
    Features = Features,
    loadModule = loadModule -- Expose for dynamic loading
}
