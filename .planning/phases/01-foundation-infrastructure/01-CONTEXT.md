# Phase 1: Foundation & Infrastructure - Context

**Gathered:** 2025-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish the modular architecture, utilities, and hosting that all features depend on. This includes the loader system, core utilities (timing, config, services), and GitHub hosting setup. No actual auto-farming features — just the foundation they build upon.

</domain>

<decisions>
## Implementation Decisions

### Module Organization
- Grouped by type: `core/`, `features/`, `ui/` subfolders
- Single entry point via one loadstring() call — loader fetches all other modules automatically
- Hosted on GitHub raw URLs

### Configuration Approach
- All settings are configurable: feature toggles, timing settings, webhook URL, egg preferences
- Separate egg config file for mutation types (easy to update when game adds new eggs)
- Sensible defaults — script works out of the box without requiring initial setup

### Error Handling Philosophy
- Retry then notify: retry silently a few times, then notify user if still failing
- Isolate failures: if one feature fails, pause that feature but keep others running
- Show errors both in-game (notification) and in console
- Log errors for debugging/troubleshooting

### Script Initialization
- Progress indicator during load ("Loading modules...")
- Wait for user to enable features via UI after loading (no auto-start)
- Auto-detect game — work in any Build A Zoo server
- Open UI only as confirmation of successful load (no splash or extra messages)

### Claude's Discretion
- Module loading strategy (lazy vs upfront) — decide based on performance tradeoffs
- Settings storage approach — decide what works best for Delta Executor
- Exact retry count and timing for failed requests
- Progress indicator visual style

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for Roblox scripting.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-infrastructure*
*Context gathered: 2025-01-31*
