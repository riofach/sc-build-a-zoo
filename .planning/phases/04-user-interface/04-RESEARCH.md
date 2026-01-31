# Phase 4: User Interface - Research

**Researched:** 2026-01-31
**Domain:** Rayfield UI Library Implementation untuk Mobile Executor (Delta)
**Confidence:** HIGH

## Summary

Phase 4 membangun Rayfield UI untuk kontrol semua fitur auto-farm di mobile. Research ini fokus pada implementasi Rayfield dengan benar — bukan pemilihan library (sudah locked: Rayfield), tapi HOW to use it correctly untuk mencapai:

1. **Window dan Tab creation** - 5 tabs: Collect, Eggs, Stats, Settings, About
2. **Interactive elements** - Toggle, Slider, Dropdown untuk kontrol fitur
3. **Dynamic stats display** - Label yang update periodic
4. **Settings persistence** - Built-in Rayfield config saving + custom config merge
5. **Mobile/Delta compatibility** - Specific considerations untuk Delta Executor

**Temuan kunci:**
- Rayfield sudah memiliki built-in `ConfigurationSaving` yang handle toggle/slider/dropdown state automatically
- Setiap element WAJIB punya unique `Flag` untuk config saving berfungsi
- Toggle callbacks WAJIB menggunakan `task.spawn()` untuk loops — blocking callback freezes UI
- Label updates via `Label:Set()` method — TIDAK ada auto-refresh, harus manual periodic update
- Delta Executor: wait 10-15 detik setelah join sebelum execute, clear cache jika stuck loading
- Destroy previous UI instance dengan `getgenv()` check untuk prevent stacking

**Primary recommendation:** Gunakan Rayfield's built-in ConfigurationSaving untuk UI state (toggles, slider values), dan custom config.lua untuk non-UI settings (webhook URL, egg priorities). Wire toggle callbacks ke feature modules via `task.spawn()`. Update stats labels dengan dedicated periodic loop (2-5 detik interval).

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rayfield UI | Latest (sirius.menu) | GUI framework | Mobile-optimized, built-in config saving, notifications, actively maintained |
| core/config.lua | Phase 1 | Non-UI settings persistence | JSON-based, merge loading untuk forward compatibility |
| core/timing.lua | Phase 1 | Randomized delays | Human-like timing untuk anti-detection |

### Supporting

| Library | Purpose | When to Use |
|---------|---------|-------------|
| HttpService:JSONEncode/JSONDecode | Config serialization | Custom config file (non-Rayfield data) |
| getgenv() | Global state flags | Prevent double-loading UI, feature toggle flags |
| task.spawn() | Background loops | Toggle callbacks yang memulai loops |
| task.cancel() | Stop background loops | Immediate stop saat toggle off |

### Rayfield Components Used

| Component | Purpose | Phase 4 Usage |
|-----------|---------|---------------|
| CreateWindow | Main window | Script container dengan ConfigurationSaving |
| CreateTab | Navigation tabs | 5 tabs (Collect, Eggs, Stats, Settings, About) |
| CreateToggle | On/off switches | Auto-Collect toggle, Egg System toggle |
| CreateSlider | Numeric ranges | Interval slider untuk Auto-Collect |
| CreateDropdown | Selection list | Mutation type selection |
| CreateLabel | Text display | Stats: Money, Eggs, Script status |
| CreateParagraph | Multi-line text | About info, credits |
| Notify | User feedback | Error notifications, status changes |
| LoadConfiguration | Load saved state | At script end, restore UI state |

## Architecture Patterns

### Recommended Module Structure

```
ui/
├── main.lua              # Main UI module
│   ├── init()            # Load Rayfield, create window
│   ├── createTabs()      # Create all 5 tabs
│   ├── wireCallbacks()   # Connect toggles to feature modules
│   ├── startStatsLoop()  # Periodic stats update
│   └── destroy()         # Cleanup UI
├── stats-tracker.lua     # Session stats management
│   ├── moneyCollected    # Counter untuk money
│   ├── eggsHatched       # Counter untuk eggs
│   ├── incrementMoney()  # Called by auto-collect
│   ├── incrementEggs()   # Called by egg-hatcher
│   └── getFormatted()    # Return formatted strings
```

### Pattern 1: Window Creation dengan Config Saving

