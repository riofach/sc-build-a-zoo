# Phase 3: Egg System - Research

**Researched:** 2026-01-31
**Domain:** Roblox Egg System Automation (Buy, Place, Hatch)
**Confidence:** MEDIUM

## Summary

Phase 3 mengimplementasikan **complete egg loop**: monitor conveyor untuk mutasi target → auto-buy saat uang cukup → auto-place ke plot kosong → auto-hatch saat egg ready. Research ini fokus pada lima area utama:

1. **Conveyor Egg Detection** - Cara mendeteksi egg di conveyor dan membaca nama mutasi via BillboardGui/TextLabel
2. **Money Detection** - Pattern untuk membaca saldo player (leaderstats, PlayerGui, Attributes)
3. **Empty Plot Detection** - Cara menemukan plot kosong dan mendeteksi contextual "Place" button
4. **Ready Egg Detection** - Pattern untuk mendeteksi egg yang siap hatch (visual indicator atau Attribute)
5. **Buy/Place/Hatch RemoteEvents** - Pattern untuk menemukan dan memanggil RemoteEvent yang tepat

**Temuan kunci:** 
- Conveyor eggs paling reliable dideteksi via `DescendantAdded` event + `BillboardGui.TextLabel.Text` untuk nama mutasi
- Money detection prioritas: `leaderstats` > `PlayerGui` scan > `Player:GetAttribute()`
- Empty plot detection via `ProximityPrompt.Enabled` atau absence of child object "Egg"
- Hatch ready detection via `GetAttribute("Ready")` atau visual indicator (Highlight/BillboardGui)
- Anti-detection WAJIB: timing variance 10-30%, jitter pada semua actions, pre-check sebelum fire remote

**Primary recommendation:** Gunakan event-based detection (`DescendantAdded`, `GetAttributeChangedSignal`) daripada polling loops untuk efisiensi. Wrap semua game interaction dalam pcall. Pre-validate conditions (uang cukup, plot kosong) sebelum fire RemoteEvent untuk menghindari "failed request spam" yang mudah terdeteksi.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| core/timing.lua | Phase 1 | Randomized delays dengan Gaussian distribution | Sudah diimplementasi, human-like timing |
| core/services.lua | Phase 1 | Service caching yang aman dari hooking | Security pattern dari Phase 1 |
| features/game-discovery.lua | Phase 2 | Player folder dan RemoteEvent discovery | Pattern established di Phase 2 |
| SimpleSpy | Latest | RemoteEvent argument discovery | Industry standard untuk menemukan remotes |

### Supporting

| Library | Purpose | When to Use |
|---------|---------|-------------|
| ProximityPromptService | Global detection untuk Place/Hatch prompts | Mendeteksi contextual actions |
| firetouchinterest | Simulate proximity touch | Fallback jika ProximityPrompt tidak ter-fire |
| fireproximityprompt | Trigger ProximityPrompt langsung | Primary method untuk Place/Hatch |
| CollectionService | Tag-based object finding | Jika game menggunakan tags untuk eggs/plots |

### Delta Executor Functions

| Function | Status | Purpose |
|----------|--------|---------|
| `fireproximityprompt(prompt)` | Supported | Trigger ProximityPrompt tanpa proximity |
| `firetouchinterest(part1, part2, state)` | Supported | Simulate Touched event |
| `getconnections(event)` | Supported | Get existing connections untuk UI buttons |
| `getgenv()` | Supported | Global environment untuk toggle flags |

## Architecture Patterns

### Recommended Module Structure

```
features/
├── egg-system.lua           # Main orchestration module
│   ├── init(deps)           # Setup, discover game structure
│   ├── start()              # Start egg loop
│   ├── stop()               # Stop loop, cleanup
│   └── cleanup()            # Full cleanup
├── conveyor-monitor.lua     # Monitor conveyor untuk target mutation
│   ├── setTargetMutation()  # Set mutasi yang dicari
│   ├── onEggDetected()      # Callback saat egg target muncul
│   └── getConveyorEggs()    # List current eggs di conveyor
├── egg-buyer.lua            # Auto-buy logic
│   ├── canAfford(eggPrice)  # Check uang cukup
│   ├── buyEgg(egg)          # Execute purchase
│   └── isHoldingEgg()       # Check sudah pegang egg
├── plot-manager.lua         # Plot detection dan placement
│   ├── findEmptyPlot()      # Find first empty plot
│   ├── placeEgg(plot)       # Place egg ke plot
│   └── getPlotStatus()      # Overview semua plots
└── egg-hatcher.lua          # Hatch ready detection
    ├── findReadyEggs()      # Find eggs ready to hatch
    ├── hatchEgg(egg)        # Execute hatch
    └── onEggReady()         # Callback untuk auto-hatch
```

