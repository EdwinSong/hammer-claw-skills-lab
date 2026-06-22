---
{
  "name": "clock_dial_demo",
  "description": "Premium animated digital clock on the board LCD with dark-themed glassmorphic UI, date display, touch toggle between 12h/24h mode, and smooth second-pulse animation.",
  "author": "HammerMiner",
  "metadata": {
    "category": [
      "utility",
      "ui"
    ],
    "tags": [
      "clock",
      "watchface",
      "dial",
      "digital",
      "lcd"
    ],
    "peripherals": [
      "display"
    ],
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "web",
    "devices": [
      "universal"
    ]
  }
}
---

# Clock Dial Demo

Use this skill when the user asks for a clock, watch face, time display,
dial, or a premium LCD demo on the board.

The Lua script renders an animated digital clock on the LCD using the
claw.display API, with a dark glassmorphic theme matching the Hammer-OS
aesthetic. The time updates every second with smooth colon pulse animation,
date display, and touch-toggle between 12-hour and 24-hour formats.

## Requirements

- A display device declared as `display_lcd` in board hardware info.
- LCD touch input for format toggle.

## Tool Call Inputs

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/clock_dial_demo.lua",
  "args": {}
}
```

Pass an empty `args` object for defaults. The clock starts immediately in
24-hour format with live time display.

## Behavior

- **Display**: Large digital time (HH:MM:SS) centered on 720×1280 portrait display.
- **Format Toggle**: Tap the time area to switch between 12h and 24h format.
- **Date**: Shows current date (YYYY-MM-DD) below the time.
- **Colon Animation**: Colon pulses on/off every second for a breathing effect.
- **Glassmorphic Design**: Dark card container with rounded corners and neon accents.
- The script runs in an infinite polling loop; stop via runtime or page switch.

## Files

- `scripts/clock_dial_demo.lua`
