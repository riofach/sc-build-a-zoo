-- core/init.lua
-- Core module aggregator
-- Loads all core modules and returns them as a single table

-- Note: This file is loaded via the loader's loadModule function
-- Services, Timing, and Config are loaded here to ensure correct order

return function(loadModule)
    local Core = {}
    
    print("[Core] Initializing core modules...")
    
    -- Load in dependency order
    Core.Services = loadModule("core/services")
    if not Core.Services then
        warn("[Core] Failed to load Services - critical error")
        return nil
    end
    
    Core.Timing = loadModule("core/timing")
    if not Core.Timing then
        warn("[Core] Failed to load Timing")
    end
    
    Core.Config = loadModule("core/config")
    if not Core.Config then
        warn("[Core] Failed to load Config")
    else
        -- Auto-load settings on init
        Core.Config:Load()
    end
    
    Core.Money = loadModule("core/money")
    if not Core.Money then
        warn("[Core] Failed to load Money")
    end
    
    print("[Core] Core modules initialized")
    
    return Core
end
