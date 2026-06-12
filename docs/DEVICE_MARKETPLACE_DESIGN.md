# BC08-P4 On-Device Skills Marketplace — Design Specification

> Phase 2 planning document. Defines the LVGL native skills marketplace page: interaction model, data structures, state machine, and API requirements. **Implementation deferred.**

---

## 1. Page Identity

| Property | Value |
|----------|-------|
| **Page Number** | Page 7 (factory page, not overwritable by user Lua) |
| **Render Engine** | LVGL C native (performance + immutability) |
| **Bottom Bar Icon** | 🛒 |
| **Build Method** | Compiled into firmware, shipped with BC08 releases |

Pages 4-6 remain for user-custom Lua pages. Page 7 is the factory skills marketplace.

---

## 2. Data Architecture

### 2.1 Data Source Layers

```
┌──────────────────────────────────────────────────┐
│  Build Time (embedded in firmware)                │
│  ┌──────────────────────────────────────────┐    │
│  │ skills-data.json  (EMBED_FILES)           │    │
│  │  ├── skills[]         Static metadata     │    │
│  │  └── tags_index{}     Category/tag index  │    │
│  └──────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────┐    │
│  │ covers/              (EMBED_FILES)         │    │
│  │  ├── miner_dashboard_thumb.png            │    │
│  │  └── ...              Cover thumbnails     │    │
│  └──────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘
         │
         ▼  Runtime dynamic data
┌──────────────────────────────────────────────────┐
│  FATFS filesystem checks                          │
│  ├── /fatfs/skills/<id>/SKILL.md  exists → installed│
│  ├── /fatfs/ui/ui_page_*.lua      exists → custom │
│  └── fatfs free space → capacity indicator         │
└──────────────────────────────────────────────────┘
```

### 2.2 Data Structures

```c
// Skill card (runtime merge of static metadata + dynamic install state)
typedef struct {
    char id[64];             // "miner_dashboard"
    char title[64];          // "Miner Dashboard"
    char description[256];   // One-line description
    char author[64];         // Author name
    uint32_t total_size;     // Total size in bytes
    bool featured;           // Featured flag
    uint8_t category;        // CAT_MINING / CAT_GAME / CAT_UTILITY / CAT_AI
    // Runtime state
    bool installed;          // FATFS detection result
    uint8_t install_state;   // INSTALL_NONE / DOWNLOADING / INSTALLING / INSTALLED
    uint8_t download_progress; // 0-100
} skill_card_t;

// Category enum
typedef enum {
    CAT_ALL = 0,
    CAT_MINING,
    CAT_GAME,
    CAT_UTILITY,
    CAT_AI,
    CAT_MY,        // "My Skills" — installed + custom pages
    CAT_COUNT
} category_t;

// Custom page entry
typedef struct {
    uint8_t page_id;         // 4-7
    char name[64];           // Extracted from filename
    uint32_t size;           // File size
    bool active;             // Whether file exists
} custom_page_t;
```

---

## 3. Page Layout

### 3.1 Overall Structure

```
┌──────────────────────────────────────┐  y=0
│  🔨 Hammer Skills Lab                │  ← Top bar h=58
│  ─────────────────────────────────── │
│  [All][⛏Mining][🎮Games][🔧Tools][🤖AI][📄My]│  ← Category tabs h=44
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 📦 Cover (80x80)               │  │
│  │                                │  │  ← Skill card h=100
│  │ Miner Dashboard                │  │     Scrollable list
│  │ Real-time hashrate/temp panel  │  │
│  │ 18.5 KB      [Install →]      │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ 🎮 Cover                       │  │
│  │ Flappy Bird                    │  │
│  │ Classic side-scroll flyer      │  │
│  │ 18.7 KB      [✅ Installed]    │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ ...                            │  │  ← More cards...
│  └────────────────────────────────┘  │
│                                      │
│  ─────────────────────────────────── │
│  Free: ████████░░ 8.2MB/10MB        │  ← Capacity indicator h=36
│  [Home][Settings][Network][Custom][🛒Mkt]│  ← Bottom bar h=58
└──────────────────────────────────────┘  y=1280
```

