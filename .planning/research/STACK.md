# Technology Stack

**Project:** Build A Zoo Auto-Farm Script  
**Researched:** January 31, 2026  
**Overall Confidence:** MEDIUM-HIGH

---

## Executive Summary

This document defines the prescriptive technology stack for building a Roblox exploit script targeting "Build A Zoo" game, running on mobile via Delta Executor, hosted on GitHub, and loaded via `loadstring()`. The stack prioritizes Delta Executor compatibility, mobile UI/UX, and maintainable multi-file structure.

---

## Recommended Stack

### UI Library

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **Rayfield** | Latest (sirius.menu) | Primary UI framework | **Best mobile support**, actively maintained by Sirius team, built-in mobile toggle button (`ShowText`), configuration saving, Discord integration, Lucide icon support, comprehensive documentation at docs.sirius.menu. Most "Build A Zoo" scripts in the wild use Rayfield. | HIGH |

**Loadstring:**
```lua
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
```

**Rationale:**
- Native mobile toggle support (critical for Delta Executor on mobile)
- `ShowText` parameter for mobile users to unhide UI
- Active maintenance (docs updated 2025)
- Built-in key system support
- Configuration persistence (`ConfigurationSaving`)
- Lucide icon integration for polished UI
- Discord server join prompt support

### Alternative UI Libraries (NOT Recommended)

| Library | Why NOT to Use |
|---------|---------------|
| **Orion** | Older library (shlexware), less mobile optimization, fewer active updates. Loadstring: `loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()`. Only use if Rayfield fails. |
| **Fluent / Fluent-Renewed** | More complex setup, larger payload, better for PC-focused scripts. Overkill for simple auto-farm UI. |
| **Kavo** | Dated, minimal mobile support |
| **DrRay** | Niche, less community support |

---

### Discord Webhook Integration

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **Webhook Proxy** | lewisakura.moe | Route webhooks safely | Roblox blocks direct Discord API calls. Proxy replaces `discord.com` with `webhook.lewisakura.moe`. ToS compliant, rate-limit handling, widely used. | HIGH |

**Implementation Pattern:**
```lua
local HttpService = game:GetService("HttpService")

local function sendWebhook(webhookUrl, data)
    -- Replace discord.com with proxy
    local proxyUrl = webhookUrl:gsub("discord.com", "webhook.lewisakura.moe")
    
    local success, err = pcall(function()
        (syn and syn.request or http and http.request or request)({
            Url = proxyUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    return success, err
end
```

**Alternative Proxies:**
- `webhook.whitehill.group` (backup)

**Rationale:**
- Direct Discord webhooks blocked by Roblox HttpService
- Proxy is ToS compliant (confirmed by Discord staff)
- Built-in rate limiting prevents API abuse
- Simple URL replacement pattern

---

### Executor Target

| Executor | Version | Platform | Compatibility Notes | Confidence |
|----------|---------|----------|---------------------|------------|
| **Delta Executor** | v2.702+ (Jan 2026) | Android/iOS | Primary target. Mobile-first, keyless execution, supports standard exploit functions. Wide script compatibility. | HIGH |

**Delta Executor Supported Functions (Verified):**
- `loadstring()` - Core requirement
- `game:HttpGet()` / `game:HttpGetAsync()` - For loading remote scripts
- `getgenv()` / `setgenv()` - Global environment manipulation
- `request()` / `http.request()` - HTTP requests (webhook support)
- `writefile()` / `readfile()` / `isfile()` - File operations (config saving)
- `setclipboard()` - Clipboard access
- Standard Roblox services access

**NOT Guaranteed on Delta Mobile:**
- `syn.request()` - Use fallback pattern with `request()` or `http.request()`
- `hookfunction()` - May have limitations
- `debug` library extensions - Partial support

---

### Script Architecture

| Pattern | Purpose | Why | Confidence |
|---------|---------|-----|------------|
| **Single-entry loader** | GitHub hosting | One loadstring URL, loads modular components | HIGH |
| **Module pattern** | Code organization | Separate concerns: UI, features, utilities, config | HIGH |
| **getgenv() globals** | Cross-script state | Share state between loaded modules | HIGH |

