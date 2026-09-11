-- ================================================================
-- watercooling_light_timer.lua — Hydro Light Control (Aqua Core)
-- @page_id 7
-- @name HydroLightControl
-- @desc Schedule the BC08-P4 water-cooling ARGB LED to turn off
--       after a delay (minutes/hours) or at a specific clock time.
--       Uses capability.call for LED control and system.* for clocks.
-- ================================================================

local PAGE = 7
-- BC08 LCD is fixed at 720x1280 (API_REFERENCE.md §5); there is no
-- get_size() in the documented API, so the geometry is hardcoded.
local SCR_W, SCR_H = 720, 1280
-- Safe widget canvas: Y 58 ~ 1170 (system status bar above, nav bar below)
local SAFE_TOP = 58
local SAFE_BOTTOM = 1170
local PAD = 24
local GAP = 16

-- Color palette — neon Aqua dark
local BG = 0x0A0D12
local CARD_BG = 0x121820
local STROKE = 0x1E2733
local TEXT = 0xFFFFFF
local SUBTEXT = 0x8B9BB4
local CYAN = 0x00E5FF
local PURPLE = 0xA855F7
local PINK = 0xEC4899
local BLUE = 0x3B82F6

-- Documented font sizes only: 13, 15, 24, 30, 45
local FS_SMALL = 13
local FS_BODY = 15
local FS_TITLE = 24
local FS_BIG = 30

-- Native modules (only whitelisted modules may be required)
local capability = require("capability")
local system = require("system")
local delay = require("delay")

-- Asset paths — images use the F: flash drive letter (API_REFERENCE.md §5)
local ASSET_DIR = "F:skills/watercooling_light_timer/assets/"
local ICONS = {
    title = ASSET_DIR .. "title_aqua_core.png",
    power = ASSET_DIR .. "power_btn.png",
    ring = ASSET_DIR .. "ring_bg.png",
    minus = ASSET_DIR .. "btn_minus.png",
    plus = ASSET_DIR .. "btn_plus.png",
    start = ASSET_DIR .. "start_btn.png",
    stop = ASSET_DIR .. "stop_btn.png",
    preset_active = ASSET_DIR .. "preset_active.png",
    preset_inactive = ASSET_DIR .. "preset_inactive.png",
    digit_colon = ASSET_DIR .. "digit_colon.png",
    chevron_up = ASSET_DIR .. "chevron_up.png",
    chevron_down = ASSET_DIR .. "chevron_down.png",
}

ICONS.digit = {}
for d = 0, 9 do
    ICONS.digit[tostring(d)] = ASSET_DIR .. "digit_" .. d .. ".png"
end

local COLORS = {
    { name = "Cyan", rgb = { r = 0, g = 229, b = 255 } },
    { name = "Pink", rgb = { r = 236, g = 72, b = 153 } },
    { name = "Purple", rgb = { r = 168, g = 85, b = 247 } },
    { name = "Blue", rgb = { r = 59, g = 130, b = 246 } },
}

local PRESETS = {
    { label = "15 min", value = 15, unit = "minutes" },
    { label = "30 min", value = 30, unit = "minutes" },
    { label = "1 hour", value = 1, unit = "hours" },
    { label = "2 hours", value = 2, unit = "hours" },
}

-- Digital time display sizes
local DIGIT_W = 52
local DIGIT_H = 78
local COLON_W = 26
local TIME_W = 6 * DIGIT_W + 2 * COLON_W

-- Application state
local ctx = {
    light_on = true,
    rgb_index = 1,
    mode = "delay",
    active = false,
    target_ts = 0,
    started_at = 0,
    delay_value = 30,
    delay_unit = "minutes",
    schedule_hour = 21,
    schedule_min = 0,
}

local timezone_offset_sec = 0
local timezone_label = "UTC"

