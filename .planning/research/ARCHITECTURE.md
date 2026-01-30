# Architecture Patterns: Roblox Exploit Scripts

**Domain:** Roblox Auto-Farm Script (Build A Zoo)  
**Platform:** Mobile (Delta Executor)  
**Researched:** 2026-01-31  
**Overall Confidence:** MEDIUM (based on ecosystem patterns from GitHub repositories and community sources)

---

## Executive Summary

Roblox exploit scripts follow a distinctive architecture pattern driven by two key constraints:
1. **Loadstring Entry Point** - Scripts must be loadable via a single `loadstring(game:HttpGet(...))()` call
2. **Client-Side Only** - All execution happens on the client; server interaction is via RemoteEvents

The architecture must balance simplicity (single-file execution) with maintainability (component separation). For a Build A Zoo auto-farm script with webhook integration, a **Hybrid Single-File with Lazy-Loaded Modules** approach is recommended.

---

## Recommended Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ENTRY POINT (loader.lua)                     │
│  loadstring(game:HttpGet("https://raw.githubusercontent.com/..."))()│
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          MAIN SCRIPT (main.lua)                     │
│  - Version check                                                    │
│  - Configuration loading                                            │
│  - Component initialization                                         │
│  - Main loop orchestration                                          │
└─────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        ▼                           ▼                           ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│   UI Module   │          │  Core Logic   │          │   Services    │
│  (Rayfield)   │◄────────►│   Module      │◄────────►│    Module     │
└───────────────┘          └───────────────┘          └───────────────┘
        │                           │                           │
        │                           ▼                           │
        │                  ┌───────────────┐                    │
        │                  │    Config     │                    │
        │                  │    Module     │                    │
        │                  └───────────────┘                    │
        │                           │                           │
        └───────────────────────────┼───────────────────────────┘
                                    ▼
                          ┌───────────────┐
                          │   Webhook     │
                          │   Module      │
                          └───────────────┘
                                    │
                                    ▼
                          ┌───────────────┐
                          │   Discord     │
                          │   (External)  │
                          └───────────────┘
```

---

## Component Boundaries

| Component | Responsibility | Communicates With | File |
|-----------|---------------|-------------------|------|
| **Loader** | Entry point, version check, loads main script | GitHub Raw → Main | `loader.lua` |
| **Main** | Orchestration, initialization, main loop | All components | `main.lua` |
| **Config** | Settings storage, defaults, persistence | Main, UI, Core | `modules/config.lua` |
| **UI** | User interface (Rayfield), toggle controls | Main, Config, Core | `modules/ui.lua` |
| **Core** | Auto-farm logic, game interaction | Config, Services, Webhook | `modules/core.lua` |
| **Services** | Roblox service wrappers, RemoteEvent handling | Core | `modules/services.lua` |
| **Webhook** | Discord notification, embed formatting | Core, Config | `modules/webhook.lua` |

---

## Data Flow

### 1. Initialization Flow
```
User executes loadstring
    │
    ▼
Loader fetches main.lua from GitHub
    │
    ▼
Main loads Config (defaults + saved settings)
    │
    ▼
Main initializes Services (game references)
    │
    ▼
Main initializes UI (Rayfield window)
    │
    ▼
Main starts Core logic loops
    │
    ▼
Webhook sends "Script Started" notification
```

### 2. Auto-Farm Runtime Flow
```
┌─────────────────────────────────────────────────────────────────┐
│                        MAIN LOOP                                 │
│  while Config.Enabled do                                        │
│      if Config.AutoBuyEgg then Core:BuyEgg() end                │
│      if Config.AutoPlaceEgg then Core:PlaceEgg() end            │
│      if Config.AutoHatch then Core:Hatch() end                  │
│      if Config.AutoCollect then Core:CollectMoney() end         │
│      task.wait(Config.LoopDelay)                                │
│  end                                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CORE ACTIONS                                │
│  Core:BuyEgg()                                                   │
│      └─► Services:FireRemote("BuyEgg", eggType)                 │
│      └─► Webhook:Log("Bought egg: " .. eggType)                 │
│                                                                  │
│  Core:PlaceEgg()                                                │
│      └─► Services:FindIncubator()                               │
│      └─► Services:FireRemote("PlaceEgg", incubatorId)           │
│                                                                  │
│  Core:Hatch()                                                   │
│      └─► Services:FindReadyEggs()                               │
│      └─► Services:FireRemote("Hatch", eggId)                    │
│      └─► Webhook:Log("Hatched: " .. petName)                    │
│                                                                  │
│  Core:CollectMoney()                                            │
│      └─► Services:FindMoneyDrops()                              │
│      └─► Player teleport/touch simulation                       │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Configuration Flow
```
UI Toggle Changed
    │
    ▼
Config:Set(key, value)
    │
    ├─► Update runtime config table
    │
    └─► Persist to executor filesystem (if available)
            │
            ▼
        writefile("BuildAZoo_Config.json", ...)
```

