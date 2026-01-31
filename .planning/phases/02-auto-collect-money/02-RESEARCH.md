# Phase 2: Auto-Collect Money - Research

**Researched:** 2026-01-31
**Domain:** Roblox Game Object Discovery & RemoteEvent Exploitation (Build A Zoo)
**Confidence:** MEDIUM

## Summary

Phase 2 mengimplementasikan auto-collect money sebagai validasi pertama bahwa architecture Phase 1 bekerja dengan game sebenarnya. Research ini fokus pada tiga area utama:

1. **RemoteEvent Discovery** - Cara menemukan dan mengeksploitasi RemoteEvent "Collect All" atau per-animal collection
2. **Game Object Traversal** - Pattern untuk menemukan animals milik player dan detect money-ready state
3. **Collection Loop Architecture** - Pattern untuk cycle loop yang aman dari memory leaks

**Temuan kunci:** Game-game seperti Build A Zoo umumnya menyimpan animals dalam folder per-player di Workspace (e.g., `Workspace.PlayerObjects.[PlayerName]`). Money collection bisa dilakukan via RemoteEvent (prioritas) atau via `firetouchinterest` (fallback). Collect All yang berbayar Robux kemungkinan TIDAK bisa di-bypass karena validasi server-side via `MarketplaceService`. Fallback ke per-animal collection via RemoteEvent discovery adalah strategi yang lebih realistis.

**Primary recommendation:** Gunakan SimpleSpy untuk discover RemoteEvent collection, implement fallback via `firetouchinterest` untuk proximity-based collection, dan gunakan `task.spawn` + cleanup pattern untuk collection loop.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SimpleSpy | Latest | RemoteEvent discovery | Industry standard untuk menemukan remotes dan arguments |
| core/timing.lua | Phase 1 | Randomized delays | Sudah diimplementasi dengan Box-Muller gaussian |
| core/services.lua | Phase 1 | Service caching | Sudah cache services yang dibutuhkan |

### Supporting

| Library | Purpose | When to Use |
|---------|---------|-------------|
| CollectionService | Tag-based object finding | Jika game menggunakan tags untuk animals |
| firetouchinterest | Simulate proximity touch | Fallback jika RemoteEvent tidak tersedia |
| task.spawn/task.cancel | Background loop management | Collection cycle loop |

### Delta Executor Functions

| Function | Status | Purpose |
|----------|--------|---------|
| `firetouchinterest(part1, part2, state)` | Supported | Simulate Touched event |
| `fireproximityprompt(prompt)` | Supported | Trigger ProximityPrompt |
| `getgenv()` | Supported | Global environment for toggle flags |
| `hookmetamethod` | Supported | Untuk advanced RemoteEvent interception |

**Note:** Semua fungsi ini adalah executor-specific, bukan Roblox standard API.

## Architecture Patterns

### Recommended Module Structure

```
features/
├── auto-collect.lua       # Main collection logic
│   ├── init()            # Setup, discover remotes
│   ├── start()           # Start collection loop
│   ├── stop()            # Stop loop, cleanup
│   └── collectCycle()    # Single collection cycle
└── game-discovery.lua    # Game object traversal utilities
    ├── findPlayerAnimals()
    ├── findCollectRemote()
    └── isMoneyReady()
```

### Pattern 1: RemoteEvent Discovery via SimpleSpy

**What:** Gunakan SimpleSpy untuk menemukan RemoteEvent yang digunakan game untuk collection
**When to use:** ALWAYS - fase research/discovery sebelum hardcode path
**Confidence:** HIGH

```lua
-- Discovery script (run manually with SimpleSpy active)
-- Lakukan collect manual di game, lihat RemoteEvent yang ter-fire di SimpleSpy
-- Copy generated code dari SimpleSpy

-- Setelah discovery, pattern untuk fire remote:
local remote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes", true)
    and game.ReplicatedStorage.Remotes:FindFirstChild("CollectMoney")

if remote then
    remote:FireServer(animalId) -- Arguments dari SimpleSpy
end
```

### Pattern 2: Game Object Discovery

