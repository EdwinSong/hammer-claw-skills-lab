-- ================================================================
-- flappybird.lua — FLAPPY BIRD (Claw Display Version)
-- @page_id 8
-- @name FlappyBird
-- @desc Tap to flap! Avoid the pipes.
-- ================================================================
-- Uses claw_display API only (no board_manager/display/audio)
-- Compatible with BC08-P4 / Hammer-OS

local PAGE = 8

-- ── Game Constants ──
local SCR_W, SCR_H = 720, 1280
local GAME_Y_TOP = 60   -- below top bar
local GAME_Y_BOT = SCR_H - 60
local GAME_H = GAME_Y_BOT - GAME_Y_TOP

local BIRD_W, BIRD_H = 48, 48
local BIRD_X = 120
local GRAVITY = 0.8
local FLAP_VELOCITY = -9.0
local PIPE_W = 60
local PIPE_GAP = 160
local PIPE_SPEED = 4.0
local PIPE_SPAWN_FRAMES = 60  -- frames between pipe spawns
local GROUND_Y = GAME_Y_BOT

-- ── Object IDs ──
local ID_BIRD = 10
local ID_SCORE = 20
local ID_INFO = 30
local ID_RESTART = 40
local ID_GAMEOVER_TITLE = 50
local ID_GAMEOVER_SCORE = 60
local PIPE_IDS_START = 100  -- pipes use 100-199
local PIPE_COUNT = 0

-- ── Game State ──
local bird_y, bird_vel = 0, 0
local pipes = {}         -- {x, gap_y}
local score = 0
local frame_count = 0
local game_state = "waiting"  -- "waiting", "playing", "game_over"
local pipe_id_counter = PIPE_IDS_START

-- ── Bird Drawing ──
local function draw_bird()
    local y = math.floor(bird_y)
    claw.display.button(PAGE, ID_BIRD, BIRD_X, y, BIRD_W, BIRD_H, "", 0xF5A623)
end

-- ── Pipe Drawing ──
local function draw_pipe(pipe, top_id, bot_id)
    local x = math.floor(pipe.x)
    local gap_y = pipe.gap_y
    -- Top pipe (above gap)
    local top_h = gap_y - GAME_Y_TOP
    if top_h > 0 then
        claw.display.button(PAGE, top_id, x, GAME_Y_TOP, PIPE_W, top_h, "", 0x34C759)
    end
    -- Bottom pipe (below gap)
    local bot_y = gap_y + PIPE_GAP
    local bot_h = GAME_Y_BOT - bot_y
    if bot_h > 0 then
        claw.display.button(PAGE, bot_id, x, bot_y, PIPE_W, bot_h, "", 0x34C759)
    end
end

-- ── Clear Pipe ──
local function clear_pipe(pipe)
    -- Remove old pipe objects by drawing over them (button with bg color)
    if pipe.top_id then
        claw.display.button(PAGE, pipe.top_id, 0, 0, 0, 0, "", 0)  -- hide
    end
    if pipe.bot_id then
        claw.display.button(PAGE, pipe.bot_id, 0, 0, 0, 0, "", 0)
    end
end

-- ── Score Display ──
local function update_score()
    claw.display.label(PAGE, ID_SCORE, SCR_W/2 - 40, GAME_Y_TOP + 4, tostring(score), 0xFFFFFF, 36)
end

-- ── Collision Check ──
local function check_collision(pipe)
    local bx1, bx2 = BIRD_X, BIRD_X + BIRD_W
    local by1, by2 = bird_y, bird_y + BIRD_H
    local px1, px2 = pipe.x, pipe.x + PIPE_W

    if bx2 < px1 or bx1 > px2 then return false end

    -- Check top pipe
    if by1 < pipe.gap_y then return true end
    -- Check bottom pipe
    if by2 > pipe.gap_y + PIPE_GAP then return true end

    return false
end