### 4. Webhook Flow
```
Event occurs (egg hatched, rare pet, error)
    │
    ▼
Webhook:Send(eventType, data)
    │
    ▼
Format Discord embed
    │
    ▼
request({
    Url = Config.WebhookURL,
    Method = "POST",
    Headers = {["Content-Type"] = "application/json"},
    Body = HttpService:JSONEncode(embed)
})
    │
    ▼
Discord channel receives notification
```

---

## File/Module Organization for GitHub

### Recommended Repository Structure

```
sc-build-a-zoo/
├── loader.lua              # Minimal entry point for loadstring
├── main.lua                # Main orchestration script
├── modules/
│   ├── config.lua          # Configuration management
│   ├── ui.lua              # Rayfield UI setup
│   ├── core.lua            # Auto-farm logic
│   ├── services.lua        # Roblox service wrappers
│   └── webhook.lua         # Discord webhook integration
├── .planning/              # Project planning files
└── README.md               # Usage instructions
```

### Loadstring Entry Point Pattern

**loader.lua** (what users execute):
```lua
-- Build A Zoo Script by [Author]
-- Version check and main loader

local HttpService = game:GetService("HttpService")
local BASE_URL = "https://raw.githubusercontent.com/[user]/sc-build-a-zoo/main/"

-- Load main script
loadstring(game:HttpGet(BASE_URL .. "main.lua"))()
```

**main.lua** (orchestration):
```lua
-- Main orchestration script
local HttpService = game:GetService("HttpService")
local BASE_URL = "https://raw.githubusercontent.com/[user]/sc-build-a-zoo/main/"

-- Module loader helper
local function LoadModule(name)
    return loadstring(game:HttpGet(BASE_URL .. "modules/" .. name .. ".lua"))()
end

-- Load all modules
local Config = LoadModule("config")
local Services = LoadModule("services")
local Webhook = LoadModule("webhook")
local UI = LoadModule("ui")
local Core = LoadModule("core")

-- Initialize
Config:Init()
Services:Init()
Webhook:Init(Config)
UI:Init(Config, Core)
Core:Init(Config, Services, Webhook)

-- Start main loop
Core:Start()
```

---

## Patterns to Follow

### Pattern 1: Service Caching
**What:** Cache Roblox service references at script start  
**When:** Always - reduces repeated GetService calls  
**Example:**
```lua
-- services.lua
local Services = {}

-- Cache services once
Services.Players = game:GetService("Players")
Services.Workspace = game:GetService("Workspace")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.HttpService = game:GetService("HttpService")
Services.TweenService = game:GetService("TweenService")
Services.RunService = game:GetService("RunService")

-- Cache player references
Services.LocalPlayer = Services.Players.LocalPlayer
Services.Character = Services.LocalPlayer.Character or Services.LocalPlayer.CharacterAdded:Wait()

return Services
```

### Pattern 2: RemoteEvent Discovery
**What:** Dynamically find and cache RemoteEvents  
**When:** Game structure may change between updates  
**Example:**
```lua
-- services.lua
function Services:FindRemotes()
    self.Remotes = {}
    
    -- Common locations for RemoteEvents
    local locations = {
        self.ReplicatedStorage,
        self.ReplicatedStorage:FindFirstChild("Remotes"),
        self.ReplicatedStorage:FindFirstChild("Events"),
        self.Workspace:FindFirstChild("Remotes"),
    }
    
    for _, location in ipairs(locations) do
        if location then
            for _, child in ipairs(location:GetDescendants()) do
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    self.Remotes[child.Name] = child
                end
            end
        end
    end
end

function Services:FireRemote(name, ...)
    local remote = self.Remotes[name]
    if remote then
        if remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(...)
        end
    else
        warn("[Services] Remote not found: " .. name)
    end
end
```

