# BC08-P4 Device-Side Skills Marketplace — Detailed Design Specification

> Phase 2 Planning Document. This document defines the complete layout, data structures, state machine, and C APIs for the LVGL C native Skills Marketplace. **No code implementation yet.**

---

## 1. Page Positioning

| Attribute | Value |
|------|-----|
| **Page Index** | Page 4 (Factory Native C page, cannot be overridden by user Lua scripts) |
| **Rendering Engine** | LVGL C Native (Ensuring performance, stability, and tamper-proof safety) |
| **Bottom Bar Entry** | 🛒 (Market) Icon (Direct shortcut or bottom navigation) |
| **Compilation** | Built-in firmware, compiled alongside BC08 |

Pages 1 to 3 are native miner UI pages (Dashboard, Settings, Network). Page 4 is the native Skills Marketplace (🛒). Pages 5 to 7 are reserved for custom sandbox-rendered Lua screens.

---

## 2. Data Architecture

### 2.1 Data Source Layers

```
┌──────────────────────────────────────────────────┐
│  Compile-time (Firmware Embedded)                │
│  ┌──────────────────────────────────────────┐    │
│  │ skills-data.json  (EMBED_FILES)           │    │
│  │  ├── skills[]         Skill metadata (static) │    │
│  │  └── tags_index{}     Category indexes     │    │
│  └──────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────┐    │
│  │ covers/              (EMBED_FILES)         │    │
│  │  ├── miner_dashboard_thumb.png            │    │
│  │  └── ...              Cover thumbnails     │    │
│  └──────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘
         │
         ▼  Runtime Dynamic State Checks
┌──────────────────────────────────────────────────┐
│  FATFS Filesystem Checks                         │
│  ├── /fatfs/skills/<id>/SKILL.md  exists -> Installed
│  ├── /fatfs/ui/ui_page_5.lua      exists -> Custom Page
│  └── FATFS remaining space -> Disk space indicator
└──────────────────────────────────────────────────┘
```

### 2.2 Data Structures

```c
// Skill metadata and runtime state (merged in memory)
typedef struct {
    char id[64];             // "miner_dashboard"
    char title[64];          // "Miner Dashboard"
    char description[256];   // Brief summary / description of the skill
    char author[64];         // Author name
    uint32_t total_size;     // Total install size in bytes
    bool featured;           // Highlighted/Featured flag
    uint8_t category;        // CAT_MINING / CAT_GAME / CAT_UTILITY / CAT_AI
    char download_url[256];  // Download URL link for the skill zip/tar bundle
    char sha256[65];         // SHA256 checksum for verification
    // Runtime status
    bool installed;          // FATFS status check result
    uint8_t install_state;   // INSTALL_NONE / DOWNLOADING / VERIFYING / INSTALLING / INSTALLED
    uint8_t download_progress; // Real-time percentage progress (0-100)
} skill_card_t;

// Filter categories
typedef enum {
    CAT_ALL = 0,
    CAT_MINING,
    CAT_GAME,
    CAT_UTILITY,
    CAT_AI,
    CAT_INSTALLED,  // "Installed" filter category replacing "My"
    CAT_COUNT
} category_t;

// Custom Lua page entry
typedef struct {
    uint8_t page_id;         // 5-7
    char name[64];           // Extracted from script metadata
    uint32_t size;           // File size
    bool active;             // Whether the script file exists
} custom_page_t;
```

---

## 3. UI Layout

### 3.1 Overall Structure

All text display is strictly in **English** only. No Chinese characters are supported or displayed.

