# Domain Pitfalls: Roblox Exploit Scripts (Build A Zoo Auto-Farm)

**Domain:** Roblox mobile exploit script with Delta Executor
**Researched:** January 31, 2026
**Target:** Build A Zoo auto-farming script (mobile via Delta Executor)
**Confidence:** MEDIUM (based on community patterns, official docs, and executor-specific sources)

---

## Critical Pitfalls

Mistakes that cause script failure, detection, or major issues.

### Pitfall 1: Inhuman Behavior Patterns (Anti-Cheat Detection)

**What goes wrong:** Script performs actions too fast, too precisely, or in impossible patterns that anti-cheat systems flag immediately. Examples include:
- Instant teleportation across the map
- Perfect timing on every action (0ms variance)
- Clicking/interacting faster than humanly possible
- Moving through walls or to unreachable areas
- Performing actions while character is in impossible states

**Why it happens:** Developers optimize for speed without considering detection patterns. Auto-farm scripts that execute actions at maximum speed are trivially detectable.

**Consequences:**
- Account ban (temporary or permanent)
- Script blacklisted by game's server-side detection
- Pattern added to anti-cheat database affecting all users

**Warning signs:**
- Actions complete suspiciously fast
- No randomization in timing
- Script works but account gets banned within hours/days
- Reports from users about sudden bans

**Prevention:**
```lua
-- BAD: Fixed timing
wait(1)
clickEgg()

-- GOOD: Randomized human-like timing
local function humanDelay(min, max)
    wait(min + math.random() * (max - min))
end
humanDelay(0.8, 1.5)
clickEgg()
```
- Add 10-30% random variance to ALL timing
- Include "human" pauses (occasional longer delays)
- Never exceed humanly possible action rates
- Simulate mouse movement, not instant teleport clicks

**Phase to address:** Phase 1 (Core Architecture) - Build timing utilities from the start

**Detection:** Test with stopwatch - if actions are perfectly consistent, add randomization

---

### Pitfall 2: Server-Side Validation Bypass Attempts

**What goes wrong:** Script tries to manipulate values that are validated server-side, resulting in either:
- Actions being rejected silently
- Immediate detection and ban
- Desync between client display and actual server state

**Why it happens:** Misunderstanding of Roblox's FilteringEnabled architecture. All Roblox games use server-authoritative models - the client cannot directly modify server state.

**Consequences:**
- Script appears to work but nothing actually happens
- Wasted development time on impossible features
- Account flagged for suspicious RemoteEvent calls

**Warning signs:**
- Money/items increase on screen but reset on rejoin
- Actions trigger but have no effect
- Error messages in console about rejected requests

**Prevention:**
- **Never try to:** Directly modify player money, inventory, or game state
- **Do instead:** Automate legitimate client actions (clicks, movements) that trigger server-validated responses
- Research the specific game's RemoteEvents to understand what's client-controlled
- Focus on automating what players can actually do manually

**Phase to address:** Phase 1 (Research) - Analyze Build A Zoo's specific client/server architecture

**Detection:** If a value changes on screen but reverts after rejoin, it's server-validated

---

### Pitfall 3: Delta Executor Version Mismatch

**What goes wrong:** Script uses APIs or syntax not supported by the user's Delta Executor version, or Delta itself is outdated relative to Roblox's current client.

**Why it happens:** 
- Roblox updates frequently (sometimes weekly)
- Delta Executor must update to match Roblox's client
- Script may use features from newer Delta versions

**Consequences:**
- "Script Execution Failed" errors
- Script loads but functions don't work
- Delta crashes on injection
- "Roblox Upgrade" error loop

**Warning signs:**
- Script works for some users but not others
- Errors mention undefined functions
- Delta shows injection success but nothing happens

**Prevention:**
```lua
-- Version check at script start
local MINIMUM_DELTA_VERSION = "2.69.960"
-- Use only widely-supported APIs
-- Avoid cutting-edge Delta features
-- Test on multiple Delta versions before release
```
- Document minimum Delta version in script header
- Use conservative/stable API subset
- Provide clear error messages for version issues
- Test after every Roblox update

**Phase to address:** Phase 2 (Implementation) - Build version detection early

**Detection:** Test script immediately after any Roblox or Delta update

---

### Pitfall 4: Memory Leaks on Mobile (Critical for Long Sessions)

**What goes wrong:** Script consumes increasing memory over time, eventually causing Roblox to crash with "Low Memory" error (Error Code 292) on mobile devices.

**Why it happens:**
- Event connections not disconnected when no longer needed
- Tables growing unbounded without cleanup
- Creating new instances without destroying old ones
- Coroutines/threads not properly terminated

**Consequences:**
- Roblox crashes after 30-60 minutes of farming
- User loses progress
- Device becomes sluggish
- Script gets reputation for instability

**Warning signs:**
- Crashes happen after extended use, not immediately
- Mobile devices crash before PC
- Memory usage steadily climbs in Developer Console

