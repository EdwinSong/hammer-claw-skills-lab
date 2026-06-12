# Hammer Claw Skills Lab

> Open-source skills marketplace for the Hammer Claw AI Agent ecosystem.  
> Create, share, and install Lua-powered skills on your mining or IoT devices.

---

## What Is This?

Hammer Claw Skills Lab is a community-driven repository of **Skills** — LLM-invokable packages that extend what your device can do. Each skill bundles a `SKILL.md` instruction file with optional Lua scripts, assets, and references. The device's built-in AI agent reads these skills and can execute them on demand.

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

## How to Contribute

### 1. Fork & Clone

```bash
git clone https://github.com/YOUR_USERNAME/hammer-claw-skills-lab.git
cd hammer-claw-skills-lab
```

### 2. Create Your Skill

```bash
mkdir -p skills/my_skill/scripts
```

Write `skills/my_skill/SKILL.md` following the format above. Add any Lua scripts to `scripts/`.

### 3. Validate

```bash
pnpm install
pnpm validate-skills
```

This checks that all `SKILL.md` files have correct frontmatter, valid categories, matching directory names, and proper formatting.

### 4. Submit a Pull Request

Push your branch and open a PR against `main`. A maintainer will review your submission. Once merged, your skill becomes available to all devices.

### 5. Custom Page Sharing

Have a custom Lua page you built for your device? You can share it:

1. Package it as a standard skill (wrap the Lua script in `scripts/` with a proper `SKILL.md`)
2. Add `"category": ["utility"]` (or appropriate category)
3. Submit via PR as above

After review and merge, other users can install it from the marketplace.

---

## For Device Firmware Developers

### Integrating the Skills Lab

Your device firmware needs:

1. **`skills_lab_downloader` skill** — tells the LLM how to fetch from the marketplace. The download URL is:

   ```
   https://raw.githubusercontent.com/HammerMiner/hammer-claw-skills-lab/main/skills/<skill_id>/SKILL.md
   ```

2. **HTTP allowlist** — ensure your device allows outbound requests to:
   - `raw.githubusercontent.com`
   - `skills-lab.hammerminer.com` (web frontend, optional)

3. **`skills-data.json`** — generated by `pnpm build` in this repo. Embed it in firmware for the on-device marketplace page.

### Compatibility Check

When installing a skill, the device should:

1. Fetch `_metadata.json` from the skill directory
2. Compare `metadata.devices` against the device model
3. Compare `metadata.peripherals` against available hardware
4. Warn the user if conflicts exist, allow force-install

---

## Project Structure

```
hammer-claw-skills-lab/
├── README.md                     # This file
├── LICENSE                       # MIT
├── skills/                       # All shared skills
│   ├── flappybird/               # Game
│   ├── current_weather/          # Weather
│   ├── miner_dashboard/          # Mining dashboard
│   └── ...
├── build/                        # Vite plugin for skill metadata generation
│   └── vite-plugin-skills.ts
├── scripts/                      # CI validation
│   └── validate-skills.ts
├── src/                          # Web frontend (Vue 3)
│   ├── config/
│   │   └── allowlist.ts          # Category/peripheral/device definitions
│   └── ...
├── package.json
└── .github/workflows/            # CI: validate on every push
```

---

## Local Development

```bash
# Requirements
node >= 22.12.0
pnpm >= 11.0

# Install dependencies
pnpm install

# Start dev server
pnpm dev

# Validate all skills
pnpm validate-skills

# Production build
pnpm build
# → dist/            Static web frontend
# → dist/raw/        Raw skill files (direct device downloads)
# → src/generated/   skills-data.json + tags.json
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
