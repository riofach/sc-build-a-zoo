# Feature Landscape: Roblox Auto-Farming Scripts

**Domain:** Roblox exploit scripts for pet/zoo simulation games  
**Researched:** January 31, 2026  
**Target Platform:** Mobile (Delta Executor)  
**Game:** Build A Zoo

## Table Stakes

Features users expect. Missing = script feels incomplete and users will leave for alternatives.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Auto Buy Egg** | Core automation - eliminates repetitive clicking on egg shop | Low | Game API hooks | Must handle different egg tiers/rarities |
| **Auto Place Egg** | Essential flow - eggs must be placed on plot to hatch | Low | Auto Buy Egg | Need to find available plot spaces |
| **Auto Hatch** | Completes the egg cycle - users expect full automation | Low | Auto Place Egg | Detect when eggs are ready |
| **Auto Collect Money** | Primary resource loop - cash collection is tedious manually | Low | None | Most basic feature, often first implemented |
| **Toggle On/Off** | Users need control over automation | Low | UI Framework | Individual toggles per feature expected |
| **Anti-AFK** | Mobile sessions get kicked after 20 mins idle | Low | None | Prevents Roblox's built-in idle kick |
| **Mobile-Friendly UI** | Delta Executor is mobile-first | Medium | UI Library selection | Touch-friendly buttons, readable on small screens |
| **Minimizable/Draggable UI** | Don't obstruct gameplay view | Medium | UI Framework | Critical for mobile where screen space is limited |

## Differentiators

Features that set script apart from competition. Not expected, but valued highly.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **Discord Webhook Notifications** | Remote monitoring - know when rare pets hatched, money milestones | Medium | HTTP request capability | High value for overnight farming; embeds with pet info |
| **Auto Upgrade System** | Automatically spend money on upgrades when thresholds met | Medium | Auto Collect Money | Needs game-specific upgrade detection |
| **Smart Egg Selection** | Prioritize rare eggs based on user preference | Medium | Auto Buy Egg | Configuration UI needed |
| **Inventory Management** | Auto-sell/delete low-tier pets to free space | High | Game inventory API | Prevents inventory full blocking |
| **Statistics Dashboard** | Track earnings, hatches, rare drops over time | Medium | All auto features | Local storage or webhook logging |
| **Configurable Delays** | Adjust speed to avoid detection | Low | All features | Slider controls in UI |
| **Save/Load Settings** | Persist user preferences across sessions | Medium | All toggles | DataStore or file system |
| **Keyless Operation** | No key system = instant use | Low | None | Major UX differentiator - most scripts require keys |
| **Multi-Plot Support** | Handle multiple zoo plots if game supports | High | Auto Place Egg | Game-specific feature detection |
| **Auto Rebirth/Prestige** | Automate prestige mechanics if game has them | Medium | Money tracking | Game-specific implementation |

## Anti-Features

Features to explicitly NOT build. Common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Infinite Money Exploit** | Server-sided values can't be hacked client-side; fake scripts claiming this are scams/malware | Focus on legitimate automation that speeds up real gameplay |
| **Pet Duplication** | Server-authoritative - doesn't work, damages credibility | Build reliable automation, not impossible hacks |
| **Speed Hacks** | Easily detected, leads to bans | Use configurable delays that mimic human behavior |
| **Teleport Exploits** | Not needed for zoo games, adds detection risk | Keep script focused on automation only |
| **Complex Key Systems** | Frustrates users, adds friction | Go keyless or use simple one-time verification |
| **Bloated Feature Set** | Too many features = slow, buggy, hard to maintain | Focus on core loop: buy -> place -> hatch -> collect |
| **Obfuscated Code** | Users distrust it (potential malware), harder to debug | Keep code readable, build trust |
| **Auto-Execute on Join** | Unexpected behavior, can cause issues | Let user manually start script |
| **Aggressive Farming Speeds** | Looks bot-like, triggers anti-cheat | Add randomized delays between actions |

## Feature Dependencies

```
[UI Framework] (foundation for everything)
     |
     v
[Toggle System] --> [Save/Load Settings]
     |
     v
[Anti-AFK] (standalone, no deps)
     |
     +---> [Auto Collect Money] (no deps on other features)
     |
     +---> [Auto Buy Egg] 
               |
               v
          [Auto Place Egg] --> [Smart Egg Selection]
               |
               v
          [Auto Hatch] --> [Discord Webhook] (notify on hatch)
               |
               v
          [Auto Upgrade] (uses collected money)
               |
               v
          [Inventory Management] (cleanup after hatching)
               |
               v
          [Statistics Dashboard] (tracks all above)
```