### 3.2 Card Layout Detail

```
┌──────────────────────────────────────────────┐
│ ┌────────┐                                   │
│ │        │  Miner Dashboard          ⛏ Featured│  ← Title + featured badge
│ │  COVER │  Real-time hashrate/temp panel    │  ← Description (2 lines)
│ │  80x80 │  Author: HammerMiner              │  ← Author
│ │        │  18.5 KB          [ Install → ]   │  ← Size + button
│ └────────┘                                   │
└──────────────────────────────────────────────┘

Button states:
  [ Install → ]     Gray bg + blue arrow      ← Not installed
  [ ⏳ Downloading ] Orange bg + progress bar   ← Downloading
  [ ✅ Installed ]   Green bg + checkmark      ← Installed (tap to uninstall)
  [ ❌ No Space ]    Red bg                    ← Insufficient space
```

### 3.3 "📄 My Skills" Tab Layout

```
┌──────────────────────────────────────┐
│  Installed Skills                     │
│  ┌────────────────────────────────┐  │
│  │ Miner Dashboard   ✅ Installed │  │
│  │ 18.5 KB          [Uninstall]  │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Flappy Bird       ✅ Installed │  │
│  │ 18.7 KB          [Uninstall]  │  │
│  └────────────────────────────────┘  │
│                                      │
│  Custom Pages                         │
│  ┌────────────────────────────────┐  │
│  │ Page 4: Minesweeper            │  │
│  │ /fatfs/ui/ui_page_4.lua       │  │
│  │ 5.2 KB          [▶ Preview]   │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Page 5: Calendar               │  │
│  │ /fatfs/ui/ui_page_5.lua       │  │
│  │ 8.1 KB          [▶ Preview]   │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ [+ Create New Custom Page...]  │  │  ← Opens WebIM for AI generation
│  └────────────────────────────────┘  │
│                                      │
│  Free: ████████░░ 8.2MB/10MB        │
└──────────────────────────────────────┘
```

---

## 4. State Machine

### 4.1 Skill Install State Machine

```
                    ┌─────────┐
        enter detail  │  IDLE   │
       ┌───────────→│         │←──────────┐
       │            └────┬────┘           │
       │                 │ tap [Install]    │ no space / failure
       │                 ▼                 │
       │            ┌─────────┐           │
       │            │ SPACE   │─────→ Dialog:
       │            │ _CHECK  │      "Need X MB, available Y MB"
       │            └────┬────┘           │
       │           enough │               │
       │                 ▼                 │
       │            ┌─────────┐           │
       │  progress   │DOWNLOAD │           │
       │  ←────────│ _ING    │           │
       │            └────┬────┘           │
       │          complete │              │
       │                 ▼                 │
       │            ┌─────────┐   fail    │
       │            │INSTALL  │───────────┘
       │            │ _ING    │
       │            └────┬────┘
       │           written │
       │                 ▼
       │            ┌─────────┐
       │            │INSTALLED│  tap [Uninstall]
       └───────────│         │──────────→ Confirm dialog → delete files → IDLE
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
            "Insufficient space!\nRequired: %llu KB\nAvailable: %llu KB\nUninstall other skills and retry.",
            need_kb, free_kb);
        show_dialog("No Space", msg, DIALOG_OK);
        return ESP_ERR_NO_MEM;
    }
    return ESP_OK;
}
```

---

## 5. Cover Image Strategy

### 5.1 Three-Tier Approach

| Tier | Source | Pros | Cons |
|------|--------|------|------|
| **A** | Skill's own `assets/cover.png`, base64-embedded in skills-data.json | Offline, zero latency | Increases firmware size |
| **B** | GitHub raw lazy-load, cache to `/fatfs/cache/` on first view | No firmware bloat | Slow first load, needs network |
| **C** | Category-colored placeholder + icon text (fallback) | Zero dependency | Not "premium" looking |

