# Roadmap: Build A Zoo Script

## Overview

This roadmap delivers an end-to-end auto-farming script for Roblox's "Build A Zoo" game, running on mobile via Delta Executor. We start with infrastructure and utilities, validate with the simplest feature (auto-collect), then build the core egg system, wrap it with UI controls, and finally add Discord notifications. Each phase delivers a testable, working capability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation & Infrastructure** - Core architecture, utilities, and hosting setup
- [x] **Phase 2: Auto-Collect Money** - First auto-feature to validate architecture
- [x] **Phase 3: Egg System** - Complete egg loop (buy, place, hatch)
- [ ] **Phase 4: User Interface** - Rayfield UI with toggles and settings
- [ ] **Phase 5: Discord Integration** - Webhook notifications with proxy

## Phase Details

### Phase 1: Foundation & Infrastructure
**Goal**: Establish the modular architecture, utilities, and hosting that all features depend on
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-04, FARM-05
**Success Criteria** (what must be TRUE):
  1. Script loads successfully via loadstring() from GitHub raw URL
  2. Modular loader fetches and executes separate module files
  3. Script runs without errors on Delta Executor (mobile)
  4. Randomized timing utility produces delays with 10-30% variance
**Plans**: 2 plans (Wave 1: 01-01, Wave 2: 01-02)

Plans:
- [x] 01-01-PLAN.md — Project structure and loader entry point
- [x] 01-02-PLAN.md — Core utilities (timing, config, services)

### Phase 2: Auto-Collect Money
**Goal**: Implement first auto-feature to validate architecture works with actual game
**Depends on**: Phase 1
**Requirements**: FARM-01
**Success Criteria** (what must be TRUE):
  1. Script auto-detects animals that have money ready
  2. Script auto-collects money from all ready animals
  3. Collection uses randomized timing (not instant)
  4. Money collection works repeatedly without memory leaks
**Plans**: 2 plans (Wave 1: 02-01, Wave 2: 02-02)

Plans:
- [x] 02-01-PLAN.md — Game discovery utilities (findPlayerAnimals, isMoneyReady, findCollectRemote)
- [x] 02-02-PLAN.md — Auto-collect implementation (init/start/stop lifecycle, collection loop)

### Phase 3: Egg System
**Goal**: Complete the core farming loop - buy, place, and hatch eggs automatically
**Depends on**: Phase 2
**Requirements**: FARM-02, FARM-03, FARM-04, EGG-01, EGG-02, EGG-03
**Success Criteria** (what must be TRUE):
  1. User can select egg mutation type from available options
  2. Script auto-buys selected egg type when triggered
  3. Script auto-detects empty plots and places eggs there
  4. Script auto-hatches eggs when they're ready
  5. Egg types are stored in config file (easy to update for new mutations)
**Plans**: 3 plans (Wave 1: 03-01, Wave 2: 03-02, Wave 3: 03-03)

Plans:
- [x] 03-01-PLAN.md — Egg types config dan money detection utility
- [x] 03-02-PLAN.md — Conveyor monitor dan auto-buy implementation
- [x] 03-03-PLAN.md — Plot manager, egg hatcher, dan egg system orchestrator

### Phase 4: User Interface
**Goal**: Provide mobile-friendly controls for all auto-farm features
**Depends on**: Phase 3
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05
**Success Criteria** (what must be TRUE):
  1. Rayfield UI renders properly on mobile screen
  2. Each auto-feature has its own toggle (on/off)
  3. UI can be minimized to not block gameplay
  4. Settings persist across script sessions
  5. Stats dashboard shows eggs hatched, money collected, etc.
**Plans**: TBD

Plans:
- [ ] 04-01: Rayfield UI setup and main window
- [ ] 04-02: Feature toggles and settings persistence
- [ ] 04-03: Stats dashboard

### Phase 5: Discord Integration
**Goal**: Send notifications to user's Discord via webhook
**Depends on**: Phase 4
**Requirements**: DISC-01, DISC-02, DISC-03, DISC-04, DISC-05, INFRA-03
**Success Criteria** (what must be TRUE):
  1. User can input their webhook URL in UI settings
  2. Webhook sends periodic farming stats (configurable interval)
  3. Webhook sends notification when egg hatches
  4. Webhook sends alert when error occurs
  5. Webhook respects rate limit (max 25/minute) via queue
**Plans**: TBD

Plans:
- [ ] 05-01: Webhook module with rate limiter and proxy
- [ ] 05-02: Notification integration (stats, hatch, errors)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Infrastructure | 2/2 | ✓ Complete | 2026-01-31 |
| 2. Auto-Collect Money | 2/2 | ✓ Complete | 2026-01-31 |
| 3. Egg System | 3/3 | ✓ Complete | 2026-01-31 |
| 4. User Interface | 0/3 | Not started | - |
| 5. Discord Integration | 0/2 | Not started | - |

---
*Roadmap created: 2025-01-31*
*Total plans: 12 (estimated)*
*Total requirements: 22 mapped*
