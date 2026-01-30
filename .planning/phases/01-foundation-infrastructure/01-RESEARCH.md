# Phase 1: Foundation & Infrastructure - Research

**Researched:** 2026-01-31
**Domain:** Roblox Luau Exploit Script Architecture (GitHub-hosted, Delta Executor)
**Confidence:** MEDIUM-HIGH

## Summary

This phase establishes the foundational architecture for a Roblox exploit script targeting Build A Zoo, hosted on GitHub and compatible with Delta Executor on mobile. The research covers six key domains: loadstring module loading patterns, Delta Executor compatibility, randomized timing for anti-detection, service access patterns, configuration storage, and error handling.

The standard approach for 2025-2026 involves:
1. A single loadstring entry point that fetches a bootstrapper/loader from GitHub raw URLs
2. The loader then fetches individual modules from organized subfolders (core/, features/, ui/)
3. Settings stored via JSON files in the executor's workspace folder
4. Randomized timing using Gaussian distribution for human-like delays (not uniform random)
5. All services cached at script top using `game:GetService()` for security and performance
6. Isolated error handling with pcall/xpcall, exponential backoff for retries, and task.spawn for module isolation

**Primary recommendation:** Use upfront loading for core modules (loader, config, timing) but lazy loading (via metatables) for features to minimize boot time and executor timeout risks.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rayfield UI | Latest (sirius.menu) | GUI framework | Mobile-optimized, built-in config saving, notifications, actively maintained |
| Luau/Lua 5.1 | Roblox standard | Scripting language | Only option for Roblox exploit scripts |

### Supporting

| Library | Purpose | When to Use |
|---------|---------|-------------|
| HttpService (JSONEncode/JSONDecode) | Config serialization | Saving/loading settings to JSON files |
| game:HttpGet() | Fetch external scripts | Loading modules from GitHub raw URLs |
| writefile/readfile/isfile | Local storage | Persisting user settings between sessions |

### GitHub Hosting

| Approach | When to Use | Why |
|----------|-------------|-----|
| GitHub raw URLs | Development | Easy updates, version control |
| Commit hash URLs | Production releases | Prevents breaking changes from affecting users |
| jsDelivr CDN | High-scale deployment | Better rate limits, caching |

**Loadstring URL Format:**
```lua
-- Development (mutable)
"https://raw.githubusercontent.com/User/Repo/main/loader.lua"

-- Production (immutable - use commit hash)
"https://raw.githubusercontent.com/User/Repo/abc123def/loader.lua"
```

## Architecture Patterns

### Recommended Project Structure

```
sc-build-a-zoo/
├── loader.lua           # Entry point - loadstring fetches this first
├── core/
│   ├── init.lua         # Core initialization, service caching
│   ├── config.lua       # Configuration management (load/save)
│   ├── timing.lua       # Randomized timing utilities
│   └── services.lua     # Cached service references
├── features/
│   ├── auto-collect.lua # Auto-collect feature module
│   ├── auto-hatch.lua   # Auto-hatch feature module
│   └── webhook.lua      # Discord webhook integration
└── ui/
    └── main.lua         # Rayfield UI setup
```

### Pattern 1: Bootstrapper Loader

**What:** Single entry point that fetches and initializes all modules in correct order
**When to use:** Always - this is the standard for modular exploit scripts

```lua
-- loader.lua (Entry point)
local BASE_URL = "https://raw.githubusercontent.com/User/Repo/main/"

local function loadModule(path)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. path .. ".lua"))()
    end)
    if not success then
        warn("[Loader] Failed to load " .. path .. ": " .. tostring(result))
        return nil
    end
    return result
end

-- Load core modules upfront
local Config = loadModule("core/config")
local Timing = loadModule("core/timing")
local Services = loadModule("core/services")

-- Lazy-load features via metatable
local Features = setmetatable({}, {
    __index = function(t, key)
        local module = loadModule("features/" .. key)
        t[key] = module
        return module
    end
})

-- Initialize UI last
local UI = loadModule("ui/main")

return {
    Config = Config,
    Timing = Timing,
    Services = Services,
    Features = Features,
    UI = UI
}
```