**Recommended Project Structure:**
```
repository/
├── loader.lua           # Entry point (loadstring target)
├── src/
│   ├── main.lua         # Main orchestrator
│   ├── ui.lua           # Rayfield UI setup
│   ├── features/
│   │   ├── auto_collect.lua
│   │   ├── auto_buy_egg.lua
│   │   ├── auto_place_egg.lua
│   │   ├── auto_hatch.lua
│   │   └── webhook.lua
│   └── utils/
│       ├── http.lua     # HTTP wrapper with fallbacks
│       ├── player.lua   # Player utilities
│       └── game.lua     # Game-specific utilities
└── README.md
```

**Loader Pattern (loader.lua):**
```lua
-- loader.lua - Entry point
local baseUrl = "https://raw.githubusercontent.com/USERNAME/REPO/main/src/"

local function load(path)
    return loadstring(game:HttpGet(baseUrl .. path .. ".lua", true))()
end

-- Initialize global environment
getgenv().BuildAZoo = getgenv().BuildAZoo or {}
getgenv().BuildAZoo.load = load
getgenv().BuildAZoo.baseUrl = baseUrl

-- Load main script
load("main")
```

**Module Loading Pattern (main.lua):**
```lua
-- main.lua
local load = getgenv().BuildAZoo.load

-- Load utilities first
local Http = load("utils/http")
local PlayerUtils = load("utils/player")

-- Load UI
local UI = load("ui")

-- Load features
local AutoCollect = load("features/auto_collect")
local AutoBuyEgg = load("features/auto_buy_egg")
-- ... etc
```

---

### Core Dependencies

| Dependency | Source | Purpose | Confidence |
|------------|--------|---------|------------|
| **Rayfield UI** | `https://sirius.menu/rayfield` | User interface | HIGH |
| **Webhook Proxy** | `webhook.lewisakura.moe` | Discord integration | HIGH |

**No external Lua libraries needed** - All functionality achievable with:
- Roblox built-in services
- Executor-provided functions
- Rayfield UI library

---

### Game Services Required

```lua
-- Services used by Build A Zoo scripts
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Hardcoded webhook URLs in source** | Exposed in public repo | Use config file or obfuscation |
| **Direct discord.com calls** | Blocked by Roblox | Use webhook proxy |
| **Single monolithic script** | Hard to maintain, slow to load | Modular structure |
| **No error handling** | Silent failures confuse users | Wrap in pcall, notify errors |
| **Assuming syn functions** | Delta may not support all | Use fallback patterns |
| **Infinite loops without yields** | Crashes/freezes | Use `task.wait()` or `RunService.Heartbeat` |
| **Client-side RemoteEvent creation** | Won't work, server-only | Find and use existing remotes |
| **No toggle/kill switch** | Can't stop script | Always provide UI toggle |

---

## HTTP Request Fallback Pattern

Delta Executor compatibility requires fallback patterns:

```lua
-- utils/http.lua
local HttpService = game:GetService("HttpService")

local function makeRequest(options)
    local requestFunc = syn and syn.request 
        or http and http.request 
        or request 
        or http_request
        or fluxus and fluxus.request
    
    if not requestFunc then
        warn("[HTTP] No request function available")
        return nil
    end
    
    local success, result = pcall(function()
        return requestFunc(options)
    end)
    
    if success then
        return result
    else
        warn("[HTTP] Request failed:", result)
        return nil
    end
end

return {
    request = makeRequest,
    get = function(url)
        return makeRequest({
            Url = url,
            Method = "GET"
        })
    end,
    post = function(url, body, headers)
        return makeRequest({
            Url = url,
            Method = "POST",
            Headers = headers or {["Content-Type"] = "application/json"},
            Body = type(body) == "table" and HttpService:JSONEncode(body) or body
        })
    end
}
```

---

## Configuration Saving Pattern

For persistent settings across sessions:

```lua
-- Using Rayfield's built-in config
local Window = Rayfield:CreateWindow({
    Name = "Build A Zoo",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BuildAZoo",
        FileName = "config"
    }
})

