-- ================================================================
-- flappybird.lua — FLAPPY BIRD (Claw Display Version)
-- @page_id 8
-- @name FlappyBird
-- @desc Tap to flap! Avoid the pipes.
-- ================================================================

local PAGE = 8

-- Game constants
local SCR_W, SCR_H = 720, 1280
local GAME_TOP = 60
local GAME_BOT = SCR_H - 40

local BIRD_SIZE = 80
local BIRD_X = 100
local GRAVITY = 0.6
local FLAP_VEL = -8.0
local PIPE_W = 60
local PIPE_GAP = 200
local PIPE_SPEED = 3.0

-- Object IDs
local ID_BIRD        = 10
local ID_SCORE       = 20
local ID_MSG         = 30
local ID_RESTART     = 40
local ID_RESTART_LBL = 41

-- State
local bird_y, bird_vel = 0, 0
local pipes = {}
local score = 0
local state = "waiting"  -- waiting, playing, over
local last_spawn = 0
local last_flap = 0
local next_pipe_id = 100

-- ── Drawing ──
local function draw_bird()
    local y = math.floor(bird_y)
    claw.display.button(PAGE, ID_BIRD, BIRD_X, y, BIRD_SIZE, BIRD_SIZE, "", 0xFFB700)
end

local function draw_pipe(p)
    local x = math.floor(p.x)
    -- Top pipe
    local th = p.gap_y - GAME_TOP
    if th > 0 then
        claw.display.button(PAGE, p.top_id, x, GAME_TOP, PIPE_W, th, "", 0x30C050)
    end
    -- Bottom pipe
    local by = p.gap_y + PIPE_GAP
    local bh = GAME_BOT - by
    if bh > 0 then
        claw.display.button(PAGE, p.bot_id, x, by, PIPE_W, bh, "", 0x30C050)
    end
end

local function hide_pipe(p)
    claw.display.button(PAGE, p.top_id, 0, 0, 0, 0, "", 0)
    claw.display.button(PAGE, p.bot_id, 0, 0, 0, 0, "", 0)
end

local function update_score()
    claw.display.label(PAGE, ID_SCORE, SCR_W / 2 - 30, GAME_TOP + 8, tostring(score), 0xFFFFFF, 42)
end

local function show_msg(text, color)
    color = color or 0xAAAAAA
    claw.display.label(PAGE, ID_MSG, SCR_W / 2 - 150, GAME_TOP + (GAME_BOT - GAME_TOP) / 2 - 20, text, color, 24)
end

-- ── Collision ──
local function hit_test(p)
    local bx1 = BIRD_X + 8
    local bx2 = BIRD_X + BIRD_SIZE - 8
    local by1 = bird_y + 8
    local by2 = bird_y + BIRD_SIZE - 8

    if bx2 < p.x or bx1 > p.x + PIPE_W then return false end
    if by1 < p.gap_y or by2 > p.gap_y + PIPE_GAP then return true end
    return false
end

-- ── Game flow ──
local function new_game()
    claw.display.clear_page(PAGE)
    claw.display.create_page(PAGE, "FLAPPY BIRD")
    bird_y = GAME_TOP + (GAME_BOT - GAME_TOP) / 2
    bird_vel = 0
    pipes = {}
    score = 0
    state = "waiting"
    last_spawn = 0
    last_flap = 0
    next_pipe_id = 100

    draw_bird()
    update_score()
    show_msg("TAP TO START")

    -- Hidden restart button (shown on game over)
    claw.display.button(PAGE, ID_RESTART, 0, 0, 0, 0, "", 0)
    claw.display.label(PAGE, ID_RESTART_LBL, 0, 0, "", 0, 0)
end

local function show_game_over()
    state = "over"
    claw.display.label(PAGE, ID_MSG, SCR_W / 2 - 100, GAME_TOP + (GAME_BOT - GAME_TOP) / 2 - 40, "GAME OVER", 0xFF3B30, 36)
    claw.display.label(PAGE, ID_SCORE, SCR_W / 2 - 60, GAME_TOP + (GAME_BOT - GAME_TOP) / 2 + 10, "Score: " .. score, 0xFFFFFF, 24)
    claw.display.button(PAGE, ID_RESTART, SCR_W / 2 - 80, GAME_TOP + (GAME_BOT - GAME_TOP) / 2 + 60, 160, 60, "", 0x30D158)
    claw.display.label(PAGE, ID_RESTART_LBL, SCR_W / 2 - 35, GAME_TOP + (GAME_BOT - GAME_TOP) / 2 + 76, "RESTART", 0xFFFFFF, 22)
end

-- ════════════════════════════════════════════════════
-- MAIN ENTRY
-- ════════════════════════════════════════════════════
new_game()

-- Main Polling Loop
local tick = 0
while true do
    local pid, oid = claw.display.pop_event()
    tick = tick + 1

    if pid == PAGE then
        if oid == ID_RESTART and state == "over" then
            new_game()
        elseif state == "waiting" then
            state = "playing"
            bird_vel = FLAP_VEL
            last_flap = tick
            show_msg("")
        elseif state == "playing" then
            -- Cooldown: max 1 flap per 5 ticks (~165ms)
            if tick - last_flap > 5 then
                bird_vel = FLAP_VEL
                last_flap = tick
            end
        end
    end

    if state == "playing" then
        -- Physics
        bird_vel = bird_vel + GRAVITY
        bird_y = bird_y + bird_vel

        -- Ceiling clamp
        if bird_y < GAME_TOP then
            bird_y = GAME_TOP
            bird_vel = 0
        end

        -- Ground hit
        if bird_y + BIRD_SIZE >= GAME_BOT then
            bird_y = GAME_BOT - BIRD_SIZE
            show_game_over()
        end

        draw_bird()

        -- Spawn pipes
        if tick - last_spawn > 60 then  -- ~2 seconds at ~30fps
            last_spawn = tick
            local gap_y = GAME_TOP + 60 + math.random(0, GAME_BOT - GAME_TOP - PIPE_GAP - 120)
            local p = {
                x = SCR_W + PIPE_W,
                gap_y = gap_y,
                top_id = next_pipe_id,
                bot_id = next_pipe_id + 1,
                scored = false
            }
            next_pipe_id = next_pipe_id + 2
            pipes[#pipes + 1] = p
            draw_pipe(p)
        end

        -- Move pipes
        local i = 1
        while i <= #pipes do
            local p = pipes[i]
            hide_pipe(p)
            p.x = p.x - PIPE_SPEED

            if p.x > -PIPE_W then
                draw_pipe(p)
                -- Score
                if not p.scored and p.x + PIPE_W < BIRD_X then
                    p.scored = true
                    score = score + 1
                    update_score()
                end
                -- Collision
                if hit_test(p) then
                    show_game_over()
                end
                i = i + 1
            else
                table.remove(pipes, i)
            end
        end
    end

    delay.delay_ms(33)
end
