---
{
  "name": "flappybird",
  "description": "Run a Flappy Bird mini-game on the board LCD with touch-driven flap control, pipe obstacle generation, score tracking, and game-over restart flow.",
  "author": "HammerMiner",
  "metadata": {
    "category": [
      "game",
      "ui"
    ],
    "tags": [
      "flappybird",
      "arcade",
      "game",
      "touch",
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

# Flappy Bird

Use this skill when the user asks to play Flappy Bird, a bird game, tap-to-flap
arcade game, or an interactive game demo on the board LCD.

The Lua script renders the bird, pipes, and score on the LCD using the
claw.display API. Touch input makes the bird flap upward. Avoid pipes and the
ground to survive and build your score.

## Requirements

- A display device declared as `display_lcd` in board hardware info.
- LCD touch input for flap control.

## Tool Call Inputs

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/flappybird.lua",
  "args": {}
}
```

Pass an empty `args` object for defaults. The game starts in "waiting" mode;
tap the screen to begin playing.

## Behavior

- **Bird**: 80×80px square rendered at x=100. Gravity pulls it down; each tap
  gives an upward flap impulse.
- **Pipes**: 60px wide green pipes with 200px gap, spawning every ~2 seconds
  at random heights from the right edge.
- **Scoring**: +1 point each time the bird passes a pipe pair.
- **Collision**: AABB hit-test against pipe gaps and ground boundary.
- **Game Over**: Shows GAME OVER screen with final score and RESTART button.
- The script runs in an infinite polling loop; stop via runtime or page switch.

## Files

- `scripts/flappybird.lua`