-- ── Julian day helpers ──
local function ymd_to_days(y, m, d)
    local a = math.floor((14 - m) / 12)
    local yy = y + 4800 - a
    local mm = m + 12 * a - 3
    return d + math.floor((153 * mm + 2) / 5) + 365 * yy + math.floor(yy / 4) - math.floor(yy / 100) + math.floor(yy / 400) - 32045
end

local function time_to_utc_seconds(y, m, d, h, min, s)
    return (ymd_to_days(y, m, d) - ymd_to_days(1970, 1, 1)) * 86400 + h * 3600 + min * 60 + s
end

-- system.date() returns a local date string "YYYY-MM-DD HH:MM:SS"
local function parse_local_date()
    local y, m, d, h, min, s = system.date():match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    return tonumber(y), tonumber(m), tonumber(d), tonumber(h), tonumber(min), tonumber(s)
end

-- ── Timezone ──
local function compute_timezone_offset()
    local now = system.time()
    local y, m, d, h, min, s = parse_local_date()
    local local_as_utc = time_to_utc_seconds(y, m, d, h, min, s)
    return local_as_utc - now
end

local function format_offset(seconds)
    local sign = seconds >= 0 and "+" or "-"
    local abs_s = math.abs(seconds)
    local h = math.floor(abs_s / 3600)
    local m = math.floor((abs_s % 3600) / 60)
    return string.format("UTC%s%02d:%02d", sign, h, m)
end

-- ── RGB control via capability bus (API_REFERENCE.md §3) ──
local function apply_rgb()
    local c = COLORS[ctx.rgb_index]
    if not ctx.light_on then
        print("apply_rgb: off")
        capability.call("miner_set_led_mode", { on = false })
        return
    end
    print(string.format("apply_rgb: color=%s rgb=%d,%d,%d", c.name, c.rgb.r, c.rgb.g, c.rgb.b))
    capability.call("miner_set_led_mode", { on = true })
    capability.call("miner_set_led_color", c.rgb)
end

-- ── Delay duration ──
local function get_delay_duration_ms()
    if ctx.delay_unit == "hours" then
        return ctx.delay_value * 3600 * 1000
    else
        return ctx.delay_value * 60 * 1000
    end
end

local function format_time_hms(total_seconds)
    total_seconds = math.max(0, total_seconds)
    local h = math.floor(total_seconds / 3600)
    local m = math.floor((total_seconds % 3600) / 60)
    local s = total_seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- ── Timer logic ──
local function compute_schedule_target(hour, min)
    local now = system.time()
    local y, m, d = parse_local_date()
    local target_local = time_to_utc_seconds(y, m, d, hour, min, 0)
    local target_utc = target_local - timezone_offset_sec
    if target_utc <= now then
        target_utc = target_utc + 24 * 3600
    end
    return target_utc
end

local function get_remaining_seconds()
    if not ctx.active then return 0 end
    local now = system.time()
    if ctx.mode == "delay" then
        return (ctx.started_at + math.floor(get_delay_duration_ms() / 1000)) - now
    else
        return ctx.target_ts - now
    end
end

local function start_timer()
    if ctx.mode == "delay" then
        ctx.started_at = system.time()
        print(string.format("timer started: delay mode value=%d unit=%s", ctx.delay_value, ctx.delay_unit))
    else
        ctx.target_ts = compute_schedule_target(ctx.schedule_hour, ctx.schedule_min)
        print(string.format("timer started: schedule target_ts=%d", ctx.target_ts))
    end
    ctx.active = true
end

local function cancel_timer()
    ctx.active = false
    print("timer cancelled")
end

-- ── UI helpers ──
-- claw.display has no container widget; a button with empty text serves
-- as a filled background card (API_REFERENCE.md §5 example).
local function draw_card(x, y, w, h, color, id)
    claw.display.button(PAGE, id, math.floor(x), math.floor(y), math.floor(w), math.floor(h), "", color)
end

