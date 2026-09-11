# Hammer Claw / BC08 Skill API Reference

> Complete technical reference for internal telemetry, hardware control, capability bus, and native Lua runtime modules on BC08-P4 and the Hammer Claw OS.

---

## 1. Architecture Overview & Communication Channels

When running on a BC08 device, your Lua script executes within the **H-Claw Agent** runtime on the ESP32-P4 SoC. Skills can access internal miner telemetry and control hardware through three primary channels:

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Lua Skill Script                    │
└──────┬──────────────────────┬───────────────────────┬───────┘
       │                      │                       │
       ▼                      ▼                       ▼
【1. Capability Bus】      【2. Native Lua Modules】   【3. Localhost REST API】
  require("capability")      system / storage / delay       http_request
(miner_get_sensors, etc.)      claw.display / json       (127.0.0.1 endpoints)
       │                              │                       │
       ▼                              ▼                       ▼
 Zero-latency direct memory    Low-level OS, file I/O     Per-chip BM1370 ASIC
 telemetry reading & controls    and 720x1280 LCD UI         diagnostics
```

### 1.1 The Capability Bus (`require("capability")`) — Recommended
Capabilities communicate directly with firmware shared memory pointers. This channel incurs **zero HTTP overhead**, executes synchronously without network sockets, and is non-blocking.

```lua
local capability = require("capability")
local json = require("json")

-- Signature: ok, output_str, err = capability.call(name, payload_table[, opts])
local ok, out, err = capability.call("miner_get_sensors", {})
if ok then
    local sensors = json.decode(out)
    print("Hashrate:", sensors.hashrate, "TH/s")
    print("Chip Temp:", sensors.chip_temp_0, "°C")
else
    print("Call failed:", err)
