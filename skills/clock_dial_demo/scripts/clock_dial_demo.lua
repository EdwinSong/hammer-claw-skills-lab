-- ================================================================
-- clock_dial_demo.lua — PREMIUM DIGITAL CLOCK (Claw Display Version)
-- @page_id 3
-- @name Clock-Dial-Demo
-- @desc Premium animated digital clock with 12h/24h toggle
-- ================================================================

local PAGE = 3
local SCR_W, SCR_H = 720, 1280

-- Object IDs
local ID_TITLE      = 301
local ID_CONTAINER  = 302
local ID_TIME       = 303
local ID_DATE       = 304
local ID_FORMAT     = 305
local ID_SEC_RING   = 310  -- base for 60 second-dot IDs (310–369)

-- State
local use_24h = true
local last_second = -1

-- Ring geometry (absolute page coords)
local RING_CX, RING_CY = 360, 360
local RING_R = 160
local DOT_SIZE = 6
local DOT_COLOR_OFF = 0x1A1C38
local DOT_COLOR_ON  = 0x00E5FF

-- ── Helpers ──
local function get_time()
    local ts = os.time()
    local t = os.date("*t", ts)
    return t.hour, t.min, t.sec, t.year, t.month, t.day
end

local function fmt_time(h, m, s)
    if use_24h then
        return string.format("%02d:%02d:%02d", h, m, s)
    else
        local h12 = h % 12
        if h12 == 0 then h12 = 12 end
        local ampm = (h >= 12) and "PM" or "AM"
        return string.format("%02d:%02d:%02d %s", h12, m, s, ampm)
    end
end

local function fmt_date(y, mon, d)
    return string.format("%04d-%02d-%02d", y, mon, d)
end

-- ── Dot position helper ──
local function dot_xy(sec)
    local rad = math.rad(sec * 6 - 90)
    local x = RING_CX + math.floor(math.cos(rad) * RING_R + 0.5) - DOT_SIZE // 2
    local y = RING_CY + math.floor(math.sin(rad) * RING_R + 0.5) - DOT_SIZE // 2
    return x, y
end

-- ── Draw a single second dot ──
local function draw_dot(sec, color)
    local x, y = dot_xy(sec)
    claw.display.button(PAGE, ID_SEC_RING + sec, x, y, DOT_SIZE, DOT_SIZE, "", color)
end

-- ── Update a dot: turn old off, new on ──
local function update_dot(old_sec, new_sec)
    if old_sec == new_sec then return end
    if old_sec >= 0 and old_sec < 60 then
        draw_dot(old_sec, DOT_COLOR_OFF)
    end
    if new_sec >= 0 and new_sec < 60 then
        draw_dot(new_sec, DOT_COLOR_ON)
    end
end

-- ── Draw static shell ──
local function draw_shell()
    -- Title
    claw.display.label(PAGE, ID_TITLE, 48, 70, "CLOCK DIAL", 0x00E5FF, 24)

    -- Glassmorphic container (touch target for format toggle)
    claw.display.container(PAGE, ID_CONTAINER, 48, 120, 624, 480, 0x16182E, 20)

    -- All ring dots (initially dark)
    for i = 0, 59 do
        draw_dot(i, DOT_COLOR_OFF)
    end
end

-- ── Update time display (1 fps) ──
local function update_display()
    local h, m, s, y, mon, d = get_time()

    if s == last_second then return end

    -- Update second dot
    update_dot(last_second, s)
    last_second = s

    -- Time string
    local time_str = fmt_time(h, m, s)
    local tx = use_24h and 150 or 120
    claw.display.label(PAGE, ID_TIME, tx, 205, time_str, 0xFFFFFF, 58)

    -- Date
    claw.display.label(PAGE, ID_DATE, 240, 290, fmt_date(y, mon, d), 0x8899AA, 24)

    -- Format badge
    claw.display.label(PAGE, ID_FORMAT, 332, 350, use_24h and "24H" or "12H", 0x30D158, 20)
end

-- ════════════════════════════════════════════════════
-- MAIN ENTRY
-- ════════════════════════════════════════════════════
claw.display.create_page(PAGE, "CLOCK DIAL")
draw_shell()

-- Main Polling Loop
while true do
    local pid, oid = claw.display.pop_event()

    if pid == PAGE and oid == ID_CONTAINER then
        use_24h = not use_24h
        last_second = -1  -- force full redraw
    end

    update_display()
    delay.delay_ms(200)
end