```
┌──────────────────────────────────────┐  y=0
│  🔨 Hammer Skills Lab                │  ← Top Bar h=58
│  ─────────────────────────────────── │
│  [All][Mining][Game][Utility][AI][Installed] ← Category Tabs h=44
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 📦 Cover (80x80)               │  │
│  │                                │  │  ← Skill Card h=100
│  │ Miner Dashboard                │  │     Scrollable List
│  │ Real-time Hashrate telemetry   │  │
│  │ 18.5 KB      [Install]         │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ 🎮 Cover                       │  │
│  │ Flappy Bird                    │  │
│  │ Retro bird flying game         │  │
│  │ 18.7 KB      [Uninstall]       │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ...                            │  │  ← More cards...
│  └────────────────────────────────┘  │
│                                      │
│  ─────────────────────────────────── │
│  Free space: ████████░░ 8.2MB/10MB   │  ← Capacity indicator h=36
│  [Home][Network][Setting][🛒Market]   │  ← Bottom bar (Normal Mode) h=58
└──────────────────────────────────────┘  y=1280
```

#### Bottom Bar States:
* **Normal Mode (Pages 1-4)**: Shows the standard 4 navigation buttons: `[Home] [Network] [Setting] [🛒Market]`. Clicking `[🛒Market]` switches directly to Page 4 (Marketplace).
* **Claw Mode (Lua Custom Sandbox Pages 5-7)**: Bottom bar dynamically switches to:
  `[Home]                     [🛒Market][◀][▶]`
  Adding the `[🛒Market]` button before the left/right page cycling arrows allows users to jump back to the Marketplace directly from any custom page.

### 3.2 Card Layout Details

Each card must display the title, author, total size, featured badge, and a **brief summary (description)** of the skill.

```
┌──────────────────────────────────────────────┐
│ ┌────────┐                                   │
│ │        │  Miner Dashboard       ⛏ Featured  │  ← Title + Featured Badge
│ │  COVER │  Real-time Hashrate telemetry     │  ← Summary / Description (2 lines)
│ │  80x80 │  Author: HammerMiner              │  ← Author
│ │        │  18.5 KB          [ Install ]     │  ← Size + Action Button
│ └────────┘                                   │
└──────────────────────────────────────────────┘

Interactive Behavior:
  - Clicking anywhere on the card body of an INSTALLED skill directly runs it (launches page/registers tool).
  - Clicking the action button triggers installation or uninstallation actions.

Button States:
  - [ Install ]     Gray background + blue icon       ← Not installed
  - [ Installing ]  Orange background + progress bar   ← Real-time download progress bar
  - [ Uninstall ]   Green background + white check     ← Installed (clicks trigger uninstall popup)
  - [ Low Space ]   Red background                     ← Insufficient disk space
```

### 3.3 "[Installed]" Category Layout

Shows currently installed skills and custom Lua pages side by side for easy launch and maintenance.

```
┌──────────────────────────────────────┐
│  Installed Skills                     │
│  ┌────────────────────────────────┐  │
│  │ Miner Dashboard    [Uninstall] │  │ (Clicking card body runs it)
│  │ 18.5 KB                        │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Flappy Bird        [Uninstall] │  │
│  │ 18.7 KB                        │  │
│  └────────────────────────────────┘  │
│                                      │
│  Custom Pages                         │
│  ┌────────────────────────────────┐  │
│  │ Page 5: Minesweeper            │  │
│  │ /fatfs/ui/ui_page_5.lua        │  │
│  │ 5.2 KB           [Preview]     │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Page 6: Calendar               │  │
│  │ /fatfs/ui/ui_page_6.lua        │  │
│  │ 8.1 KB           [Preview]     │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ [+ Create Custom Page...]       │  │  ← Triggers WebIM code generator
│  └────────────────────────────────┘  │
│                                      │
│  Free space: ████████░░ 8.2MB/10MB   │
└──────────────────────────────────────┘
```

---

## 4. State Machine

### 4.1 Skill Installation State Machine