### 5.2 Recommended: Tier B with C fallback

```
First open of marketplace:
  ① Show Tier C placeholder (category color block + emoji)
  ② Async download cover PNG (80x80) in background
  ③ Replace placeholder on download complete
  ④ Cache to /fatfs/cache/covers/<skill_id>.png

Subsequent opens:
  ① Check cache first, display if exists
  ② Fall back to network if cache miss
```

### 5.3 Cover Specs

```
Dimensions: 80x80 px
Format: PNG (RGBA8888, lodepng decode — BC08 already supports)
Max size: < 5KB per image
Cache path: /fatfs/cache/covers/<skill_id>.png
Max cached: 32 images (≈160KB)
```

---

## 6. Storage Management

### 6.1 Partition Layout

```
FATFS (esp_claw partition): 2MB (0x200000 bytes)
├── skills/         ← Installed skills
├── ui/             ← Custom page Lua scripts
├── sessions/       ← Chat history
├── memory/         ← AI memory
├── cache/          ← Cover image cache
├── router_rules/   ← Event routing
├── scheduler/      ← Scheduled tasks
└── scripts/        ← Other Lua scripts
```

### 6.2 Capacity Indicator

```c
#define FATFS_TOTAL_KB  (2 * 1024)  // 2MB

void update_space_indicator(lv_obj_t *bar, lv_obj_t *label) {
    uint64_t free_bytes = fatfs_get_free_space("/fatfs");
    uint64_t used_kb = FATFS_TOTAL_KB - (free_bytes / 1024);

    lv_bar_set_value(bar, (int)(used_kb * 100 / FATFS_TOTAL_KB), LV_ANIM_ON);
    lv_label_set_text_fmt(label, "Free: %llu KB / %d KB",
                          free_bytes / 1024, FATFS_TOTAL_KB);

    // Red warning below 256KB
    if (free_bytes < 256 * 1024) {
        lv_obj_set_style_bg_color(bar, lv_color_hex(0xFF4444), LV_PART_INDICATOR);
    }
}
```

---

## 7. Custom Pages Section (📄 My Skills)

### 7.1 Storage Separation

```
/fatfs/
├── skills/              ← Skill install directory (skills_lab_downloader managed)
│   ├── flappybird/
│   └── miner_dashboard/
│
└── ui/                  ← Custom page directory (AI-generated + user-edited)
    ├── ui_page_4.lua    ← Minesweeper
    ├── ui_page_5.lua    ← Calendar
    ├── ui_page_6.lua    ← Image viewer
    └── ui_page_7.lua    ← Reserved (skills marketplace, not for customization)
```

### 7.2 Create Custom Page Flow

```
User → Tap [+ Create New Custom Page...]
     → Dialog: "Describe the page you want..."
     → Backend: Call WebIM → LLM generates Lua code
     → LLM writes /fatfs/ui/ui_page_X.lua
     → Auto-refresh page list on write complete
     → User can tap [▶ Preview] to navigate to the page
```

### 7.3 Custom Page Metadata

Convention: header comments in Lua script:

```lua
-- @name Hashrate Dashboard
-- @desc Real-time hashrate curve, temperature, fan speed
-- @author User
-- @version 1.0
-- @icon hashrate
```

The marketplace parses these comments for display names and descriptions.

### 7.4 Custom Page Management

```
Actions:
  [▶ Preview]     → claw.display.change_page(page_id)
  [✏ Edit]        → Open WebIM, tell LLM "modify page X"
  [🗑 Delete]      → Confirm dialog → unlink(/fatfs/ui/ui_page_X.lua)
  [📋 View Source] → Open WebIM, display file contents
```

---

## 8. Install / Uninstall Implementation

### 8.1 Download Flow