### Pattern 1: Conveyor Egg Detection via DescendantAdded

**What:** Monitor conveyor area untuk egg baru, baca nama mutasi dari BillboardGui
**When to use:** Detecting eggs saat muncul di conveyor
**Confidence:** HIGH (verified dari WebSearch + Roblox patterns)

```lua
-- Source: WebSearch verified pattern 2025
local ConveyorMonitor = {
    _targetMutation = nil,
    _connections = {},
    _conveyorPath = nil, -- workspace.Conveyor atau sejenisnya
}

function ConveyorMonitor:init(conveyorPath)
    self._conveyorPath = conveyorPath
end

function ConveyorMonitor:setTargetMutation(mutationName)
    self._targetMutation = mutationName
end

function ConveyorMonitor:start(onEggCallback)
    -- Scan existing eggs
    for _, obj in ipairs(self._conveyorPath:GetDescendants()) do
        self:_checkEgg(obj, onEggCallback)
    end
    
    -- Listen for new eggs
    local conn = self._conveyorPath.DescendantAdded:Connect(function(descendant)
        self:_checkEgg(descendant, onEggCallback)
    end)
    table.insert(self._connections, conn)
end

function ConveyorMonitor:_checkEgg(obj, callback)
    -- Skip non-eggs
    if not obj:IsA("Model") then return end
    
    task.spawn(function()
        -- Wait for BillboardGui to load (StreamingEnabled)
        local billboard = obj:WaitForChild("BillboardGui", 3)
        if not billboard then return end
        
        local textLabel = billboard:FindFirstChildOfClass("TextLabel")
        if not textLabel then return end
        
        local mutationName = textLabel.Text
        
        -- Check if matches target
        if self._targetMutation and mutationName:lower():find(self._targetMutation:lower()) then
            callback(obj, mutationName)
        end
    end)
end

function ConveyorMonitor:stop()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    self._connections = {}
end
```

### Pattern 2: Money Detection (Multi-Source)

**What:** Detect player money dari multiple possible locations
**When to use:** Pre-check sebelum buy egg
**Confidence:** HIGH (standard Roblox pattern)

```lua
-- Source: WebSearch verified pattern 2025
local function getPlayerMoney()
    local player = Services.LocalPlayer
    
    -- Priority 1: leaderstats (most common)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local moneyNames = {"Cash", "Money", "Coins", "Gold", "Credits", "Balance", "Bucks"}
        for _, name in ipairs(moneyNames) do
            local currency = leaderstats:FindFirstChild(name)
            if currency and currency:IsA("ValueBase") then
                return currency.Value, currency
            end
        end
    end
    
    -- Priority 2: Player Attributes
    local attributes = player:GetAttributes()
    for name, value in pairs(attributes) do
        if type(value) == "number" and (
            name:lower():find("money") or 
            name:lower():find("cash") or
            name:lower():find("coin")
        ) then
            return value, nil
        end
    end
    
    -- Priority 3: PlayerGui scan (fallback)
    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        for _, v in ipairs(playerGui:GetDescendants()) do
            if v:IsA("TextLabel") or v:IsA("TextBox") then
                -- Look for "$" or currency pattern
                local text = v.Text
                if text:find("$") or v.Name:lower():find("money") then
                    -- Extract number from text
                    local num = tonumber(text:gsub("[^%d]", ""))
                    if num then
                        return num, v
                    end
                end
            end
        end
    end
    
    return 0, nil
end
```

### Pattern 3: Empty Plot Detection

**What:** Find empty plots untuk place egg
**When to use:** Setelah buy egg, cari tempat untuk place
**Confidence:** MEDIUM (perlu validate dengan game sebenarnya)