```
                    ┌─────────┐
        Enter Page    │  IDLE   │
       ┌───────────→│         │←──────────────────────┐
       │            └────┬────┘                       │
       │                 │ Click [Install]            │
       │                 ▼                             │
       │            ┌─────────┐                       │
       │            │ SPACE   │─────→ Popup Alert      │
       │            │ _CHECK  │      "Low space, need X MB"
       │            └────┬────┘                       │
       │             Space OK │                          │
       │                 ▼                             │
       │            ┌─────────┐                       │
       │  Refresh   │DOWNLOAD │                       │
       │  Progress  │ _ING    │                       │
       │  Bar       └────┬────┘                       │
       │             Download │                          │
       │             Complete │                          │
       │                 ▼                             │
       │            ┌─────────┐                       │
       │            │ VERIFY  │─────→ Verify Failed    │
       │            │ _ING    │       (Hash mismatch) │
       │            └────┬────┘                       │
       │             Verify OK│                          │
       │                 ▼                             │
       │            ┌─────────┐                       │
       │            │INSTALL  │───────────────────────┤ (Write/Unzip Failed)
       │            │ _ING    │                       │
       │            └────┬────┘                       │
       │             Write OK │                       │
       │                 ▼                             │
       │            ┌─────────┐                       │
       │            │INSTALLED│  Click [Uninstall]    │
       └───────────│         │──────────→ Confirm Popup ┘
                    └─────────┘
```

### 4.2 Space Check Logic

```c
esp_err_t check_space_before_install(skill_card_t *skill) {
    uint64_t free_kb = fatfs_get_free_space("/fatfs");
    uint64_t need_kb = skill->total_size / 1024 + 256;  // +256KB safety margin

    if (free_kb < need_kb) {
        char msg[128];
        snprintf(msg, sizeof(msg),
            "Insufficient Space!\nNeed: %llu KB\nAvailable: %llu KB\nPlease delete some skills and try again.",
            need_kb, free_kb);
        show_dialog("Insufficient Space", msg, DIALOG_OK);
        return ESP_ERR_NO_MEM;
    }
    return ESP_OK;
}
```

---

## 5. Cover Image Strategy

### 5.1 Three-Level Fallback

| Level | Source | Pros | Cons |
|------|------|------|------|
| **Level A** | Built-in asset inside `skills-data.json` (base64) or embedded flash | Offline ready, zero latency | Increases binary size |
| **Level B** | GitHub Raw lazy-load, downloaded and cached to `/fatfs/cache/` | No flash consumption | Slow first load, needs Internet |
| **Level C** | Colored block placeholder with Emoji / Title | Zero dependency, instant | Less aesthetic |

### 5.2 Recommended Strategy: Level B + Level C Fallback

```
First load of Marketplace:
  ① Render Level C placeholder (Category color + generic icon)
  ② Start background download of PNG cover (80x80 px)
  ③ Replace placeholder when download completes
  ④ Cache it to: /fatfs/cache/covers/<skill_id>.png
  
Subsequent loads:
  ① Check cache. If found, display immediately.
  ② Fall back to network download only on cache miss.
```

### 5.3 Cover Specifications & Cache Eviction

```
Dimensions: 80x80 px
Format: PNG (RGBA8888, decoded via lodepng — supported by BC08)
Size: < 5KB per cover
Cache Path: /fatfs/cache/covers/<skill_id>.png
Max Cache Size: 32 covers (≈160KB)
```

**Cache Eviction Policy (LRU)**:
- **Condition 1 (Limit Reached)**: When downloading a new cover and the cache folder reaches 32 covers, the system deletes the Least Recently Used (LRU) cover file.
- **Condition 2 (Low Storage)**: When FATFS remaining space drops below 256KB, the system automatically purges the entire cover cache folder `/fatfs/cache/covers/*`.

---

## 6. Storage Space Management

### 6.1 Partition Layout

```
FATFS (esp_claw partition): 2MB (0x200000 bytes)
├── skills/         ← Installed skills
├── ui/             ← Custom sandbox page scripts
├── sessions/       ← LLM chat logs
├── memory/         ← LLM long-term memory
├── cache/          ← Cover cache
├── router_rules/   ← Event router configurations
├── scheduler/      ← Scheduler rules
└── scripts/        ← Helper scripts
```

### 6.2 Disk Space Indicator Logic