**What:** Create Rayfield window dengan built-in configuration saving enabled
**When to use:** Script initialization
**Confidence:** HIGH (official docs verified)

```lua
-- Source: https://docs.sirius.menu/rayfield/configuration/windows
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Prevent double-loading (critical for re-execution)
if getgenv().BuildAZooLoaded then
    Rayfield:Destroy()
    task.wait(0.5)
end
getgenv().BuildAZooLoaded = true

local Window = Rayfield:CreateWindow({
    Name = "Build A Zoo Auto-Farm",
    Icon = 0, -- No icon (mobile-friendly)
    LoadingTitle = "Build A Zoo Script",
    LoadingSubtitle = "Loading...",
    Theme = "Default",
    
    -- Mobile-specific
    ShowText = "Menu", -- Text shown untuk unhide di mobile
    ToggleUIKeybind = "K", -- Desktop toggle key
    
    -- Config saving - CRITICAL untuk persistence
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BuildAZoo", -- Unique folder name
        FileName = "UIConfig"      -- Unique file name
    },
    
    -- Disable extras
    KeySystem = false,
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
    
    Discord = {
        Enabled = false
    }
})
```

### Pattern 2: Tab Creation dengan Lucide Icons

**What:** Create 5 tabs dengan appropriate icons
**When to use:** After window creation
**Confidence:** HIGH (official docs verified)

```lua
-- Source: https://docs.sirius.menu/rayfield/configuration/windows
-- Lucide icons: https://lucide.dev/icons/

local TabCollect = Window:CreateTab("Collect", "coins")     -- coins icon
local TabEggs = Window:CreateTab("Eggs", "egg")             -- egg icon
local TabStats = Window:CreateTab("Stats", "bar-chart-2")   -- chart icon
local TabSettings = Window:CreateTab("Settings", "settings") -- gear icon
local TabAbout = Window:CreateTab("About", "info")          -- info icon
```

### Pattern 3: Toggle dengan Non-Blocking Callback

**What:** Toggle yang memulai/stop background loop tanpa freeze UI
**When to use:** Auto-Collect toggle, Egg System toggle
**Confidence:** HIGH (verified pitfall dari community)

```lua
-- Source: WebSearch verified pattern 2025
-- CRITICAL: Wrap loops dalam task.spawn(), simpan thread untuk cancel

local autoCollectThread = nil

local AutoCollectToggle = TabCollect:CreateToggle({
    Name = "Auto-Collect",
    CurrentValue = true, -- Default ON per CONTEXT.md
    Flag = "AutoCollect", -- UNIQUE flag untuk config saving
    Callback = function(Value)
        -- Stop existing thread first (immediate stop)
        if autoCollectThread then
            task.cancel(autoCollectThread)
            autoCollectThread = nil
        end
        
        if Value then
            -- Start new thread (non-blocking)
            autoCollectThread = task.spawn(function()
                Features["auto-collect"]:start()
            end)
        else
            -- Stop feature
            Features["auto-collect"]:stop()
        end
    end
})
```

### Pattern 4: Slider untuk Interval

**What:** Slider untuk set collect interval
**When to use:** Auto-Collect interval setting
**Confidence:** HIGH (official docs verified)

```lua
-- Source: https://docs.sirius.menu/rayfield/interaction/interactive-elements

local IntervalSlider = TabCollect:CreateSlider({
    Name = "Collect Interval",
    Range = {1, 30}, -- 1 to 30 seconds
    Increment = 1,   -- Step by 1
    Suffix = " seconds",
    CurrentValue = 5, -- Default 5 seconds
    Flag = "CollectInterval", -- UNIQUE flag
    Callback = function(Value)
        -- Update config immediately
        Features["auto-collect"]:setInterval(Value)
    end
})
```

### Pattern 5: Dropdown untuk Mutation Type

**What:** Dropdown untuk select mutation target
**When to use:** Egg System mutation selection
**Confidence:** HIGH (official docs verified)

