-- ================================================================
-- Game-MineSweeper.lua — MINESWEEPER (BC08 Built-in match)
-- @page_id 5
-- @name Game-MineSweeper
-- @desc Classic minesweeper: 6x6 grid, 6 mines, flag mode, new game
-- ================================================================
-- Matches BC08-P4 built-in C minesweeper functionality

local PAGE = 5
local ROWS, COLS = 6, 6
local MINES = 6
local CELL = 96
local GAP = 4
local GRID_X = 40
local GRID_Y = 200

-- Colors (matching C version)
local CLR_BG        = 0x0D1117
local CLR_HIDDEN    = 0x223344
local CLR_REVEALED  = 0x1A1A2E
local CLR_EMPTY     = 0x0D1117
local CLR_FLAG      = 0x334455
local CLR_MINE_BG   = 0x552222
local CLR_MINE_FLAG = 0x665500
local CLR_TEXT      = 0xCCCCCC
local CLR_NUM1      = 0x44AAFF
local CLR_NUM2      = 0x44CC44
local CLR_NUM3      = 0xFF4444
local CLR_NUM4      = 0x8844FF
local CLR_NUM5      = 0xFF8844
local CLR_NUM6      = 0x44CCCC
local CLR_ACCENT    = 0x89D992
local CLR_BTN_BG    = 0x334455
local CLR_BTN_NEW   = 0x227744

-- Object IDs: cell at (r,c) = 200 + r*10 + c
local ID_STATUS  = 101
local ID_MINES   = 102
local ID_FLAGS   = 103
local ID_TITLE   = 100
local ID_MODE    = 300
local ID_MODE_LBL = 301
local ID_NEWGAME = 302
local ID_NEWGAME_LBL = 303

local function cell_id(r, c) return 200 + r * 10 + c end
local function cell_label_id(r, c) return 400 + r * 10 + c end

-- Game state
local grid = {}
local revealed = {}
local flagged = {}
local game_over = false
local game_won = false
local first_click = true
local flag_mode = false

-- Number colors
local num_colors = {[0]=CLR_TEXT, CLR_NUM1, CLR_NUM2, CLR_NUM3, CLR_NUM4, CLR_NUM5, CLR_NUM6}

-- ── Place mines (safe cell = where player first clicked) ──
local function place_mines(sr, sc)
    for r = 0, ROWS-1 do
        grid[r] = {}
        for c = 0, COLS-1 do grid[r][c] = 0 end
    end
    local n = 0
    math.randomseed(os.time())
    while n < MINES do
        local r = math.random(0, ROWS-1)
        local c = math.random(0, COLS-1)
        if grid[r][c] == 0 and not (r == sr and c == sc) then
            grid[r][c] = -1; n = n + 1
        end
    end
    for r = 0, ROWS-1 do
        for c = 0, COLS-1 do
            if grid[r][c] ~= -1 then
                local cnt = 0
                for dr = -1, 1 do for dc = -1, 1 do
                    local nr, nc = r+dr, c+dc
                    if nr>=0 and nr<ROWS and nc>=0 and nc<COLS and grid[nr][nc]==-1 then
                        cnt = cnt + 1
                    end
                end end
                grid[r][c] = cnt
            end
        end
    end
end

-- ── Draw single cell ──
local function draw_cell(r, c)
    local bid = cell_id(r, c)
    local lid = cell_label_id(r, c)
    local x = GRID_X + c * (CELL + GAP)
    local y = GRID_Y + r * (CELL + GAP)

    if revealed[r][c] then
        if grid[r][c] == -1 then
            claw.display.button(PAGE, bid, x, y, CELL, CELL, "", CLR_MINE_BG)
            claw.display.label(PAGE, lid, x + CELL/2 - 8, y + CELL/2 - 16, "X", CLR_NUM3, 30)
        elseif grid[r][c] == 0 then
            claw.display.button(PAGE, bid, x, y, CELL, CELL, "", CLR_EMPTY)
            claw.display.label(PAGE, lid, 0, 0, "", 0, 0)
        else
            claw.display.button(PAGE, bid, x, y, CELL, CELL, "", CLR_REVEALED)
            claw.display.label(PAGE, lid, x + CELL/2 - 10, y + CELL/2 - 16, tostring(grid[r][c]), num_colors[grid[r][c]] or CLR_TEXT, 30)
        end
    elseif flagged[r][c] then
        claw.display.button(PAGE, bid, x, y, CELL, CELL, "", CLR_FLAG)
        claw.display.label(PAGE, lid, x + CELL/2 - 8, y + CELL/2 - 16, "F", CLR_MINE_FLAG, 30)
    else
        claw.display.button(PAGE, bid, x, y, CELL, CELL, "", CLR_HIDDEN)
        claw.display.label(PAGE, lid, x + CELL/2 - 8, y + CELL/2 - 16, "?", CLR_TEXT, 30)
    end
