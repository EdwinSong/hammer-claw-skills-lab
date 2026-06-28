-- ================================================================
-- clock_dial_demo.lua — PREMIUM VINTAGE MECHANICAL CLOCK DIAL
-- @page_id 7
-- @name Clock-Dial-Demo
-- @desc Premium animated mechanical Roman clock dial
-- ================================================================

local PAGE = 7
local SCR_W, SCR_H = 720, 1280

-- Center of the clock dial
local CENTER_X = 360
local CENTER_Y = 625

-- Object IDs
local ID_BG         = 301
local ID_DIAL       = 302
local ID_CENTER_CAP = 303

-- Keep track of last state to minimize updates
local last_min = -1
local last_hour = -1

-- ── Helpers ──
local function get_time()
    local ts = os.time()
    local t = os.date("*t", ts)
    return t.hour, t.min
end

-- ── Update hands positions ──
local function update_hands(hours, minutes)
    -- Hour hand angle (30 deg/hour + 0.5 deg/minute)
    local h_angle = (hours % 12) * 30 + minutes * 0.5
    local h_rad = math.rad(h_angle - 90)
    
    -- Minute hand angle (6 deg/minute)
    local m_angle = minutes * 6
    local m_rad = math.rad(m_angle - 90)
    
    -- Draw Hour Hand (14 dots, length 140, tapered size 14 -> 8)
    for i = 1, 14 do
        local dist = i * 10
        local size = 14 - math.floor(i * 6 / 14)
        local x = CENTER_X + math.floor(math.cos(h_rad) * dist + 0.5) - size // 2
        local y = CENTER_Y + math.floor(math.sin(h_rad) * dist + 0.5) - size // 2
        -- Color: Deep metallic blue/black (0x1F2A38)
        claw.display.button(PAGE, 310 + i, x, y, size, size, "", 0x1F2A38)
    end
    
    -- Draw Minute Hand (25 dots, length 200, tapered size 10 -> 6)
    for i = 1, 25 do
        local dist = i * 8
        local size = 10 - math.floor(i * 4 / 25)
        local x = CENTER_X + math.floor(math.cos(m_rad) * dist + 0.5) - size // 2
        local y = CENTER_Y + math.floor(math.sin(m_rad) * dist + 0.5) - size // 2
        -- Color: Classic metallic steel blue (0x2C4B5E)
        claw.display.button(PAGE, 330 + i, x, y, size, size, "", 0x2C4B5E)
    end
end

-- ── Draw static shell ──
local function draw_shell()
    -- 1. Full-screen dark green background card
    claw.display.container(PAGE, ID_BG, 0, 0, SCR_W, SCR_H, 0x162520, 0)

    -- 2. Dial Image (600x600 centered at X=60, Y=325)
    claw.display.image(PAGE, ID_DIAL, 60, 325, 600, 600, "/fatfs/skills/clock_dial_demo/scripts/dial.png")

    -- 3. Center cap (brass color, 24x24 centered at X=348, Y=613)
    claw.display.button(PAGE, ID_CENTER_CAP, 348, 613, 24, 24, "", 0xA17A4A)
end

-- ════════════════════════════════════════════════════
-- MAIN ENTRY
-- ════════════════════════════════════════════════════
-- Create page with empty title to keep top bar clean and hide default title label
claw.display.create_page(PAGE, "")
draw_shell()

-- Main Polling Loop
while true do
    -- Pop events to keep queue clean (we have no buttons to handle)
    claw.display.pop_event()

    local h, m = get_time()
    if h ~= last_hour or m ~= last_min then
        update_hands(h, m)
        last_hour = h
        last_min = m
    end

    delay.delay_ms(1000)
end