```lua
-- Source: WebSearch verified pattern 2025
local PlotManager = {
    _playerPlots = nil, -- Folder containing player's plots
}

function PlotManager:init()
    -- Discovery: Find player's plot area
    local player = Services.LocalPlayer
    local workspace = Services.Workspace
    
    local plotPatterns = {
        workspace:FindFirstChild("Plots") and 
            workspace.Plots:FindFirstChild(player.Name),
        workspace:FindFirstChild("Tycoons") and 
            workspace.Tycoons:FindFirstChild(player.Name),
        workspace:FindFirstChild(player.Name) and 
            workspace[player.Name]:FindFirstChild("Plots"),
        workspace:FindFirstChild("PlayerZoos") and 
            workspace.PlayerZoos:FindFirstChild(player.Name),
    }
    
    for _, folder in ipairs(plotPatterns) do
        if folder then
            self._playerPlots = folder
            print("[PlotManager] Found plots: " .. folder:GetFullName())
            return true
        end
    end
    
    warn("[PlotManager] Player plots not found")
    return false
end

function PlotManager:findEmptyPlot()
    if not self._playerPlots then return nil end
    
    for _, plot in ipairs(self._playerPlots:GetChildren()) do
        -- Method A: Check for ProximityPrompt "Place" yang enabled
        local prompt = plot:FindFirstChildOfClass("ProximityPrompt")
        if prompt and prompt.Enabled and prompt.ActionText:lower():find("place") then
            return plot, prompt
        end
        
        -- Method B: Check absence of "Egg" child
        local hasEgg = plot:FindFirstChild("Egg") or plot:FindFirstChild("Animal")
        if not hasEgg then
            -- Method B2: Check Occupied attribute/value
            local occupied = plot:FindFirstChild("Occupied") or plot:GetAttribute("Occupied")
            if not occupied or (type(occupied) == "boolean" and not occupied) or 
               (typeof(occupied) == "Instance" and not occupied.Value) then
                return plot, nil
            end
        end
    end
    
    return nil, nil
end

function PlotManager:placeEgg(plot, prompt)
    if prompt then
        -- Primary: Fire ProximityPrompt
        local success = pcall(function()
            fireproximityprompt(prompt)
        end)
        return success
    else
        -- Fallback: Try RemoteEvent
        local placeRemote = self:_findPlaceRemote()
        if placeRemote then
            local success = pcall(function()
                placeRemote:FireServer(plot)
            end)
            return success
        end
    end
    return false
end
```

### Pattern 4: Hatch Ready Detection

**What:** Detect eggs yang sudah ready untuk hatch
**When to use:** Scanning placed eggs untuk auto-hatch
**Confidence:** MEDIUM (perlu validate indicator visual)

```lua
-- Source: WebSearch verified pattern 2025
local EggHatcher = {
    _readyEggs = {},
    _connections = {},
}

function EggHatcher:scanForReadyEggs(plotsFolder)
    local readyEggs = {}
    
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local egg = plot:FindFirstChild("Egg")
        if egg then
            if self:isEggReady(egg) then
                table.insert(readyEggs, {egg = egg, plot = plot})
            end
        end
    end
    
    return readyEggs
end

function EggHatcher:isEggReady(egg)
    -- Method A: Check "Ready" attribute
    local readyAttr = egg:GetAttribute("Ready")
    if readyAttr == true then
        return true
    end
    
    -- Method B: Check for ProximityPrompt "Hatch" yang enabled
    local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
    if prompt and prompt.Enabled and prompt.ActionText:lower():find("hatch") then
        return true
    end
    
    -- Method C: Check visual indicator (BillboardGui with exclamation mark)
    local billboard = egg:FindFirstChildOfClass("BillboardGui")
    if billboard and billboard.Enabled then
        local textLabel = billboard:FindFirstChildOfClass("TextLabel")
        if textLabel and (textLabel.Text:find("!") or textLabel.Text:lower():find("ready")) then
            return true
        end
        -- Check for ImageLabel (exclamation icon)
        local imageLabel = billboard:FindFirstChildOfClass("ImageLabel")
        if imageLabel and imageLabel.Visible then
            return true
        end
    end
    
    -- Method D: Check for Highlight effect (2025 pattern)
    local highlight = egg:FindFirstChildOfClass("Highlight")
    if highlight and highlight.Enabled then
        return true
    end
    
    return false
end

function EggHatcher:hatchEgg(egg, prompt)
    if prompt then
        -- Primary: Fire ProximityPrompt
        local success = pcall(function()
            fireproximityprompt(prompt)
        end)
        return success
    else
        -- Fallback: Try RemoteEvent
        local hatchRemote = self:_findHatchRemote()
        if hatchRemote then
            local success = pcall(function()
                hatchRemote:FireServer(egg)
            end)
            return success
        end
    end
    return false
end

-- Event-based monitoring (lebih efisien dari polling)
function EggHatcher:watchForReady(egg, callback)
    local conn = egg:GetAttributeChangedSignal("Ready"):Connect(function()
        if egg:GetAttribute("Ready") == true then
            callback(egg)
        end
    end)
    table.insert(self._connections, conn)
end
```