```lua
-- Source: https://docs.sirius.menu/rayfield/interaction/interactive-elements
local EggTypes = require("config/egg-types")

local MutationDropdown = TabEggs:CreateDropdown({
    Name = "Mutation Type",
    Options = EggTypes.getNames(), -- {"Normal", "Shiny", "Electric", ...}
    CurrentOption = {"Normal"},    -- Default selection (table format)
    MultipleOptions = false,       -- Single selection only
    Flag = "MutationType",         -- UNIQUE flag
    Callback = function(Options)
        -- Options is a table, get first element
        local selected = Options[1]
        Features["egg-system"]:setTargetMutation(selected)
    end
})

-- Refresh dropdown jika options berubah runtime
-- MutationDropdown:Refresh({"New Option 1", "New Option 2"})
```

### Pattern 6: Dynamic Label Updates untuk Stats

**What:** Label yang di-update periodic untuk show stats
**When to use:** Stats tab - Money Collected, Eggs Hatched
**Confidence:** HIGH (official docs verified)

```lua
-- Source: https://docs.sirius.menu/rayfield/ui-components/text
-- Labels TIDAK auto-update — harus manual :Set()

local MoneyLabel = TabStats:CreateLabel("Money Collected: 0", "coins")
local EggsLabel = TabStats:CreateLabel("Eggs Hatched: 0", "egg")

-- Periodic update loop (separate thread)
local statsUpdateThread = nil

local function startStatsLoop()
    statsUpdateThread = task.spawn(function()
        while true do
            local moneyFormatted = StatsTracker:getFormattedMoney()
            local eggsFormatted = StatsTracker:getFormattedEggs()
            
            -- Update labels
            MoneyLabel:Set("Money Collected: " .. moneyFormatted, "coins")
            EggsLabel:Set("Eggs Hatched: " .. eggsFormatted, "egg")
            
            task.wait(3) -- Update setiap 3 detik
        end
    end)
end

-- Stop loop saat cleanup
local function stopStatsLoop()
    if statsUpdateThread then
        task.cancel(statsUpdateThread)
        statsUpdateThread = nil
    end
end
```

### Pattern 7: Paragraph untuk About Tab

**What:** Multi-line text block untuk credits dan info
**When to use:** About tab - version, credits, status
**Confidence:** HIGH (official docs verified)

```lua
-- Source: https://docs.sirius.menu/rayfield/ui-components/text

local StatusParagraph = TabAbout:CreateParagraph({
    Title = "Script Status",
    Content = "Running"
})

local VersionParagraph = TabAbout:CreateParagraph({
    Title = "Version",
    Content = "v1.0.0"
})

local CreditsParagraph = TabAbout:CreateParagraph({
    Title = "Credits",
    Content = "Build A Zoo Auto-Farm Script\nDeveloped by [Author]"
})

-- Update status dynamically
local function updateStatus(status)
    StatusParagraph:Set({
        Title = "Script Status",
        Content = status -- "Running", "Paused", "Error (3)"
    })
end
```

### Pattern 8: Number Formatting dengan Separator

**What:** Format angka dengan thousand separator (1,250,000)
**When to use:** Stats display
**Confidence:** HIGH (standard Lua pattern)

```lua
-- Source: Standard Lua pattern
local function formatNumber(num)
    local formatted = tostring(math.floor(num))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- Usage
formatNumber(1250000) -- "1,250,000"
formatNumber(500)     -- "500"
```

### Pattern 9: Rayfield Config + Custom Config Coexistence

**What:** Rayfield handles UI state, custom config handles script-specific data
**When to use:** Separation of concerns untuk persistence
**Confidence:** MEDIUM (pattern dari Phase 1 research)

```lua
-- Rayfield handles:
-- - Toggle states (Auto-Collect ON/OFF)
-- - Slider values (Interval)
-- - Dropdown selections (Mutation Type)
-- Saved to: BuildAZoo/UIConfig.json

-- Custom config.lua handles:
-- - Webhook URL (future)
-- - Egg priorities (future)
-- - Non-UI settings
-- Saved to: BuildAZoo/settings.json

-- At script end:
Rayfield:LoadConfiguration() -- Load UI state
Config:Load()                -- Load custom settings
```

### Pattern 10: Visibility Control dan Minimize

**What:** Control window visibility untuk minimize
**When to use:** User minimize window, atau hide sementara
**Confidence:** HIGH (official docs verified)

```lua
-- Source: https://docs.sirius.menu/rayfield/configuration/windows

-- Hide window
Rayfield:SetVisibility(false)

-- Show window
Rayfield:SetVisibility(true)

-- Check current visibility
local isVisible = Rayfield:IsVisible()

-- Mobile users: ShowText property di CreateWindow determines
-- the text shown to unhide (default: tap text on screen)
```

