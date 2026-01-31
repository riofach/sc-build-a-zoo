# Phase 2 Context: Auto-Collect Money

> Decisions dari diskusi dengan user — guide untuk research dan planning

## Overview

Phase ini mengimplementasikan fitur auto-collect money sebagai validasi pertama bahwa architecture Phase 1 bekerja dengan game sebenarnya.

## Keputusan yang Sudah Dikunci

### 1. Mekanisme Collection

**Prioritas: Collect All RemoteEvent**
- Coba temukan dan exploit RemoteEvent "Collect All" yang biasanya berbayar Robux
- Kalau berhasil trigger via script tanpa bayar = solusi optimal
- Ini jauh lebih efisien daripada jalan ke setiap animal

**Fallback: Per-Animal Collection**
- Jika Collect All tidak bisa di-exploit, fallback ke collect satu-satu
- Animal posisinya tetap di tempat egg di-hatch
- Collection trigger: lewat/sentuh animal (proximity-based)

### 2. Timing & Pacing

| Parameter | Value | Notes |
|-----------|-------|-------|
| Cycle interval | 60 detik (default) | Configurable di Phase 4 UI |
| Delay per animal | 0.5 detik | Hanya untuk fallback per-animal |
| Batch mode | Semua sekaligus | Tidak perlu batching |

**Randomization:** Gunakan timing utilities dari Phase 1 (20% variance default)

### 3. Error Handling

| Skenario | Behavior |
|----------|----------|
| Collect gagal | Skip, lanjut animal berikutnya |
| Retry limit | 3x per animal per cycle, lalu stop trying |
| Player teleport/loading | Script recover sendiri |
| Animal hilang (sold) | Skip tanpa notifikasi |

**Prinsip:** Santai, game tidak punya anti-cheat ketat. Prioritaskan simplicity.

### 4. Feedback ke User

| Aspek | Keputusan |
|-------|-----------|
| Counter di layar | Tidak perlu (silent) |
| Notifikasi per cycle | Tidak perlu (diam) |
| Error warning | Ya, tampilkan warning |
| Stats persistence | Reset per session (persist ditambahkan di Phase 4) |

## Yang Perlu Di-Research

### RemoteEvent Discovery (Prioritas Tinggi)
- [ ] Temukan RemoteEvent untuk Collect All
- [ ] Test apakah bisa di-fire tanpa validasi Robux
- [ ] Fallback: temukan RemoteEvent untuk collect per-animal

### Game Object Structure
- [ ] Bagaimana animals diorganisir dalam game hierarchy?
- [ ] Apa property/attribute yang menandakan animal ada money?
- [ ] Bagaimana detect semua animals milik player?

## Batasan Scope

**Dalam scope Phase 2:**
- Auto-collect money mechanism
- Cycle timing dengan randomization
- Basic error handling

**Di luar scope (phase lain):**
- UI untuk toggle on/off (Phase 4)
- UI untuk atur interval (Phase 4)
- Stats dashboard (Phase 4)
- Discord notification saat collect (Phase 5)

## Deferred Ideas

*Ide yang muncul tapi bukan untuk phase ini:*

- None

---
*Context created: 2026-01-31*
*Source: User discussion*