### Pattern 2: Randomized Timing with Gaussian Distribution

**What:** Human-like delays using Box-Muller transform for bell-curve distribution
**When to use:** All automated actions to avoid detection

```lua
-- core/timing.lua
local Timing = {}

-- Gaussian random using Box-Muller transform
function Timing.gaussianRandom(mean, stdDev)
    local u1 = math.random()
    local u2 = math.random()
    local z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)
    return z0 * stdDev + mean
end

-- Get delay with variance (10-30% as specified in requirements)
-- variance: 0.1 to 0.3 (10% to 30%)
function Timing.getDelay(baseDelay, variancePercent)
    variancePercent = variancePercent or 0.2 -- Default 20%
    local stdDev = baseDelay * variancePercent / 2 -- ~95% within variance range
    local delay = Timing.gaussianRandom(baseDelay, stdDev)
    return math.max(0.1, delay) -- Never go below 0.1s
end

-- Convenience wrapper that waits
function Timing.wait(baseDelay, variancePercent)
    task.wait(Timing.getDelay(baseDelay, variancePercent))
end

return Timing
```

### Pattern 3: Service Caching

**What:** Cache all Roblox services at script start for security and performance
**When to use:** Always - at the very top of scripts before any task.wait()

```lua
-- core/services.lua
local Services = {}

-- Cache immediately on load (before any yields)
Services.Players = game:GetService("Players")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.HttpService = game:GetService("HttpService")
Services.RunService = game:GetService("RunService")
Services.TweenService = game:GetService("TweenService")
Services.UserInputService = game:GetService("UserInputService")
Services.Workspace = game:GetService("Workspace")

-- Derived references
Services.LocalPlayer = Services.Players.LocalPlayer

return Services
```

### Pattern 4: Configuration Storage

**What:** JSON-based settings with merge loading for forward compatibility
**When to use:** For persisting user preferences between sessions

```lua
-- core/config.lua
local HttpService = game:GetService("HttpService")

local Config = {}
local FOLDER = "BuildAZoo"
local FILE = FOLDER .. "/settings.json"

-- Default settings
Config.Settings = {
    AutoCollect = false,
    AutoHatch = false,
    TimingVariance = 0.2,
    WebhookURL = "",
    EggPriority = {}
}

function Config:Save()
    if not isfolder(FOLDER) then makefolder(FOLDER) end
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(self.Settings)
    end)
    if success then
        writefile(FILE, encoded)
    end
end

function Config:Load()
    if not isfile(FILE) then
        self:Save() -- Create default
        return
    end
    
    local success, content = pcall(readfile, FILE)
    if not success then return end
    
    local decodeSuccess, data = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    
    if decodeSuccess and type(data) == "table" then
        -- Merge: preserve new defaults, load saved values
        for key, value in pairs(data) do
            if self.Settings[key] ~= nil then
                self.Settings[key] = value
            end
        end
    end
end

return Config
```

### Anti-Patterns to Avoid

- **Using `game.Players` instead of `game:GetService("Players")`:** Can be spoofed by exploiters or renamed by anti-cheat
- **Using `wait()` instead of `task.wait()`:** Deprecated, less precise, throttled by scheduler
- **Using uniform `math.random()` for timing:** Easily detected by pattern analysis; use Gaussian
- **Loading all modules upfront:** Risk of executor timeout; use lazy loading for features
- **Not wrapping external calls in pcall:** Single failure crashes entire script
- **Overwriting config table on load:** Loses new settings added in updates; use merge pattern

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UI Framework | Custom ScreenGui system | Rayfield UI | Mobile-optimized, config saving, notifications, key system, actively maintained |
| JSON handling | String parsing/building | HttpService:JSONEncode/JSONDecode | Battle-tested, handles edge cases |
| Random delays | Simple `math.random()` range | Gaussian distribution (Box-Muller) | Uniform distribution is detectable; Gaussian mimics human behavior |
| File existence check | try/catch readfile | `isfile()` function | Cleaner, standard API |
| Module fetching | Inline HttpGet everywhere | Centralized loadModule function | Error handling, caching, single point of change |

**Key insight:** The Roblox exploit ecosystem has mature solutions for common problems. Custom solutions introduce bugs that the community has already solved and create compatibility issues with executors.

