# Research Summary: Build A Zoo Script

**Domain:** Roblox exploit script untuk game Build A Zoo  
**Researched:** January 31, 2026  
**Overall confidence:** MEDIUM-HIGH

## Executive Summary

Build A Zoo adalah game Roblox tipe pet/zoo simulator dengan gameplay loop: beli egg → place di tanah → tunggu hatch → animal produce money → collect. Script ini akan mengautomasi seluruh loop tersebut untuk mobile via Delta Executor.

Ecosystem Roblox exploit scripting sudah mature dengan tools yang established. **Rayfield** adalah UI library standar untuk mobile scripts dengan dokumentasi lengkap di docs.sirius.menu. Untuk webhook Discord, wajib menggunakan **proxy** (webhook.lewisakura.moe) karena Roblox memblokir direct Discord API calls.

Arsitektur yang direkomendasikan adalah **modular loader pattern**: satu entry point loadstring yang memuat komponen terpisah dari GitHub. Ini memudahkan maintenance dan update tanpa mengubah loadstring URL yang sudah tersebar.

Critical pitfalls yang harus diantisipasi: (1) Anti-cheat detection dari timing patterns yang inhuman - semua delay harus di-randomize 10-30%, (2) Memory leaks pada mobile yang menyebabkan crash setelah 30-60 menit farming, (3) Discord webhook rate limit 30/menit yang harus di-queue, (4) GitHub raw hosting rate limits yang memerlukan CDN fallback.

## Key Findings

**Stack:** Rayfield UI + Delta Executor + Webhook proxy (lewisakura.moe) + Modular GitHub hosting

**Architecture:** Loader → Main → Config/Services/Webhook → Core → UI, dengan RemoteEvent discovery pattern untuk adaptasi game updates

**Critical pitfall:** Inhuman timing patterns adalah detection vector utama - add 10-30% random variance ke semua delays

## Table Stakes Features
- Auto Buy Egg (pilih jenis mutasi)
- Auto Place Egg (detect tanah kosong)
- Auto Hatch (detect egg ready)
- Auto Collect Money
- Toggle on/off per feature
- Anti-AFK
- Mobile-friendly UI

## Differentiators
- Discord Webhook notifications (stats, hatches, errors)
- Modular egg types (mudah tambah via config)
- Keyless operation (tanpa key system)
- Settings persistence across sessions

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Phase 1: Foundation & Core Architecture**
   - Config module, Services wrapper, Webhook module dengan rate limiter
   - Timing utilities dengan randomization
   - Connection cleanup patterns
   - Addresses: Memory leaks, rate limiting pitfalls

2. **Phase 2: Game Discovery & Auto-Collect**
   - RemoteEvent discovery untuk Build A Zoo
   - Auto Collect Money (fitur paling sederhana, validasi arsitektur)
   - Addresses: CONT-01 dari features

3. **Phase 3: Egg System**
   - Auto Buy Egg dengan egg type selection
   - Auto Place Egg dengan plot detection
   - Auto Hatch
   - Addresses: Core loop requirements

4. **Phase 4: UI & Webhook**
   - Rayfield UI setup
   - Toggles, settings, webhook URL input
   - Notification integration
   - Addresses: UI/UX requirements

5. **Phase 5: Polish & Distribution**
   - Mobile optimization
   - Error handling
   - GitHub + CDN hosting setup
   - Documentation
   - Addresses: Distribution pitfalls

**Phase ordering rationale:**
- Foundation first karena semua komponen depend on config, services, dan utilities
- Auto-collect sebelum egg system untuk validasi arsitektur dengan fitur sederhana
- UI terakhir karena bisa dikembangkan paralel dan butuh core logic stable

**Research flags for phases:**
- Phase 2: Likely needs in-game research (RemoteEvent names, game object structure)
- Phase 3: Needs testing dengan actual Build A Zoo gameplay
- Phase 4: Standard Rayfield patterns, unlikely to need research

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Rayfield docs verified, webhook proxy documented |
| Features | HIGH | Standard pattern across pet sim scripts |
| Architecture | MEDIUM | Based on community patterns, needs validation |
| Pitfalls | MEDIUM-HIGH | Critical ones well-documented, game-specific TBD |

## Gaps to Address

- **Build A Zoo specific RemoteEvents** - Requires in-game discovery during Phase 2
- **Egg placement mechanics** - How plots work, capacity limits
- **Anti-cheat behavior** - Game-specific detection patterns
- **Exact egg types list** - Need to verify all mutation types available

## Technology Decisions (Locked)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| UI Library | Rayfield | Best mobile support, active maintenance |
| Webhook Proxy | lewisakura.moe | ToS compliant, reliable, documented |
| Hosting | GitHub + jsDelivr CDN | Free, fallback for rate limits |
| Architecture | Modular loader | Maintainable, cacheable, updatable |
| Timing | Randomized delays | Anti-detection essential |

---
*Research completed: January 31, 2026*
*Ready for roadmap creation*
