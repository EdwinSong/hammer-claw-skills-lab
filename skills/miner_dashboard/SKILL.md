---
{
  "name": "miner_dashboard",
  "description": "Display a clean, card-based Bitcoin miner dashboard with hashrate, temperature, BTC price, network status, mining config, ASIC config, and system info on the board LCD.",
  "author": "HammerMiner",
  "metadata": {
    "category": [
      "mining",
      "ui"
    ],
    "tags": [
      "bitcoin",
      "miner",
      "dashboard",
      "asic",
      "monitoring",
      "lcd"
    ],
    "peripherals": [
      "display",
      "asic"
    ],
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "web",
    "devices": [
      "bc08-p4"
    ]
  }
}
---

# Bitcoin Miner Dashboard

Use this skill when the user asks for a miner dashboard, mining status overview,
Bitcoin miner monitor, hashrate display, or device diagnostics on the board LCD.

The Lua script renders a clean, card-based dashboard for Bitcoin mining devices.
It reads live telemetry through the Capability Bus (`miner_get_sensors`,
`miner_get_status`, `miner_get_system_info`, `miner_get_pools`) and device info
through the native `system` module (`system.ip()`, `system.date()`), showing
real hashrate, chip temperature, BTC price, network block height, mining pool
configuration, ASIC settings, and firmware version. The design follows the
ESP32 card-based UI guidelines: dark theme, high-contrast accent colors,
no animations, and optimized image assets.

## Requirements

- A display device declared as `display_lcd` in board hardware info.
- ASIC mining hardware (e.g. BC08-P4) for accurate device targeting.

## Tool Call Inputs

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/miner_dashboard.lua",
  "args": {}
}
```

Pass an empty `args` object for defaults. The dashboard starts rendering live
device telemetry immediately.

## Behavior

- **Display**: 720×1280 portrait dashboard with dark background and neon-accent cards, drawn inside the safe canvas (Y 58–1170).
- **Top Bar**: WiFi status, device IP (`system.ip()`), current time (`system.date()`), and online status indicator.
- **Metric Cards**: Hashrate, temperature, BTC price, and network block height in a two-column grid, refreshed from `miner_get_sensors`.
- **Config Cards**: Mining pool config from `miner_get_status` / `miner_get_pools` (pool, worker, password) and ASIC config from `miner_get_status` (work mode, frequency, voltage).
- **System Card**: OS name and firmware version from `miner_get_system_info`.
- **Refresh**: Telemetry is re-read and re-rendered every 2 seconds; touch events are polled non-blocking via `claw.display.pop_event()`.
- **Icons**: All interface icons are stored as separate PNG files under `assets/`, loaded from `/fatfs/skills/miner_dashboard/assets/`.

## Files

- `scripts/miner_dashboard.lua`
- `assets/wifi.png`
- `assets/status.png`
- `assets/hashrate.png`
- `assets/temp.png`
- `assets/btc.png`
- `assets/network.png`
- `assets/pool.png`
- `assets/worker.png`
- `assets/pass.png`
- `assets/asic.png`
- `assets/freq.png`
- `assets/volt.png`
- `assets/gear.png`