### Pattern 5: RemoteEvent Discovery untuk Egg Actions

**What:** Discover RemoteEvents untuk Buy, Place, Hatch
**When to use:** Init phase untuk cache remotes
**Confidence:** MEDIUM (names bervariasi per game)

```lua
-- Source: Phase 2 pattern extended
local EGG_REMOTE_PATTERNS = {
    buy = {"BuyEgg", "PurchaseEgg", "Buy", "Purchase", "GetEgg"},
    place = {"PlaceEgg", "Place", "AddEgg", "Deposit", "StartIncubation"},
    hatch = {"HatchEgg", "Hatch", "OpenEgg", "BreakEgg", "Crack"},
}

local function discoverEggRemotes()
    local remotes = {
        buy = nil,
        place = nil,
        hatch = nil,
    }
    
    local replicatedStorage = Services.ReplicatedStorage
    
    -- Search in common locations
    local searchLocations = {
        replicatedStorage,
        replicatedStorage:FindFirstChild("Remotes"),
        replicatedStorage:FindFirstChild("Events"),
        replicatedStorage:FindFirstChild("Network"),
    }
    
    for _, location in ipairs(searchLocations) do
        if location then
            for _, child in ipairs(location:GetDescendants()) do
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    for actionType, patterns in pairs(EGG_REMOTE_PATTERNS) do
                        for _, pattern in ipairs(patterns) do
                            if child.Name:lower():find(pattern:lower()) then
                                if not remotes[actionType] then
                                    remotes[actionType] = child
                                    print("[Discovery] Found " .. actionType .. " remote: " .. child:GetFullName())
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return remotes
end
```

### Pattern 6: Main Egg Loop dengan State Machine

**What:** Orchestration loop yang handle buy → place → hatch cycle
**When to use:** Core loop untuk egg system
**Confidence:** HIGH (based on Phase 2 pattern)

```lua
-- Source: Extended from Phase 2 auto-collect pattern
local EggSystem = {
    _active = false,
    _thread = nil,
    _connections = {},
    _state = "IDLE", -- IDLE, BUYING, PLACING, HATCHING
    _holdingEgg = false,
    _config = {
        targetMutation = "Normal",
        cycleDelay = 1,      -- Delay between state checks
        hatchDelay = 0.5,    -- Delay between hatch actions
    },
}

function EggSystem:mainLoop()
    while self._active do
        local success, err = pcall(function()
            if self._state == "IDLE" then
                -- Check for ready eggs first (highest priority)
                local readyEggs = self._hatcher:scanForReadyEggs(self._plots)
                if #readyEggs > 0 then
                    self._state = "HATCHING"
                elseif not self._holdingEgg then
                    -- Monitor conveyor for target mutation
                    self._state = "BUYING"
                else
                    -- Holding egg, need to place
                    self._state = "PLACING"
                end
                
            elseif self._state == "BUYING" then
                -- Wait for target egg callback from conveyor monitor
                -- (handled by event, not polling)
                self._state = "IDLE"
                
            elseif self._state == "PLACING" then
                local plot, prompt = self._plotManager:findEmptyPlot()
                if plot then
                    local success = self._plotManager:placeEgg(plot, prompt)
                    if success then
                        self._holdingEgg = false
                    end
                end
                self._state = "IDLE"
                
            elseif self._state == "HATCHING" then
                local readyEggs = self._hatcher:scanForReadyEggs(self._plots)
                for _, data in ipairs(readyEggs) do
                    if not self._active then break end
                    
                    local prompt = data.egg:FindFirstChildOfClass("ProximityPrompt")
                    self._hatcher:hatchEgg(data.egg, prompt)
                    
                    Timing.wait(self._config.hatchDelay)
                end
                self._state = "IDLE"
            end
        end)
        
        if not success then
            warn("[EggSystem] Loop error: " .. tostring(err))
        end
        
        Timing.wait(self._config.cycleDelay)
    end
end
```

