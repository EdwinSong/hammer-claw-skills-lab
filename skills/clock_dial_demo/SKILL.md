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
dial, or a premium vintage analog watch face on the board LCD.

The Lua script renders a beautiful vintage mechanical bronze clock dial on the LCD
using the claw.display API. It features Roman numerals, ornate engraving,
a dark green background matching the premium aesthetics, and dynamically rendered
tapered hour and minute hands.

## Requirements

- A display device declared as `display_lcd` in board hardware info.

## Tool Call Inputs

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/clock_dial_demo.lua",
  "args": {}
}
```

Pass an empty `args` object for defaults. The clock starts immediately with live time display.

## Behavior

- **Display**: Ornate mechanical watch face (600×600) centered on a 720×1280 portrait layout.
- **Hands**: Tapered metallic blue hour and minute hands update dynamically every minute.
- **Status Bar**: The top system status bar remains visible for connectivity and device status.
- The script runs in an infinite polling loop; stop via runtime or page switch.

## Files

- `scripts/clock_dial_demo.lua`
- `scripts/dial.png`
