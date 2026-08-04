# Hammer Claw Skills Lab

> Open-source skills marketplace for the Hammer Claw AI Agent ecosystem.  
> Create, share, and install Lua-powered skills on your mining or IoT devices.

---

## What Is This?

Hammer Claw Skills Lab is a community-driven repository of **Skills** — LUA scripte based UI framework, which could leverage AI to help you built custom UI pages. Each skill bundles a `SKILL.md` instruction file with optional Lua scripts, assets, and references. The device's built-in AI agent reads these skills and can execute them on demand.

This project is derived from [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab) (MIT), adapted for the Hammer hardware ecosystem.

---

## Quick Start

### Browse & Install Skills

Visit **[skills-lab.hammerminer.com](https://skills-lab.hammerminer.com)** (coming soon) or browse the [`skills/`](skills/) directory directly on GitHub.

To install a skill on your device, send this prompt to your device's AI agent:

```
Install the skill "flappybird" from the Skills Lab
```

The device will automatically fetch metadata, check hardware compatibility, download the skill files, and register them.

### For Developers: Create a Skill

A skill is a directory under `skills/` containing at minimum a `SKILL.md` file:

```
skills/
└── my_skill/
    ├── SKILL.md          # Required: JSON frontmatter + Markdown body
    ├── scripts/          # Optional: Lua scripts
    │   └── action.lua
    ├── references/       # Optional: documentation
    │   └── guide.md
    └── assets/           # Optional: images, data files
        └── icon.png
```

#### SKILL.md Format

Every `SKILL.md` must have a JSON frontmatter block wrapped in `---`:

```markdown
---
{
  "name": "my_skill",
  "description": "What this skill does in one sentence. Include trigger words users might say.",
  "author": "Your Name",
  "metadata": {
    "category": ["utility"],
    "devices": ["universal"],
    "peripherals": [],
    "cap_groups": ["cap_lua"],
    "manage_mode": "readonly"
  }
}
---

# My Skill Title

Use this skill when the user asks to do the specific thing.

## Script Args Schema
...

## Tool Call Inputs
...
```

#### Field Reference

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Must match the directory name exactly (lowercase, digits, `_`, `-`) |
| `description` | ✅ | One sentence describing user intent. Include common trigger phrases. |
| `author` | ❌ | Your name or `Name <email>` |
| `metadata.category` | ✅ | One or more from the allowed list (see below) |
| `metadata.devices` | ✅ | Device compatibility: `["universal"]` or `["bc08-p4", "pockt"]` |
| `metadata.peripherals` | ❌ | Required hardware: `["display", "asic", "fan", "camera"]` |
| `metadata.cap_groups` | ❌ | Required capability groups: `["cap_lua", "cap_web_search"]` |
| `metadata.manage_mode` | ✅ | Always `"readonly"` for shared skills |

#### Allowed Categories

| Category | Description |
|----------|-------------|
| `mining` | Cryptocurrency mining tools |
| `game` | Games and entertainment |
| `utility` | General-purpose tools |
| `ai` | AI/LLM-related skills |
| `hardware` | Hardware control and diagnostics |
| `network` | Network tools |
| `media` | Media and display |
| `sensor` | Sensor data |

#### Device Compatibility Tags

| Tag | Meaning |
|-----|---------|
| `universal` | Works on all Hammer Claw devices |
| `bc08-p4` | Requires BC08-P4 hardware (ASIC miner) |
| `pockt` | Requires Pockt hardware |

#### Allowed Peripherals

`display`, `asic`, `fan`, `hashboard`, `psu`, `temp_sensor`, `vreg`, `argb_led`, `frequency_controller`, `camera`, `button`, `led`, `speaker`, `microphone`, `motor`, `gpio`, `battery`, `ir`, `servo`, `ws2812`, `imu`

---

## UI Design Guidelines

Skills running on ESP32 devices should follow these design principles to ensure smooth performance and a clean visual experience on resource-constrained hardware.

### Card-Based Layout

- Use a **card-based design** to organize content into clear, self-contained blocks.
- Each card should represent a single piece of information or a single interaction unit.
- Maintain consistent spacing between cards and uniform padding within them.
- Avoid deep nesting — keep the visual hierarchy flat and easy to scan.

### No Animations

- **Do not use animations.** ESP32 devices have limited CPU and memory; animations can cause frame drops and UI lag.
- Prefer instant state transitions over animated effects.
- Use color changes, borders, or text updates to indicate state changes instead of motion.

### Color Palette

- Keep colors **simple and clean**. Use a limited palette of 3–5 primary colors.
- Prefer dark backgrounds with high-contrast foreground text for readability on LCD panels.
- Suggested base palette:
  - Background: `#1A1A2E` (dark navy)
  - Card background: `#16213E` (deep blue)
  - Primary accent: `#0F3460` (royal blue)
  - Highlight: `#E94560` (coral red)
  - Text: `#FFFFFF` / `#B0B0B0` (white / light gray)
- Avoid gradients and complex shading — solid colors render faster and look cleaner on small displays.

### Image Assets

- Keep all image assets **under 200 KB** to reduce memory usage and load time.
- Use compressed formats (PNG-8 where possible).
- Preview screenshots (`preview.png`) should also stay under 200 KB.
- Recommended preview dimensions: 360×640 px (portrait) or smaller.

---

## How to Contribute

### 1. Fork the Repository

Go to [github.com/HammerMiner/hammer-claw-skills-lab](https://github.com/HammerMiner/hammer-claw-skills-lab) and click the **Fork** button in the top-right corner. This creates your own copy under your GitHub account, e.g. `https://github.com/YOUR_USERNAME/hammer-claw-skills-lab`.

### 2. Clone Your Fork

```bash
git clone https://github.com/YOUR_USERNAME/hammer-claw-skills-lab.git
cd hammer-claw-skills-lab
```

### 3. Add the Upstream Remote

Add the original repository as `upstream` so you can sync the latest changes later:

```bash
git remote add upstream https://github.com/HammerMiner/hammer-claw-skills-lab.git
```

Verify your remotes:

```bash
git remote -v
```

You should see:

```
origin    https://github.com/YOUR_USERNAME/hammer-claw-skills-lab.git (fetch)
origin    https://github.com/YOUR_USERNAME/hammer-claw-skills-lab.git (push)
upstream  https://github.com/HammerMiner/hammer-claw-skills-lab.git (fetch)
upstream  https://github.com/HammerMiner/hammer-claw-skills-lab.git (push)
```

### 4. Create Your Skill

```bash
mkdir -p skills/my_skill/scripts
```

Write `skills/my_skill/SKILL.md` following the format above. Add any Lua scripts to `scripts/`.

### 5. Validate

```bash
pnpm install
pnpm validate-skills
```

This checks that all `SKILL.md` files have correct frontmatter, valid categories, matching directory names, and proper formatting.

### 6. Test on the Simulator

Before submitting a pull request, verify your skill on the HammerMiner online simulator:

**[https://www.hammerminer.com/#/bc08-simulator](https://www.hammerminer.com/#/bc08-simulator)**

Upload your Lua script to the simulator and confirm that:

- The UI renders correctly on the simulated 720×1280 LCD.
- Touch interactions respond as expected.
- No runtime errors or crashes occur.
- The layout follows the [UI Design Guidelines](#ui-design-guidelines) above.

### 7. Create a Branch and Commit

```bash
git checkout -b add-my-skill
git add skills/my_skill/
git commit -m "Add my_skill skill"
```

### 8. Push to Your Fork

```bash
git push origin add-my-skill
```

### 9. Submit a Pull Request

Open your fork on GitHub:

```
https://github.com/YOUR_USERNAME/hammer-claw-skills-lab
```

GitHub will show a **"Compare & pull request"** banner. Click it and make sure the PR targets:

- **base repository**: `HammerMiner/hammer-claw-skills-lab`
- **base branch**: `test`
- **head repository**: `YOUR_USERNAME/hammer-claw-skills-lab`
- **compare branch**: `add-my-skill`

Add a clear title and description, then submit. A maintainer will review your submission. Once merged, your skill becomes available to all devices.

### 10. Sync Your Fork Later

Before starting your next contribution, sync your fork with the latest upstream changes:

```bash
git fetch upstream
git checkout test
git merge upstream/test
git push origin test
```

### 11. Custom Page Sharing

Have a custom Lua page you built for your device? You can share it:

1. Package it as a standard skill (wrap the Lua script in `scripts/` with a proper `SKILL.md`)
2. Add `"category": ["utility"]` (or appropriate category)
3. Submit via PR as above

After review and merge, and necessary testing on backend,other users can install it from the marketplace.

---

## Project Structure

```
hammer-claw-skills-lab/
├── README.md                     # This file
├── scripts/                      # Build and validation scripts
│   └── generate_catalog.py       # Generates dist/skills-catalog.json
├── skills/                       # All shared skills
│   └── game_minesweeper/         # Minesweeper game
└── ...                           # Additional project files
```

---

## License

MIT License. Inherited from [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab).

---

## Related

| Project | Description |
|---------|-------------|
| [espressif/esp-claw](https://github.com/espressif/esp-claw) | ESP-Claw AI Agent framework (upstream) |
| [espressif/esp-claw-skills-lab](https://github.com/espressif/esp-claw-skills-lab) | Original Skills Lab (upstream source) |
