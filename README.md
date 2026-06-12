# Hammer Claw Skills Lab

> 🔨 The skills marketplace for Hammer Miner ecosystem — mining × AI, forged in hardware.

## Relationship to ESP-Claw Skills Lab

This project is **forked and heavily modified** from [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab) (MIT License).

| Dimension | esp-claw-skills-lab | hammer-claw-skills-lab |
|-----------|---------------------|------------------------|
| **Target Hardware** | ESP32-S3/C5/C6 general dev boards | **BC08-P4** (ESP32-P4+C6+8×BM1370), **Pockt** |
| **Ecosystem** | General IoT AI Agent | **Mining + AI ecosystem** |
| **Unique Capabilities** | camera, imu, gpio, i2c sensors | **Hashrate control, voltage/freq tuning, chip thermal mgmt, pool switching, fan policy** |
| **Skill Categories** | game, utility, hardware, media, network, sensor, ai | ➕ **mining**, retains game/utility/ai |
| **Peripherals** | camera, led, motor, speaker, display, button... | ➕ **asic, fan, hashoard, psu, temp_sensor, vreg, argb_led** |
| **Install Method** | Device LLM via skills_lab_downloader skill | ✅ Fully compatible |
| **Frontend** | Standalone website skills-lab.esp-claw.com | **Device factory page** (LVGL native, read-only) |

### Code Provenance

```
├── Inherited from esp-claw-skills-lab (MIT License):
│   ├── build/vite-plugin-skills.ts      → Skill metadata scanning & generation
│   ├── scripts/validate-skills.ts       → Skill format validation
│   ├── src/config/allowlist.ts          → Category/peripheral allowlists (extended)
│   ├── src/types/                       → TypeScript type definitions
│   ├── src/utils/                       → Utility functions
│   └── Vue 3 + Vite + TypeScript architecture
│
├── Hammer Customizations:
│   ├── src/config/allowlist.ts          → Added mining category, miner peripherals
│   ├── src/assets/                      → Hammer brand assets
│   ├── skills/                          → Miner-exclusive skills + curated official imports
│   └── On-device factory page (LVGL C native)
│
└── Reusable Official Skills (skills/):
    ├── flappybird/          ← Game
    ├── current_weather/     ← Weather
    ├── current_ip_info/     ← Network info
    ├── dino/                ← Dino game
    └── ... (filtered by hardware compatibility)
```

---

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│  hammer-claw-skills-lab (GitHub repo)                        │
│                                                             │
│  skills/                     build/           src/          │
│  ├── miner_dashboard/        vite-plugin  →   generated/    │
│  ├── miner_overclock/        skills.ts        skills-data   │
│  ├── pool_switcher/             │              .json         │
│  ├── fan_control/               │              tags.json     │
│  ├── flappybird/   ← imported   │                            │
│  └── ...                        ▼                            │
│                          npm run build                       │
│                          ┌──────────┐                        │
│                          │  dist/   │  ← Static site output  │
│                          │  raw/    │  ← Skill source mirror │
│                          └──────────┘                        │
└─────────────────────────────────────────────────────────────┘
         │                              │
         │ ① Skill install (device LLM) │ ② Factory page (LVGL C)
         ▼                              ▼
┌─────────────────┐          ┌──────────────────────────┐
│  BC08-P4 Device  │          │  BC08-P4 Factory Page     │
│                 │          │  (LVGL Native Page 7)     │
│  skills_lab_    │          │                          │
│  downloader     │          │  ┌────────────────────┐   │
│  pulls skill    │          │  │ Hammer Skills Lab  │   │
│  files          │          │  │ ────────────────── │   │
│  → /fatfs/      │          │  │ ⛏ Miner Dashboard  │   │
│    skills/      │          │  │ ⚡ Overclock Guide  │   │
│                 │          │  │ 🌀 Fan Control     │   │
│                 │          │  │ 🌊 Pool Switcher   │   │
│                 │          │  │ 🎮 Flappy Bird     │   │
│                 │          │  │ ☀️ Current Weather  │   │
│                 │          │  │ ...                │   │
│                 │          │  │          [Install] │   │
│                 │          │  └────────────────────┘   │
│                 │          │                          │
│                 │          │  Data: dist/skills-      │
│                 │          │  data.json (embedded)     │
└─────────────────┘          └──────────────────────────┘
```

---

## Skill Categories

### New `mining` category

```typescript
// src/config/allowlist.ts (Hammer extended)
export const ALLOWED_CATEGORIES = [
  'mining',    // 🆕 Mining exclusive
  'game',      // Retained
  'utility',   // Retained
  'hardware',  // Retained
  'ai',        // Retained
  'network',   // Retained
  'media',     // Retained
  'sensor',    // Retained
] as const;

