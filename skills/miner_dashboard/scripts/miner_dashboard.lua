-- ================================================================
-- miner_dashboard.lua — BITCOIN MINER DASHBOARD
-- @page_id 5
-- @name MinerDashboard
-- @desc Live Bitcoin miner dashboard for BC08-P4 LCD.
--       Uses the Capability Bus for real-time miner telemetry,
--       system module for IP/time, and storage for static config.
-- ================================================================

local PAGE = 5

-- Screen dimensions (safe drawing area)
local SCR_W, SCR_H = 720, 1280
local PAD = 24
local GAP = 24
local CARD_W = math.floor((SCR_W - PAD * 2 - GAP) / 2)  -- 324
local TOP_H = 80
local SMALL_H = 220
local CONFIG_H = 320
local SYSTEM_H = 120

-- Color palette (dark theme, neon accents)
local BG = 0x050508
local CARD_BG = 0x0D0D14
local WHITE = 0xFFFFFF
local GRAY = 0x808080
local CYAN = 0x00FFFF
local MAGENTA = 0xFF00B0
local ORANGE = 0xFF8C00
local GREEN = 0x00FF41

-- Asset paths
local ASSET_DIR = "F:skills/miner_dashboard/assets/"
local ICONS = {
    wifi = ASSET_DIR .. "wifi.png",
    status = ASSET_DIR .. "status.png",
    hashrate = ASSET_DIR .. "hashrate.png",
    temp = ASSET_DIR .. "temp.png",
    btc = ASSET_DIR .. "btc.png",
    network = ASSET_DIR .. "network.png",
    pool = ASSET_DIR .. "pool.png",
    worker = ASSET_DIR .. "worker.png",
    pass = ASSET_DIR .. "pass.png",
    asic = ASSET_DIR .. "asic.png",
    freq = ASSET_DIR .. "freq.png",
    volt = ASSET_DIR .. "volt.png",
    gear = ASSET_DIR .. "gear.png",
}

-- Dashboard data.
--   ip / time             -> system.ip() / system.date()
--   hashrate / temp / btc / network -> capability.call("miner_get_sensors")
--   pool / worker / pass / mode / freq / volt -> capability.call("miner_get_status")
--   os                    -> capability.call("miner_get_system_info")
local DATA = {
    ip = "--",
    time = "--:--",
    hashrate = "--",
    hashrate_unit = "TH/s",
    temp = "--",
    btc_price = "--",
    btc_unit = "USD",
    network = "--",
    network_unit = "blocks",
    pool = "--",
    worker = "--",
    pass = "--",
    mode = "--",
    freq = "--",
    volt = "--",
    os = "--",
}

-- Optional on-device config overlay for fields that may be hard to read via capabilities.
local CONFIG_FILE = storage.join_path(storage.get_root_dir(), "skills", "miner_dashboard", "config.json")
local CONFIG_KEYS = { "temp", "pool", "worker", "pass", "mode", "freq", "volt", "os" }

-- Native modules (also exposed as globals; using require is closer to device behaviour).
local capability = require("capability")
local json = require("json")
local system = require("system")

-- ── Helpers ──
local function safe_decode(str)
    if type(str) ~= "string" or str == "" then return nil end
    local ok, data = pcall(json.decode, str)
    if ok and type(data) == "table" then return data end
    return nil
end

local function load_config()
    local ok, exists = pcall(storage.exists, CONFIG_FILE)
    if not ok or not exists then return end
    local ok_read, content = pcall(storage.read_file, CONFIG_FILE)
    if not ok_read or not content then return end
    local cfg = safe_decode(content)
    if not cfg then
        sys.log("warn", "config is not valid JSON")
        return
    end
    for _, k in ipairs(CONFIG_KEYS) do
        if cfg[k] ~= nil then DATA[k] = tostring(cfg[k]) end
    end
end

