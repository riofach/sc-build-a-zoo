---
phase: 03-egg-system
plan: 02
subsystem: automation
tags: [roblox, lua, conveyor, egg-detection, auto-buy, anti-detection]

# Dependency graph
requires:
  - phase: 03-01
    provides: EggTypes config, Money detection module
provides:
  - Event-based conveyor egg detection via DescendantAdded
  - Auto-buy with pre-check anti-detection (canAfford, isHoldingEgg)
  - ConveyorMonitor -> EggBuyer callback integration
affects: [03-03 egg-system orchestrator, ui integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Event-based detection via DescendantAdded (not polling)
    - Pre-check pattern for anti-detection before remote fire
    - Multi-method discovery (10+ path patterns for conveyor, 15+ for buy remote)
    - 4-tier holding egg detection (character, attributes, GUI)
    - Callback integration pattern (ConveyorMonitor -> EggBuyer)

key-files:
  created:
    - features/conveyor-monitor.lua
    - features/egg-buyer.lua
  modified: []

key-decisions:
  - "DescendantAdded for real-time detection (not polling)"
  - "3 mandatory pre-checks before any remote fire"
  - "4 argument patterns for buy remote compatibility"
  - "StreamingEnabled compatibility with WaitForChild timeout"

patterns-established:
  - "Event-based detection: Use DescendantAdded for real-time object detection"
  - "Pre-check anti-detection: ALWAYS validate conditions before firing remotes"
  - "Discovery fallback: Auto-discovery with 10+ common path patterns"

# Metrics
duration: 4min
completed: 2026-01-31
---

# Phase 03 Plan 02: Conveyor Monitoring & Egg Buyer Summary

**Event-based conveyor egg detection with auto-buy pre-check anti-detection, integrating ConveyorMonitor callback to EggBuyer for target mutation purchases**

## Performance

- **Duration:** 4 min
- **Started:** 2026-01-31T08:59:21Z
- **Completed:** 2026-01-31T09:03:24Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments
- Conveyor monitor with event-based detection via DescendantAdded
- Auto-buy with 3 mandatory pre-checks (holding, afford, remote)
- Integration: ConveyorMonitor callback triggers EggBuyer.buyEgg
- Multi-method discovery patterns for both conveyor and buy remote
- StreamingEnabled compatibility with WaitForChild timeout

## Task Commits

Each task was committed atomically:

1. **Task 1: Create conveyor-monitor.lua module** - `2efd458` (feat)
2. **Task 2: Create egg-buyer.lua module** - `9065a1e` (feat)

## Files Created/Modified
- `features/conveyor-monitor.lua` - Event-based conveyor egg detection with target mutation filtering
- `features/egg-buyer.lua` - Auto-buy with pre-check anti-detection and ConveyorMonitor integration

## What Was Built

### features/conveyor-monitor.lua
- **Event-based detection**: Uses DescendantAdded (not polling) for real-time egg detection
- **Auto-discovery**: 10 common conveyor path patterns with fallback search
- **Target filtering**: Case-insensitive mutation name matching
- **StreamingEnabled**: WaitForChild with 3s timeout for BillboardGui
- **Exports**: init, setTargetMutation, start, stop, getConveyorEggs

### features/egg-buyer.lua
- **Pre-check anti-detection** (CRITICAL):
  1. Check not already holding egg
  2. Check canAfford via Money.canAfford()
  3. Validate buy remote exists
- **Remote discovery**: 15 common patterns for buy RemoteEvent
- **4 argument patterns**: egg instance, mutation name, both, none
- **Holding detection**: 4 methods (character children, attributes, GUI text)
- **Integration**: ConveyorMonitor callback triggers _onTargetEggFound
- **Exports**: init, start, stop, isHoldingEgg, buyEgg

### Key Integration Flow
```
ConveyorMonitor.start(callback)
    → DescendantAdded detects egg
    → _checkEgg reads BillboardGui TextLabel
    → If matches target mutation → callback(egg, mutationName)
    
EggBuyer.start()
    → Sets callback on ConveyorMonitor
    → _onTargetEggFound(egg, mutationName)
    → Pre-checks (holding, afford, remote)
    → buyEgg with timing variance
```

## Decisions Made
- **DescendantAdded over polling**: Event-based is more efficient and responsive
- **3 mandatory pre-checks**: Required for anti-detection (never fire without validation)
- **4 argument patterns**: Game may expect different remote signatures
- **WaitForChild timeout**: 3 seconds for StreamingEnabled compatibility

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- ConveyorMonitor and EggBuyer ready for orchestrator integration
- Plan 03-03 will create egg-system.lua orchestrator
- UI integration can call EggBuyer.setTargetMutation() and start()

---
*Phase: 03-egg-system*
*Plan: 02*
*Completed: 2026-01-31*