```c
#define FATFS_TOTAL_KB  (2 * 1024)  // 2MB

void update_space_indicator(lv_obj_t *bar, lv_obj_t *label) {
    uint64_t free_bytes = fatfs_get_free_space("/fatfs");
    uint64_t used_kb = FATFS_TOTAL_KB - (free_bytes / 1024);
    
    lv_bar_set_value(bar, (int)(used_kb * 100 / FATFS_TOTAL_KB), LV_ANIM_ON);
    lv_label_set_text_fmt(label, "Free: %llu KB / %d KB", 
                          free_bytes / 1024, FATFS_TOTAL_KB);
    
    // Change bar color to red if available space is under 256KB
    if (free_bytes < 256 * 1024) {
        lv_obj_set_style_bg_color(bar, lv_color_hex(0xFF4444), LV_PART_INDICATOR);
    }
}
```

---

## 7. Custom UI Sandbox Directory (Pages 5-7)

### 7.1 Separation of Storage

Page 4 is native C. Custom screens use slots 5 to 7.

```
/fatfs/
├── skills/              ← Skill packages (managed by downloader)
│   ├── flappybird/
│   └── miner_dashboard/
│
└── ui/                  ← Custom sandbox screens (AI generated / user modified)
    ├── ui_page_4.lua    ← Reserved (No longer used, Page 4 is C Native)
    ├── ui_page_5.lua    ← Minesweeper UI
    ├── ui_page_6.lua    ← Calendar UI
    └── ui_page_7.lua    ← Custom Image Viewer UI
```

### 7.2 Custom Page Creation

```
User → Clicks [+ Create Custom Page...]
     → Input Popup: "Describe the page you want to build..."
     → Triggers WebIM → LLM generates Lua code
     → LLM writes to `/fatfs/ui/ui_page_X.lua` (where X is 5, 6, or 7)
     → UI lists refresh automatically
     → User clicks [Preview] to preview the screen
```

### 7.3 Custom Page Metadata Header

Metadata is placed in comments at the top of the Lua script:

```lua
-- @name Minesweeper
-- @desc Retro minesweeper game with 3 difficulty settings
-- @author AI Assistant
-- @version 1.0
-- @icon game
```

### 7.4 Custom Page Management Actions

```
Available actions:
  [Preview]     → claw.display.change_page(page_id)
  [Edit]        → Triggers WebIM request: "Edit ui_page_X.lua according to user prompt"
  [Delete]      → Confirms deletion → unlink(/fatfs/ui/ui_page_X.lua)
  [View Code]   → Triggers WebIM view: dumps script content
```

---

## 8. Download/Install/Uninstall Implementation

### 8.1 Download & Installation Flow

```
① User clicks [Install] on the card.
② Space check runs (check_space_before_install).
③ Card state switches to DOWNLOADING. An active progress bar appears.
④ Background download launches:
   Runs cap_lua_async with download_skill.lua (action=install).
   - Downloader enhancement: The Lua downloader script is updated to output structured log lines (e.g., "[PROGRESS] 45%") to stdout/stderr during chunk transfers.
⑤ Progress Polling & Extraction:
   The native C page timer polls the running Job logs, parses the progress output, and updates the LVGL progress bar dynamically.
⑥ Integrity & Hash Check:
   - Once downloaded, state changes to VERIFYING.
   - The C core (or Lua installer) computes the SHA256 hash of the downloaded package and verifies it against the `sha256` field inside `skills-data.json`.
   - If verification fails, files are deleted, state reverts to IDLE, and a "Hash verification failed" popup appears.
⑦ Extraction:
   - On success, state changes to INSTALLING.
   - Unzips/moves the package contents to `/fatfs/skills/<id>/`.
⑧ Dynamic Update:
   - State changes to INSTALLED, progress bar hides, and button label changes to "Uninstall".
   - Updates the disk capacity indicator.
   - Automatically registers the new skill to the LLM manager by calling `claw_skill_register("/fatfs/skills/<id>/SKILL.md")`. The AI assistant can now use the new tools without requiring a reboot.
   - Refreshes the list if the "Installed" category tab is active.
```