```
① User taps [Install]
② Space check (check_space_before_install)
③ Card state → DOWNLOADING, show progress bar
④ Call skills_lab_downloader Lua script (async):
   cap_lua_async → download_skill.lua action=install
⑤ Poll job status + parse log output for progress
⑥ Complete → state INSTALLED
⑦ Refresh capacity indicator
⑧ Refresh "My Skills" tab if open
```

### 8.2 Uninstall Flow

```
① User long-presses installed card (or taps [Uninstall] button)
② Confirm dialog: "Uninstall Miner Dashboard?"
   [Confirm] [Cancel]
③ Recursively delete /fatfs/skills/<id>/
④ Call unregister_skill (remove from LLM skill list)
⑤ Card state → IDLE
⑥ Refresh capacity indicator
```

### 8.3 Required C-Level APIs

```c
// Install skill (async, returns job_id for polling)
esp_err_t skill_market_install(const char *skill_id,
                                char *job_id_out, size_t job_id_size);

// Query install progress
esp_err_t skill_market_get_progress(const char *job_id,
                                     uint8_t *progress_out,
                                     char *status_out, size_t status_size);

// Uninstall skill
esp_err_t skill_market_uninstall(const char *skill_id);

// Check if installed
bool skill_market_is_installed(const char *skill_id);

// Get FATFS free space
uint64_t skill_market_get_free_space(void);
```

---

## 9. API Requirements Summary

### 9.1 New LVGL APIs (C layer, Lua-callable)

| API | Purpose | Priority |
|-----|---------|----------|
| `claw.display.update_label(id, text)` | Update existing label text | **Phase 1** |
| `claw.display.update_bar(id, value)` | Update existing bar value | **Phase 1** |
| `claw.display.delete(id)` | Remove UI element | **Phase 1** |
| `claw.display.sleep(ms)` | Non-blocking delay | **Phase 1** |
| `claw.display.peek_event()` | Non-blocking event poll | Phase 2 |
| `claw.display.image(x, y, path)` | Display PNG image | Phase 2 |

### 9.2 Marketplace-Specific C Interfaces

| Interface | Source | Purpose |
|-----------|--------|---------|
| `skills-data.json` | Build-time embed | Skill catalog metadata |
| `cap_lua_async_submit()` | cap_lua | Async execute install Lua script |
| `cap_lua_async_get_status()` | cap_lua | Query install progress |
| `fatfs_get_free_space()` | FATFS | Space check |
| `unlink()` / `rmdir_r()` | POSIX | Delete files on uninstall |
| `claw_skill_unregister()` | cap_skill_mgr | Remove from LLM skill list |

---

## 10. File Manifest (Implementation)

```
New files:
  main/tasks/skill_market_page.c       ← LVGL marketplace page
  main/tasks/skill_market_page.h
  main/tasks/skill_market_installer.c  ← Install/uninstall/space management
  main/tasks/skill_market_installer.h
  components/esp_claw/.../skills-data.json  ← Embedded skill catalog

Modified files:
  main/lvgl_screen.c                   ← Register Page 7 + bottom bar icon
  main/http_server/...                 ← May need skill status in web UI
  components/esp_claw/.../cap_lua      ← peek_event + sleep + update_* APIs
```

---

## 11. Phased Plan

### Phase 2a — Core (1-2 weeks)

- [x] Design spec (this document)
- [ ] `skills-data.json` generation script + firmware embedding
- [ ] Card list rendering (category filter + scroll)
- [ ] Install/uninstall buttons + FATFS state detection
- [ ] Capacity indicator
- [ ] Insufficient space dialog

### Phase 2b — Visual Polish (1 week)

- [ ] Cover image async download + caching
- [ ] Install progress bar
- [ ] Download failure retry

### Phase 2c — Custom Pages (1 week)

- [ ] "My Skills" tab
- [ ] Custom page list + preview/delete
- [ ] Create new custom page → LLM generation

### Phase 2d — Lua API Extensions (parallel with 2a)

- [ ] `update_label` / `update_bar` / `delete` / `sleep`
- [ ] `peek_event` / `image`

---

*Design spec version: 1.2 · 2026-06-12*