## MVP Recommendation

For MVP, prioritize in this order:

### Phase 1: Core Loop (Must Ship)
1. **UI Framework Setup** - Mobile-friendly, minimizable (use Kavo UI or similar)
2. **Anti-AFK** - Prevents idle kick
3. **Auto Collect Money** - Most requested, immediate value
4. **Auto Buy Egg** - Start the automation cycle
5. **Auto Place Egg** - Complete placement automation
6. **Auto Hatch** - Finish the core loop
7. **Toggle System** - Per-feature on/off controls

### Phase 2: Quality of Life
8. **Discord Webhook** - Remote monitoring (differentiator)
9. **Configurable Delays** - User control over speed
10. **Save/Load Settings** - Persist across sessions

### Defer to Post-MVP
- **Smart Egg Selection**: Requires understanding egg tier system, adds complexity
- **Auto Upgrade**: Game-specific, needs reverse engineering
- **Inventory Management**: Complex, potential for bugs
- **Statistics Dashboard**: Nice-to-have, not core value
- **Multi-Plot Support**: Only if game actually supports it

## UI/UX Feature Details

### Required UI Components
| Component | Purpose | Priority |
|-----------|---------|----------|
| Window (draggable) | Container for all controls | Critical |
| Minimize button | Hide UI when not needed | Critical |
| Toggle switches | Enable/disable each feature | Critical |
| Status labels | Show current state (running/stopped) | High |
| Notification system | Feedback on actions | Medium |
| Settings tab | Delays, webhook URL, preferences | Medium |

### Recommended UI Libraries (Mobile Compatible)
| Library | Mobile Support | Notes |
|---------|---------------|-------|
| Kavo UI | Yes (with mobile fork) | Popular, well-documented |
| Orion Lib | Partial | May need touch adjustments |
| Rayfield | Yes | Modern look, good mobile support |
| DRAXUI | Yes | ImGui-inspired, responsive |

**Recommendation:** Use Kavo UI Mobile fork for best Delta Executor compatibility.

## Safety Features Details

### Anti-Detection Measures
| Feature | Implementation | Complexity |
|---------|---------------|------------|
| Randomized delays | Add 0.5-2s random wait between actions | Low |
| Human-like patterns | Don't perform actions in exact sequences | Medium |
| Rate limiting | Cap actions per minute | Low |
| Error handling | Graceful failure, don't spam errors | Low |

### Anti-Kick Protection
| Feature | What It Does | Notes |
|---------|-------------|-------|
| Anti-AFK | Simulates activity to prevent idle kick | Essential for overnight farming |
| Anti-Kick hook | Blocks client-side kick attempts | Only works for client kicks, not server |
| Reconnect logic | NOT recommended - complex, unreliable | Defer or skip |

## Complexity Summary

| Complexity | Features |
|------------|----------|
| **Low** | Anti-AFK, Auto Collect, Toggle System, Delays, Keyless |
| **Medium** | UI Framework, Auto Buy/Place/Hatch, Discord Webhook, Save/Load, Egg Selection |
| **High** | Inventory Management, Multi-Plot, Statistics Dashboard, Auto Upgrade |

## Sources

- MobileMaters.gg Build A Zoo scripts guide (Jan 2026) - HIGH confidence
- GitHub Pet Simulator X script repositories - MEDIUM confidence
- Delta Executor official documentation - HIGH confidence
- rscripts.net Discord webhook modules - MEDIUM confidence
- Kavo UI Library documentation - HIGH confidence
- Community YouTube tutorials - LOW confidence (verified patterns only)

## Confidence Assessment

| Area | Confidence | Reason |
|------|------------|--------|
| Core auto-farming features | HIGH | Multiple sources confirm standard feature set |
| UI library recommendations | HIGH | Kavo/Orion well-documented, verified mobile support |
| Discord webhook integration | HIGH | Multiple working examples found |
| Anti-detection strategies | MEDIUM | Community patterns, not officially documented |
| Game-specific mechanics | LOW | Build A Zoo specific APIs need reverse engineering |
