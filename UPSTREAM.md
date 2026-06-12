# Upstream Tracking

## Fork Provenance

| Project | Repository | License |
|---------|------------|---------|
| **Upstream** | [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab) | MIT |
| **This Project** | [HammerMiner/hammer-claw-skills-lab](https://github.com/HammerMiner/hammer-claw-skills-lab) | MIT |

## Modification Summary

Relative to upstream `espressif/esp-claw-skills-lab`, this project applies the following substantial modifications:

### 1. Category Extension
- **Added `mining` category**: Mining-exclusive skills (hashrate control, voltage tuning, pool management, etc.)
- Retained `game`, `utility`, `ai`, `hardware`, `network`, `media`, `sensor`

### 2. Peripheral Extension
- **Added miner peripherals**: `asic`, `fan`, `hashboard`, `psu`, `temp_sensor`, `vreg`, `argb_led`, `frequency_controller`
- Retained official general peripherals (`display`, `button`, `led`, etc.)

### 3. Skill Content
- **Added**: 8+ miner-exclusive skills (miner_dashboard, miner_overclock, pool_switcher, etc.)
- **Imported**: Curated official skills (flappybird, current_weather, dino, etc.)
- **Removed**: Skills dependent on unavailable hardware (camera_preview, balance_ball, dfrobot_*, unihiker_*)

### 4. Branding & Interface
- Brand: ESP-Claw → Hammer Miner
- Theme: Cyberpunk dark theme
- Device-side: LVGL native factory page (replaces standalone website)

### 5. Target Platforms
- BC08-P4: ESP32-P4 + C6 + 8×BM1370 ASIC (primary)
- Pockt: Portable miner (secondary)

## Sync Strategy

### Periodic Sync
```bash
# Check upstream updates quarterly
git fetch upstream master
git diff main upstream/master -- skills/   # View new official skills
git diff main upstream/master -- build/     # View build tooling updates
git diff main upstream/master -- src/       # View frontend updates (rarely needed)

# Selective merge
git checkout upstream/master -- skills/<new_skill>/
pnpm validate-skills
```

### Non-Tracked Parts
- `src/` frontend code → We use on-device LVGL page, no standalone website
- `.github/workflows/deploy.yml` → No Vercel/Cloudflare deployment needed
- Hardware-dependent skills → Documented in skip list below

## Skipped Skills

| Skill | Reason |
|-------|--------|
| `camera_preview` | No camera on BC08 |
| `balance_ball` | No IMU on BC08 |
| `movement_detection` | No IMU on BC08 |
| `dfrobot_matrix_lidar_8x8_i2c` | I2C occupied by miner |
| `dfrobot_stcc4_i2c` | I2C occupied by miner |
| `unihiker_button` | Requires UNIHIKER expansion board |
| `unihiker_expansion_*` | Requires UNIHIKER expansion board |
| `lcd_touch_paint` | Display-only panel (no touch input) |

## License Statement

This project is distributed under the MIT License, inherited from upstream `espressif/esp-claw-skills-lab`.

Original copyright:
```
MIT License
Copyright (c) 2026 Espressif Systems (Shanghai) CO LTD
```
