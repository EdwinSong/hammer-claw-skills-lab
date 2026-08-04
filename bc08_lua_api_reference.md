# BC08 Skill Card Lua API Reference

> API version: `0.1`
> Screen size: `720 × 1280` (portrait)
> Color format: 24-bit integer `0xRRGGBB`, e.g. `0x02FFB5`
> Coordinate system: top-left is `(0, 0)`, x grows right, y grows down

---

## 1. `claw.display` — Screen UI API

### `claw.display.get_size()`

Returns the screen width and height.

```lua
local w, h = claw.display.get_size()
-- w = 720, h = 1280
```

**Returns**

| # | Type | Description |
|---|------|-------------|
| 1 | number | Screen width in pixels |
| 2 | number | Screen height in pixels |

---

### `claw.display.create_page(page_id, title)`

Creates a new page (screen) for drawing controls.

```lua
claw.display.create_page(1, "Hello")
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `page_id` | number | Unique page identifier |
| `title` | string | Page title shown internally |

---

### `claw.display.clear_page(page_id)`

Removes all controls from a page but keeps the page itself.

```lua
claw.display.clear_page(1)
```

---

### `claw.display.delete_page(page_id)`

Deletes a page entirely.

```lua
claw.display.delete_page(1)
```

---

### `claw.display.button(page, id, x, y, w, h, text, color)`

Draws a clickable button.

```lua
claw.display.button(1, 10, 100, 200, 200, 80, "OK", 0x02FFB5)
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `page` | number | Page ID |
| `id` | number | Control ID, returned on touch events |
| `x` | number | Left position |
| `y` | number | Top position |
| `w` | number | Width |
| `h` | number | Height |
| `text` | string | Button label |
| `color` | number | Text color `0xRRGGBB` |

---

### `claw.display.label(page, id, x, y, text, color, font_size)`

Draws a text label.

```lua
claw.display.label(1, 2, 100, 100, "Hello HAMMER!", 0x02FFB5, 40)
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `page` | number | Page ID |
| `id` | number | Control ID |
| `x` | number | Left position |
| `y` | number | Top position |
| `text` | string | Text content |
| `color` | number | Text color `0xRRGGBB` |
| `font_size` | number | Font size in pixels (default `24`) |

---

### `claw.display.container(page, id, x, y, w, h, color, radius)`

Draws a filled rectangle, useful for backgrounds.

```lua
claw.display.container(1, 1, 0, 0, 720, 1280, 0x000000, 0)
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `page` | number | Page ID |
| `id` | number | Control ID |
| `x` | number | Left position |
| `y` | number | Top position |
| `w` | number | Width |
| `h` | number | Height |
| `color` | number | Fill color `0xRRGGBB` |
| `radius` | number | Corner radius (currently ignored) |

---

### `claw.display.image(page, id, x, y, w, h, path)`

Draws an image on the page.

```lua
claw.display.image(1, 5, 100, 500, 64, 64, "F:skills/my_skill/assets/icon.png")
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `page` | number | Page ID |
| `id` | number | Control ID |
| `x` | number | Left position |
| `y` | number | Top position |
| `w` | number | Width |
| `h` | number | Height |
| `path` | string | Image path. In simulator imported skills are resolved from localStorage; otherwise paths are mapped relative to `public/skills/hammer-claw-skills-lab/` |

---

### `claw.display.pop_event()`

Polls the next touch/click event. Non-blocking, returns `nil, nil` if no event.

```lua
while true do
    local page_id, obj_id = claw.display.pop_event()
    if page_id then
        sys.log("info", "touched page=" .. page_id .. " obj=" .. obj_id)
    end
    delay.delay_ms(33)
end
```

**Returns**

| # | Type | Description |
|---|------|-------------|
| 1 | number \| nil | Page ID where the touch occurred |
| 2 | number \| nil | Control ID that was touched, or `0` for background |

---

### UI Main Loop

A normal Skill UI must run an event loop to receive touch events. The simulator provides two common patterns:

**Pattern 1 — pure event driven**

`pop_event()` is non-blocking and returns `nil, nil` when no touch has occurred. For a simple UI that only reacts to touches:

```lua
while true do
    local page_id, obj_id = claw.display.pop_event()
    if page_id then
        -- handle touch
    end
end
```

> Note: because `pop_event()` does not block, this pattern keeps the Lua coroutine running. It is safe in the simulator but burns CPU; add `delay.delay_ms(33)` if you also need animations.

**Pattern 2 — event driven + animation**

For games or animations that must update every frame, call `delay.delay_ms(ms)` to yield time to the browser:

```lua
while true do
    local page_id, obj_id = claw.display.pop_event()
    if page_id then
        -- handle touch
    end

    -- per-frame update
    updateAnimation()

    delay.delay_ms(33)  -- ~30 fps
end
```

---

## 2. `claw.rgb` — Water-cooling LED API

### `claw.rgb.set(color)`

Sets the entire LED strip to a solid color.

```lua
claw.rgb.set(0x02FFB5)
```

---

### `claw.rgb.set_mode(mode, value)`

Sets the LED mode.

```lua
-- solid color
claw.rgb.set_mode("solid", 0x02FFB5)

-- per-zone colors (array of 4 colors)
claw.rgb.set_mode("zone", {0xFF0000, 0x00FF00, 0x0000FF, 0xFFFFFF})

-- named effect
claw.rgb.set_mode("effect", "rainbow")
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `mode` | string | `"solid"`, `"zone"`, `"effect"`, or custom string |
| `value` | number \| table \| string | Color, zone array, or effect name |