**Prevention:**
```lua
-- BAD: Connection never cleaned up
someEvent:Connect(function()
    -- handler
end)

-- GOOD: Store and cleanup connections
local connections = {}
table.insert(connections, someEvent:Connect(function()
    -- handler
end))

-- Cleanup function
local function cleanup()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
end
```
- Disconnect ALL event connections when done
- Clear tables that accumulate data
- Use weak tables where appropriate
- Implement periodic garbage collection hints
- Target max 100MB memory footprint for mobile

**Phase to address:** Phase 1 (Architecture) - Design cleanup patterns from start

**Detection:** Monitor memory in 30-minute test sessions

---

### Pitfall 5: GitHub Raw Content Rate Limiting

**What goes wrong:** Script hosted on GitHub via `raw.githubusercontent.com` fails to load for users due to rate limiting, especially after May 2025 rate limit changes.

**Why it happens:**
- GitHub tightened rate limits on unauthenticated raw file requests
- Many users loading script = many requests from same IPs
- HTTP 429 "Too Many Requests" returned instead of script content

**Consequences:**
- Script fails to load with cryptic error
- Works for developer but not for users
- Intermittent failures frustrate users
- Script appears broken when GitHub is the issue

**Warning signs:**
- "Unable to load script" errors that come and go
- Works fine for small user base, fails at scale
- loadstring returns nil intermittently

**Prevention:**
```lua
-- Use CDN mirror instead of raw GitHub
-- BAD:
loadstring(game:HttpGet("https://raw.githubusercontent.com/user/repo/main/script.lua"))()

-- BETTER: Use jsDelivr CDN
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/user/repo@main/script.lua"))()

-- BEST: Use paste service with no rate limits
loadstring(game:HttpGet("https://paste.ee/r/XXXXX"))()
```
- Use jsDelivr CDN as GitHub mirror (no rate limits)
- Consider paste services (paste.ee, pastebin with API)
- Implement fallback URLs
- Cache script locally after first successful load

**Phase to address:** Phase 3 (Distribution) - Choose hosting strategy early

**Detection:** Test with VPN from different regions; monitor for 429 errors

---

### Pitfall 6: Discord Webhook Rate Limiting and Spam

**What goes wrong:** Script sends too many webhook messages, gets rate limited or webhook URL gets disabled by Discord.

**Why it happens:**
- Discord webhooks have strict rate limits: ~30 messages per minute per webhook
- Auto-farm scripts can trigger many events (each egg hatched, each money collection)
- No batching or throttling implemented

**Consequences:**
- HTTP 429 rate limit responses
- Webhook silently stops working
- Discord may delete the webhook for abuse
- Users complain notifications stopped working

**Warning signs:**
- Some webhook messages arrive, others don't
- Webhook works initially then stops
- HTTP 429 in response

**Prevention:**
```lua
-- Implement message queue with rate limiting
local webhookQueue = {}
local RATE_LIMIT = 25 -- messages per minute (leave buffer)
local lastSendTime = 0
local messageCount = 0

local function queueWebhook(message)
    table.insert(webhookQueue, message)
end

-- Batch messages and send periodically
local function processQueue()
    local now = tick()
    if now - lastSendTime > 60 then
        messageCount = 0
        lastSendTime = now
    end
    
    if messageCount < RATE_LIMIT and #webhookQueue > 0 then
        -- Batch multiple messages into one embed
        local batch = {}
        for i = 1, math.min(5, #webhookQueue) do
            table.insert(batch, table.remove(webhookQueue, 1))
        end
        sendBatchedWebhook(batch)
        messageCount = messageCount + 1
    end
end
```
- Queue messages instead of immediate send
- Batch multiple events into single message
- Respect 30/minute limit (use 25 for safety)
- Implement exponential backoff on 429
- Allow users to configure notification frequency

**Phase to address:** Phase 2 (Webhook Feature) - Build rate limiter before any webhook code

**Detection:** Log all webhook sends; monitor for 429 responses

---

## Moderate Pitfalls

Mistakes that cause delays, poor UX, or technical debt.

### Pitfall 7: UI Blocking Main Thread

**What goes wrong:** UI updates or animations block the main Lua thread, causing game freezes and making the script obvious to anti-cheat.

**Why it happens:** Running expensive UI operations synchronously instead of using proper Roblox UI patterns.

**Prevention:**
- Use TweenService for animations (runs separately)
- Minimize UI updates (batch changes)
- Never do heavy computation in UI event handlers
- Keep UI simple - minimalist is better for performance AND stealth

**Phase to address:** Phase 2 (UI Implementation)

---

### Pitfall 8: Touch Controls Interference (Mobile)

**What goes wrong:** Script UI elements interfere with game's touch controls, or script's simulated inputs conflict with user's actual touches.

**Why it happens:** Mobile touch handling is complex; multiple systems can fight for input.

**Prevention:**
- Place UI in corners/edges away from game controls
- Make UI draggable so users can reposition
- Use small, collapsible UI
- Don't simulate touches when user is actively playing
- Implement "pause when touched" logic

**Phase to address:** Phase 2 (UI Implementation)

---

### Pitfall 9: Hardcoded Game-Specific Values

**What goes wrong:** Script breaks when game updates change object names, positions, or mechanics.

