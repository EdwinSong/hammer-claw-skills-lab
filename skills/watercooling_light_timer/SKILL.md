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
      "led"
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

- Supports two modes: **Delay** and **Clock**.
- **Delay mode**: enter a number and choose the unit (**Minutes** or **Hours**). Use the **-** / **+** buttons to adjust the value.
- **Clock mode**: set a target clock time (e.g. 21:00). The skill automatically rolls over to the next day if the time has already passed.
- Displays the current timezone offset (e.g. `UTC+08:00`) on the top bar.
- Persists the active timer state to `skills/watercooling_light_timer/state.json`.
- On launch, restores an unfinished timer if the deadline has not been reached.
- Calls `claw.rgb.off()` when the deadline is reached and clears the persisted state.
- The user can press **Cancel** at any time to abort the timer.

## Files

- `scripts/watercooling_light_timer.lua`