end
```

---

## 2. Miner Telemetry & Status APIs

### 2.1 `miner_get_sensors` (Complete Real-Time Telemetry)
- **Description**: Reads all cached sensor telemetry, electrical statistics, real-time hashrate, temperatures, and block height directly from memory.
- **Input**: `{}` (empty table)
- **Output JSON Schema**:

```json
{
  "hashrate": 14.25,             // Real-time total hashrate (TH/s)
  "efficiency": 8.58,            // Real-time efficiency ratio (J/TH)
  "cpu_temp": 48.5,              // ESP32-P4 SoC core temperature (°C)
  "psu_temp": 52,                // Control board / power supply zone temp (°C)
  "chip_temp_0": 65,             // Hashboard temperature channel 0 (°C)
  "chip_temp_1": 67,             // Hashboard temperature channel 1 (°C)
  "fan_rpm_0": 3800,             // Fan 1 real-time speed (RPM)
  "fan_rpm_1": 3750,             // Fan 2 real-time speed (RPM)
  "fan_percent_0": 100,          // Fan 1 duty cycle percentage (0-100)
  "fan_percent_1": 100,          // Fan 2 duty cycle percentage (0-100)
  "auto_fan_mode": true,         // Whether fan is under automatic thermal control
  "manual_fan_percent": 80,      // Manual fan percentage setting
  "input_voltage": 12.08,        // 12V DC input voltage (V)
  "voltage": 4.80,               // ASIC series core supply voltage (V)
  "out_voltage": 4.80,           // Measured core voltage (V)
  "out_current": 25.40,          // Measured core current (A)
  "power": 121.92,               // Real-time measured power consumption (W)
  "max_power": 240.0,            // Maximum power limit ceiling (W)
  "nominal_input_voltage": 12,   // Nominal DC input voltage (12V)
  "best_diff": "15.8M",          // Best difficulty share submitted since boot
  "latest_block_height": 860432, // Current Bitcoin network block height
  "latest_block_pool": "ZSolo",  // Latest block solver pool
  "latest_block_reward": 3.125,  // Latest block reward (BTC)
  "btc_price": 98520.0,          // Real-time Bitcoin spot price (USD)
  "btc_change_pct": 2.35,        // 24h price change percentage (%)
  "sn": "BC08-P4-00123456"       // Miner hardware unique serial number
}
```

### 2.2 `miner_get_status` (ASIC & Pool State)
- **Description**: Returns current ASIC clock frequency, voltage level, operating mode, active Stratum pool, and worker name.
- **Input**: `{}`
- **Output JSON Schema**:
```json
{
  "frequency": 500,                    // ASIC clock frequency (MHz)
  "voltage": 480,                      // Voltage setting in 10mV units (480 = 4.80V)
  "work_mode": "Normal",               // Operating mode: "Normal", "Overclock", "Custom"
  "pool": "solo.ckpool.org:3333",      // Active primary Stratum pool endpoint
  "worker": "1A1zP1eP5QGefi2D...bc08", // Worker address / name
  "uptime_s": 86400                    // Miner uptime in seconds
}
```

### 2.3 `miner_get_system_info` (Identity & Device Configuration)
- **Description**: Returns hostname, Wi-Fi SSID, timezone, hardware/firmware version strings, screen brightness, and ARGB status.
- **Input**: `{}`
- **Output JSON Schema**:
```json
{
  "hostname": "bc08-miner",            // Configured hostname
  "wifi_ssid": "MyHome_WiFi",          // Connected Wi-Fi SSID
  "wifi_password": "********",         // Password masked
  "timezone": "UTC+8",                 // System timezone string
  "sn": "BC08-P4-00123456",            // Serial number
  "firmware_version": "v1.2.0",        // Firmware release version
  "web_version": "1.3.8",              // Web console bundle version
  "hardware_version": "BC08 v1",       // Hardware revision
  "screen_brightness": 100,            // Screen backlight percentage (0-100)
  "led_on": true,                      // ARGB water-cooling fan lights enabled
  "led_color": { "r": 0, "g": 255, "b": 128 } // ARGB current color
}
```

### 2.4 `miner_get_pools` (Stratum Pool Settings)
- **Description**: Queries configured primary and fallback (backup) Stratum pools.
- **Input**: `{}`
- **Output JSON Schema**:
```json
{
  "primary": { "url": "solo.ckpool.org", "port": 3333, "user": "...", "pass": "x" },
  "backup":  { "url": "pool.vkbit.com",  "port": 3333, "user": "...", "pass": "x" }
}
```

---

## 3. Miner Hardware Control APIs

Scripts can automate hardware policies such as **thermal LED warnings, dynamic fan speed control, night-mode dimming, and frequency adjustments**:

| Capability ID | Input Payload (Table) | Execution | Description |
|---|---|---|---|
| `miner_set_screen_brightness` | `{ brightness = 0..100 }` | **Instant** | Adjusts LCD backlight brightness (`0` - `100`%). Persists across boots. |
| `miner_set_led_color` | `{ r = 0..255, g = 0..255, b = 0..255 }` | **Instant** | Sets the color of the 30 ARGB LEDs on the cooling fan. |
| `miner_set_led_mode` | `{ on = true/false }` | **Instant** | Turns the ARGB fan LEDs ON (`true`) or OFF (`false`). |
| `miner_set_fan_mode` | `{ auto = true/false }` | **Instant** | Sets fan control mode: `true` for auto thermal PWM, `false` for manual. |
| `miner_set_fan_speed` | `{ speed = 0..100 }` | **Instant** (if in manual mode) | Sets custom fan speed percentage (`0` - `100`%). |
| `miner_set_work_mode` | `{ mode = "Normal"|"Overclock"|"Custom" }` | Requires reboot | Changes miner operating mode (`"Normal"`, `"Overclock"`, or `"Custom"`). |
| `miner_set_frequency` | `{ mhz = 100..2600 }` | Requires reboot | Configures ASIC chip clock frequency (`100` to `2600` MHz). |
| `miner_set_voltage` | `{ v = 400..500 }` or `{ mv = 4000..5000 }` | Requires reboot | Configures ASIC series supply voltage (unit: 10mV; 400=4.00V, 500=5.00V). |
| `miner_set_pool` | `{ type = "primary"|"backup", url, port, user, pass }` | Requires reboot | Updates primary or backup Stratum pool credentials. |
| `miner_set_system_config` | `{ hostname?, wifi_ssid?, wifi_password?, timezone? }` | Timezone instant | Configures hostname, Wi-Fi credentials, or timezone (e.g. `"UTC+8"`). |
| `miner_restart` | `{}` | 500ms delay | Safely reboots the device to apply pending hardware configs. |

---

## 4. System & OS Runtime (`require("system")`)

The `system` module is a native C extension exposed directly to the Lua environment without Capability wrapper overhead:

```lua
local system = require("system")

-- 1. Clocks & Timers
local ts = system.time()           -- Current Unix epoch timestamp in seconds
local date_str = system.date()     -- Formatted local date string (default: "%Y-%m-%d %H:%M:%S")
local ms = system.millis()         -- Monotonic millisecond counter since boot
local uptime = system.uptime()     -- Uptime in integer seconds

-- 2. Network Info
local ip = system.ip()             -- Station IP address string (e.g. "192.168.1.50") or nil if offline

-- 3. Memory & Wi-Fi Diagnostic Summary
local info = system.info()
print("WiFi SSID:", info.wifi_ssid)
print("WiFi RSSI:", info.wifi_rssi, "dBm")
print("Free Internal SRAM:", info.sram_free, "bytes")
print("Free External PSRAM:", info.psram_free, "bytes")