**Why it happens:** Developers hardcode paths like `game.Workspace.Eggs.Egg1` instead of using robust finding methods.

**Prevention:**
```lua
-- BAD: Hardcoded path
local egg = game.Workspace.Eggs.Egg1

-- GOOD: Flexible finding
local function findEggs()
    local eggs = {}
    for _, obj in ipairs(game.Workspace:GetDescendants()) do
        if obj.Name:match("Egg") and obj:IsA("Model") then
            table.insert(eggs, obj)
        end
    end
    return eggs
end
```
- Use pattern matching instead of exact names
- Find objects by properties/type, not just name
- Build abstraction layer for game-specific logic
- Document which values might change

**Phase to address:** Phase 1 (Architecture) - Design game abstraction layer

---

### Pitfall 10: No Error Handling for Network Failures

**What goes wrong:** Script crashes or hangs when network requests fail (loadstring, HttpGet, webhooks).

**Why it happens:** Mobile networks are unreliable; no pcall wrapping on network operations.

**Prevention:**
```lua
-- Wrap all network operations
local success, result = pcall(function()
    return game:HttpGet(url)
end)

if not success then
    warn("Network error: " .. tostring(result))
    -- Implement retry logic
end
```
- pcall ALL network operations
- Implement retry with exponential backoff
- Provide user feedback on failures
- Have fallback behaviors

**Phase to address:** Phase 1 (Core utilities)

---

## Minor Pitfalls

Annoyances that are fixable but worth avoiding.

### Pitfall 11: Obfuscated Scripts Breaking on Updates

**What goes wrong:** Heavy obfuscation makes scripts brittle and harder to debug when issues arise.

**Prevention:**
- Use light obfuscation only if needed
- Keep un-obfuscated source in version control
- Test obfuscated version separately

---

### Pitfall 12: Missing User Configuration

**What goes wrong:** Users can't customize behavior (timing, features, webhook URL), leading to complaints and requests for modifications.

**Prevention:**
- Build settings system from the start
- Store user preferences
- Allow webhook URL configuration
- Let users enable/disable features

---

### Pitfall 13: No Status Feedback

**What goes wrong:** Users don't know if script is working, stuck, or waiting.

**Prevention:**
- Show current action in UI
- Display statistics (eggs hatched, money earned)
- Indicate when paused/waiting
- Log important events

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation |
|-------|---------------|------------|
| Research | Misunderstanding game mechanics | Manually test all features before automating |
| Architecture | Memory leaks, no cleanup patterns | Design connection/cleanup system first |
| Core Auto-Farm | Inhuman timing patterns | Build randomization utilities immediately |
| Webhook Integration | Rate limiting | Implement queue before any webhook code |
| UI Development | Touch interference, thread blocking | Keep UI minimal, test on actual mobile |
| Distribution | GitHub rate limits | Use CDN mirror from day one |
| Testing | Works on PC, fails on mobile | Test on low-end Android device throughout |

---

## Byfron Anti-Cheat Considerations (2025-2026)

Roblox's Byfron anti-cheat (acquired 2023, fully deployed) adds kernel-level protection. Current state:

**What Byfron Does:**
- Obfuscates Roblox client code
- Kernel-level detection of injection
- Memory protection and integrity checks
- Detection of known executor signatures

**Why Mobile is Different:**
- Byfron primarily targets Windows/desktop
- Mobile (Android/iOS) uses different injection vectors
- Delta Executor specifically designed for mobile bypass
- Mobile anti-cheat is less aggressive (for now)

**Implications for This Project:**
- Delta Executor handles Byfron bypass - script doesn't need to
- Focus on game-level detection, not client-level
- Server-side anti-cheat (behavior analysis) is the real threat
- Keep script behavior human-like to avoid server detection

---

## Sources

**HIGH Confidence (Official/Authoritative):**
- Roblox Creator Hub - Security Tactics: https://create.roblox.com/docs/scripting/security/security-tactics
- Roblox Creator Hub - Performance Optimization: https://create.roblox.com/docs/performance-optimization/improve
- Roblox Creator Hub - Memory Usage: https://create.roblox.com/docs/studio/optimization/memory-usage
- Discord Developer Docs - Rate Limits: https://discord.com/developers/docs/topics/rate-limits
- GitHub Changelog - Rate Limit Updates (May 2025): https://github.blog/changelog/2025-05-08-updated-rate-limits-for-unauthenticated-requests

**MEDIUM Confidence (Verified Community Sources):**
- Delta Executor Troubleshooting: https://delta-executor.com/not-injecting-fix/
- Blox Fruits Anti-Detection Guide: https://bloxfruitscript.pro/how-to-avoid-getting-banned/
- RemoteEvent Security Patterns: https://scriptinghelpers.org/guides/how-to-use-remoteevents-properly
- Memory Leak Patterns: https://lualearning.org/tutorials/memory-management-amp-leaks

**LOW Confidence (Community Discussion - Validate Before Using):**
- Byfron bypass discussions (rapidly changing landscape)
- Specific game detection patterns (game-specific)