local function draw_label(x, y, text, color, size, id)
    claw.display.label(PAGE, id, math.floor(x), math.floor(y), text, color, size)
end

local function text_width(text, size)
    return #text * size * 0.5
end

local function draw_label_center(x, y, text, color, size, id)
    draw_label(x - math.floor(text_width(text, size) / 2), y, text, color, size, id)
end

local function draw_image(x, y, path, id, w, h)
    claw.display.image(PAGE, id, math.floor(x), math.floor(y), w or 48, h or (w or 48), path)
end

local function draw_time_images(cx, y, time_str, id_start)
    local x = cx - TIME_W / 2
    for i = 1, #time_str do
        local ch = time_str:sub(i, i)
        if ch == ":" then
            draw_image(x, y, ICONS.digit_colon, id_start + i - 1, COLON_W, DIGIT_H)
            x = x + COLON_W
        else
            draw_image(x, y, ICONS.digit[ch], id_start + i - 1, DIGIT_W, DIGIT_H)
            x = x + DIGIT_W
        end
    end
end

-- ── Main UI ──
-- Object IDs follow the miner_dashboard.lua convention: each section gets a
-- block base ID, and every draw_* function receives its base and only uses
-- small offsets inside its own block. Touch handling references the same
-- bases, so IDs never appear as bare magic numbers.
local ID_BG = 1         -- full-screen background
local ID_HEADER = 10    -- 11..14: title image, power button/image, timezone
local ID_MODE = 40      -- 40..49: Timer/Schedule mode switch
local ID_RING = 50      -- 50..60: ring image + countdown digits
local ID_SCHED = 70     -- 70..93: schedule card, chevrons, summary, countdown
local ID_WHEEL_H = 100  -- 100..128: hours wheel
local ID_WHEEL_M = 140  -- 140..168: minutes wheel
local ID_PRESET = 170   -- 170..181: preset buttons
local ID_INPUT = 190    -- 190..194: countdown +/- input
local ID_FOOTER = 195   -- footer hint
local ID_START = 196    -- 196..198: start/stop button

local function draw_header(base)
    local y = SAFE_TOP + 12 -- 70, keep clear of the system status bar
    local power_size = 72
    draw_image(PAD, y, ICONS.title, base + 1, 220, 44)
    claw.display.button(PAGE, base + 2, SCR_W - PAD - power_size, y, power_size, power_size, "", BG)
    draw_image(SCR_W - PAD - power_size, y, ICONS.power, base + 3, power_size, power_size)
    local tz_w = text_width(timezone_label, FS_SMALL)
    draw_label(SCR_W - PAD - power_size - 16 - tz_w, y + 26, timezone_label, SUBTEXT, FS_SMALL, base + 4)
end

local function draw_mode_switch(base)
    local y = 210
    local pill_w = 360
    local pill_h = 60
    local pill_x = math.floor((SCR_W - pill_w) / 2)
    local half = math.floor(pill_w / 2)

    draw_card(pill_x, y, pill_w, pill_h, STROKE, base)

    local count_active = ctx.mode == "delay"
    claw.display.button(PAGE, base + 1, pill_x, y, half, pill_h, "", count_active and CYAN or STROKE)
    draw_label_center(pill_x + half / 2, y + 18, "Timer", count_active and BG or SUBTEXT, FS_TITLE, base + 2)

    local sched_active = ctx.mode == "schedule"
    claw.display.button(PAGE, base + 3, pill_x + half, y, half, pill_h, "", sched_active and CYAN or STROKE)
    draw_label_center(pill_x + half + half / 2, y + 18, "Schedule", sched_active and BG or SUBTEXT, FS_TITLE, base + 4)
end