export const ALLOWED_PERIPHERALS = [
  // Hammer miner specific
  'asic',              // BM1370 ASIC chips
  'fan',               // Cooling fan
  'hashboard',         // Hash board
  'psu',               // Power supply (TPS546)
  'temp_sensor',       // Temperature sensor (TMP75)
  'vreg',              // Voltage regulator
  'argb_led',          // WS2812B LED strip
  'frequency_controller', // Frequency controller
  // Retained from official
  'display',
  'button',
  'led',
  'camera',
  'speaker',
  'microphone',
  'motor',
  'gpio',
  'battery',
  'ir',
  'servo',
  'ws2812',
] as const;
```

---

## Planned Skills

### 🔨 Miner Exclusive (New)

| Skill ID | Title | Requires | Cap Groups | Description |
|----------|-------|----------|------------|-------------|
| `miner_dashboard` | Miner Dashboard | asic, fan, temp_sensor | cap_miner | Real-time hashrate/temp/revenue panel |
| `miner_overclock` | Safe Overclock | asic, vreg, frequency_controller | cap_miner | Guided freq/voltage tuning via LLM |
| `pool_switcher` | Pool Switcher | - | cap_miner | One-tap primary/fallback pool switch |
| `fan_control` | Fan Policy | fan, temp_sensor | cap_miner | Auto fan speed by chip temperature |
| `hashrate_monitor` | Hashrate Monitor | asic | cap_miner | Historical curve + anomaly alerts |
| `power_efficiency` | Efficiency Analyzer | psu, asic, vreg | cap_miner | Power/hashrate ratio optimization |
| `chip_health` | Chip Health Check | asic, temp_sensor | cap_miner | Per-chip status report |
| `rgb_mood` | Mood Lighting | argb_led | cap_miner | Color shifts by hashrate/temp |

### 🎮 Imported from Official (curated)

| Skill ID | Source | BC08 OK | Pockt OK | Notes |
|----------|--------|---------|----------|-------|
| `flappybird` | official | ✅ | ✅ | Tested install success |
| `current_weather` | official | ✅ | ✅ | API config required |
| `current_ip_info` | official | ✅ | ✅ | |
| `dino` | official | ✅ | ✅ | Chrome dino game |
| `github_repo_star` | official | ✅ | ✅ | |
| `china_a_share_quote` | official | ✅ | ✅ | A-share quotes |
| `clock_dial_demo` | official | ✅ | ✅ | Analog clock |
| `bilibili_up_fans` | official | ✅ | ✅ | Bilibili follower count |
| `codex_usage_dashboard` | official | ✅ | ✅ | Codex usage stats |
| `balance_ball` | official | ❌ No IMU | ✅ (if present) | Needs accelerometer |
| `camera_preview` | official | ❌ No camera | ❌ | |

---

## Project Structure

```
hammer-claw-skills-lab/
├── README.md                     # ← This file
├── LICENSE                       # MIT (inherited from esp-claw-skills-lab)
├── UPSTREAM.md                   # Fork provenance & sync strategy
│
├── skills/                       # Skill directory ← Core content
│   ├── miner_dashboard/          # 🆕 Miner dashboard
│   │   ├── SKILL.md
│   │   ├── scripts/
│   │   │   └── dashboard.lua
│   │   └── assets/
│   │       └── icon.png
│   ├── miner_overclock/          # 🆕 Safe overclock
│   ├── pool_switcher/            # 🆕 Pool switch
│   ├── fan_control/              # 🆕 Fan control
│   ├── hashrate_monitor/         # 🆕 Hashrate monitor
│   ├── power_efficiency/         # 🆕 Efficiency
│   ├── chip_health/              # 🆕 Chip health
│   ├── rgb_mood/                 # 🆕 Mood lighting
│   ├── flappybird/               # ← Imported official
│   ├── current_weather/          # ← Imported official
│   ├── dino/                     # ← Imported official
│   └── ...
│
├── build/                        # Build tooling
│   └── vite-plugin-skills.ts     # Vite plugin: scan skills/ → generate JSON
│
├── scripts/                      # CI/utility scripts
│   └── validate-skills.ts        # Skill format validation (CI gate)
│
├── src/                          # Web frontend (Vue 3 + Vite + TypeScript)
│   ├── App.vue
│   ├── main.ts
│   ├── config/
│   │   └── allowlist.ts          # Category/peripheral allowlists (Hammer extended)
│   ├── components/               # Vue components
│   ├── composables/              # Composables
│   ├── generated/                # Build artifacts (gitignored)
│   │   ├── skills-data.json      # Skill metadata
│   │   └── tags.json             # Tag index
│   ├── i18n/                     # Internationalization
│   ├── router/                   # Routes
│   ├── stores/                   # Pinia state
│   ├── styles/                   # Stylesheets
│   ├── types/                    # TS type definitions
│   ├── utils/                    # Utilities
│   └── views/                    # Page views
│
├── docs/
│   └── DEVICE_MARKETPLACE_DESIGN.md  # On-device marketplace design spec
│
├── public/                       # Static assets
│   └── favicon.svg
│
├── package.json                  # pnpm workspace
├── pnpm-lock.yaml
├── vite.config.ts
├── tsconfig.json
└── .github/workflows/            # CI/CD
    └── validate.yml              # Skill validation + build