end

-- ── Draw all cells ──
local function draw_grid()
    for r = 0, ROWS-1 do
        for c = 0, COLS-1 do
            draw_cell(r, c)
        end
    end
end

-- ── Reveal recursive ──
local function reveal(r, c)
    if r < 0 or r >= ROWS or c < 0 or c >= COLS then return end
    if revealed[r][c] or flagged[r][c] then return end
    revealed[r][c] = true
    draw_cell(r, c)
    if grid[r][c] == 0 then
        for dr = -1, 1 do for dc = -1, 1 do
            if dr ~= 0 or dc ~= 0 then reveal(r+dr, c+dc) end
        end end
    end
end

-- ── Reveal all mines ──
local function reveal_all()
    for r = 0, ROWS-1 do
        for c = 0, COLS-1 do
            if grid[r][c] == -1 then revealed[r][c] = true; draw_cell(r, c) end
        end
    end
end

-- ── Check win ──
local function check_win()
    for r = 0, ROWS-1 do
        for c = 0, COLS-1 do
            if grid[r][c] ~= -1 and not revealed[r][c] then return false end
        end
    end
    return true
end

-- ── Update status bar ──
local function update_status()
    local fcnt = 0
    for r = 0, ROWS-1 do for c = 0, COLS-1 do
        if flagged[r][c] then fcnt = fcnt + 1 end
    end end

    if game_over and not game_won then
        claw.display.label(PAGE, ID_STATUS, 100, 100, "GAME OVER", CLR_NUM3, 24)
    elseif game_won then
        claw.display.label(PAGE, ID_STATUS, 100, 100, "YOU WIN!", CLR_ACCENT, 24)
    else
        claw.display.label(PAGE, ID_STATUS, 100, 100, "Playing...", CLR_TEXT, 24)
    end
    claw.display.label(PAGE, ID_MINES, 420, 100, "Mines: "..(MINES-fcnt), CLR_TEXT, 15)
    claw.display.label(PAGE, ID_FLAGS, 560, 100, "Flags: "..fcnt, CLR_TEXT, 15)
end

-- ── New game ──
local function new_game()
    claw.display.clear_page(PAGE)
    claw.display.create_page(PAGE, "MINESWEEPER")

    game_over = false; game_won = false
    first_click = true; flag_mode = false

    for r = 0, ROWS-1 do
        grid[r] = {}
        revealed[r] = {}
        flagged[r] = {}
        for c = 0, COLS-1 do
            grid[r][c] = 0
            revealed[r][c] = false
            flagged[r][c] = false
        end
    end

    -- Title
    claw.display.label(PAGE, ID_TITLE, 270, 40, "MINESWEEPER", CLR_ACCENT, 45)

    -- Draw grid
    draw_grid()

    -- Status labels
    update_status()

    -- Bottom buttons
    local by = GRID_Y + ROWS * (CELL + GAP) + 30
    claw.display.button(PAGE, ID_MODE, 40, by, 290, 56, "", CLR_BTN_BG)
    claw.display.label(PAGE, ID_MODE_LBL, 100, by+16, "Flag Mode: OFF", CLR_TEXT, 15)

    claw.display.button(PAGE, ID_NEWGAME, 390, by, 290, 56, "", CLR_BTN_NEW)
    claw.display.label(PAGE, ID_NEWGAME_LBL, 440, by+16, "NEW GAME", CLR_TEXT, 24)
end

-- ── Main ──
new_game()

while true do
    local pid, oid = claw.display.pop_event()
    if pid == PAGE and oid then
        if oid == ID_NEWGAME then
            new_game()
        elseif oid == ID_MODE then
            flag_mode = not flag_mode
            claw.display.label(PAGE, ID_MODE_LBL, 100, GRID_Y + ROWS*(CELL+GAP)+46, flag_mode and "Flag Mode: ON" or "Flag Mode: OFF", CLR_TEXT, 15)
            claw.display.button(PAGE, ID_MODE, 40, GRID_Y + ROWS*(CELL+GAP)+30, 290, 56, "", flag_mode and CLR_MINE_FLAG or CLR_BTN_BG)
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
                    if grid[r][c] == -1 then
                        game_over = true
                        reveal_all()
                    elseif check_win() then
                        game_won = true
                        game_over = true
                        reveal_all()
                    end
                    update_status()
                end
            end
        end
    end
    delay.delay_ms(100)
end