local function draw_ring(base)
    local ring_w = 440
    local ring_x = math.floor((SCR_W - ring_w) / 2)
    local ring_y = 330
    draw_image(ring_x, ring_y, ICONS.ring, base, ring_w, ring_w)

    local cx = ring_x + ring_w / 2
    local cy = ring_y + ring_w / 2

    local total
    if ctx.active then
        total = get_remaining_seconds()
    else
        total = ctx.delay_unit == "hours" and ctx.delay_value * 3600 or ctx.delay_value * 60
    end
    local time_str = format_time_hms(total)

    draw_label_center(cx, cy - 100, "Turns off in", SUBTEXT, FS_BODY, base + 1)
    draw_time_images(cx, cy - 39, time_str, base + 2) -- 8 digit/colon images
    draw_label_center(cx, cy + 55, "Hours : Minutes : Seconds", SUBTEXT, FS_SMALL, base + 10)
end

-- ── Schedule mode: wheel picker card ──
local WHEEL_DIGIT_W = 44
local WHEEL_DIGIT_H = 66

local function draw_wheel_value(box_cx, row_cy, value, selected, id_base)
    local str = string.format("%02d", value)
    if selected then
        local total_w = WHEEL_DIGIT_W * 2
        local x = box_cx - total_w / 2
        local y = row_cy - WHEEL_DIGIT_H / 2
        draw_image(x, y, ICONS.digit[str:sub(1, 1)], id_base, WHEEL_DIGIT_W, WHEEL_DIGIT_H)
        draw_image(x + WHEEL_DIGIT_W, y, ICONS.digit[str:sub(2, 2)], id_base + 1, WHEEL_DIGIT_W, WHEEL_DIGIT_H)
    else
        draw_label_center(box_cx, row_cy - 12, str, SUBTEXT, FS_TITLE, id_base)
    end
end

local function draw_wheel(box_x, box_y, box_w, box_h, value, max_val, id_base)
    draw_card(box_x, box_y, box_w, box_h, CARD_BG, id_base)
    local box_cx = box_x + box_w / 2
    local row_h = box_h / 5
    -- highlight dividers around the selected (middle) row
    local sel_y = box_y + row_h * 2
    draw_card(box_x + 20, sel_y, box_w - 40, 2, STROKE, id_base + 10)
    draw_card(box_x + 20, sel_y + row_h, box_w - 40, 2, STROKE, id_base + 11)
    for i = -2, 2 do
        local v = (value + i) % max_val
        local row_cy = box_y + row_h * (i + 2) + row_h / 2
        draw_wheel_value(box_cx, row_cy, v, i == 0, id_base + 20 + (i + 2) * 2)
    end
end