local function draw_card(x, y, w, h, border_clr, id)
    claw.display.button(PAGE, id, x, y, w, h, "", border_clr)
    claw.display.button(PAGE, id + 1, x + 2, y + 2, w - 4, h - 4, "", CARD_BG)
end

local function draw_title(x, y, text, color, id)
    claw.display.label(PAGE, id, x, y, text, color, 22)
end

local function draw_value(x, y, text, color, size, id)
    claw.display.label(PAGE, id, x, y, text, color, size)
end

local function draw_icon(x, y, path, id)
    claw.display.image(PAGE, id, x, y, 48, 48, path)
end

-- ── Top Bar ──
local function draw_top_bar()
    local x, y = PAD, 20
    local w = SCR_W - PAD * 2
    draw_card(x, y, w, TOP_H, CYAN, 10)

    draw_icon(x + 16, y + 16, ICONS.wifi, 12)
    claw.display.label(PAGE, 13, x + 72, y + 18, "IP", GRAY, 16)
    claw.display.label(PAGE, 14, x + 72, y + 40, DATA.ip, WHITE, 24)
    claw.display.label(PAGE, 15, x + w - 140, y + 28, DATA.time, CYAN, 28)
    draw_icon(x + w - 56, y + 16, ICONS.status, 16)
end

-- ── Metric Cards ──
local function draw_metric_card(x, y, title, value, unit, icon_path, color, base_id)
    draw_card(x, y, CARD_W, SMALL_H, color, base_id)
    draw_title(x + 16, y + 16, title, color, base_id + 2)
    draw_icon(x + 16, y + 80, icon_path, base_id + 3)
    draw_value(x + 76, y + 76, value, WHITE, 42, base_id + 4)
    draw_value(x + 76, y + 126, unit, color, 20, base_id + 5)
end

-- ── Config Row ──
local function draw_config_row(x, y, icon_path, label, value, color, base_id)
    draw_icon(x, y, icon_path, base_id)
    claw.display.label(PAGE, base_id + 1, x + 56, y + 6, label, color, 18)
    claw.display.label(PAGE, base_id + 2, x + 130, y + 6, value, WHITE, 18)
end

-- ── Config Cards ──
local function draw_mining_config(x, y, base_id)
    draw_card(x, y, CARD_W, CONFIG_H, CYAN, base_id)
    draw_title(x + 16, y + 16, "MINING CONFIG", CYAN, base_id + 2)
    draw_config_row(x + 16, y + 64, ICONS.pool, "POOL", DATA.pool, CYAN, base_id + 5)
    draw_config_row(x + 16, y + 132, ICONS.worker, "WORKER", DATA.worker, CYAN, base_id + 8)
    draw_config_row(x + 16, y + 200, ICONS.pass, "PASS", DATA.pass, CYAN, base_id + 11)
end

local function draw_asic_config(x, y, base_id)
    draw_card(x, y, CARD_W, CONFIG_H, MAGENTA, base_id)
    draw_title(x + 16, y + 16, "ASIC CONFIG", MAGENTA, base_id + 2)
    draw_config_row(x + 16, y + 64, ICONS.asic, "MODE", DATA.mode, MAGENTA, base_id + 5)
    draw_config_row(x + 16, y + 132, ICONS.freq, "FREQ", DATA.freq, MAGENTA, base_id + 8)
    draw_config_row(x + 16, y + 200, ICONS.volt, "VOLT", DATA.volt, MAGENTA, base_id + 11)
end

-- ── System Card ──
local function draw_system_card(x, y, base_id)
    local w = SCR_W - PAD * 2
    draw_card(x, y, w, SYSTEM_H, CYAN, base_id)
    draw_icon(x + 16, y + 36, ICONS.gear, base_id + 2)
    draw_title(x + 80, y + 42, "SYSTEM", CYAN, base_id + 3)
    draw_value(x + w - 230, y + 44, DATA.os, WHITE, 22, base_id + 4)