### Pattern 3: Rayfield UI Integration
**What:** Use Rayfield UI library for clean, mobile-friendly interface  
**When:** Always for user-facing scripts  
**Example:**
```lua
-- ui.lua
local UI = {}

function UI:Init(Config, Core)
    -- Load Rayfield
    local Rayfield = loadstring(game:HttpGet(
        "https://sirius.menu/rayfield"
    ))()
    
    -- Create window
    local Window = Rayfield:CreateWindow({
        Name = "Build A Zoo Script",
        LoadingTitle = "Loading...",
        LoadingSubtitle = "by [Author]",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "BuildAZoo",
            FileName = "Config"
        }
    })
    
    -- Main tab
    local MainTab = Window:CreateTab("Main", 4483362458)
    
    -- Auto-farm toggles
    MainTab:CreateToggle({
        Name = "Auto Buy Egg",
        CurrentValue = Config.AutoBuyEgg,
        Callback = function(value)
            Config:Set("AutoBuyEgg", value)
        end
    })
    
    MainTab:CreateToggle({
        Name = "Auto Place Egg",
        CurrentValue = Config.AutoPlaceEgg,
        Callback = function(value)
            Config:Set("AutoPlaceEgg", value)
        end
    })
    
    -- Settings tab
    local SettingsTab = Window:CreateTab("Settings", 4483362458)
    
    SettingsTab:CreateInput({
        Name = "Webhook URL",
        PlaceholderText = "Discord Webhook URL",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            Config:Set("WebhookURL", text)
        end
    })
    
    self.Window = Window
    self.Rayfield = Rayfield
end

return UI
```

### Pattern 4: Request Function Compatibility
**What:** Handle different executor request implementations  
**When:** Supporting multiple executors (Delta, Synapse, etc.)  
**Example:**
```lua
-- webhook.lua
local Webhook = {}

-- Get compatible request function
local request = (syn and syn.request) 
    or (http and http.request) 
    or http_request 
    or request 
    or HttpPost

function Webhook:Send(title, description, color)
    if not self.Config.WebhookURL or self.Config.WebhookURL == "" then
        return
    end
    
    local embed = {
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = description,
            ["color"] = color or 5814783,
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            ["footer"] = {
                ["text"] = "Build A Zoo Script"
            }
        }}
    }
    
    pcall(function()
        request({
            Url = self.Config.WebhookURL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = game:GetService("HttpService"):JSONEncode(embed)
        })
    end)
end

return Webhook
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Blocking Main Thread
**What:** Using `wait()` or long loops without yielding  
**Why bad:** Causes UI freezing, especially on mobile  
**Instead:** Use `task.wait()` and break long operations into chunks

```lua
-- BAD
for i = 1, 1000 do
    -- process item
    wait(0.1)  -- deprecated, can cause issues
end

-- GOOD
for i = 1, 1000 do
    -- process item
    task.wait(0.1)  -- modern, more reliable
    if i % 100 == 0 then
        task.wait()  -- yield to prevent freezing
    end
end
```

### Anti-Pattern 2: Hardcoded Game References
**What:** Assuming exact paths to game objects  
**Why bad:** Breaks when game updates change structure  
**Instead:** Use FindFirstChild with fallbacks, discovery patterns

```lua
-- BAD
local buyRemote = game.ReplicatedStorage.Remotes.BuyEgg

-- GOOD
local function FindRemote(name)
    local locations = {
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"),
        game:GetService("ReplicatedStorage"):FindFirstChild("Events"),
    }
    
    for _, loc in ipairs(locations) do
        if loc then
            local remote = loc:FindFirstChild(name, true)
            if remote then return remote end
        end
    end
    return nil
end

local buyRemote = FindRemote("BuyEgg")
```

### Anti-Pattern 3: No Error Handling
**What:** Calling game APIs without pcall  
**Why bad:** Script crashes on any error  
**Instead:** Wrap risky operations in pcall

```lua
-- BAD
remote:FireServer(data)

-- GOOD
local success, err = pcall(function()
    remote:FireServer(data)
end)

if not success then
    warn("[Core] Remote failed: " .. tostring(err))
end
```

### Anti-Pattern 4: Monolithic Single File
**What:** Putting everything in one 2000+ line file  
**Why bad:** Impossible to maintain, debug, or update  
**Instead:** Use modular structure with lazy loading

---

## Mobile-Specific Considerations

### 1. Touch-Friendly UI
- Rayfield is mobile-optimized by default
- Use larger touch targets for buttons
- Minimize number of tabs/elements
- Consider a minimize/toggle button for screen real estate

### 2. Performance Optimization
```lua
-- Reduce loop frequency on mobile
local LOOP_DELAY = 0.5  -- Desktop: 0.1, Mobile: 0.5

-- Limit concurrent operations
local MAX_CONCURRENT_ACTIONS = 3  -- Desktop: 10, Mobile: 3