### Anti-Patterns to Avoid

- **Polling tanpa event-based:** Jangan `while true do checkConveyor()` - gunakan `DescendantAdded`
- **Fire remote tanpa pre-check:** WAJIB cek uang cukup sebelum buy, cek plot kosong sebelum place
- **Instant actions:** Jangan buy-place-hatch dalam 1 frame - gunakan delay per action
- **Hardcoded paths:** Jangan `workspace.Conveyor.Egg1` - gunakan discovery pattern
- **No pcall:** Semua game interaction HARUS wrapped dalam pcall
- **Ignore StreamingEnabled:** Gunakan `WaitForChild` untuk objects yang mungkin belum loaded

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timing variance | `math.random()` uniform | `core/timing.lua` gaussian | Gaussian lebih human-like, anti-detection |
| Service access | `game.Players` | `core/services.lua` | Cached, secure against hooking |
| RemoteEvent discovery | Manual path guessing | SimpleSpy + discovery patterns | Game structure bisa berubah |
| ProximityPrompt trigger | Character teleport | `fireproximityprompt()` | Executor function yang handle edge cases |
| Touch simulation | Manual CFrame | `firetouchinterest()` | Already handles touch state |
| UI button firing | VirtualUser | `getconnections()` + `Fire()` | VirtualUser terdeteksi anti-cheat |

**Key insight:** Fokus pada game-specific logic (finding eggs, detecting mutations). Infrastructure sudah tersedia dari Phase 1-2 dan executor functions.

## Common Pitfalls

### Pitfall 1: Remote Spam Detection

**What goes wrong:** Server detect pattern dan kick/ban player
**Why it happens:** Fire RemoteEvent terlalu cepat/konsisten tanpa pre-check
**How to avoid:**
- WAJIB pre-check: uang cukup, plot kosong, egg ready
- Jangan fire remote jika condition tidak terpenuhi (failed request = red flag)
- Gunakan timing variance 10-30% (Gaussian dari Phase 1)
- Batasi max 20-30 remote fires per second
**Warning signs:** Actions work sekali lalu berhenti; silent ban (luck = 0)

### Pitfall 2: StreamingEnabled Breaking Script

**What goes wrong:** Script error karena object belum loaded
**Why it happens:** Game menggunakan StreamingEnabled, objects load asynchronously
**How to avoid:**
```lua
-- ALWAYS use WaitForChild dengan timeout
local billboard = egg:WaitForChild("BillboardGui", 5)
if not billboard then return end -- Handle nil case

-- ALWAYS check for nil before access
local textLabel = billboard and billboard:FindFirstChildOfClass("TextLabel")
if textLabel then
    local text = textLabel.Text
end
```
**Warning signs:** Intermittent "attempt to index nil" errors

### Pitfall 3: Perfect Timing Detection (Metronome Trap)

**What goes wrong:** Anti-cheat detect automated script
**Why it happens:** Actions happen exactly every N seconds (perfect periodicity)
**How to avoid:**
- Gunakan `Timing.wait()` dengan variance (sudah ada dari Phase 1)
- Tambah random jitter: `task.wait(1 + math.random(-10, 10) / 100)`
- Jangan gunakan fixed interval untuk semua actions
**Warning signs:** Account flagged setelah berjalan beberapa jam

### Pitfall 4: Ignoring Inventory/State Checks

