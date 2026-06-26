-- ================================================================
-- Game-MineSweeper.lua — MINESWEEPER (Premium Animated Version)
-- @page_id 5
-- @name Game-MineSweeper
-- @desc Classic minesweeper game on claw mode
-- ================================================================

local PAGE = 5
local ROWS, COLS = 5, 5
local CELL, GAP = 120, 6
local GRID_X, GRID_Y = 48, 240

-- Level persistence
local LEVEL_FILE = storage.join_path(storage.get_root_dir(), "skills", "game_minesweeper", "level.txt")
local function load_level()
    if storage.exists(LEVEL_FILE) then
        local ok, data = pcall(storage.read_file, LEVEL_FILE)
        if ok and data then
            local lv = tonumber(data)
            if lv and lv >= 1 and lv <= 5 then return lv end
        end
    end
    return 1
end
local function save_level(lv)
    pcall(storage.write_file, LEVEL_FILE, tostring(lv))
end

-- ── Helpers ──
local function cell_id(r, c) return 200 + r * 10 + c end
local function label_id(r, c) return 400 + r * 10 + c end
local function cell_xy(r, c)
    return GRID_X + c * (CELL + GAP), GRID_Y + r * (CELL + GAP)
end

-- ── Game state ──
local grid = {}
local revealed = {}
local flagged = {}
local game_over = false
local first_click = true
local flag_mode = false
local level = load_level()
local game_state = "playing" -- "playing", "victory", "game_over"

-- Calculate number of mines based on level (Level 1: 3, Level 2: 4, etc.)
local function get_mines_count()
    return 2 + level
end

-- ── Init Grid ──
local function init_grid()
    for r = 0, ROWS - 1 do
        grid[r] = {}
        revealed[r] = {}
        flagged[r] = {}
        for c = 0, COLS - 1 do
            grid[r][c] = 0
            revealed[r][c] = false
            flagged[r][c] = false
        end
    end
end

-- ── Place Mines ──
local function place_mines(sr, sc)
    math.randomseed(os.time())
    local mines_count = get_mines_count()
    local n = 0
    while n < mines_count do
        local r = math.random(0, ROWS - 1)
        local c = math.random(0, COLS - 1)
        if grid[r][c] == 0 and not (r == sr and c == sc) then
            grid[r][c] = -1; n = n + 1
        end
    end
    for r = 0, ROWS - 1 do
        for c = 0, COLS - 1 do
            if grid[r][c] ~= -1 then
                local cnt = 0
                for dr = -1, 1 do for dc = -1, 1 do
                    local nr, nc = r + dr, c + dc
                    if nr >= 0 and nr < ROWS and nc >= 0 and nc < COLS then
                        if grid[nr][nc] == -1 then cnt = cnt + 1 end
                    end
                end end
                grid[r][c] = cnt
            end
        end
    end
end

-- Premium colors for digits (VT323 Size 35)
local num_colors = {
    0x34C759, -- 1: neon green
    0x00C7BE, -- 2: neon teal
    0xFF9500, -- 3: neon orange
    0xFF375F, -- 4: neon pink
    0xAF52DE  -- 5: neon purple
}

-- ── Render Single Cell ──
local function draw_cell(r, c)
    local x, y = cell_xy(r, c)
    local b_id = cell_id(r, c)
    local l_id = label_id(r, c)

    if not revealed[r][c] then
        local txt = flagged[r][c] and "F" or "?"
        local bg_clr = flagged[r][c] and 0x242745 or 0x1A1C38
        local txt_clr = flagged[r][c] and 0x34C759 or 0x5D619E
        
        claw.display.button(PAGE, b_id, x, y, CELL, CELL, "", bg_clr)
        claw.display.label(PAGE, l_id, x + 51, y + 44, txt, txt_clr, 35)
    else
        -- Revealed
        if grid[r][c] == -1 then
            claw.display.button(PAGE, b_id, x, y, CELL, CELL, "", 0xFF3B30)
            claw.display.label(PAGE, l_id, x + 51, y + 44, "*", 0xFFFFFF, 35)
        elseif grid[r][c] == 0 then
            claw.display.button(PAGE, b_id, x, y, CELL, CELL, "", 0x101124)
            claw.display.label(PAGE, l_id, x + 51, y + 44, "", 0, 35)
        else
            local num = grid[r][c]
            local clr = num_colors[num] or 0xFFFFFF
            claw.display.button(PAGE, b_id, x, y, CELL, CELL, "", 0x101124)
            claw.display.label(PAGE, l_id, x + 51, y + 44, tostring(num), clr, 35)
        end
    end
end

-- ── Render Board Grid ──
local function draw_grid()
    for r = 0, ROWS - 1 do
        for c = 0, COLS - 1 do
            draw_cell(r, c)
        end
    end
end