-- ── New Game ──
local function new_game()
    claw.display.clear_page(PAGE)
    claw.display.create_page(PAGE, "FLAPPY BIRD")
    bird_y = GAME_Y_TOP + GAME_H / 2
    bird_vel = 0
    pipes = {}
    score = 0
    frame_count = 0
    game_state = "waiting"
    pipe_id_counter = PIPE_IDS_START

    draw_bird()
    update_score()
    claw.display.label(PAGE, ID_INFO, SCR_W/2 - 80, GAME_Y_TOP + GAME_H/2 - 30, "TAP TO START", 0xAAAAAA, 24)
    -- Hidden restart button (shown on game over)
    claw.display.button(PAGE, ID_RESTART, 0, 0, 0, 0, "", 0)
end

-- ── Game Over ──
local function game_over()
    game_state = "game_over"
    claw.display.label(PAGE, ID_GAMEOVER_TITLE, SCR_W/2 - 100, GAME_Y_TOP + GAME_H/2 - 60, "GAME OVER", 0xFF3B30, 36)
    claw.display.label(PAGE, ID_GAMEOVER_SCORE, SCR_W/2 - 60, GAME_Y_TOP + GAME_H/2, "Score: " .. score, 0xFFFFFF, 24)
    claw.display.button(PAGE, ID_RESTART, SCR_W/2 - 80, GAME_Y_TOP + GAME_H/2 + 50, 160, 60, "", 0x30D158)
    claw.display.label(PAGE, ID_RESTART + 1, SCR_W/2 - 40, GAME_Y_TOP + GAME_H/2 + 66, "RESTART", 0xFFFFFF, 24)
end

-- ── Main ──
new_game()

while true do
    local pid, oid = claw.display.pop_event()
    local skip_update = false
    
    if pid == PAGE then
        if oid == ID_RESTART then
            new_game()
            skip_update = true
        end
        
        if game_state == "waiting" or game_state == "playing" then
            -- Any click = flap
            if game_state == "waiting" then
                game_state = "playing"
                -- Clear info text
                claw.display.label(PAGE, ID_INFO, 0, 0, "", 0, 0)
            end
            if game_state == "playing" then
                bird_vel = FLAP_VELOCITY
            end
        end
    end
    
    if game_state == "playing" and not skip_update then
        -- Physics
        bird_vel = bird_vel + GRAVITY
        bird_y = bird_y + bird_vel
        
        -- Ground/ceiling check
        if bird_y <= GAME_Y_TOP then bird_y = GAME_Y_TOP; bird_vel = 0 end
        if bird_y >= GROUND_Y - BIRD_H then bird_y = GROUND_Y - BIRD_H; game_over(); end
        
        draw_bird()
        
        -- Spawn pipes
        frame_count = frame_count + 1
        if frame_count % PIPE_SPAWN_FRAMES == 0 then
            local gap_y = GAME_Y_TOP + math.random(60, GAME_H - PIPE_GAP - 40)
            local pipe = {
                x = SCR_W + PIPE_W,
                gap_y = gap_y,
                top_id = pipe_id_counter,
                bot_id = pipe_id_counter + 1,
                scored = false
            }
            pipe_id_counter = pipe_id_counter + 2
            pipes[#pipes + 1] = pipe
            draw_pipe(pipe, pipe.top_id, pipe.bot_id)
        end
        
        -- Move & check pipes
        local to_remove = {}
        for i, pipe in ipairs(pipes) do
            clear_pipe(pipe)
            pipe.x = pipe.x - PIPE_SPEED
            if pipe.x > -PIPE_W then
                draw_pipe(pipe, pipe.top_id, pipe.bot_id)
            end
            
            -- Score
            if not pipe.scored and pipe.x + PIPE_W < BIRD_X then
                pipe.scored = true
                score = score + 1
                update_score()
            end
            
            -- Collision
            if check_collision(pipe) then
                game_over()
            end
            
            -- Remove off-screen
            if pipe.x < -PIPE_W - 20 then
                to_remove[#to_remove + 1] = i
            end
        end
        
        -- Remove off-screen pipes (reverse order)
        for i = #to_remove, 1, -1 do
            table.remove(pipes, to_remove[i])
        end
    end
    
    delay.delay_ms(33)  -- ~30 FPS
end