-- Or manual file-based config
local function saveConfig(data)
    if writefile then
        writefile("BuildAZoo_config.json", HttpService:JSONEncode(data))
    end
end

local function loadConfig()
    if isfile and isfile("BuildAZoo_config.json") then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile("BuildAZoo_config.json"))
        end)
        if success then return data end
    end
    return {} -- defaults
end
```

---

## GitHub Hosting Requirements

| Requirement | Implementation |
|-------------|---------------|
| **Raw file access** | Use `https://raw.githubusercontent.com/USER/REPO/BRANCH/path` |
| **Cache busting** | Add `?t=` .. tick() or version parameter |
| **HTTPS only** | GitHub raw URLs are HTTPS by default |
| **Public repo** | Required for loadstring access |

**Loadstring URL Pattern:**
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/USERNAME/build-a-zoo-script/main/loader.lua"))()
```

---

## Mobile UI Considerations

For Delta Executor on mobile:

1. **Use Rayfield's ShowText** - Provides touch-friendly toggle button
2. **Large touch targets** - Buttons should be easy to tap
3. **Minimize text input** - Use toggles/dropdowns over text fields
4. **Notification feedback** - Use `Rayfield:Notify()` for status updates
5. **Consider screen real estate** - Mobile screens are smaller

```lua
local Window = Rayfield:CreateWindow({
    Name = "Build A Zoo",
    ShowText = "Zoo", -- Mobile toggle button text
    -- ...
})
```

---

## Version Compatibility

| Component | Minimum Version | Notes |
|-----------|-----------------|-------|
| Delta Executor | v2.689+ | Tested with v2.702 (Jan 2026) |
| Rayfield | Latest | Auto-updated via loadstring |
| Roblox Client | Current | Delta handles client updates |

---

## Sources

| Source | Type | Confidence |
|--------|------|------------|
| https://docs.sirius.menu/rayfield | Official Docs | HIGH |
| https://webhook.lewisakura.moe | Official Proxy | HIGH |
| https://github.com/ActualMasterOogway/Fluent-Renewed | GitHub | MEDIUM |
| https://rscripts.net (Build A Zoo scripts) | Community | MEDIUM |
| https://arceusx.com/build-a-zoo-script/ | Community | MEDIUM |
| https://deltaaxecutor.com | Executor Info | MEDIUM |
| YouTube tutorials (2025-2026) | Community | LOW-MEDIUM |

---

## Summary Decision Matrix

| Category | Choice | Rationale |
|----------|--------|-----------|
| **UI Library** | Rayfield | Best mobile support, active maintenance |
| **Webhook** | lewisakura.moe proxy | ToS compliant, reliable |
| **Executor** | Delta Executor | Mobile-first, wide compatibility |
| **Structure** | Modular loader pattern | Maintainable, cacheable |
| **Hosting** | GitHub raw | Free, reliable, simple |

---

## Quick Start Template

```lua
-- loader.lua (entry point for loadstring)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Build A Zoo Script",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by YourName",
    ShowText = "Zoo", -- Mobile toggle
    Theme = "Default",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BuildAZoo",
        FileName = "settings"
    }
})

local MainTab = Window:CreateTab("Main", "home")
local SettingsTab = Window:CreateTab("Settings", "settings")

-- Feature toggles
local autoCollect = false

MainTab:CreateToggle({
    Name = "Auto Collect",
    CurrentValue = false,
    Flag = "AutoCollect",
    Callback = function(Value)
        autoCollect = Value
    end,
})

-- Main loop
task.spawn(function()
    while task.wait(0.5) do
        if autoCollect then
            -- Auto collect logic here
        end
    end
end)

Rayfield:LoadConfiguration()
```

---

## Open Questions for Phase-Specific Research

1. **Game-specific remotes**: Need to research actual RemoteEvent/RemoteFunction names in Build A Zoo
2. **Anti-cheat detection**: May need to research game's anti-cheat mechanisms
3. **Webhook payload structure**: Define exact embed format for Discord notifications
4. **Egg placement coordinates**: May need to map valid placement positions
