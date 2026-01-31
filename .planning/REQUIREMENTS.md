# Requirements: Build A Zoo Script

**Defined:** 2025-01-31  
**Core Value:** Auto-egg system yang berjalan end-to-end — dari buy egg sampai collect money, tanpa perlu intervensi manual

## v1 Requirements

Requirements untuk initial release. Setiap requirement akan di-map ke phases di roadmap.

### Auto-Farming

- [ ] **FARM-01**: Script dapat auto-collect money dari semua animal yang ada di zoo
- [ ] **FARM-02**: Script dapat auto-buy egg dengan jenis mutasi yang dipilih user via dropdown UI
- [ ] **FARM-03**: Script dapat auto-detect tanah/plot kosong dan auto-place egg di sana
- [ ] **FARM-04**: Script dapat auto-hatch egg yang sudah ready untuk dipecahkan
- [ ] **FARM-05**: Semua auto-actions menggunakan randomized timing (10-30% variance) untuk anti-detection

### Egg System

- [ ] **EGG-01**: User dapat memilih jenis egg mutation via dropdown selector di UI
- [ ] **EGG-02**: Egg types tersimpan dalam config yang mudah di-update untuk future mutations
- [ ] **EGG-03**: Script mendeteksi kapan egg ready untuk hatch berdasarkan game state

### User Interface

- [ ] **UI-01**: UI menggunakan Rayfield library dengan mobile-friendly design
- [ ] **UI-02**: Setiap fitur auto-farm memiliki toggle on/off terpisah
- [ ] **UI-03**: UI dapat diminimalkan untuk tidak menghalangi gameplay
- [ ] **UI-04**: Settings tersimpan dan persist across sessions (config file)
- [ ] **UI-05**: UI menampilkan stats dashboard (eggs hatched, money collected, dll)

### Discord Integration

- [ ] **DISC-01**: User dapat input webhook URL sendiri via UI settings
- [ ] **DISC-02**: Webhook mengirim notifikasi stats farming secara periodik
- [ ] **DISC-03**: Webhook mengirim notifikasi saat egg berhasil hatch
- [ ] **DISC-04**: Webhook mengirim alert saat terjadi error
- [ ] **DISC-05**: Webhook menggunakan rate limiter (max 25/menit) untuk mencegah Discord ban

### Infrastructure

- [ ] **INFRA-01**: Script di-host di GitHub dengan loadstring entry point
- [ ] **INFRA-02**: Arsitektur modular (loader → modules) untuk easy updates
- [ ] **INFRA-03**: Webhook menggunakan proxy (lewisakura.moe) untuk bypass Roblox block
- [ ] **INFRA-04**: Script kompatibel dengan Delta Executor di mobile

## v2 Requirements

Deferred to future release. Tracked tapi tidak di current roadmap.

### Auto-Farming Advanced

- **FARM-06**: Auto Upgrade - spend money otomatis untuk upgrades saat threshold tercapai
- **FARM-07**: Smart Egg Selection - prioritas egg berdasarkan rarity/value
- **FARM-08**: Inventory Management - auto-sell low-tier pets untuk free space

### Safety Advanced

- **SAFE-01**: Anti-AFK - prevent idle kick dari Roblox
- **SAFE-02**: Auto-reconnect - reconnect otomatis jika disconnect

### UI Advanced

- **UI-06**: Minimizable to floating button
- **UI-07**: Theme customization

## Out of Scope

Explicitly excluded. Documented untuk prevent scope creep.

| Feature | Reason |
|---------|--------|
| Infinite Money Exploit | Server-sided, tidak mungkin dilakukan client-side |
| Pet Duplication | Server-authoritative, akan merusak kredibilitas |
| Speed Hacks | Easily detected, leads to bans |
| Teleport Exploits | Tidak diperlukan untuk zoo game, tambah detection risk |
| Complex Key System | Frustrating UX, target keyless operation |
| Desktop-specific features | Target mobile-first |
| Obfuscated code | Sulit debug, user distrust |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FARM-01 | Phase 2 | Complete |
| FARM-02 | Phase 3 | Pending |
| FARM-03 | Phase 3 | Pending |
| FARM-04 | Phase 3 | Pending |
| FARM-05 | Phase 1 | Complete |
| EGG-01 | Phase 3 | Pending |
| EGG-02 | Phase 3 | Pending |
| EGG-03 | Phase 3 | Pending |
| UI-01 | Phase 4 | Pending |
| UI-02 | Phase 4 | Pending |
| UI-03 | Phase 4 | Pending |
| UI-04 | Phase 4 | Pending |
| UI-05 | Phase 4 | Pending |
| DISC-01 | Phase 5 | Pending |
| DISC-02 | Phase 5 | Pending |
| DISC-03 | Phase 5 | Pending |
| DISC-04 | Phase 5 | Pending |
| DISC-05 | Phase 5 | Pending |
| INFRA-01 | Phase 1 | Complete |
| INFRA-02 | Phase 1 | Complete |
| INFRA-03 | Phase 5 | Pending |
| INFRA-04 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22 ✓
- Unmapped: 0

---
*Requirements defined: 2025-01-31*
*Last updated: 2025-01-31 after roadmap creation (traceability updated)*