### Anti-Patterns to Avoid

- **Duplicate Flags:** NEVER use same Flag for multiple elements — causes config conflicts
- **Blocking Callbacks:** NEVER put `while true` loop directly in callback — freezes UI
- **Missing Flag:** ALWAYS provide Flag untuk elements yang perlu saved (Toggle, Slider, Dropdown)
- **Immediate Remote Fire:** ALWAYS use `task.spawn()` untuk callbacks yang trigger features
- **No Destroy Check:** ALWAYS check `getgenv()` flag sebelum create window — prevent stacking
- **Forget LoadConfiguration:** ALWAYS call `Rayfield:LoadConfiguration()` di akhir script

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UI Framework | Custom ScreenGui | Rayfield | Mobile-optimized, config saving, tested |
| Config saving | Manual JSON per element | Rayfield ConfigurationSaving + Flag | Built-in, handles edge cases |
| Toggle state management | Global booleans | Rayfield Flags + CurrentValue | Auto-persist, auto-load |
| Number formatting | Basic tostring | formatNumber() helper | Proper thousand separators |
| Stats flash effect | Custom animation | Future enhancement | Keep simple for now |
| Error count display | Toast notifications | Label di About tab | Subtle per CONTEXT.md |

**Key insight:** Rayfield sudah solve UI problems. Fokus pada wiring callbacks ke feature modules dan periodic stats updates.

## Common Pitfalls

### Pitfall 1: Flag Conflicts (Duplicate Identifiers)

**What goes wrong:** Toggle A affects Toggle B; settings tidak persist correctly
**Why it happens:** Two elements share same Flag string
**How to avoid:**
```lua
-- BAD - Same flag
Tab:CreateToggle({ Name = "Feature A", Flag = "Toggle1", ... })
Tab:CreateToggle({ Name = "Feature B", Flag = "Toggle1", ... }) -- Conflict!

-- GOOD - Unique flags
Tab:CreateToggle({ Name = "Auto-Collect", Flag = "AutoCollect", ... })
Tab:CreateToggle({ Name = "Egg System", Flag = "EggSystem", ... })
```
**Warning signs:** Changing one toggle changes another; config loads wrong values

### Pitfall 2: UI Freeze dari Blocking Callbacks

**What goes wrong:** UI completely unresponsive setelah toggle on
**Why it happens:** `while true` loop di callback tanpa `task.spawn()`
**How to avoid:**
```lua
-- BAD - Blocks UI thread
Callback = function(Value)
    while Value do -- FREEZES UI!
        doSomething()
        task.wait(1)
    end
end

-- GOOD - Background thread
local thread = nil
Callback = function(Value)
    if thread then task.cancel(thread) end
    if Value then
        thread = task.spawn(function()
            while true do
                doSomething()
                task.wait(1)
            end
        end)
    end
end
```
**Warning signs:** UI tidak respond ke input; tidak bisa toggle off

### Pitfall 3: Window Stacking (Multiple Instances)

**What goes wrong:** Multiple UI windows overlap; memory leak; crash
**Why it happens:** Script re-executed tanpa destroy previous instance
**How to avoid:**
```lua
-- At script start, BEFORE loadstring Rayfield
if getgenv().BuildAZooLoaded then
    if Rayfield then
        Rayfield:Destroy()
    end
    task.wait(0.5)
end
getgenv().BuildAZooLoaded = true

-- Then load Rayfield
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
```
**Warning signs:** Multiple windows visible; FPS drop; memory increase

### Pitfall 4: Missing LoadConfiguration Call

**What goes wrong:** Settings tidak persist antar session
**Why it happens:** Lupa call `Rayfield:LoadConfiguration()` di akhir script
**How to avoid:**
```lua
-- At the VERY END of script, after all UI elements created
Rayfield:LoadConfiguration()
```
**Warning signs:** Toggles reset ke default setiap restart

### Pitfall 5: Delta Executor Infinite Loading

