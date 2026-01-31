---
phase: "03"
plan: "01"
subsystem: egg-system
tags: [config, utility, money, egg-types]
dependency_graph:
  requires: [01-foundation]
  provides: [egg-types-config, money-detection]
  affects: [03-02-egg-buyer, 03-03-egg-placer]
tech_stack:
  added: []
  patterns: [lookup-cache, multi-source-detection, pcall-safety]
key_files:
  created:
    - config/egg-types.lua
    - core/money.lua
  modified:
    - core/init.lua
decisions:
  - id: EGG-01
    choice: "6 default mutation types with addType() for extensibility"
    reason: "Known types from research, easy to add new ones"
  - id: EGG-02
    choice: "Case-insensitive lookup with cache"
    reason: "User input may vary in casing, O(1) access after first use"
  - id: EGG-03
    choice: "3-tier money detection (leaderstats, attributes, GUI)"
    reason: "Games use different storage methods, prioritize common patterns"
  - id: EGG-04
    choice: "10 common currency names for detection"
    reason: "Cover most games without being exhaustive"
metrics:
  duration: 4min
  completed: 2026-01-31
---

# Phase 03 Plan 01: Egg Types Config & Money Detection Summary

Multi-source money detection with getPlayerMoney() and canAfford() helpers, plus egg types config with 6 mutations and extensibility via addType()

## Completed Tasks

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create egg-types.lua config module | 8f67222 | config/egg-types.lua |
| 2 | Create money.lua utility module | 751df08 | core/money.lua, core/init.lua |

## What Was Built

### config/egg-types.lua
- **EggTypes.Types table**: 6 known mutations (Normal, Shiny, Electric, Christmas, Radioactive, Mythic)
- **getNames()**: Returns array of mutation names for UI dropdown
- **getPrice(name)**: Case-insensitive price lookup with O(1) cache
- **isValid(name)**: Validates mutation name exists
- **addType(name, price)**: Add/update mutations at runtime
- **getAll()**: Returns all types as array for iteration

### core/money.lua
- **getPlayerMoney()**: Returns (amount, source) tuple
  - Priority 1: leaderstats (10 common names)
  - Priority 2: Player attributes
  - Priority 3: PlayerGui text scan ($ patterns)
- **canAfford(price)**: Simple boolean helper for pre-checks
- **watchMoney(callback)**: Subscribe to money changes
- **debug()**: Print current detection result

### core/init.lua
- Added Money module to Core aggregator
- Access via `Core.Money.getPlayerMoney()`

## Decisions Made

| ID | Decision | Rationale |
|----|----------|-----------|
| EGG-01 | 6 default mutations with addType() extensibility | Known types from research, easy to add new ones |
| EGG-02 | Case-insensitive lookup with cache | User input may vary, O(1) after first use |
| EGG-03 | 3-tier detection priority | Games use different storage, prioritize common patterns |
| EGG-04 | 10 common currency names | Cover most games without exhaustive list |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

- [x] config/egg-types.lua exists
- [x] core/money.lua exists
- [x] Both modules follow existing codebase patterns
- [x] All functions wrapped in pcall for safety
- [x] Money module registered in core/init.lua

## Next Phase Readiness

### Ready for Plan 02 (egg-buyer)
- `EggTypes.getPrice(mutation)` available for cost lookup
- `Money.canAfford(price)` available for pre-check before buy
- Integration pattern: `local EggTypes = require("config/egg-types")`

### Dependencies Provided
- **config/egg-types.lua** exports: `EggTypes`, `getNames`, `getPrice`, `isValid`, `addType`
- **core/money.lua** exports: `getPlayerMoney`, `canAfford`, `watchMoney`

### Known Limitations
- Egg prices are estimates (need in-game validation)
- GUI money detection limited to 5 levels deep
- watchMoney only works with leaderstats (not attributes/GUI)