local function draw_schedule_card(base)
    local card_y = 330
    local card_h = 560
    draw_card(PAD, card_y, SCR_W - PAD * 2, card_h, CARD_BG, base)

    draw_label(PAD + 32, card_y + 20, "SCHEDULE OFF", TEXT, FS_BIG, base + 1)
    draw_label(PAD + 32, card_y + 56, "Pick a time to power off", CYAN, FS_BODY, base + 2)

    -- geometry: [hours box][mid col: ^ : v][minutes box][^ v]
    local box_w = 200
    local box_h = 300
    local box_y = card_y + 100
    local hours_x = 70
    local mins_x = 370
    local mid_cx = 320          -- colon + hour chevrons
    local right_cx = 610        -- minute chevrons
    local hours_cx = hours_x + box_w / 2
    local mins_cx = mins_x + box_w / 2

    draw_label_center(hours_cx, box_y - 32, "HOURS", CYAN, FS_SMALL, base + 3)
    draw_label_center(mins_cx, box_y - 32, "MINUTES", CYAN, FS_SMALL, base + 4)

    draw_wheel(hours_x, box_y, box_w, box_h, ctx.schedule_hour, 24, ID_WHEEL_H)
    draw_wheel(mins_x, box_y, box_w, box_h, ctx.schedule_min, 60, ID_WHEEL_M)

    -- colon between selected rows
    local sel_cy = box_y + box_h / 2
    draw_image(mid_cx - 10, sel_cy - 30, ICONS.digit_colon, base + 5, 20, 60)

    -- hour chevrons (middle column)
    local chev = 56
    claw.display.button(PAGE, base + 6, mid_cx - chev / 2, box_y - 8, chev, chev, "", CARD_BG)
    draw_image(mid_cx - chev / 2, box_y - 8, ICONS.chevron_up, base + 7, chev, chev)
    claw.display.button(PAGE, base + 8, mid_cx - chev / 2, box_y + box_h - chev + 8, chev, chev, "", CARD_BG)
    draw_image(mid_cx - chev / 2, box_y + box_h - chev + 8, ICONS.chevron_down, base + 9, chev, chev)

    -- minute chevrons (right column)
    claw.display.button(PAGE, base + 10, right_cx - chev / 2, box_y - 8, chev, chev, "", CARD_BG)
    draw_image(right_cx - chev / 2, box_y - 8, ICONS.chevron_up, base + 11, chev, chev)
    claw.display.button(PAGE, base + 12, right_cx - chev / 2, box_y + box_h - chev + 8, chev, chev, "", CARD_BG)
    draw_image(right_cx - chev / 2, box_y + box_h - chev + 8, ICONS.chevron_down, base + 13, chev, chev)

    -- summary
    local target = compute_schedule_target(ctx.schedule_hour, ctx.schedule_min)
    if ctx.active then
        target = ctx.target_ts
    end
    local diff = math.max(0, target - system.time())
    local hh = math.floor(diff / 3600)
    local mm = math.floor((diff % 3600) / 60)
    local summary = string.format("Turn off at %02d:%02d", ctx.schedule_hour, ctx.schedule_min)
    draw_label_center(SCR_W / 2, card_y + 430, summary, TEXT, FS_TITLE, base + 14)
    local sub
    if hh > 0 then
        sub = string.format("in %d hour%s %d min", hh, hh > 1 and "s" or "", mm)
    else
        sub = string.format("in %d min", mm)
    end
    draw_label_center(SCR_W / 2, card_y + 470, sub, SUBTEXT, FS_BODY, base + 15)

    -- live countdown digits while the timer is running
    if ctx.active then
        local cd = format_time_hms(diff)
        local dw, dh, cw = 26, 39, 13
        local x = (SCR_W - (6 * dw + 2 * cw)) / 2
        local y = card_y + 500
        for i = 1, #cd do
            local ch = cd:sub(i, i)
            if ch == ":" then
                draw_image(x, y, ICONS.digit_colon, base + 15 + i, cw, dh)
                x = x + cw
            else
                draw_image(x, y, ICONS.digit[ch], base + 15 + i, dw, dh)
                x = x + dw
            end
        end
    end
end

local function draw_presets(base)
    if ctx.mode == "schedule" then return end
    local y = 790
    local h = 64
    local btn_w = math.floor((SCR_W - PAD * 2 - GAP * 3) / 4)
    for i, p in ipairs(PRESETS) do
        local x = PAD + (i - 1) * (btn_w + GAP)
        local is_active = ctx.delay_value == p.value and ctx.delay_unit == p.unit
        local img = is_active and ICONS.preset_active or ICONS.preset_inactive
        local fill = is_active and CYAN or CARD_BG
        claw.display.button(PAGE, base + i - 1, x, y, btn_w, h, "", fill)
        draw_image(x, y, img, base + 4 + i - 1, btn_w, h)
        draw_label_center(x + btn_w / 2, y + 22, p.label, is_active and BG or TEXT, FS_BODY, base + 8 + i - 1)
    end
end