**What goes wrong:** Rayfield stuck di loading screen
**Why it happens:** Execute terlalu cepat setelah join; ISP block GitHub
**How to avoid:**
1. Wait 10-15 detik setelah join game sebelum execute
2. Clear Delta cache (Android Settings > Apps > Delta > Clear Cache)
3. Use VPN jika GitHub blocked (1.1.1.1 Cloudflare)
4. Update Delta ke versi terbaru
**Warning signs:** "Rayfield is Loading" screen tidak hilang

### Pitfall 6: Stats Label Not Updating

**What goes wrong:** Stats tetap 0 meski features running
**Why it happens:** Tidak ada periodic update loop untuk labels
**How to avoid:**
```lua
-- Labels TIDAK auto-update!
-- MUST have explicit update loop

local function startStatsLoop()
    task.spawn(function()
        while true do
            MoneyLabel:Set("Money: " .. stats.money)
            EggsLabel:Set("Eggs: " .. stats.eggs)
            task.wait(3)
        end
    end)
end
```
**Warning signs:** Stats stuck di initial value

### Pitfall 7: Executor writefile Not Supported

**What goes wrong:** Config tidak tersimpan; error saat save
**Why it happens:** Executor tidak support `writefile` function
**How to avoid:**
```lua
-- Check di script start
if not writefile then
    Rayfield:Notify({
        Title = "Warning",
        Content = "Settings cannot be saved (writefile not supported)",
        Duration = 5,
        Image = "alert-triangle"
    })
end
```
**Warning signs:** Rayfield error saat save; settings reset

### Pitfall 8: Notification Spam

**What goes wrong:** Hundreds of notifications crash game
**Why it happens:** `Rayfield:Notify()` inside fast loop
**How to avoid:**
- Only notify on STATE CHANGES (toggle on/off, error occurs)
- NEVER notify per action (per collect, per hatch)
- Limit to max 1 notification per 5 seconds untuk same event
**Warning signs:** FPS drop; UI lag; game crash

## Code Examples

### Complete Tab Collect Implementation

```lua
-- Source: Official docs + verified patterns
local TabCollect = Window:CreateTab("Collect", "coins")

-- Auto-Collect Toggle
local autoCollectThread = nil
local AutoCollectToggle = TabCollect:CreateToggle({
    Name = "Auto-Collect",
    CurrentValue = true, -- Default ON
    Flag = "AutoCollect",
    Callback = function(Value)
        -- Immediate stop
        if autoCollectThread then
            task.cancel(autoCollectThread)
            autoCollectThread = nil
        end
        Features["auto-collect"]:stop()
        
        if Value then
            autoCollectThread = task.spawn(function()
                Features["auto-collect"]:start()
            end)
        end
    end
})

-- Interval Slider
local IntervalSlider = TabCollect:CreateSlider({
    Name = "Collect Interval",
    Range = {1, 30},
    Increment = 1,
    Suffix = " seconds",
    CurrentValue = 5,
    Flag = "CollectInterval",
    Callback = function(Value)
        Features["auto-collect"]:setInterval(Value)
    end
})
```

### Complete Tab Eggs Implementation

```lua
-- Source: Official docs + verified patterns
local TabEggs = Window:CreateTab("Eggs", "egg")
local EggTypes = require("config/egg-types")

-- Mutation Dropdown (FIRST, so user picks before enabling)
local MutationDropdown = TabEggs:CreateDropdown({
    Name = "Mutation Type",
    Options = EggTypes.getNames(),
    CurrentOption = {"Normal"},
    MultipleOptions = false,
    Flag = "MutationType",
    Callback = function(Options)
        Features["egg-system"]:setTargetMutation(Options[1])
    end
})

-- Egg System Toggle
local eggSystemThread = nil
local EggSystemToggle = TabEggs:CreateToggle({
    Name = "Egg System",
    CurrentValue = false, -- Default OFF
    Flag = "EggSystem",
    Callback = function(Value)
        -- Immediate stop
        if eggSystemThread then
            task.cancel(eggSystemThread)
            eggSystemThread = nil
        end
        Features["egg-system"]:stop()
        
        if Value then
            eggSystemThread = task.spawn(function()
                Features["egg-system"]:start()
            end)
        end
    end
})
```

### Complete Tab Stats Implementation