### 8.2 Uninstallation Flow

```
① User clicks [Uninstall] on the installed skill card.
② A popup asks: "Are you sure you want to uninstall Miner Dashboard?" [Confirm] [Cancel].
③ Physical deletion: Recursively deletes the skill directory `/fatfs/skills/<id>/`.
④ Synchronous Unregistration: Calls `claw_skill_unregister(skill_id)` to instantly remove the tools from the LLM context.
⑤ Revert State: Card status resets to IDLE. Button label reverts to "Install".
⑥ Refresh: Updates disk capacity bar and refreshes lists if on the "Installed" tab.
```

### 8.3 Card Selection Run Behavior

- When a card is `INSTALLED`, **clicking anywhere on the card body directly runs the skill** (e.g., calling `claw.display.change_page(target_page)` or triggering its entrypoint script).
- Only clicking the `[Uninstall]` action button triggers the deletion flow.

### 8.4 C API Functions (Marketplace Control)

```c
// Starts skill download (async, returns a job ID)
esp_err_t skill_market_install(const char *skill_id, 
                                char *job_id_out, size_t job_id_size);

// Queries installation and progress logs
esp_err_t skill_market_get_progress(const char *job_id,
                                     uint8_t *progress_out,
                                     char *status_out, size_t status_size);

// Uninstalls a skill package
esp_err_t skill_market_uninstall(const char *skill_id);

// Checks if a skill package is installed
bool skill_market_is_installed(const char *skill_id);

// Retrieves the remaining free space in FATFS
uint64_t skill_market_get_free_space(void);
```

---

## 9. API Summary

### 9.1 New LVGL display C APIs (Exposed to Lua)

| API | Description | Priority |
|-----|------|--------|
| `claw.display.update_label(id, text)` | Update text of an existing label | **Phase 1** |
| `claw.display.update_bar(id, value)` | Update value of an existing progress bar | **Phase 1** |
| `claw.display.delete(id)` | Delete a widget by its ID | **Phase 1** |
| `claw.display.sleep(ms)` | Non-blocking delay inside Lua task | **Phase 1** |
| `claw.display.peek_event()` | Non-blocking event poll | Phase 2 |
| `claw.display.image(x, y, path)` | Renders a PNG image | Phase 2 |

### 9.2 Marketplace C APIs (Used internally)

| Function | Source | Description |
|------|------|------|
| `skills-data.json` | Embedded file | Skill catalog metadata |
| `cap_lua_async_submit()` | cap_lua | Submit Lua download script in background |
| `cap_lua_async_get_status()` | cap_lua | Check job logs and completion status |
| `fatfs_get_free_space()` | FATFS | Free space calculation |
| `unlink()` / `rmdir_r()` | POSIX | Deletion of files/directories |
| `claw_skill_register()` | cap_skill_mgr | Hot-register skill to the LLM tools context |
| `claw_skill_unregister()` | cap_skill_mgr | Deregister skill from the LLM tools context |

### 9.3 HTTP REST Web APIs (Exposed for Web UI)

To support remote installation and management via the desktop Web interface, the HTTP server must support:

| API Endpoint | HTTP Method | Request Body / Query | Description |
|--------------|-------------|----------------------|-------------|
| `/api/skills` | GET | None | Get all available skills, install status, and free space |
| `/api/skills/install` | POST | `{"id": "miner_dashboard"}` | Triggers async background download and install, returns job_id |
| `/api/skills/uninstall` | POST | `{"id": "miner_dashboard"}` | Triggers physical package wipe and AI tool deregistration |
| `/api/skills/progress` | GET | `?job_id=xxx` | Retrieve progress percentage and download status |

---

## 10. File Inventory (To be Created/Modified)