local function draw_custom_input(base)
    if ctx.mode == "schedule" then return end
    local y = 865
    local cx = math.floor(SCR_W / 2)
    local btn_size = 84

    -- Countdown: +/- buttons centered with a divider
    local spacing = 120
    local btn_inner = 60
    local offset = (btn_size - btn_inner) / 2
    claw.display.button(PAGE, base, cx - spacing - btn_size + offset, y + offset, btn_inner, btn_inner, "", CARD_BG)
    draw_image(cx - spacing - btn_size, y, ICONS.minus, base + 1, btn_size, btn_size)
    claw.display.button(PAGE, base + 2, cx + spacing + offset, y + offset, btn_inner, btn_inner, "", CARD_BG)
    draw_image(cx + spacing, y, ICONS.plus, base + 3, btn_size, btn_size)
    -- subtle vertical divider
    draw_card(cx - 1, y + 20, 2, btn_size - 40, STROKE, base + 4)
end

local function draw_footer(base)
    draw_label_center(SCR_W / 2, 960, "LED will turn off automatically", SUBTEXT, FS_SMALL, base)
end

local function draw_start_button(base)
    local y = 1000
    local w = SCR_W - PAD * 2
    local h = 90
    local text
    if ctx.active then
        text = "Stop Timer"
    elseif ctx.mode == "schedule" then
        text = "Set Schedule"
    else
        text = "Start Timer"
    end
    local img = ctx.active and ICONS.stop or ICONS.start
    local text_clr = ctx.active and TEXT or BG
    claw.display.button(PAGE, base, PAD, y, w, h, "", CARD_BG)
    draw_image(PAD, y, img, base + 1, w, h)
    draw_label_center(SCR_W / 2, y + 34, text, text_clr, FS_TITLE, base + 2)
end

local function draw_ui()
    print(string.format("draw_ui: mode=%s active=%s light_on=%s rgb_index=%d", ctx.mode, tostring(ctx.active), tostring(ctx.light_on), ctx.rgb_index))
    claw.display.clear_page(PAGE)
    draw_card(0, 0, SCR_W, SCR_H, BG, ID_BG)

    draw_header(ID_HEADER)
    draw_mode_switch(ID_MODE)
    if ctx.mode == "schedule" then
        draw_schedule_card(ID_SCHED)
    else
        draw_ring(ID_RING)
        draw_presets(ID_PRESET)
        draw_custom_input(ID_INPUT)
    end
    draw_footer(ID_FOOTER)
    draw_start_button(ID_START)
end