```lua
-- Source: Official docs + verified patterns
local TabStats = Window:CreateTab("Stats", "bar-chart-2")

-- Stats Labels
local MoneyLabel = TabStats:CreateLabel("Money Collected: 0", "coins")
local EggsLabel = TabStats:CreateLabel("Eggs Hatched: 0", "egg")

-- Periodic update
local statsThread = nil

local function formatNumber(num)
    local formatted = tostring(math.floor(num))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

local function startStatsUpdate()
    statsThread = task.spawn(function()
        while true do
            local money = StatsTracker.moneyCollected or 0
            local eggs = StatsTracker.eggsHatched or 0
            
            MoneyLabel:Set("Money Collected: " .. formatNumber(money), "coins")
            EggsLabel:Set("Eggs Hatched: " .. formatNumber(eggs), "egg")
            
            task.wait(3)
        end
    end)
end

startStatsUpdate()
```

### Complete Tab About Implementation

```lua
-- Source: Official docs + verified patterns
local TabAbout = Window:CreateTab("About", "info")

-- Script Status
local StatusParagraph = TabAbout:CreateParagraph({
    Title = "Script Status",
    Content = "Running"
})

-- Update function untuk status
local function updateScriptStatus(status, errorCount)
    local content = status
    if errorCount and errorCount > 0 then
        content = status .. " (Errors: " .. errorCount .. ")"
    end
    StatusParagraph:Set({
        Title = "Script Status",
        Content = content
    })
end

-- Version Info
TabAbout:CreateParagraph({
    Title = "Version",
    Content = "v1.0.0"
})

-- Credits
TabAbout:CreateParagraph({
    Title = "Credits",
    Content = "Build A Zoo Auto-Farm\nPowered by Rayfield UI"
})
```

### Complete Stats Tracker Module

```lua
-- stats-tracker.lua
local StatsTracker = {
    moneyCollected = 0,
    eggsHatched = 0,
    errorsCount = 0,
    sessionStart = os.time(),
}

function StatsTracker:incrementMoney(amount)
    self.moneyCollected = self.moneyCollected + (amount or 0)
end

function StatsTracker:incrementEggs(count)
    self.eggsHatched = self.eggsHatched + (count or 1)
end

function StatsTracker:incrementErrors()
    self.errorsCount = self.errorsCount + 1
end

function StatsTracker:reset()
    self.moneyCollected = 0
    self.eggsHatched = 0
    self.errorsCount = 0
    self.sessionStart = os.time()
end

function StatsTracker:getFormattedMoney()
    return self:_formatNumber(self.moneyCollected)
end

function StatsTracker:getFormattedEggs()
    return self:_formatNumber(self.eggsHatched)
end

function StatsTracker:_formatNumber(num)
    local formatted = tostring(math.floor(num))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

return StatsTracker
```

### Complete UI Module Skeleton