---

### `claw.rgb.set_zone(zone_index, color)`

Sets one zone color. Zones are indexed `1~4`.

```lua
claw.rgb.set_zone(1, 0xFF0000)
```

---

### `claw.rgb.effect(name, params)`

Activates a named light effect.

```lua
claw.rgb.effect("breathe", { color = 0x02FFB5, duration = 2000 })
claw.rgb.effect("rainbow", { duration = 5000 })
```

---

### `claw.rgb.off()`

Turns the LED off (sets color to black).

```lua
claw.rgb.off()
```

---

### `claw.rgb.get_color()`

Returns the current solid color.

```lua
local c = claw.rgb.get_color()
```

**Returns**

| # | Type | Description |
|---|------|-------------|
| 1 | number | Current color `0xRRGGBB` |

---

## 3. `delay` — Timing API

### `delay.delay_ms(milliseconds)`

Yields the Lua script for the given time. In the simulator this is implemented as a non-blocking coroutine yield so the browser UI stays responsive.

```lua
while true do
    -- run at ~30 fps
    delay.delay_ms(33)
end
```

---

## 4. `sys` — System API

### `sys.log(level, message)`

Writes a log message to the simulator debug console.

```lua
sys.log("info", "hello")
sys.log("warn", "low memory")
sys.log("error", "failed")
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `level` | string | `"debug"`, `"info"`, `"warn"`, `"error"` |
| `message` | string | Log content |

---

### `sys.millis()`

Returns milliseconds elapsed since the script started.

```lua
local t = sys.millis()
```

**Returns**

| # | Type | Description |
|---|------|-------------|
| 1 | number | Elapsed milliseconds |

---

### `sys.time()`

Returns the current Unix timestamp in seconds.

```lua
local ts = sys.time()
```

---

### `sys.date(format, timestamp)`

Returns date information.

```lua
local t = sys.date("*t", sys.time())
-- t.year, t.month, t.day, t.hour, t.min, t.sec, t.wday
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `format` | string | `"*t"` returns a table; otherwise returns ISO string |
| `timestamp` | number | Unix seconds (default: now) |

**Returns (when `format == "*t"`)**

| Field | Type | Description |
|-------|------|-------------|
| `year` | number | Full year |
| `month` | number | 1~12 |
| `day` | number | 1~31 |
| `hour` | number | 0~23 |
| `min` | number | 0~59 |
| `sec` | number | 0~59 |
| `wday` | number | 1=Sunday ~ 7=Saturday |
| `yday` | number | Always `0` (not implemented) |

---

## 5. `net` — Network API

> In the simulator requests are sent through the browser `fetch` and are subject to CORS.

### `net.get(url, options, callback)`

Performs an HTTP GET request.

```lua
net.get("https://api.example.com/price", {}, function(status, body, headers)
    sys.log("info", "status=" .. status)
end)
```

**Parameters**

| Name | Type | Description |
|------|------|-------------|
| `url` | string | Request URL |
| `options` | table | Optional fetch options (`headers`, etc.) |
| `callback` | function | `function(status, body, headers)` |

---

### `net.post(url, body, options, callback)`

Performs an HTTP POST request. Tables are JSON-encoded automatically.

```lua
net.post("https://api.example.com/data", { foo = "bar" }, {}, function(status, body)
    sys.log("info", "posted")
end)
```

---

### `net.put(url, body, options, callback)`

Same as `net.post` but uses PUT.

---

### `net.delete(url, options, callback)`

Performs an HTTP DELETE request.

---

### `net.parse_json(json_string)`

Parses a JSON string into a Lua table. Returns `nil` on error.

```lua
local data = net.parse_json('{"usd": 65000}')
sys.log("info", data.usd)
```

---

### `net.url_encode(text)`

URL-encodes a string.

```lua
local s = net.url_encode("hello world")
-- s = "hello%20world"
```

---

## 6. `storage` — File System API (simulator stub)

The simulator provides an in-memory file system stub. Files do not persist across simulator reloads.

### `storage.get_root_dir()`

Returns the root directory string.

```lua
local root = storage.get_root_dir()
-- root = "/bc08"
```

---

### `storage.join_path(part1, part2, ...)`

Joins path parts with `/`.

```lua
local p = storage.join_path("skills", "my_skill", "data.txt")
-- p = "skills/my_skill/data.txt"
```

---

### `storage.exists(path)`

Returns `true` if the file exists in memory.

```lua
if storage.exists("config.txt") then
    -- ...
end
```

---

### `storage.read_file(path)`

Reads a file. Raises an error if the file does not exist.

```lua
local text = storage.read_file("config.txt")
```

---

### `storage.write_file(path, content)`

Writes a string to memory.

```lua
storage.write_file("config.txt", "hello")
```

---

## 7. Minimal Skill Template

```lua
local PAGE = 1
local W, H = claw.display.get_size()

claw.display.create_page(PAGE, "Hello")
claw.display.container(PAGE, 1, 0, 0, W, H, 0x000000, 0)
claw.display.label(PAGE, 2, W / 2 - 130, H / 2 - 30, "Hello HAMMER!", 0x02FFB5, 40)

claw.rgb.set_mode("solid", 0x02FFB5)

while true do
    local p, obj = claw.display.pop_event()
    if p then
        sys.log("info", "event page=" .. p .. " obj=" .. obj)
    end
    delay.delay_ms(33)
end
```
