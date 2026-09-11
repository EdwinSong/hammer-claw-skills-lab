---
{
  "name": "hydro_light_control",
  "description": "Schedule the BC08-P4 water-cooling RGB LED to turn off after a delay (minutes or hours) or at a specific clock time. Supports state persistence and shows current timezone. Invoke when the user asks for LED timer, schedule light off, water-cooling RGB shutdown, or turn off the light after a delay.",
  "author": "HammerMiner",
  "metadata": {
    "category": [
      "utility",
      "hardware"
    ],
    "tags": [
      "watercooling",
      "rgb",
      "led",
      "timer",
      "schedule",
      "timezone"
    ],
    "peripherals": [
      "display",
      "argb_led"
    ],
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "readonly",
    "devices": [
      "bc08-p4"
    ]
  }
}
---

# Hydro Light Control

Use this skill when the user wants to automatically turn off the water-cooling RGB LED after a delay or at a specific time.

## Tool Call Inputs

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/watercooling_light_timer.lua",
  "args": {}
}
```

Pass an empty `args` object for defaults.

## Behavior

- Supports two modes: **Timer** (countdown) and **Schedule** (clock time).
- **Timer mode**: pick a preset (**15 min** / **30 min** / **1 hour** / **2 hours**) or adjust the value with the **-** / **+** buttons (1–999, minutes or hours).
- **Schedule mode**: wheel pickers set the target clock time (hour 0–23, minute 0–59) via the chevron buttons. The skill automatically rolls over to the next day if the time has already passed, and shows a live `HH:MM:SS` countdown below the summary while the timer is running.
- The power button toggles the ARGB LED immediately via `capability.call("miner_set_led_mode", { on = ... })`; the four color dots apply instantly via `capability.call("miner_set_led_color", { r, g, b })`.
- Displays the current timezone offset (e.g. `UTC+08:00`) on the top bar, derived from `system.time()` and `system.date()`.
- Persists the timer state to `/fatfs/skills/watercooling_light_timer/state.json` via the `storage` module (pcall-protected).
- On launch, restores an unfinished timer if the deadline has not been reached.
- When the deadline is reached, the LED is turned off via `capability.call("miner_set_led_mode", { on = false })` and the persisted state is cleared.
- The user can press **Stop Timer** at any time to abort; switching modes or picking a preset also cancels the active timer.

## Files

- `scripts/watercooling_light_timer.lua`
