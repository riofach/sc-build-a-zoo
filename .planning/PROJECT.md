# Build A Zoo Script

## What This Is

Script executor untuk game Roblox "Build A Zoo" yang berjalan di mobile via Delta Executor. Script ini mengautomasi seluruh loop gameplay: membeli egg, menempatkan di tanah, menetas, dan mengumpulkan uang dari animal. Di-host di GitHub dan diload via `loadstring()`.

## Core Value

**Auto-egg system yang berjalan end-to-end** — dari buy egg sampai collect money, tanpa perlu intervensi manual. Ini adalah loop utama yang harus bekerja sempurna.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Auto Buy Egg dengan pilihan jenis mutasi
- [ ] Auto Place Egg di tanah kosong (auto-detect)
- [ ] Auto Hatch ketika egg ready
- [ ] Auto Collect Money dari semua animal
- [ ] Webhook Discord (stats, egg hatched, error alerts)
- [ ] UI minimalis yang mobile-friendly
- [ ] Modular egg types (mudah ditambah via config)
- [ ] Loadstring compatible untuk Delta Executor

### Out of Scope

- Teleport/speed hacks — fokus ke farming system dulu
- Dupe/exploit items — terlalu berisiko ban
- Desktop-specific features — target mobile
- Complex UI seperti Chloe X — minimalis lebih prioritas

## Context

**Platform Target:**
- Mobile (Android) via Delta Executor
- Game: Build A Zoo di Roblox

**Delivery Method:**
- Host di GitHub repository
- Load via: `loadstring(game:HttpGet("https://raw.githubusercontent.com/..."))()`

**Egg Mutation Types (Known):**
- Jurassic, Golden, Diamond, Electric, Fire, Halloween
- Akan ada update baru — desain harus modular

**Gameplay Loop yang di-automate:**
1. Buy Egg (pilih mutasi) → 
2. Place di tanah kosong (auto-detect) → 
3. Wait timer → 
4. Hatch (auto) → 
5. Animal produce money → 
6. Collect money (auto)

## Constraints

- **Platform**: Mobile-first, UI harus touch-friendly
- **Executor**: Delta Executor compatibility required
- **Hosting**: GitHub raw content untuk loadstring
- **Language**: Lua/Luau (Roblox scripting)
- **Anti-detection**: Harus subtle, hindari pattern yang mudah terdeteksi

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| UI Minimalis | Mobile screen kecil, performa > estetika | — Pending |
| Modular egg config | Future-proof untuk update game | — Pending |
| GitHub hosting | Mudah update, gratis, reliable | — Pending |
| Webhook Discord | Monitoring tanpa buka game | — Pending |

---
*Last updated: 2025-01-31 after initialization*
