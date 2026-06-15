-- ================================================================
-- dino.lua — DINO RUNNER (Claw Display Version)
-- @page_id 9
-- @name Dino Runner
-- @desc Tap to jump! Avoid the obstacles.
-- ================================================================
-- Uses claw_display API only (no board_manager/display)
-- Compatible with BC08-P4 / Hammer-OS

local PAGE = 9

-- ── Game Constants ──
local SCR_W, SCR_H = 720, 1280
local GAME_Y_TOP = 60
local GAME_Y_BOT = SCR_H - 60
local GROUND_Y = GAME_Y_BOT - 10

local DINO_W, DINO_H = 50, 60
local DINO_X = 80
local DINO_Y_RUN = GROUND_Y - DINO_H
local GRAVITY = 1.0
local JUMP_VELOCITY = -14.0

local OBSTACLE_W, OBSTACLE_H = 40, 50
local OBSTACLE_SPEED = 5.0
local OBSTACLE_SPAWN_FRAMES = 50

-- ── Object IDs ──
local ID_DINO = 10
local ID_SCORE = 20
local ID_INFO = 30
local ID_RESTART = 40
local ID_GROUND = 50
local ID_GAMEOVER = 60
local ID_GAMEOVER_SCORE = 70
local OBSTACLE_ID_START = 100

-- ── Game State ──
local dino_y, dino_vel = DINO_Y_RUN, 0
local obstacles = {}
local score = 0
local frame_count = 0
local game_state = "waiting"
local obstacle_id_counter = OBSTACLE_ID_START
local is_jumping = false

-- ── Draw Dino ──
local function draw_dino()
    local y = math.floor(dino_y)
    local color = 0x5B6ABF  -- blue-ish dino
    if is_jumping then color = 0x7B8ADF end  -- lighter when jumping
    claw.display.button(PAGE, ID_DINO, DINO_X, y, DINO_W, DINO_H, "", color)
end

-- ── Draw Ground ──
local function draw_ground()
    claw.display.button(PAGE, ID_GROUND, 0, GROUND_Y, SCR_W, 8, "", 0x555555)
end

-- ── Draw Obstacle ──
local function draw_obstacle(obs)
    local x = math.floor(obs.x)
    local y = GROUND_Y - OBSTACLE_H
    claw.display.button(PAGE, obs.id, x, y, OBSTACLE_W, OBSTACLE_H, "", obs.cactus and 0xE85D3A or 0x34C759)
end

-- ── Update Score ──
local function update_score()
    claw.display.label(PAGE, ID_SCORE, SCR_W - 120, GAME_Y_TOP + 4, tostring(score), 0xFFFFFF, 36)
end

-- ── Collision Check ──
local function check_collision(obs)
    local dx1, dx2 = DINO_X, DINO_X + DINO_W
    local dy1, dy2 = dino_y, dino_y + DINO_H
    local ox1, ox2 = obs.x, obs.x + OBSTACLE_W
    local oy1, oy2 = GROUND_Y - OBSTACLE_H, GROUND_Y

    -- Simple AABB check with some margin
    local margin = 8
    if dx2 - margin < ox1 or dx1 + margin > ox2 then return false end
    if dy2 - margin < oy1 or dy1 + margin > oy2 then return false end
    return true
end

-- ── New Game ──
local function new_game()
    claw.display.clear_page(PAGE)
    claw.display.create_page(PAGE, "DINO RUNNER")
    dino_y = DINO_Y_RUN
    dino_vel = 0
    is_jumping = false
    obstacles = {}
    score = 0
    frame_count = 0
    game_state = "waiting"
    obstacle_id_counter = OBSTACLE_ID_START

    draw_ground()
    draw_dino()
    update_score()
    claw.display.label(PAGE, ID_INFO, SCR_W/2 - 80, GAME_Y_TOP + (GAME_Y_BOT - GAME_Y_TOP)/2 - 30, "TAP TO START", 0xAAAAAA, 24)
    claw.display.button(PAGE, ID_RESTART, 0, 0, 0, 0, "", 0)  -- hidden
end

-- ── Game Over ──
local function game_over()
    game_state = "game_over"
    claw.display.label(PAGE, ID_GAMEOVER, SCR_W/2 - 100, GAME_Y_TOP + (GAME_Y_BOT - GAME_Y_TOP)/2 - 60, "GAME OVER", 0xFF3B30, 36)
    claw.display.label(PAGE, ID_GAMEOVER_SCORE, SCR_W/2 - 60, GAME_Y_TOP + (GAME_Y_BOT - GAME_Y_TOP)/2, "Score: " .. score, 0xFFFFFF, 24)
    claw.display.button(PAGE, ID_RESTART, SCR_W/2 - 80, GAME_Y_TOP + (GAME_Y_BOT - GAME_Y_TOP)/2 + 50, 160, 60, "", 0x30D158)
    claw.display.label(PAGE, ID_RESTART + 1, SCR_W/2 - 40, GAME_Y_TOP + (GAME_Y_BOT - GAME_Y_TOP)/2 + 66, "RESTART", 0xFFFFFF, 24)
end

-- ── Main ──
new_game()

while true do
    local pid, oid = claw.display.pop_event()
    
    if pid == PAGE then
        if oid == ID_RESTART then
            new_game()
            goto continue
        end
        
        if game_state == "waiting" or game_state == "playing" then
            if game_state == "waiting" then
                game_state = "playing"
                claw.display.label(PAGE, ID_INFO, 0, 0, "", 0, 0)  -- clear
            end
            if not is_jumping then
                dino_vel = JUMP_VELOCITY
                is_jumping = true
            end
        end
    end
    
    if game_state == "playing" then
        ::continue::
        -- Physics
        if is_jumping then
            dino_vel = dino_vel + GRAVITY
            dino_y = dino_y + dino_vel
            if dino_y >= DINO_Y_RUN then
                dino_y = DINO_Y_RUN
                dino_vel = 0
                is_jumping = false
            end
        end
        draw_dino()
        
        -- Spawn obstacles
        frame_count = frame_count + 1
        if frame_count % OBSTACLE_SPAWN_FRAMES == 0 then
            local obs = {
                x = SCR_W + OBSTACLE_W,
                id = obstacle_id_counter,
                scored = false,
                cactus = math.random() > 0.5
            }
            obstacle_id_counter = obstacle_id_counter + 1
            obstacles[#obstacles + 1] = obs
            draw_obstacle(obs)
        end
        
        -- Move & check obstacles
        local to_remove = {}
        for i, obs in ipairs(obstacles) do
            -- Hide old position
            claw.display.button(PAGE, obs.id, 0, 0, 0, 0, "", 0)
            obs.x = obs.x - OBSTACLE_SPEED
            if obs.x > -OBSTACLE_W then
                draw_obstacle(obs)
            end
            
            -- Score
            if not obs.scored and obs.x + OBSTACLE_W < DINO_X then
                obs.scored = true
                score = score + 1
                update_score()
            end
            
            -- Collision
            if check_collision(obs) then
                game_over()
            end
            
            -- Remove off-screen
            if obs.x < -OBSTACLE_W - 20 then
                to_remove[#to_remove + 1] = i
            end
        end
        
        for i = #to_remove, 1, -1 do
            table.remove(obstacles, to_remove[i])
        end
    end
    
    delay.delay_ms(33)
end
