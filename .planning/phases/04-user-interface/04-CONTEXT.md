# Phase 4 Context: User Interface

## Overview

Phase ini membangun Rayfield UI untuk kontrol semua fitur auto-farm di mobile. UI harus compact, intuitif, dan tidak mengganggu gameplay.

## Locked Decisions

### Layout & Navigasi Window

| Aspek | Keputusan | Alasan |
|-------|-----------|--------|
| Jumlah tab | 5 tab: Collect, Eggs, Stats, Settings, About | Detail navigation untuk akses cepat per-fitur |
| Urutan tab | Collect → Eggs → Stats → Settings → About | Auto-Collect paling sering dipakai, di depan |
| Ukuran window | Compact | Minimize screen real estate di mobile |
| Posisi default | Kiri atas (Rayfield default) | Familiar position |
| Draggable | Ya | User bisa pindahkan sesuai preferensi |

### Toggle & Kontrol Fitur

| Fitur | Kontrol | Detail |
|-------|---------|--------|
| Auto-Collect | Toggle + Interval slider | Slider untuk set "collect every X seconds" |
| Egg System | Toggle master on/off | Satu toggle untuk buy + place + hatch sekaligus |
| Mutation type | Dropdown di tab Eggs | Pilih mutation sebelum aktifkan Egg System |
| Default state | Auto-Collect ON, Egg System OFF | Langsung collect saat script start |
| Stop behavior | Immediate stop | Cancel proses yang sedang jalan saat toggle off |

### Stats Dashboard

| Aspek | Keputusan |
|-------|-----------|
| Metrics | Money collected, Eggs hatched (2 angka basic) |
| Reset timing | Session-based (reset setiap script start) |
| Format angka | Angka penuh dengan separator: 1,250,000 |
| Update frequency | Periodic (bukan real-time) |

### Visual States & Feedback

| Aspek | Keputusan |
|-------|-----------|
| Toggle indicator | Warna saja (hijau aktif, abu nonaktif) |
| Error notification | Subtle — error count di Stats tab |
| Event notification | Subtle — stats number flash/highlight |
| Script status | Ditampilkan di tab About |

## Implementation Boundaries

### In Scope
- Rayfield window dengan 5 tab
- Toggle controls untuk Auto-Collect dan Egg System
- Interval slider untuk Auto-Collect
- Dropdown mutation type untuk Egg System
- Stats display (money + eggs)
- Settings persistence (save/load config)
- Minimize/drag functionality

### Out of Scope (Deferred)
- Per-animal filter untuk collect
- Per-phase toggle untuk Egg System (buy/place/hatch terpisah)
- Lifetime stats (akumulasi lintas session)
- Toast notifications untuk setiap event
- Detailed stats breakdown per mutation

## Technical Notes

- Rayfield library sudah dipilih dari research phase
- Lazy loading via metatable untuk prevent executor timeout
- Settings persistence menggunakan config system dari Phase 1

## Tab Structure

```
[Collect] [Eggs] [Stats] [Settings] [About]

Tab Collect:
├── Toggle: Auto-Collect [ON/OFF]
└── Slider: Interval (X seconds)

Tab Eggs:
├── Dropdown: Mutation Type
└── Toggle: Egg System [ON/OFF]

Tab Stats:
├── Label: Money Collected: X
└── Label: Eggs Hatched: X

Tab Settings:
├── (Future: Discord webhook URL)
└── (Future: Other settings)

Tab About:
├── Script status: Running/Paused/Error
├── Version info
└── Credits
```

## Success Metrics

1. UI renders tanpa error di Delta Executor mobile
2. Toggle berfungsi on/off untuk kedua fitur
3. Interval slider mengubah collect frequency
4. Stats update periodic saat fitur aktif
5. Settings tersimpan dan load saat restart
6. Window bisa di-minimize dan di-drag

---
*Context created: 2026-01-31*
*Decisions locked for Phase 4 planning*
