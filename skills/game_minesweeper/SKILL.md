---
{
  "name": "game_minesweeper",
  "description": "Run a premium animated Minesweeper game on the board LCD with 5x5 grid, multiple levels (1-5), flag mode, explosion ripple animation, and victory celebration screen. Touch-driven with dark-themed LVGL UI.",
  "author": "HammerMiner",
  "metadata": {
    "category": [
      "game",
      "ui"
    ],
    "tags": [
      "minesweeper",
      "game",
      "touch",
      "puzzle",
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

# Game MineSweeper

Use this skill when the user asks to play Minesweeper, mine sweeping game,
or a touch-based puzzle game on the board LCD.

The Lua script renders a 5×5 dark-themed grid with premium neon-colored number
cells, flag/flag mode toggle, explosion ripple animation on detonation, and
victory/game-over screens with level progression (5 levels, mines: 3→7).

## Requirements

- A display device declared as `display_lcd` in board hardware info.
- LCD touch input for cell selection and flag mode interaction.

## Tool Call Inputs

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/game_minesweeper.lua",
  "args": {}
}
```

Pass an empty `args` object for defaults. The game starts immediately with
Level 1 (3 mines on 5×5 grid).

## Behavior

- **Grid**: 5×5 cells, 120×120px each, centered on 720×1280 portrait display.
- **Flag Mode**: Toggle with FLAG MODE button. Flagged cells show a green "F".
- **Levels**: 1 (3 mines) → 5 (7 mines). Level up on victory.
- **Explosion Animation**: Ripple shockwave from detonated mine outward,
  revealing all other mines in deep red with 120ms ring delay.
- **Victory Screen**: Neon green VICTORY! with NEXT LEVEL / REPLAY LEVEL options.
- **Game Over Screen**: Neon red GAME OVER with TRY AGAIN / RESET TO LEVEL 1 options.
- The script runs in an infinite polling loop; stop via runtime or page switch.

## Files

- `scripts/game_minesweeper.lua`