```
New Files:
  main/displays/skill_market_page.c       ← Marketplace screen creation and list management
  main/displays/skill_market_page.h
  main/displays/skill_market_installer.c  ← Background download, integrity check, and FS operations
  main/displays/skill_market_installer.h
  components/esp_claw/.../skills-data.json ← Embedded skills marketplace metadata list

Modified Files:
  main/displays/lvgl_screen.c             ← Page 4 registration and bottom navigation buttons integration
  main/displays/claw_display.c            ← Routing white-list bypass for Page 4 (native)
  main/http_server/...                    ← Web REST API implementation for remote skills management
  components/esp_claw/.../cap_lua         ← Lua async support, custom script runner, and extra UI functions
  main/esp_claw_init.c                    ← Custom UI page scan index range updated from [4-7] to [5-7]
```

---

## 11. Phased Roadmap

### Phase 2a — Core Functionality (1-2 Weeks)

- [x] Refinement of Marketplace Plan (This specification)
- [ ] Script and flow to embed `skills-data.json` inside flash
- [ ] Basic marketplace card layout list rendering & scroll filtering
- [ ] Install/Uninstall button actions & FATFS checks
- [ ] Disk space capacity indicator bar
- [ ] Insufficient space dialog boxes

### Phase 2b — Visual Enhancements & Safety (1 Week)

- [ ] Background downloading of cover images & local file caching
- [ ] Downloader progress output polling & dynamic UI progress bar updating
- [ ] Package SHA256 integrity verification step
- [ ] Auto-reloading of LLM tools on install/uninstall

### Phase 2c — Custom Pages (1 Week)

- [ ] "Installed" filter category view
- [ ] Sandbox pages list & delete actions
- [ ] Integration with WebIM code generator to save files as Page 5+ (`ui_page_5.lua`)

### Phase 2d — Sandbox Expansion & Web Integration (1 Week)

- [ ] Web HTTP REST endpoints implementation and remote management tabs
- [ ] Multi-page navigation arrows in Claw Mode bottom bar

---

## 12. Architecture & Security Recommendations

### 12.1 Page 4 Native Routing in `claw_display.c`
Currently, `claw_display.c` handles all pages `page_id >= 4` as sandboxed Lua screens. Since Page 4 is now a native C marketplace, we must whitelist it:
* **`claw_display_is_page_active(page_id)` Modification**:
  * Return `true` unconditionally for `page_id == 4`, bypassing the `s_ext_pages` and custom page switches.
* **`claw_display_switch_page(page_id)` Modification**:
  * For `page_id == 4`, load the native C screen (`SCREEN_MARKET` / `refresh_market_screen`) directly instead of looking for Lua sandbox page definitions.
* **Firewall Filter (`claw_display_timer_cb`)**:
  * Keep sandbox command filters active starting from Page 5 (`CLAW_DISPLAY_EXT_PAGE_BASE` must be modified to `5` instead of `4`), so that Page 4's C native controls can draw directly on the screen without sandbox restrictions.

### 12.2 Sandbox Scope & Write Boundaries
- **Path Restrictions**: Custom installation extraction must be strictly restricted to the `/fatfs/skills/<id>/` subdirectory.
- **Write Checks**: The Lua sandbox filesystem wrapper must block custom scripts from writing to critical configuration folders such as `/fatfs/router_rules/` and `/fatfs/scheduler/` to maintain device security.

### 12.3 Dynamic Tool Synchronization
- **Context Updates**: When a skill is installed, registering it via `claw_skill_register` inserts the tool description into the LLM's active context immediately.
- **Deregistration**: Deregistering on uninstallation ensures the AI helper is aware the tool is no longer on disk, preventing hallucinated tool calls.

### 12.4 Heap and PSRAM Memory Controls
- To prevent SRAM exhaustion on the ESP32-S3, the marketplace catalog `skill_card_t` list should be allocated in PSRAM using:
  ```c
  skill_card_t *cards = heap_caps_malloc(sizeof(skill_card_t) * card_count, MALLOC_CAP_SPIRAM);
  ```
  This guarantees that mining stratum socket buffering, network stacks, and image decoding have sufficient internal memory to operate without crashes.

---

*Specification Version: v1.2 · 2026-06-12*