**What:** Temukan animals milik player dengan pattern yang robust
**When to use:** Untuk iterate semua animals yang perlu di-collect
**Confidence:** MEDIUM

```lua
-- Pattern 1: Folder-based (paling umum untuk tycoon/simulator games)
local function findPlayerAnimals()
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    
    -- Try common folder patterns
    local playerFolder = Workspace:FindFirstChild(LocalPlayer.Name)
        or Workspace:FindFirstChild(tostring(LocalPlayer.UserId))
        or (Workspace:FindFirstChild("PlayerObjects") 
            and Workspace.PlayerObjects:FindFirstChild(LocalPlayer.Name))
        or (Workspace:FindFirstChild("Zoos") 
            and Workspace.Zoos:FindFirstChild(LocalPlayer.Name))
    
    if not playerFolder then
        warn("[AutoCollect] Player folder not found")
        return {}
    end
    
    -- Find all animals (adjust pattern based on game structure)
    local animals = {}
    for _, obj in ipairs(playerFolder:GetDescendants()) do
        if obj:IsA("Model") and (
            obj:FindFirstChild("Animal") or 
            obj:GetAttribute("IsAnimal") or
            obj.Name:match("Animal")
        ) then
            table.insert(animals, obj)
        end
    end
    
    return animals
end
```

### Pattern 3: Money Ready Detection

**What:** Detect apakah animal punya money yang siap di-collect
**When to use:** Filter animals sebelum attempt collection
**Confidence:** MEDIUM (perlu validate dengan game sebenarnya)

```lua
-- Pattern: Check for money indicator
local function isMoneyReady(animal)
    -- Common patterns in simulator games:
    
    -- Pattern A: NumberValue/IntValue
    local money = animal:FindFirstChild("Money") 
        or animal:FindFirstChild("Cash")
        or animal:FindFirstChild("Coins")
    if money and money:IsA("ValueBase") and money.Value > 0 then
        return true, money.Value
    end
    
    -- Pattern B: Attribute
    local moneyAttr = animal:GetAttribute("Money") 
        or animal:GetAttribute("CollectableMoney")
    if moneyAttr and moneyAttr > 0 then
        return true, moneyAttr
    end
    
    -- Pattern C: Visual indicator (BillboardGui dengan "$")
    local billboard = animal:FindFirstChildOfClass("BillboardGui")
    if billboard and billboard.Enabled then
        return true, nil -- Amount unknown
    end
    
    -- Pattern D: Part dengan nama "MoneyDrop" atau similar
    local moneyPart = animal:FindFirstChild("MoneyDrop", true)
        or animal:FindFirstChild("CoinDrop", true)
    if moneyPart then
        return true, nil
    end
    
    return false, 0
end
```

### Pattern 4: Collection Loop dengan Cleanup

**What:** Main loop untuk collection cycle dengan proper memory management
**When to use:** Core collection functionality
**Confidence:** HIGH

```lua
local AutoCollect = {
    _active = false,
    _thread = nil,
    _connections = {},
}

function AutoCollect:start(config)
    if self._active then return end
    self._active = true
    
    local cycleInterval = config.cycleInterval or 60
    local delayPerAnimal = config.delayPerAnimal or 0.5
    
    self._thread = task.spawn(function()
        while self._active do
            local success, err = pcall(function()
                self:collectCycle(delayPerAnimal)
            end)
            
            if not success then
                warn("[AutoCollect] Cycle error: " .. tostring(err))
            end
            
            -- Randomized wait for next cycle
            Timing.wait(cycleInterval)
        end
    end)
end

function AutoCollect:stop()
    self._active = false
    
    -- Cancel thread if running
    if self._thread then
        task.cancel(self._thread)
        self._thread = nil
    end
    
    -- Disconnect all connections
    for _, conn in ipairs(self._connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    self._connections = {}
end

function AutoCollect:collectCycle(delayPerAnimal)
    local animals = findPlayerAnimals()
    
    for _, animal in ipairs(animals) do
        if not self._active then break end
        
        local ready, amount = isMoneyReady(animal)
        if ready then
            self:collectFromAnimal(animal)
            Timing.wait(delayPerAnimal)
        end
    end
end
```