```lua
-- ui/main.lua
local UI = {
    _rayfield = nil,
    _window = nil,
    _tabs = {},
    _elements = {},
    _threads = {},
}

function UI:init(deps)
    self._features = deps.Features
    self._statsTracker = deps.StatsTracker
    self._config = deps.Config
    
    -- Prevent double-loading
    if getgenv().BuildAZooLoaded then
        if self._rayfield then
            self._rayfield:Destroy()
        end
        task.wait(0.5)
    end
    getgenv().BuildAZooLoaded = true
    
    -- Load Rayfield
    self._rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    
    -- Create window
    self:_createWindow()
    
    -- Create tabs
    self:_createTabCollect()
    self:_createTabEggs()
    self:_createTabStats()
    self:_createTabSettings()
    self:_createTabAbout()
    
    -- Start stats update loop
    self:_startStatsLoop()
    
    -- Load saved configuration LAST
    self._rayfield:LoadConfiguration()
    
    return true
end

function UI:destroy()
    -- Stop all threads
    for _, thread in ipairs(self._threads) do
        task.cancel(thread)
    end
    self._threads = {}
    
    -- Destroy Rayfield
    if self._rayfield then
        self._rayfield:Destroy()
    end
    
    getgenv().BuildAZooLoaded = false
end

return UI
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom ScreenGui | Rayfield/UI libraries | 2022+ | Mobile support, less code |
| Manual file save | Rayfield ConfigurationSaving | 2023+ | Automatic persistence |
| `wait()` in callbacks | `task.spawn()` + `task.cancel()` | 2022+ | Non-blocking, cancellable |
| Single config file | Rayfield + custom config separation | 2024+ | UI state vs script data |
| Immediate execution | Wait after join + cache clear | 2025+ | Delta Executor compatibility |

**Deprecated/outdated:**
- Old Rayfield GitHub (jensonhirst): Archived Nov 2024; use sirius.menu
- `wait()` in callbacks: Causes UI freeze
- `spawn()` instead of `task.spawn()`: Deprecated
- Direct loops in callbacks: Always use task.spawn()

## Delta Executor Specifics

### Mobile Considerations

| Aspect | Recommendation |
|--------|----------------|
| Window size | Compact (default Rayfield) |
| Icons | Lucide icons (string, not asset ID) |
| Touch targets | Rayfield handles automatically |
| ShowText | Set meaningful text for unhide button |
| Wait before execute | 10-15 seconds after game join |
| Cache issues | Clear Delta cache if stuck loading |

### Known Issues (2025)

1. **Infinite Loading Screen**
   - Cause: Execute terlalu cepat atau ISP block
   - Fix: Wait, clear cache, use VPN

2. **UI Invisible**
   - Cause: Force GPU Rendering ON di developer options
   - Fix: Turn OFF Force GPU Rendering

3. **Config Not Saving**
   - Cause: writefile not supported atau permission issue
   - Fix: Check executor compatibility; warn user

### Rayfield Mobile Features

- `ShowText` property: Text button untuk unhide UI
- Draggable window: Built-in, works on touch
- Touch-friendly elements: Toggle, Slider, Dropdown semua mobile-optimized

## Open Questions

1. **Stats flash effect implementation**
   - What we know: CONTEXT.md mentions "stats number flash/highlight"
   - What's unclear: Rayfield tidak punya built-in flash; need custom?
   - Recommendation: Defer untuk future enhancement; basic labels dulu

2. **Error count display location**
   - What we know: "Subtle" di Stats tab per CONTEXT.md
   - What's unclear: Separate label atau append ke existing?
   - Recommendation: Use Status paragraph di About tab: "Running (Errors: 3)"

3. **Default Auto-Collect interval**
   - What we know: Slider 1-30 seconds
   - What's unclear: What's optimal default?
   - Recommendation: Start with 5 seconds; tunable

## Sources

### Primary (HIGH confidence)
- https://docs.sirius.menu/rayfield - Official Rayfield documentation
- https://docs.sirius.menu/rayfield/configuration/windows - Window/Tab creation
- https://docs.sirius.menu/rayfield/interaction/interactive-elements - Toggle, Slider, Dropdown
- https://docs.sirius.menu/rayfield/ui-components/text - Label, Paragraph

### Secondary (MEDIUM confidence)
- WebSearch: "Rayfield UI library Roblox executor common mistakes 2025" - Pitfalls verified
- WebSearch: "Delta Executor mobile Rayfield UI loading issues 2025" - Delta specifics
- Phase 1 Research: core/config.lua patterns

### Tertiary (LOW confidence)
- Stats flash effect: Not documented, needs experimentation

## Metadata

**Confidence breakdown:**
- Rayfield API: HIGH - Official docs verified
- Config persistence: HIGH - Built-in feature documented
- Mobile/Delta: MEDIUM - Community patterns, may change
- Stats update pattern: HIGH - Standard Lua/Roblox approach
- Pitfalls: HIGH - Well-documented community experience

**Research date:** 2026-01-31
**Valid until:** 2026-03-01 (30 days - Rayfield stable, revalidate for major updates)

---

## Checklist Sebelum Planning

- [x] Rayfield Window API documented
- [x] Rayfield Tab creation documented
- [x] Rayfield Toggle API documented (with Flag)
- [x] Rayfield Slider API documented (with Flag)
- [x] Rayfield Dropdown API documented (with Flag)
- [x] Rayfield Label API documented (with :Set())
- [x] Rayfield Paragraph API documented
- [x] Settings persistence pattern documented (ConfigurationSaving)
- [x] Mobile/Delta specific considerations documented
- [x] Common pitfalls catalogued with solutions
- [x] Code examples untuk semua UI components needed
- [x] Integration dengan feature modules pattern documented
- [x] Stats update loop pattern documented

**Ready for planning:** Ya, dengan semua Rayfield components dan patterns documented. Implementation straightforward dengan official API.