-- ── Event handling ──
-- Buttons are the intended touch targets, but on device images/labels drawn
-- on top of a button can steal the event. Map those overlay IDs back to the
-- same action as the button beneath them.
local function handle_touch(obj)
    print(string.format("handle_touch: obj=%d", obj))

    -- Power button (and the power icon image on top of it)
    if obj == ID_HEADER + 2 or obj == ID_HEADER + 3 then
        ctx.light_on = not ctx.light_on
        print("handle_touch: power toggle light_on=" .. tostring(ctx.light_on))
        apply_rgb()

    -- Timer/Schedule pill button (and labels drawn on top)
    elseif obj == ID_MODE + 1 or obj == ID_MODE + 2 then
        print("handle_touch: switch to delay mode")
        cancel_timer()
        ctx.mode = "delay"
    elseif obj == ID_MODE + 3 or obj == ID_MODE + 4 then
        print("handle_touch: switch to schedule mode")
        cancel_timer()
        ctx.mode = "schedule"

    -- Preset buttons, their background images, and their labels
    elseif (obj >= ID_PRESET and obj <= ID_PRESET + 3)
        or (obj >= ID_PRESET + 4 and obj <= ID_PRESET + 7)
        or (obj >= ID_PRESET + 8 and obj <= ID_PRESET + 11) then
        local idx
        if obj >= ID_PRESET and obj <= ID_PRESET + 3 then idx = obj - ID_PRESET + 1
        elseif obj >= ID_PRESET + 4 and obj <= ID_PRESET + 7 then idx = obj - (ID_PRESET + 4) + 1
        else idx = obj - (ID_PRESET + 8) + 1 end
        local p = PRESETS[idx]
        print("handle_touch: preset " .. p.label)
        cancel_timer()
        ctx.mode = "delay"
        ctx.delay_value = p.value
        ctx.delay_unit = p.unit

    -- Minus/Plus buttons (and the icon images on top)
    elseif obj == ID_INPUT or obj == ID_INPUT + 1 then
        ctx.delay_value = math.max(1, ctx.delay_value - 1)
        print("handle_touch: delay_value=" .. ctx.delay_value)
    elseif obj == ID_INPUT + 2 or obj == ID_INPUT + 3 then
        ctx.delay_value = math.min(999, ctx.delay_value + 1)
        print("handle_touch: delay_value=" .. ctx.delay_value)

    -- Schedule chevron buttons (and the chevron icon images on top)
    elseif obj == ID_SCHED + 6 or obj == ID_SCHED + 7 then -- hour up
        ctx.schedule_hour = (ctx.schedule_hour + 1) % 24
        print("handle_touch: schedule_hour=" .. ctx.schedule_hour)
        if ctx.active and ctx.mode == "schedule" then
            ctx.target_ts = compute_schedule_target(ctx.schedule_hour, ctx.schedule_min)
        end
    elseif obj == ID_SCHED + 8 or obj == ID_SCHED + 9 then -- hour down
        ctx.schedule_hour = (ctx.schedule_hour - 1) % 24
        print("handle_touch: schedule_hour=" .. ctx.schedule_hour)
        if ctx.active and ctx.mode == "schedule" then
            ctx.target_ts = compute_schedule_target(ctx.schedule_hour, ctx.schedule_min)
        end
    elseif obj == ID_SCHED + 10 or obj == ID_SCHED + 11 then -- minute up
        ctx.schedule_min = (ctx.schedule_min + 1) % 60
        print("handle_touch: schedule_min=" .. ctx.schedule_min)
        if ctx.active and ctx.mode == "schedule" then
            ctx.target_ts = compute_schedule_target(ctx.schedule_hour, ctx.schedule_min)
        end
    elseif obj == ID_SCHED + 12 or obj == ID_SCHED + 13 then -- minute down
        ctx.schedule_min = (ctx.schedule_min - 1) % 60
        print("handle_touch: schedule_min=" .. ctx.schedule_min)
        if ctx.active and ctx.mode == "schedule" then
            ctx.target_ts = compute_schedule_target(ctx.schedule_hour, ctx.schedule_min)
        end

    -- Start/Stop button (and the background image + label on top)
    elseif obj == ID_START or obj == ID_START + 1 or obj == ID_START + 2 then
        if ctx.active then
            print("handle_touch: stop button")
            cancel_timer()
        else
            print("handle_touch: start button")
            start_timer()
        end
    else
        print("handle_touch: unhandled obj=" .. obj)
    end
    draw_ui()
end

-- ── Check deadline ──
local function check_deadline()
    if not ctx.active then return end
    local remaining = get_remaining_seconds()
    print(string.format("check_deadline: remaining=%d mode=%s", remaining, ctx.mode))
    if remaining <= 0 then
        ctx.light_on = false
        apply_rgb()
        ctx.active = false
        print("timer expired, LED off")
        draw_ui()
    end
end

-- ── Entry ──
claw.display.create_page(PAGE, "Hydro Light Control")
claw.display.clear_page(PAGE)

timezone_offset_sec = compute_timezone_offset()
timezone_label = format_offset(timezone_offset_sec)

apply_rgb()
check_deadline()
draw_ui()

print("hydro light control ready, timezone=" .. timezone_label)

while true do
    local p, obj = claw.display.pop_event()
    if p == PAGE and obj then
        handle_touch(obj)
    end

    if ctx.active then
        check_deadline()
        draw_ui()
    end

    -- Yield CPU and feed the watchdog (API_REFERENCE.md §7)
    delay.delay_ms(500)
end