**What goes wrong:** Thousands of failed remote requests
**Why it happens:** Script try buy/place tanpa check state dulu
**How to avoid:**
```lua
-- ALWAYS check before action
if currentMoney >= eggPrice and not isHoldingEgg then
    buyRemote:FireServer(eggType)
end

if isHoldingEgg and hasEmptyPlot then
    placeRemote:FireServer(plotId)
end
```
**Warning signs:** Actions fire tapi tidak ada efek

### Pitfall 5: Honey Pot Traps

**What goes wrong:** Script interact dengan invisible trap objects
**Why it happens:** Developer place fake ProximityPrompts/ClickDetectors
**How to avoid:**
- Filter objects by visibility: check `Transparency < 1`
- Whitelist expected object names
- Verify object has expected children (egg, billboard, etc.)
**Warning signs:** Instant kick/ban setelah interact

### Pitfall 6: Memory Leak dari Event Connections

**What goes wrong:** Script berjalan berjam-jam lalu crash
**Why it happens:** Event connections tidak di-disconnect saat stop
**How to avoid:**
```lua
-- ALWAYS track connections
table.insert(self._connections, event:Connect(handler))

-- ALWAYS cleanup di stop()
for _, conn in ipairs(self._connections) do
    conn:Disconnect()
end
self._connections = {}
```
**Warning signs:** Memory usage naik terus

## Code Examples

### Complete Egg Type Config

```lua
-- config/egg-types.lua
-- Easily updatable for future mutations
local EggTypes = {
    -- Format: {name = "Display Name", price = basePrice}
    {name = "Normal", price = 100},
    {name = "Shiny", price = 500},
    {name = "Electric", price = 1000},
    {name = "Christmas", price = 2000},
    {name = "Radioactive", price = 5000},
    {name = "Mythic", price = 10000},
}

-- Helper untuk UI dropdown
function EggTypes.getNames()
    local names = {}
    for _, egg in ipairs(EggTypes) do
        table.insert(names, egg.name)
    end
    return names
end

-- Helper untuk cek harga
function EggTypes.getPrice(name)
    for _, egg in ipairs(EggTypes) do
        if egg.name:lower() == name:lower() then
            return egg.price
        end
    end
    return 0
end

return EggTypes
```

### Complete Buy Flow dengan Pre-Checks

```lua
-- Source: Pattern dari WebSearch verified 2025
local function buyEggSafe(targetMutation)
    -- Pre-check 1: Not already holding egg
    if isHoldingEgg() then
        return false, "Already holding egg"
    end
    
    -- Pre-check 2: Money sufficient
    local currentMoney = getPlayerMoney()
    local eggPrice = EggTypes.getPrice(targetMutation)
    if currentMoney < eggPrice then
        return false, "Insufficient funds"
    end
    
    -- Pre-check 3: Has empty plot
    local emptyPlot = PlotManager:findEmptyPlot()
    if not emptyPlot then
        return false, "No empty plots"
    end
    
    -- All checks passed, fire remote
    local remote = discoveredRemotes.buy
    if not remote then
        return false, "Buy remote not found"
    end
    
    local success = pcall(function()
        -- Try common argument patterns
        remote:FireServer(targetMutation)
        -- or: remote:FireServer({Egg = targetMutation})
        -- or: remote:FireServer(targetMutation, 1)
    end)
    
    if success then
        -- Mark as holding egg (update state)
        setHoldingEgg(true)
    end
    
    return success, success and "Purchased" or "Remote failed"
end
```

### Complete Conveyor Callback Integration