-- ── Update Status Dashboard ──
local function update_status()
    local fcnt = 0
    for r = 0, ROWS - 1 do for c = 0, COLS - 1 do
        if flagged[r][c] then fcnt = fcnt + 1 end
    end end
    
    local mines_count = get_mines_count()

    claw.display.label(PAGE, 101, 310, 145, "LEVEL " .. level, 0x00E5FF, 24)
    claw.display.label(PAGE, 102, 75, 145, "MINES: " .. (mines_count - fcnt), 0xFFB700, 24)
    claw.display.label(PAGE, 103, 490, 145, "FLAGS: " .. fcnt, 0x30D158, 24)

    local mode_clr = flag_mode and 0x007AFF or 0x242745
    claw.display.button(PAGE, 300, 48, 880, 298, 70, "", mode_clr)
    claw.display.label(PAGE, 302, 135, 903, "FLAG MODE", 0xFFFFFF, 24)
end

-- ── Instructions ──
local function draw_instructions()
    local guide_y = GRID_Y + ROWS * (CELL + GAP) + 110
    claw.display.label(PAGE, 600, 55, guide_y, "Tap cell: reveal", 0x888888, 18)
    claw.display.label(PAGE, 601, 260, guide_y, "|", 0x555555, 18)
    claw.display.label(PAGE, 602, 280, guide_y, "Flag Mode: mark mine", 0x888888, 18)
    claw.display.label(PAGE, 603, 500, guide_y, "|", 0x555555, 18)
    claw.display.label(PAGE, 604, 520, guide_y, "New Game: restart", 0x888888, 18)
end

-- ── Victory Screen ──
local function victory_screen()
    game_state = "victory"
    claw.display.clear_page(PAGE)
    
    -- Center Glassmorphic Card
    claw.display.container(PAGE, 500, 48, 180, 624, 650, 0x16182E, 16)
    
    -- Large Neon Green Victory Title
    claw.display.label(PAGE, 501, 272, 280, "VICTORY!", 0x34C759, 45)
    
    -- Stats text
    claw.display.label(PAGE, 502, 252, 380, "Level " .. level .. " Completed!", 0xFFFFFF, 24)
    
    -- Button 1: Next Level / Play Again
    claw.display.button(PAGE, 503, 110, 480, 500, 80, "", 0x30D158)
    local btn1_text = (level < 5) and "NEXT LEVEL" or "PLAY AGAIN"
    claw.display.label(PAGE, 504, 300, 508, btn1_text, 0xFFFFFF, 24)
    
    -- Button 2: Replay Level
    claw.display.button(PAGE, 505, 110, 600, 500, 80, "", 0x242745)
    claw.display.label(PAGE, 506, 288, 628, "REPLAY LEVEL", 0xFFFFFF, 24)
end

-- ── Game Over Screen ──
local function game_over_screen()
    game_state = "game_over"
    claw.display.clear_page(PAGE)
    
    -- Center Glassmorphic Card
    claw.display.container(PAGE, 500, 48, 180, 624, 650, 0x16182E, 16)
    
    -- Large Neon Red Game Over Title
    claw.display.label(PAGE, 501, 261, 280, "GAME OVER", 0xFF3B30, 45)
    
    -- Stats text
    claw.display.label(PAGE, 502, 252, 380, "Level " .. level .. " Failed!", 0xFFFFFF, 24)
    
    -- Button 1: Try Again
    claw.display.button(PAGE, 503, 110, 480, 500, 80, "", 0xFF3B30)
    claw.display.label(PAGE, 504, 306, 508, "TRY AGAIN", 0xFFFFFF, 24)
    
    -- Button 2: Reset to Level 1
    claw.display.button(PAGE, 505, 110, 600, 500, 80, "", 0x242745)
    claw.display.label(PAGE, 506, 264, 628, "RESET TO LEVEL 1", 0xFFFFFF, 24)
end