-- 4. FreeRTOS Heap Allocation Statistics
local heap = system.heap.get_info(system.heap.caps.DEFAULT)
print("Largest Free Heap Block:", heap.largest_free_block)
```

---

## 5. LCD Display & UI Module (`claw.display`)

BC08 features a **720×1280 portrait color LCD**.
- Pages **1 to 4** are reserved for native factory C views (Dashboard, Settings, Network, Marketplace).
- **Pages 5, 6, and 7 are dedicated to user extension Lua pages** (`page_id >= 5`).

### Safe Drawing Area
- **Resolution**: `720 × 1280`
- **System Top Status Bar**: `Y = 0 ~ 58` (Do not place interactive widgets here)
- **System Bottom Navigation Bar**: `Y = 1170 ~ 1280` (Do not obscure page indicators)
- **Safe Widget Canvas**: `X: 0 ~ 720`, `Y: 58 ~ 1170`

```lua
local PAGE = 5

-- 1. Create or reset page (title is displayed in the status bar)
claw.display.create_page(PAGE, "My Custom Page")

-- 2. Clear all widgets on the page
claw.display.clear_page(PAGE)

-- 3. Draw or update a text label
-- Signature: claw.display.label(page_id, obj_id, x, y, text, color_hex, font_size)
-- font_size supports: 13, 15, 24, 30, 45
claw.display.label(PAGE, 101, 40, 100, "BC08 Mining Monitor", 0xFFFFFF, 30)

-- 4. Draw a button or background card
-- Signature: claw.display.button(page_id, obj_id, x, y, w, h, text, bg_color_hex)
claw.display.button(PAGE, 102, 40, 160, 640, 120, "", 0x1E222B)

-- 5. Draw an image (PNG or JPG located on the F: flash drive)
-- Signature: claw.display.image(page_id, obj_id, x, y, w, h, path)
-- Image paths use the LVGL drive-letter form: "F:skills/<skill_dir>/assets/icon.png"
claw.display.image(PAGE, 103, 50, 180, 80, 80, "F:skills/my_skill/assets/icon.png")

-- 6. Poll Touch Events (Non-blocking)
local pid, oid = claw.display.pop_event()
if pid and oid then
    print(string.format("Touch event detected: Page %d, Object %d", pid, oid))
end

-- 7. Switch Active Screen View (1-7)
claw.display.change_page(1) -- Switches back to native Dashboard
```

---

## 6. File Storage & Persistence (`require("storage")`)

Persistent flash storage is mounted under `/fatfs`. Skills can save states, logs, and assets freely:

```lua
local storage = require("storage")

local root = storage.get_root_dir() -- Returns "/fatfs"
local file_path = storage.join_path(root, "my_config.json")

-- Write file
storage.write_file(file_path, '{"theme": "dark", "refresh_interval": 2000}')

-- Check existence & read
if storage.exists(file_path) then
    local content = storage.read_file(file_path)
    print("Content:", content)
end

-- List directory contents
local entries = storage.listdir(storage.join_path(root, "skills"))
for _, name in ipairs(entries) do
    print("Skill folder:", name)
end

