# Phase 3 Context: Egg System

> Keputusan yang sudah dikunci untuk Phase 3. Downstream agents (researcher, planner) mengikuti ini tanpa perlu tanya ulang.

## Overview

Phase ini mengimplementasikan **complete egg loop**: monitor conveyor → auto-buy mutasi target → auto-place ke plot kosong → auto-hatch saat ready.

---

## Locked Decisions

### 1. Conveyor & Egg Selection

| Keputusan | Detail |
|-----------|--------|
| **Selection mode** | Single mutasi saja (bukan multi-select) |
| **Detection method** | Baca teks nama mutasi di atas egg di conveyor |
| **Egg availability** | ~5 detik per egg sebelum diganti |
| **Harga** | Berbeda per mutasi, cek uang cukup sebelum beli |

**Behavior:**
- User pilih 1 tipe mutasi (contoh: "Christmas", "Electric")
- Script monitor conveyor terus-menerus
- Saat egg dengan mutasi target muncul → cek uang → beli jika cukup
- Jika mutasi target muncul berturut-turut, beli semua selama uang cukup

### 2. Auto-Buy Flow

| Keputusan | Detail |
|-----------|--------|
| **Trigger** | Mutasi target muncul di conveyor + uang cukup |
| **Cooldown** | Tidak ada cooldown antar pembelian |
| **Post-buy state** | Egg muncul "di tangan" player |
| **Buy method** | Samperin conveyor → interact dengan egg → buy |

**Behavior:**
- Tidak ada limit pembelian per cycle
- Jika uang tidak cukup, skip (bukan error)
- Setelah beli, egg harus di-place sebelum bisa beli lagi

### 3. Plot Management

| Keputusan | Detail |
|-----------|--------|
| **Plot location** | Fixed di wilayah player (setiap player punya area sendiri) |
| **Kapasitas** | ~50 animal/egg per area |
| **Empty detection** | Detect tombol "Place" yang muncul saat pegang egg dekat plot kosong |
| **Urutan** | Tidak ada urutan spesifik, isi plot kosong manapun yang terdetect |

**Behavior:**
- Scan semua plot di wilayah player
- Detect mana yang kosong (ada tombol Place)
- Place egg ke slot kosong manapun yang ditemukan pertama

### 4. Auto-Hatch

| Keputusan | Detail |
|-----------|--------|
| **Ready indicator** | Tanda seru merah (efek visual) di atas egg |
| **Hatch trigger** | Tombol "Hatch" muncul saat mendekati egg ready |
| **Waktu inkubasi** | Bervariasi (detik sampai 8 jam), pakai auto-detect |
| **Batch behavior** | Hatch satu-satu dengan delay (bukan sekaligus) |
| **Post-hatch** | Animal langsung muncul di plot yang sama |

**Behavior:**
- Scan eggs yang sudah ready (ada indicator/tombol Hatch)
- Hatch satu per satu dengan randomized delay
- Animal otomatis occupy plot setelah hatch

---

## Implementation Notes

### Detection Patterns (untuk Research)

| Object | Detection Hint |
|--------|----------------|
| Conveyor eggs | Cari teks nama mutasi di atas egg object |
| Egg price | UI element saat interact dengan egg |
| Player money | Likely ada di leaderstats atau PlayerGui |
| Empty plots | Tombol "Place" yang muncul contextual |
| Ready eggs | Efek visual (tanda seru) atau tombol "Hatch" |

### Flow Sequence

```
[LOOP START]
  │
  ├─► Monitor Conveyor
  │     └─► Mutasi target muncul?
  │           ├─► Ya + Uang cukup → Buy egg
  │           └─► Tidak → Continue monitoring
  │
  ├─► Jika holding egg
  │     └─► Find empty plot → Place egg
  │
  ├─► Scan placed eggs
  │     └─► Ada yang ready hatch?
  │           └─► Ya → Hatch satu-satu dengan delay
  │
  └─► Delay → [LOOP START]
```

---

## Out of Scope (Deferred)

- Multi-mutasi selection (future enhancement)
- Plot prioritization/ordering (keep simple)
- Hatch notification ke Discord (Phase 5)
- UI untuk pilih mutasi (Phase 4)

---

## Config Requirements

Script harus support config untuk:
- `targetMutation`: string — nama mutasi yang di-track
- `eggTypes`: table — daftar mutasi yang tersedia (untuk validasi)

---

*Context locked: 2026-01-31*
*Ready for: /gsd-research-phase 3 atau /gsd-plan-phase 3*
