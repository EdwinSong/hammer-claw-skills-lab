-- ================================================================
-- miner_dashboard.lua — BITCOIN MINER DASHBOARD
-- @page_id 9
-- @name MinerDashboard
-- @desc Clean card-based Bitcoin miner dashboard for BC08-P4 LCD
-- ================================================================

local PAGE = 9

-- Screen dimensions
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

-- Mock dashboard data
local DATA = {
    ip = "192.168.2.71",
    time = "10:15",
    hashrate = "6.81",
    hashrate_unit = "TH/s",
    temp = "71.5",
    btc_price = "64211",
    btc_unit = "USD",
    network = "957552",
    network_unit = "sat",
    pool = "btc.zsolo.bid",
    worker = "1NjHG...uz6fm",
    pass = ".BC04",
    mode = "Normal",
    freq = "750 MHz",
    volt = "4800 mV",
    os = "Thor OS  1.0.0",
}

-- ── Helpers ──
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

-- ── Entry ──
claw.display.clear_page(PAGE)
claw.display.create_page(PAGE, "")
render_dashboard()