```

---

## Import Strategy

### Syncing official skills from upstream

```bash
# 1. Add upstream remote
git remote add upstream https://github.com/espressif/esp-claw-skills-lab.git

# 2. Fetch upstream updates
git fetch upstream master

# 3. Cherry-pick desired skill directories
git checkout upstream/master -- skills/flappybird/
git checkout upstream/master -- skills/current_weather/
# ...

# 4. Run validation
pnpm validate-skills

# 5. Commit
git commit -m "sync: upstream skills flappybird, current_weather"
```

### Skipped skills

The following official skills are incompatible with BC08 hardware:

| Skill | Reason |
|-------|--------|
| `camera_preview` | No camera on BC08 |
| `balance_ball` | No IMU on BC08 |
| `movement_detection` | No IMU on BC08 |
| `dfrobot_matrix_lidar_8x8_i2c` | I2C occupied by miner |
| `dfrobot_stcc4_i2c` | I2C occupied by miner |
| `unihiker_button` | Requires UNIHIKER expansion |
| `unihiker_expansion_*` | Requires UNIHIKER expansion |
| `lcd_touch_paint` | Display-only panel (no touch) |

These are documented in `UPSTREAM.md` but excluded from device builds.

---

## On-Device Factory Page (Phase 2)

> Design spec: [docs/DEVICE_MARKETPLACE_DESIGN.md](docs/DEVICE_MARKETPLACE_DESIGN.md)

- **Page number**: Page 7 (factory page, not overwritable)
- **Render**: LVGL C native (performance + immutability)
- **Data source**: `skills-data.json` embedded at build time
- **Features**: Category tabs, cover cards, install/uninstall, space indicator, custom pages section

---

## CI/CD

```yaml
# .github/workflows/validate.yml
name: Validate Skills
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - run: pnpm install
      - run: pnpm validate-skills
      - run: pnpm build
```

---

## Local Development

```bash
# Requirements
node >= 22.12.0
pnpm >= 11.0

# Install
pnpm install

# Dev server (preview web frontend)
pnpm dev

# Validate skill formats
pnpm validate-skills

# Build
pnpm build
# → dist/            Static site
# → dist/raw/        Skill source mirror (direct device downloads)
# → src/generated/skills-data.json  Skill metadata (firmware embedding)
```

---

## License

MIT License. Inherited from [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab).

Original copyright notice in [UPSTREAM.md](./UPSTREAM.md).

---

## Related Projects

| Project | Description |
|---------|-------------|
| [HammerMiner/BC08](https://github.com/HammerMiner/BC08) | BC08-P4 miner firmware |
| [HammerMiner/Hammer-OS](https://github.com/HammerMiner/Hammer-OS) | Hammer OS miner operating system |
| [espressif/esp-claw](https://github.com/espressif/esp-claw) | ESP-Claw AI Agent framework (upstream) |
| [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab) | ESP-Claw Skills Lab (upstream source) |