-- Check free storage capacity
local total, free, used = storage.get_free_space()
print(string.format("Storage: %d KB free / %d KB total", free // 1024, total // 1024))
```

---

## 7. Timing & Watchdog Guidelines (`require("delay")`)

Lua scripts executing long-running or interactive polling loops (`while true do`) **must invoke `delay.delay_ms()`** to yield CPU cycles to FreeRTOS and prevent Task Watchdog Timer (Task WDT) resets:

```lua
local delay = require("delay")

while true do
    -- Perform task or UI update...

    -- Yield CPU and feed watchdog timer
    delay.delay_ms(1000)
end
```

---

## 8. Network & HTTP Requests (`http_request`)

The `http_request` Capability allows scripts to fetch remote data over HTTP/HTTPS.
For security, the firmware enforces an outbound domain allowlist:
- `127.0.0.1` and the device's local station IP (for local REST endpoints)
- `raw.githubusercontent.com` / `raw.kkgithub.com` (Skills marketplace downloads)
- `api.open-meteo.com` / `api.seniverse.com` / `api.qweather.com` (Weather APIs)

```lua
local capability = require("capability")
local json = require("json")

local ok, out, err = capability.call("http_request", {
    url = "https://api.open-meteo.com/v1/forecast?latitude=31.23&longitude=121.47&current_weather=true",
    method = "GET",
    timeout_ms = 10000,
    max_body_bytes = 16384
}, { source_cap = "my_skill" })

if ok then
    -- Output format: first line is HTTP status line, followed by the response body
    local status_line, body = out:match("^(.-)\n(.*)$")
    local data = json.decode(body)
    print("Temperature:", data.current_weather.temperature, "°C")
end
```

---

## 9. IM Notifications & Chatbot Alerts (`cap_im_*`)

When temperatures rise or hashrates drop unexpectedly, skills can push alerts to configured IM accounts:

```lua
local capability = require("capability")

-- 1. Send QQ Message
capability.call("qq_send_message", {
    message = "[BC08 Alert] Hashrate dropped below 10 TH/s!"
}, {
    chat_id = "c2c:12345678",
    source_cap = "miner_alert"
})

-- 2. Send Telegram Message
capability.call("tg_send_message", {
    message = "🚨 Miner Alert: Chip temperature exceeded 75°C!"
}, {
    chat_id = "-1001234567890",
    source_cap = "miner_alert"
})

-- 3. Send WeChat Message
capability.call("wechat_send_message", {
    chat_id = "room123@chatroom",
    message = "BC08 has switched to Overclock mode."
})
```

---

## 10. Localhost REST API Reference (`127.0.0.1`)

BC08 hosts an internal embedded web server. If your script requires per-chip ASIC diagnostics or autotuning logs, query `127.0.0.1` via `http_request`:

| Endpoint | Method | Description |
|---|---|---|
| `/api/miner/status` | `GET` | Real-time miner operational status and active pool connection. |
| `/api/miner/hashrate` | `GET` | Detailed telemetry for **all 8 BM1370 ASIC chips** (individual frequency, hashrate, error rates). |
| `/api/device/status` | `GET` | Hardware sensor state (fan speeds, board temperatures, core currents/voltages). |
| `/api/device/info` | `GET` | Serial number, MAC address, firmware version, and hardware revision. |
| `/api/device/rgb` | `GET` / `PUT` | Queries or sets ARGB water-cooling fan light mode and color. |

---

## 11. Complete Developer Example: Custom Live Mining Dashboard

Save this script as `/fatfs/ui/ui_page_5.lua`. When the device boots, it will automatically load this script and display a live telemetry dashboard on Page 5 of the LCD:

```lua
-- ================================================================
-- ui_page_5.lua — Custom Real-Time Miner Dashboard
-- @page_id 5
-- ================================================================

local capability = require("capability")
local json = require("json")
local delay = require("delay")

local PAGE = 5
local SCR_W, SCR_H = 720, 1280

-- Widget Object IDs
local ID_CARD      = 100
local ID_TITLE     = 101
local ID_HASHRATE  = 102
local ID_TEMP      = 103
local ID_POWER     = 104
local ID_BTN_FAN   = 105

-- 1. Initialize Page
claw.display.create_page(PAGE, "Mining Live")
claw.display.clear_page(PAGE)

-- 2. Draw Static Layout
claw.display.button(PAGE, ID_CARD, 30, 80, 660, 420, "", 0x181E29)
claw.display.label(PAGE, ID_TITLE, 60, 105, "BC08-P4 Live Telemetry", 0x88A0C0, 24)
claw.display.button(PAGE, ID_BTN_FAN, 60, 420, 600, 60, "Set Fans to 100% (Emergency)", 0x2A4365)

-- 3. Telemetry Refresh Loop
while true do
    -- Handle touch interactions
    local pid, oid = claw.display.pop_event()
    if pid == PAGE and oid == ID_BTN_FAN then
        -- User clicked emergency fan boost: disable auto mode & set to 100%
        capability.call("miner_set_fan_mode", { auto = false })
        capability.call("miner_set_fan_speed", { speed = 100 })
        claw.display.label(PAGE, ID_TITLE, 60, 105, "Fans Set to 100% Full Speed!", 0x38A169, 24)
    end

    -- Query memory-cached telemetry (zero-cost direct memory read)
    local ok, out = capability.call("miner_get_sensors", {})
    if ok then
        local d = json.decode(out)

        -- Update Hashrate
        local hs_text = string.format("Hashrate: %.2f TH/s (%.1f J/TH)", d.hashrate, d.efficiency)
        claw.display.label(PAGE, ID_HASHRATE, 60, 160, hs_text, 0x00FF88, 30)

        -- Update Temperature & Fans
        local temp_text = string.format("Temp: Board %d°C / Chip %d°C  Fans: %d RPM", d.psu_temp, d.chip_temp_0, d.fan_rpm_0)
        claw.display.label(PAGE, ID_TEMP, 60, 240, temp_text, 0xFFCC00, 24)

        -- Update Electrical Stats
        local pwr_text = string.format("Power: %.1f W  Voltage: %.2f V", d.power, d.voltage)
        claw.display.label(PAGE, ID_POWER, 60, 320, pwr_text, 0x63B3ED, 24)
    end

    -- Sleep 1000ms to yield CPU and feed watchdog
    delay.delay_ms(1000)
end
```