## Common Pitfalls

### Pitfall 1: Executor Timeout on Large Loads
**What goes wrong:** Script attempts to load 20+ modules upfront, executor kills the thread after 5-10 seconds
**Why it happens:** Executors have built-in timeouts to prevent hanging; HttpGet has latency
**How to avoid:** Use lazy loading for features; only load core modules upfront
**Warning signs:** Script "silently fails" or partially loads on first execution

### Pitfall 2: Config File Corruption
**What goes wrong:** User manually edits JSON, introduces syntax error, script crashes on load
**Why it happens:** JSONDecode throws an error on malformed input
**How to avoid:** Wrap ALL file operations in pcall; fall back to defaults on parse failure
**Warning signs:** Script worked yesterday, crashes today without code changes

### Pitfall 3: Detection via Timing Patterns
**What goes wrong:** Account gets flagged/banned despite "random" delays
**Why it happens:** Uniform random still produces detectable patterns; perfect average over time
**How to avoid:** Use Gaussian distribution; add "drift" over time; include occasional "micro-pauses" (3-7s every few minutes)
**Warning signs:** Shadow-bans (reduced drops), delayed account termination

### Pitfall 4: Service Access After Yield
**What goes wrong:** `game:GetService()` returns unexpected/hooked result
**Why it happens:** Other scripts can hook the environment during yields
**How to avoid:** Cache ALL services at the very top of script, before any `task.wait()` or other yields
**Warning signs:** Errors about nil service references; unexpected behavior

### Pitfall 5: Module Loading Order Dependencies
**What goes wrong:** Module A requires Module B, but B isn't loaded yet
**Why it happens:** Lazy loading with circular dependencies
**How to avoid:** Core modules load upfront in explicit order; features should be self-contained or use dependency injection
**Warning signs:** "Attempt to index nil" errors on first use of a feature

### Pitfall 6: Delta Executor Update Downtime
**What goes wrong:** Script stops working after Roblox update
**Why it happens:** Delta needs 24-48 hours to update after Roblox client updates
**How to avoid:** Build graceful degradation; script should not crash even if APIs change
**Warning signs:** All Delta scripts broken simultaneously

## Code Examples

### Complete Module Loading with Error Handling

```lua
-- Source: WebSearch patterns verified across multiple sources
local HttpService = game:GetService("HttpService")
local BASE_URL = "https://raw.githubusercontent.com/User/Repo/main/"

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
```

### Isolated Feature Execution

```lua
-- Source: WebSearch patterns for error isolation
local function runFeature(name, func)
    task.spawn(function()
        local success, err = xpcall(func, function(e)
            warn("[" .. name .. "] Error: " .. tostring(e))
            print(debug.traceback())
        end)
        
        if success then
            print("[" .. name .. "] Started successfully")
        else
            -- Notify user via Rayfield
            Rayfield:Notify({
                Title = "Feature Error",
                Content = name .. " failed to start. Check console.",
                Duration = 5,
                Image = "alert-circle"
            })
        end
    end)
end

-- Usage
runFeature("AutoCollect", function()
    -- Feature code here
end)
```

### Rayfield UI with Config Integration