### Pattern 5: Collection via RemoteEvent (Prioritas)

**What:** Fire RemoteEvent untuk collect, dengan retry logic
**When to use:** Jika RemoteEvent tersedia (lebih reliable dari firetouchinterest)
**Confidence:** MEDIUM

```lua
function AutoCollect:collectViaRemote(animal)
    local remote = self._collectRemote
    if not remote then return false end
    
    local retries = 0
    local maxRetries = 3
    
    repeat
        local success = pcall(function()
            remote:FireServer(animal) -- atau animal:GetAttribute("Id"), tergantung game
        end)
        
        if success then
            return true
        end
        
        retries = retries + 1
        if retries < maxRetries then
            task.wait(0.5)
        end
    until retries >= maxRetries
    
    return false
end
```

### Pattern 6: Collection via firetouchinterest (Fallback)

**What:** Simulate touch untuk proximity-based collection
**When to use:** Fallback jika RemoteEvent tidak tersedia
**Confidence:** MEDIUM

```lua
function AutoCollect:collectViaTouch(animal)
    local character = Services.LocalPlayer.Character
    if not character then return false end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end
    
    -- Find touchable part in animal
    local touchPart = animal:FindFirstChildOfClass("BasePart")
        or animal.PrimaryPart
    
    if not touchPart then return false end
    
    -- Check if firetouchinterest is available (executor function)
    if not firetouchinterest then
        warn("[AutoCollect] firetouchinterest not available")
        return false
    end
    
    local success = pcall(function()
        firetouchinterest(rootPart, touchPart, 0) -- Start touch
        task.wait(0.1) -- Brief delay
        firetouchinterest(rootPart, touchPart, 1) -- End touch
    end)
    
    return success
end
```

### Anti-Patterns to Avoid

- **Hardcoded paths:** Jangan `game.Workspace.Zoos.Player123.Animal1` - gunakan discovery pattern
- **No pcall:** Semua game interaction HARUS wrapped dalam pcall
- **Instant collection:** Jangan collect semua dalam 1 frame - gunakan delay per animal
- **No cleanup:** WAJIB implement stop() dengan proper cleanup
- **Global state tanpa reset:** Gunakan module-level state yang bisa di-reset
- **Blocking main thread:** Gunakan task.spawn untuk collection loop

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| RemoteEvent discovery | Manual path guessing | SimpleSpy | Game structure bisa berubah; SimpleSpy otomatis generate code |
| Touch simulation | Character teleport | `firetouchinterest` | Executor function yang sudah handle edge cases |
| Timing randomization | `math.random()` uniform | `core/timing.lua` gaussian | Gaussian lebih human-like, sudah diimplementasi |
| Loop management | `while wait() do` | `task.spawn` + `task.cancel` | Modern pattern dengan proper cleanup |
| Service access | `game.Players` | `core/services.lua` | Cached, secure against hooking |

**Key insight:** Fokus pada game-specific logic (finding animals, detecting money ready). Infrastructure sudah tersedia dari Phase 1 dan executor functions.

## Common Pitfalls

### Pitfall 1: Collect All Robux Bypass (TIDAK AKAN BERHASIL)

**What goes wrong:** Mencoba fire "Collect All" RemoteEvent yang berbayar Robux
**Why it happens:** Server-side validation via `MarketplaceService:UserOwnsGamePassAsync()`
**How to avoid:** 
- Skip Collect All bypass - langsung ke per-animal collection
- Collect All hanya bisa digunakan jika BENAR-BENAR tidak ada validasi (sangat jarang)
- Fokus pada mengautomasi apa yang player bisa lakukan manual
**Warning signs:** RemoteEvent ter-fire tapi tidak ada efek; server reject silently

### Pitfall 2: Memory Leak dari Connection

**What goes wrong:** Script berjalan berjam-jam lalu crash karena memory
**Why it happens:** Event connections tidak di-disconnect saat stop()
**How to avoid:**
```lua
-- SELALU track connections
table.insert(self._connections, event:Connect(handler))

-- SELALU cleanup di stop()
for _, conn in ipairs(self._connections) do
    conn:Disconnect()
end
self._connections = {}
```
**Warning signs:** Memory usage naik terus di Developer Console