```lua
-- Main integration example
local function setupEggLoop(targetMutation)
    -- Set target
    ConveyorMonitor:setTargetMutation(targetMutation)
    
    -- Callback when target egg appears
    ConveyorMonitor:start(function(egg, mutationName)
        -- Validate still want to buy
        if not EggSystem._active then return end
        if EggSystem._holdingEgg then return end
        
        -- Try buy
        local success, msg = buyEggSafe(mutationName)
        if success then
            print("[EggSystem] Bought " .. mutationName)
        end
    end)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `wait()` loops | `task.spawn` + `task.cancel` | 2022+ | Proper cleanup, better performance |
| Polling every frame | Event-based (`DescendantAdded`, `AttributeChanged`) | 2024+ | Drastis reduce CPU usage |
| Uniform random timing | Gaussian distribution | 2024+ | Better anti-detection |
| Hardcoded paths | Dynamic discovery | 2023+ | Survives game updates |
| `VirtualUser` for UI | `getconnections` + direct fire | 2024+ | VirtualUser terdeteksi |
| Direct `FireServer` | Pre-check + FireServer | 2025+ | Avoid failed request spam |

**Deprecated/outdated:**
- `wait()`: Use `task.wait()`
- `spawn()`: Use `task.spawn()`
- Velocity-based conveyor detection: Use `AssemblyLinearVelocity` check
- Static timing: Use jitter/variance

## Open Questions

1. **Exact conveyor location di Build A Zoo**
   - What we know: Kemungkinan di workspace.Conveyor atau workspace.Map.Conveyor
   - What's unclear: Exact path
   - Recommendation: Run discovery script, log all Models dengan BillboardGui

2. **Exact RemoteEvent names untuk buy/place/hatch**
   - What we know: Patterns umum (BuyEgg, PlaceEgg, HatchEgg)
   - What's unclear: Exact names di Build A Zoo
   - Recommendation: Gunakan SimpleSpy untuk capture exact calls

3. **Holding egg state detection**
   - What we know: Setelah buy, egg "di tangan" player
   - What's unclear: Bagaimana detect ini - Character child? Attribute? UI?
   - Recommendation: Inspect Character setelah buy, cari child baru

4. **Place button trigger method**
   - What we know: Tombol "Place" muncul saat dekat plot kosong
   - What's unclear: ProximityPrompt atau ClickDetector atau UI button?
   - Recommendation: Test dengan game, observe UI/prompts

5. **Hatch ready indicator exact implementation**
   - What we know: Tanda seru merah (efek visual)
   - What's unclear: BillboardGui? Highlight? ParticleEmitter?
   - Recommendation: Inspect ready egg dengan Dex/explorer

## Sources

### Primary (HIGH confidence)
- Roblox Creator Hub - Instance API, task library, ProximityPrompt
- Phase 1-2 established patterns (core/timing.lua, core/services.lua)
- WebSearch 2025 patterns verified across multiple sources

### Secondary (MEDIUM confidence)
- WebSearch: "Roblox exploit script detect conveyor belt egg 2025" - BillboardGui pattern
- WebSearch: "Roblox script detect player money leaderstats 2025" - Multi-source detection
- WebSearch: "Roblox auto buy egg RemoteEvent pattern 2025" - Pre-check patterns
- WebSearch: "Roblox script detect empty plot incubator 2025" - ProximityPrompt detection

### Tertiary (LOW confidence)
- Build A Zoo specific structure - Needs validation dengan game sebenarnya
- Exact RemoteEvent argument format - Needs SimpleSpy capture
- Holding egg state detection - Needs in-game research

## Metadata

**Confidence breakdown:**
- Conveyor detection: HIGH - Standard Roblox pattern dengan DescendantAdded
- Money detection: HIGH - Well-documented multi-source pattern
- Plot detection: MEDIUM - Pattern umum, perlu validate exact implementation
- Hatch detection: MEDIUM - Multiple methods, perlu identify yang dipakai
- RemoteEvent discovery: MEDIUM - Names bervariasi, perlu SimpleSpy
- Anti-detection: HIGH - Well-documented community experience

**Research date:** 2026-01-31
**Valid until:** 2026-02-14 (14 days - perlu revalidate setelah test dengan game sebenarnya)

---

## Checklist Sebelum Planning

- [x] Conveyor egg detection patterns documented
- [x] Money detection patterns documented (multi-source)
- [x] Empty plot detection patterns documented
- [x] Hatch ready detection patterns documented
- [x] RemoteEvent discovery patterns documented
- [x] Anti-detection/timing patterns documented
- [x] Common pitfalls catalogued
- [x] Integration dengan Phase 1-2 utilities clear
- [x] Open questions identified untuk validation

**Ready for planning:** Ya, dengan catatan bahwa beberapa game-specific details perlu validated dengan Build A Zoo sebenarnya (conveyor path, remote names, holding state detection).