-- ── Detonation Animation ──
local function trigger_explosion(click_r, click_c)
    game_over = true
    
    local det_x, det_y = cell_xy(click_r, click_c)
    claw.display.button(PAGE, cell_id(click_r, click_c), det_x, det_y, CELL, CELL, "", 0xFF3B30)
    claw.display.label(PAGE, label_id(click_r, click_c), det_x + 51, det_y + 44, "*", 0xFFFFFF, 35)

    for dist = 1, (ROWS + COLS) do
        for r = 0, ROWS - 1 do
            for c = 0, COLS - 1 do
                local d = math.abs(r - click_r) + math.abs(c - click_c)
                if d == dist then
                    local x, y = cell_xy(r, c)
                    if grid[r][c] == -1 then
                        claw.display.button(PAGE, cell_id(r, c), x, y, CELL, CELL, "", 0xFF5E55)
                        claw.display.label(PAGE, label_id(r, c), x + 51, y + 44, "*", 0xFFFFFF, 35)
                    else
                        if not revealed[r][c] then
                            claw.display.button(PAGE, cell_id(r, c), x, y, CELL, CELL, "", 0x883311)
                        end
                    end
                end
            end
        end
        delay.delay_ms(120)
        
        for r = 0, ROWS - 1 do
            for c = 0, COLS - 1 do
                local d = math.abs(r - click_r) + math.abs(c - click_c)
                if d == dist and grid[r][c] ~= -1 and not revealed[r][c] then
                    draw_cell(r, c)
                end
            end
        end
    end

    for r = 0, ROWS - 1 do
        for c = 0, COLS - 1 do
            if grid[r][c] == -1 and not (r == click_r and c == click_c) then
                local x, y = cell_xy(r, c)
                claw.display.button(PAGE, cell_id(r, c), x, y, CELL, CELL, "", 0x552222)
                claw.display.label(PAGE, label_id(r, c), x + 51, y + 44, "*", 0xFFB700, 35)
            end
        end
    end
    
    delay.delay_ms(2000)
    game_over_screen()
end

-- ── Victory Animation ──
local function trigger_win_animation()
    game_over = true
    for step = 1, 3 do
        for r = 0, ROWS - 1 do
            for c = 0, COLS - 1 do
                if grid[r][c] == -1 then
                    local x, y = cell_xy(r, c)
                    claw.display.button(PAGE, cell_id(r, c), x, y, CELL, CELL, "", step % 2 == 1 and 0x34C759 or 0x1A3A2A)
                    claw.display.label(PAGE, label_id(r, c), x + 51, y + 44, "F", 0xFFFFFF, 35)
                end
            end
        end
        delay.delay_ms(200)
    end
    
    delay.delay_ms(1500)
    victory_screen()
end

-- ── Reveal Cell Logic ──
local function reveal(r, c)
    if r < 0 or r >= ROWS or c < 0 or c >= COLS then return end
    if revealed[r][c] or flagged[r][c] then return end
    revealed[r][c] = true
    draw_cell(r, c)

    if grid[r][c] == -1 then
        trigger_explosion(r, c)
        return
    end

    if grid[r][c] == 0 then
        for dr = -1, 1 do for dc = -1, 1 do
            if dr ~= 0 or dc ~= 0 then reveal(r + dr, c + dc) end
        end end
    end
end

-- ── Check Win ──
local function check_win()
    for r = 0, ROWS - 1 do
        for c = 0, COLS - 1 do
            if grid[r][c] ~= -1 and not revealed[r][c] then return false end
        end
    end
    return true
end

-- ── New Game ──
local function new_game()
    game_state = "playing"
    claw.display.clear_page(PAGE)
    claw.display.create_page(PAGE, "")  -- No title in top bar (avoids overlap)
    game_over = false; first_click = true; flag_mode = false
    init_grid()
    
    -- Dashboard container
    claw.display.container(PAGE, 100, 48, 120, 624, 80, 0x16182E, 12)
    draw_grid()
    draw_instructions()

    claw.display.button(PAGE, 301, 374, 880, 298, 70, "", 0x30D158)
    claw.display.label(PAGE, 303, 470, 903, "NEW GAME", 0xFFFFFF, 24)
    
    update_status()
end

-- ════════════════════════════════════════════════════
-- MAIN ENTRY
-- ════════════════════════════════════════════════════
new_game()

-- Main Polling Loop
while true do
    local pid, oid = claw.display.pop_event()
    if pid == PAGE and oid then
        if game_state == "playing" then
            if oid == 301 then
                new_game()
            elseif oid == 300 then
                flag_mode = not flag_mode
                update_status()
            elseif oid >= 200 and oid < 300 and not game_over then
                local r = math.floor((oid - 200) / 10)
                local c = (oid - 200) % 10
                if r >= 0 and r < ROWS and c >= 0 and c < COLS then
                    if flag_mode then
                        if not revealed[r][c] then
                            flagged[r][c] = not flagged[r][c]
                            draw_cell(r, c)
                            update_status()
                        end
                    elseif not flagged[r][c] then
                        if first_click then 
                            place_mines(r, c)
                            first_click = false 
                        end
                        reveal(r, c)
                        if not game_over and check_win() then
                            trigger_win_animation()
                        end
                    end
                end
            end
        elseif game_state == "victory" then
            if oid == 503 then
                if level < 5 then
                    level = level + 1
                else
                    level = 1
                end
                save_level(level)
                new_game()
            elseif oid == 505 then
                new_game()
            end
        elseif game_state == "game_over" then
            if oid == 503 then
                new_game()
            elseif oid == 505 then
                level = 1
                save_level(level)
                new_game()
            end
        end
    end
    delay.delay_ms(100)
end