end

-- ── Main Render ──
local function render_dashboard()
    claw.display.clear_page(PAGE)
    claw.display.button(PAGE, 1, 0, 0, SCR_W, SCR_H, "", BG)
    draw_top_bar()

    local row1_y = 20 + TOP_H + 20
    draw_metric_card(PAD, row1_y, "HASHRATE", DATA.hashrate, DATA.hashrate_unit, ICONS.hashrate, CYAN, 20)
    draw_metric_card(PAD + CARD_W + GAP, row1_y, "TEMP", DATA.temp, "°C", ICONS.temp, MAGENTA, 30)

    local row2_y = row1_y + SMALL_H + GAP
    draw_metric_card(PAD, row2_y, "BTC PRICE", DATA.btc_price, DATA.btc_unit, ICONS.btc, ORANGE, 40)
    draw_metric_card(PAD + CARD_W + GAP, row2_y, "NETWORK", DATA.network, DATA.network_unit, ICONS.network, GREEN, 50)

    local row3_y = row2_y + SMALL_H + GAP
    draw_mining_config(PAD, row3_y, 60)
    draw_asic_config(PAD + CARD_W + GAP, row3_y, 80)

    local row4_y = row3_y + CONFIG_H + GAP
    draw_system_card(PAD, row4_y, 100)
end

-- ── Data Fetchers ──
local function update_time()
    local t = system.date("*t", system.time())
    DATA.time = string.format("%02d:%02d", t.hour, t.min)
end

local function read_telemetry()
    local ok, out = capability.call("miner_get_sensors", {})
    if not ok then
        sys.log("warn", "miner_get_sensors failed: " .. tostring(out))
        return
    end
    local s = safe_decode(out)
    if not s then
        sys.log("warn", "miner_get_sensors returned invalid JSON")
        return
    end
    if s.hashrate ~= nil then DATA.hashrate = string.format("%.2f", tonumber(s.hashrate) or 0) end
    if s.chip_temp_0 ~= nil then DATA.temp = tostring(s.chip_temp_0) end
    if s.btc_price ~= nil then DATA.btc_price = tostring(math.floor(tonumber(s.btc_price) or 0)) end
    if s.latest_block_height ~= nil then DATA.network = tostring(s.latest_block_height) end
end

local function read_status()
    local ok, out = capability.call("miner_get_status", {})
    if not ok then return end
    local s = safe_decode(out)
    if not s then return end
    if s.pool ~= nil then DATA.pool = tostring(s.pool) end
    if s.worker ~= nil then DATA.worker = tostring(s.worker) end
    if s.work_mode ~= nil then DATA.mode = tostring(s.work_mode) end
    if s.frequency ~= nil then DATA.freq = tostring(s.frequency) .. " MHz" end
    if s.voltage ~= nil then DATA.volt = string.format("%.0f mV", tonumber(s.voltage) * 10) end
end

local function read_system_info()
    local ok, out = capability.call("miner_get_system_info", {})
    if not ok then return end
    local s = safe_decode(out)
    if not s then return end
    local os_str = ""
    if s.firmware_version then os_str = "Thor OS " .. tostring(s.firmware_version) end
    if os_str ~= "" then DATA.os = os_str end
end

local function refresh_data()
    DATA.ip = system.ip() or "--"
    update_time()
    read_telemetry()
    read_status()
    read_system_info()
    load_config()
end

-- ── Entry ──
claw.display.create_page(PAGE, "Miner Dashboard")
claw.display.clear_page(PAGE)
refresh_data()
render_dashboard()

-- Refresh every 30 seconds; handle touch events.
while true do
    local p, obj = claw.display.pop_event()
    if p == PAGE and obj then
        sys.log("info", "dashboard event page=" .. p .. " obj=" .. obj)
    end

    refresh_data()
    render_dashboard()
    delay.delay_ms(30000)
end