-- Disable heavy features by default
Config.Defaults = {
    AutoCollect = true,   -- Lightweight
    AutoBuyEgg = true,    -- Lightweight
    AutoHatch = true,     -- Moderate
    AutoPlaceEgg = false, -- Can be heavy
}
```

### 3. Delta Executor Specifics
- Delta uses "Gloop" execution engine
- Supports `request()` for HTTP calls
- Supports `writefile()`/`readfile()` for persistence
- Full UNC (Unified Naming Convention) support
- May have slight delays vs PC executors

### 4. Memory Management
```lua
-- Clean up connections when script stops
local connections = {}

function Core:Start()
    table.insert(connections, RunService.Heartbeat:Connect(function()
        -- main loop logic
    end))
end

function Core:Stop()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
end
```

---

## Build Order (Dependencies)

Based on component dependencies, the recommended implementation order:

```
Phase 1: Foundation
├── 1.1 Config module (no dependencies)
├── 1.2 Services module (depends on Config for settings)
└── 1.3 Webhook module (depends on Config for URL)

Phase 2: Core Logic
├── 2.1 Core module - basic structure
├── 2.2 Core module - game discovery (find RemoteEvents)
├── 2.3 Core module - auto-collect money
├── 2.4 Core module - auto-buy egg
├── 2.5 Core module - auto-place egg
└── 2.6 Core module - auto-hatch

Phase 3: User Interface
├── 3.1 UI module - Rayfield setup
├── 3.2 UI module - main controls tab
├── 3.3 UI module - settings tab
└── 3.4 UI module - webhook configuration

Phase 4: Integration
├── 4.1 Main orchestration script
├── 4.2 Loader entry point
├── 4.3 Webhook notifications for key events
└── 4.4 Error handling and recovery

Phase 5: Polish
├── 5.1 Mobile optimization
├── 5.2 Performance tuning
├── 5.3 Config persistence
└── 5.4 Documentation
```

### Dependency Graph

```
Config ◄────────────────────────────────────────┐
   │                                             │
   ▼                                             │
Services ◄───────────┐                           │
   │                 │                           │
   ▼                 │                           │
Webhook ◄────────────┼───────────────────────────┤
   │                 │                           │
   ▼                 │                           │
Core ◄───────────────┘                           │
   │                                             │
   ▼                                             │
UI ◄─────────────────────────────────────────────┘
   │
   ▼
Main (Loader)
```

---

## Interacting with Roblox Game Objects

### Key Services for Build A Zoo

| Service | Purpose | Common Use |
|---------|---------|------------|
| `Players` | Access LocalPlayer | Get player character, stats |
| `Workspace` | Game world objects | Find eggs, incubators, money |
| `ReplicatedStorage` | Shared data/remotes | Fire RemoteEvents |
| `HttpService` | JSON encoding | Webhook payloads |
| `TweenService` | Smooth animations | Teleport animations |
| `RunService` | Game loops | Heartbeat for main loop |

### RemoteEvent Patterns for Auto-Farm Games

```lua
-- Common remote patterns to look for:
-- Buy/Purchase
game.ReplicatedStorage.Remotes.BuyEgg:FireServer(eggType)
game.ReplicatedStorage.Events.Purchase:FireServer(itemId)

-- Collect/Claim
game.ReplicatedStorage.Remotes.Collect:FireServer(objectId)
game.ReplicatedStorage.Events.ClaimReward:FireServer()

-- Hatch/Open
game.ReplicatedStorage.Remotes.Hatch:FireServer(eggId)
game.ReplicatedStorage.Events.OpenEgg:FireServer(eggId)

-- Place/Use
game.ReplicatedStorage.Remotes.Place:FireServer(itemId, position)
```

### Finding Game-Specific Remotes

```lua
-- Discovery script (run first to find remotes)
for _, v in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
        print(v:GetFullName(), v.ClassName)
    end
end
```

---

## Sources

| Source | Type | Confidence |
|--------|------|------------|
| GitHub: depthso/RBX-Exploit-Classes | Repository | MEDIUM |
| GitHub: Rokuu010/Roblox-Exploit-Script | Repository | MEDIUM |
| docs.sirius.menu/rayfield | Official Docs | HIGH |
| GitHub: lilyscripts/webhook-builder | Repository | MEDIUM |
| GitHub: modynem/Rohook | Repository | MEDIUM |
| Community Build A Zoo scripts | Various | LOW |
| Delta Executor documentation | Official | MEDIUM |
| Roblox Creator Hub | Official Docs | HIGH |

---

## Quality Gate Checklist

- [x] Components clearly defined with boundaries
- [x] Data flow direction explicit  
- [x] Build order implications noted
- [x] Mobile-specific considerations included
- [x] RemoteEvent interaction patterns documented
- [x] Loadstring entry point pattern explained