### Pitfall 3: Race Condition saat Player Respawn

**What goes wrong:** Script error karena Character atau HumanoidRootPart nil
**Why it happens:** Player respawn/teleport, Character belum ready
**How to avoid:**
```lua
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart", 5)
if not rootPart then return end
```
**Warning signs:** Intermittent "attempt to index nil" errors

### Pitfall 4: Game Structure Mismatch

**What goes wrong:** Discovery code tidak menemukan animals
**Why it happens:** Asumsi salah tentang game hierarchy
**How to avoid:**
- WAJIB test discovery dengan game sebenarnya
- Gunakan multiple fallback patterns
- Log path yang ditemukan untuk debugging
**Warning signs:** Empty animal list padahal player punya animals

### Pitfall 5: Collection Spam Flagging

**What goes wrong:** Server detect pattern dan ignore collection requests
**Why it happens:** Terlalu cepat/konsisten dalam timing
**How to avoid:**
- Gunakan `Timing.wait()` dengan variance 20%
- Delay 0.5s per animal (sesuai CONTEXT.md)
- Cycle interval 60 detik (sesuai CONTEXT.md)
**Warning signs:** Collection works sekali lalu berhenti

## Code Examples

### Complete Discovery Pattern

```lua
-- Source: WebSearch patterns verified across multiple sources
local function discoverGameStructure()
    local discovery = {
        playerFolder = nil,
        collectRemote = nil,
        animalPattern = nil,
        moneyIndicator = nil,
    }
    
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer
    
    -- Find player folder
    local folderPatterns = {
        Workspace:FindFirstChild(LocalPlayer.Name),
        Workspace:FindFirstChild(tostring(LocalPlayer.UserId)),
        Workspace:FindFirstChild("PlayerObjects") and 
            Workspace.PlayerObjects:FindFirstChild(LocalPlayer.Name),
        Workspace:FindFirstChild("Zoos") and 
            Workspace.Zoos:FindFirstChild(LocalPlayer.Name),
        Workspace:FindFirstChild("PlayerZoos") and 
            Workspace.PlayerZoos:FindFirstChild(LocalPlayer.Name),
    }
    
    for _, folder in ipairs(folderPatterns) do
        if folder then
            discovery.playerFolder = folder
            print("[Discovery] Player folder: " .. folder:GetFullName())
            break
        end
    end
    
    -- Find collection remotes
    local remotePatterns = {"Collect", "CollectMoney", "CollectCash", "CollectAll", "Claim"}
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            for _, pattern in ipairs(remotePatterns) do
                if v.Name:match(pattern) then
                    print("[Discovery] Found remote: " .. v:GetFullName())
                    discovery.collectRemote = v
                end
            end
        end
    end
    
    return discovery
end
```

### Complete AutoCollect Module Skeleton