```lua
-- Source: https://docs.sirius.menu/rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Build A Zoo Script",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Developer",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BuildAZoo",
        FileName = "RayfieldConfig"
    },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", "home")

local AutoCollectToggle = MainTab:CreateToggle({
    Name = "Auto Collect",
    CurrentValue = false,
    Flag = "AutoCollect", -- Unique flag for config saving
    Callback = function(Value)
        Config.Settings.AutoCollect = Value
        Config:Save()
        if Value then
            Features["auto-collect"]:Start()
        else
            Features["auto-collect"]:Stop()
        end
    end
})

-- Load saved configuration at the end
Rayfield:LoadConfiguration()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `wait()` | `task.wait()` | 2022+ | More precise timing, not throttled |
| `game.Service` | `game:GetService()` | Always preferred | Security against renaming/spoofing |
| Uniform random | Gaussian distribution | 2024+ (detection evolution) | Better anti-detection |
| Single monolithic script | Modular loader architecture | 2023+ | Easier updates, better stability |
| Manual UI building | Rayfield/similar libraries | 2022+ | Mobile support, less code, more features |
| Main branch URLs | Commit hash URLs | 2024+ (reliability focus) | Prevents breaking changes |

**Deprecated/outdated:**
- `wait()`: Use `task.wait()` instead
- `spawn()`: Use `task.spawn()` instead
- `delay()`: Use `task.delay()` instead
- Old Rayfield GitHub (jensonhirst): Archived Nov 2024; use sirius.menu

## Delta Executor Specifics

### Supported Functions (Verified 2025)

| Function | Status | Notes |
|----------|--------|-------|
| `loadstring()` | Supported | Core functionality |
| `game:HttpGet()` | Supported | For fetching external scripts |
| `writefile()` | Supported | Saves to Delta/workspace |
| `readfile()` | Supported | Reads from Delta/workspace |
| `isfile()` | Supported | Check file existence |
| `isfolder()` | Supported | Check folder existence |
| `makefolder()` | Supported | Create directories |
| `listfiles()` | Supported | List directory contents |
| `appendfile()` | Supported | Append to existing file |
| `delfile()` | Supported | Delete files |
| `task.wait()` | Supported | Preferred over wait() |
| `task.spawn()` | Supported | Preferred over spawn() |
| `HttpService:JSONEncode/JSONDecode` | Supported | Via game:GetService |

### Known Limitations

1. **Update Downtime:** 24-48 hours after Roblox updates
2. **Android 15/16 Issues:** May have permission issues on newest Android
3. **Hyperion Detection:** Increasing risk of bans in 2025-2026
4. **Performance:** Mobile device limitations; avoid heavy loops

### Recommendations for Delta

1. Keep scripts lightweight (lazy load features)
2. Test on actual mobile device, not just emulator
3. Use graceful degradation for unsupported features
4. Store settings in simple JSON (no complex nested structures)
5. Minimize continuous loops; use events where possible

## Open Questions

1. **Exact Delta UNC compatibility level**
   - What we know: Core filesystem functions supported
   - What's unclear: Full UNC compatibility percentage; some advanced functions may vary
   - Recommendation: Test on actual Delta before relying on advanced executor functions

2. **Build A Zoo specific API**
   - What we know: Standard Roblox game with ReplicatedStorage remotes
   - What's unclear: Specific remote names, anti-cheat measures
   - Recommendation: Defer to Phase 2 research; use game inspection

3. **Rayfield config interaction with our custom config**
   - What we know: Rayfield has built-in ConfigurationSaving; we also have custom Config
   - What's unclear: Best way to synchronize or separate concerns
   - Recommendation: Use Rayfield's built-in saving for UI state (toggle values), custom config for script-specific data (webhook URL, egg priorities)

## Sources

### Primary (HIGH confidence)
- https://docs.sirius.menu/rayfield - Official Rayfield documentation (verified current)
- https://github.com/SiriusSoftwareLtd/Rayfield - Current Rayfield repository

### Secondary (MEDIUM confidence)
- WebSearch: "Roblox loadstring GitHub raw URL module loader pattern 2025" - Multiple sources agree on patterns
- WebSearch: "Delta Executor writefile readfile isfile supported functions" - Consistent across sources
- WebSearch: "Roblox exploit settings storage writefile readfile pcall pattern" - Standard pattern confirmed
- WebSearch: "Roblox game:GetService pattern best practices" - Consistent recommendations

### Tertiary (LOW confidence)
- WebSearch: "Roblox Luau randomized timing anti-detection" - Patterns logical but detection methods proprietary
- WebSearch: "Delta Executor mobile compatibility limitations 2025" - Fast-moving target, may change

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Rayfield verified via official docs; core patterns consistent across sources
- Architecture: MEDIUM-HIGH - Patterns consistent across multiple sources; tested in exploit community
- Pitfalls: MEDIUM - Based on community experience; some may be outdated or game-specific
- Delta specifics: MEDIUM - Executor capabilities can change with updates

**Research date:** 2026-01-31
**Valid until:** 2026-02-28 (30 days - executor ecosystem moves fast, revalidate before major changes)