```lua
-- features/auto-collect.lua
local Services = require(script.Parent.Parent.core.services)
local Timing = require(script.Parent.Parent.core.timing)

local AutoCollect = {
    _active = false,
    _thread = nil,
    _connections = {},
    _config = {
        cycleInterval = 60,
        delayPerAnimal = 0.5,
        maxRetries = 3,
    },
    _discovery = nil,
}

function AutoCollect:init()
    self._discovery = self:discoverGameStructure()
    if not self._discovery.playerFolder then
        warn("[AutoCollect] Failed to discover game structure")
        return false
    end
    return true
end

function AutoCollect:start()
    if self._active then return end
    if not self._discovery then
        if not self:init() then return end
    end
    
    self._active = true
    self._thread = task.spawn(function()
        while self._active do
            self:collectCycle()
            Timing.wait(self._config.cycleInterval)
        end
    end)
end

function AutoCollect:stop()
    self._active = false
    if self._thread then
        task.cancel(self._thread)
        self._thread = nil
    end
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    self._connections = {}
end

function AutoCollect:collectCycle()
    local animals = self:findPlayerAnimals()
    local collected = 0
    local failed = 0
    
    for _, animal in ipairs(animals) do
        if not self._active then break end
        
        if self:isMoneyReady(animal) then
            local success = self:collectFromAnimal(animal)
            if success then
                collected = collected + 1
            else
                failed = failed + 1
            end
            Timing.wait(self._config.delayPerAnimal)
        end
    end
    
    -- Silent mode per CONTEXT.md, tapi log untuk debugging
    if failed > 0 then
        warn(string.format("[AutoCollect] Cycle: %d collected, %d failed", collected, failed))
    end
end

return AutoCollect
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `wait()` loops | `task.spawn` + `task.cancel` | 2022+ | Proper cleanup, better performance |
| Hardcoded paths | Dynamic discovery | 2023+ | Survives game updates |
| Uniform random | Gaussian distribution | 2024+ | Better anti-detection |
| Global variables | Module state | 2023+ | Cleaner, no conflicts |
| No error handling | `pcall` everything | Always | Script stability |

**Deprecated/outdated:**
- `wait()`: Use `task.wait()`
- `spawn()`: Use `task.spawn()`
- Direct property access (`game.Workspace`): Use `game:GetService("Workspace")`
- Collect All bypass: Server-side validation makes this unreliable

## Open Questions

1. **Exact game structure untuk Build A Zoo**
   - What we know: Kemungkinan folder per-player, animals sebagai Models
   - What's unclear: Exact path, property names untuk money ready
   - Recommendation: Run discovery script dengan game sebenarnya, document findings

2. **RemoteEvent arguments untuk collection**
   - What we know: Kemungkinan animalId atau animal Instance
   - What's unclear: Exact argument format dan order
   - Recommendation: Gunakan SimpleSpy untuk capture exact call

3. **Apakah game punya server-side distance check**
   - What we know: Modern games sering validate proximity
   - What's unclear: Build A Zoo specific implementation
   - Recommendation: Test firetouchinterest dari jauh, jika fail maka perlu teleport

4. **Money ready indicator**
   - What we know: Bisa ValueBase, Attribute, atau visual (BillboardGui)
   - What's unclear: Yang mana yang digunakan Build A Zoo
   - Recommendation: Inspect animal model dengan Dex/explorer

## Sources

### Primary (HIGH confidence)
- Roblox Creator Hub - Instance API: https://create.roblox.com/docs/reference/engine/classes/Instance
- Roblox Creator Hub - Task Library: https://create.roblox.com/docs/reference/engine/libraries/task
- Roblox Creator Hub - RemoteEvent: https://create.roblox.com/docs/reference/engine/classes/RemoteEvent

### Secondary (MEDIUM confidence)
- WebSearch: "Roblox RemoteEvent discovery pattern 2025" - Multiple sources agree on SimpleSpy
- WebSearch: "Roblox firetouchinterest pattern exploit" - Consistent across executor communities
- WebSearch: "Roblox CollectionService GetTagged auto farm" - Standard pattern verified
- WebSearch: "Roblox memory leak RBXScriptConnection cleanup" - Trove/Janitor patterns verified

### Tertiary (LOW confidence)
- Build A Zoo specific structure - Needs validation with actual game
- Delta Executor firetouchinterest compatibility - Generally supported but verify
- Collect All bypass feasibility - Likely NOT possible due to server validation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Timing dan Services dari Phase 1 sudah verified
- Architecture: MEDIUM-HIGH - Patterns consistent across exploit community
- Game-specific discovery: LOW - Needs validation with actual Build A Zoo
- Pitfalls: HIGH - Based on documented community experience

**Research date:** 2026-01-31
**Valid until:** 2026-02-14 (14 days - perlu revalidate setelah test dengan game sebenarnya)

---

## Checklist Sebelum Planning

- [x] RemoteEvent discovery patterns documented
- [x] Game object traversal patterns documented
- [x] Collection loop with cleanup patterns documented
- [x] Memory leak prevention addressed
- [x] Fallback strategy (Remote → Touch) defined
- [x] Integration dengan Phase 1 utilities clear
- [x] Open questions identified untuk validation

**Ready for planning:** Ya, dengan catatan bahwa game-specific discovery perlu validated dengan Build A Zoo sebenarnya.
