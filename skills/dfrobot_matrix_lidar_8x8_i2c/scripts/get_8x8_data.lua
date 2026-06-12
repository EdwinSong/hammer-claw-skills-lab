local i2c = require("i2c")
local delay = require("delay")
local system = require("system")

local DEFAULT_I2C_PORT = 0
local DEFAULT_SDA = 47
local DEFAULT_SCL = 48
local DEFAULT_I2C_FREQ_HZ = 400000
local DEFAULT_ADDR = 0x33

local DEFAULT_RETRY_COUNT = 5
local DEFAULT_RETRY_DELAY_MS = 100
local DEFAULT_PACKET_TIMEOUT_MS = 8000
local DEFAULT_POLL_INTERVAL_MS = 17

local CMD_SETMODE = 0x01
local CMD_ALL_DATA = 0x02

local STATUS_SUCCESS = 0x53
local STATUS_FAILED = 0x63

local MATRIX_8X8 = 8
local FRAME_POINT_COUNT = 64
local FRAME_BYTE_LEN = FRAME_POINT_COUNT * 2

local function read_arg(name, default)
  if type(args) == "table" and args[name] ~= nil then
    return args[name]
  end
  return default
end

local function parse_int_arg(name, default, min_value, max_value)
  local value = read_arg(name, default)
  if type(value) ~= "number" or value % 1 ~= 0 then
    error(name .. " must be an integer")
  end
  if min_value ~= nil and value < min_value then
    error(string.format("%s must be >= %d", name, min_value))
  end
  if max_value ~= nil and value > max_value then
    error(string.format("%s must be <= %d", name, max_value))
  end
  return value
end

local function cleanup(dev, bus)
  if dev then
    pcall(function()
      dev:close()
    end)
  end
  if bus then
    pcall(function()
      bus:close()
    end)
  end
end

local function build_command_packet(cmd, payload)
  local payload_len = #payload
  local arg_count = payload_len + 1
  local packet = {
    0x55,
    math.floor(arg_count / 256) % 256,
    arg_count % 256,
    cmd
  }

  for i = 1, payload_len do
    packet[#packet + 1] = payload[i]
  end
  return packet
end

local function try_read(dev, len)
  local ok, data = pcall(function()
    return dev:read(len)
  end)
  if not ok or type(data) ~= "string" then
    return nil
  end
  if #data ~= len then
    return nil
  end
  return data
end

local function read_exact(dev, len, timeout_ms, poll_interval_ms)
  local start_ms = system.millis()
  local chunks = {}
  local total = 0

  while total < len do
    local want = len - total
    local data = try_read(dev, want)
    if data and #data > 0 then
      chunks[#chunks + 1] = data
      total = total + #data
    else
      if system.millis() - start_ms >= timeout_ms then
        error(string.format("i2c read timeout, expected %d bytes, got %d", len, total))
      end
      delay.delay_ms(poll_interval_ms)
    end
  end

  return table.concat(chunks)
end

local function recv_packet(dev, expected_cmd, timeout_ms, poll_interval_ms)
  local start_ms = system.millis()

  while system.millis() - start_ms < timeout_ms do
    local status_raw = try_read(dev, 1)
    if not status_raw then
      delay.delay_ms(poll_interval_ms)
    else
      local status = string.byte(status_raw, 1)
      if status ~= 0xFF then
        if status ~= STATUS_SUCCESS and status ~= STATUS_FAILED then
          delay.delay_ms(10)
        else
          local cmd_raw = read_exact(dev, 1, timeout_ms, poll_interval_ms)
          local cmd = string.byte(cmd_raw, 1)
          if cmd ~= expected_cmd then
            error(string.format("response command mismatch, expected 0x%02X got 0x%02X", expected_cmd, cmd))
          end

          local len_raw = read_exact(dev, 2, timeout_ms, poll_interval_ms)
          local len_l = string.byte(len_raw, 1)
          local len_h = string.byte(len_raw, 2)
          local payload_len = len_l + len_h * 256

          if payload_len >= 1000 then
            error(string.format("invalid payload length: %d", payload_len))
          end

          local payload = ""
          if payload_len > 0 then
            payload = read_exact(dev, payload_len, timeout_ms, poll_interval_ms)
          end

          return status, payload
        end
      else
        delay.delay_ms(poll_interval_ms)
      end
    end
  end

  error("receive packet timeout")
end

local function run_cmd_set_mode_8x8(dev, timeout_ms, poll_interval_ms)
  local payload = {0x00, 0x00, 0x00, MATRIX_8X8}
  dev:write(build_command_packet(CMD_SETMODE, payload))

  local status, response_payload = recv_packet(dev, CMD_SETMODE, timeout_ms, poll_interval_ms)
  if status == STATUS_FAILED then
    local err_code = (#response_payload > 0) and string.byte(response_payload, 1) or -1
    error(string.format("set mode failed, error code=%d", err_code))
  end
end

local function run_cmd_get_all_data(dev, timeout_ms, poll_interval_ms)
  dev:write(build_command_packet(CMD_ALL_DATA, {}))

  local status, payload = recv_packet(dev, CMD_ALL_DATA, timeout_ms, poll_interval_ms)
  if status == STATUS_FAILED then
    local err_code = (#payload > 0) and string.byte(payload, 1) or -1
    error(string.format("get all data failed, error code=%d", err_code))
  end

  if #payload < FRAME_BYTE_LEN then
    error(string.format("payload too short: %d < %d", #payload, FRAME_BYTE_LEN))
  end

  local values = {}
  for i = 1, FRAME_POINT_COUNT do
    local idx = (i - 1) * 2 + 1
    local lo = string.byte(payload, idx)
    local hi = string.byte(payload, idx + 1)
    values[i] = hi * 256 + lo
  end
  return values
end

local function matrix_to_json(values)
  local rows = {}

  for row = 1, 8 do
    local row_items = {}
    for col = 1, 8 do
      row_items[#row_items + 1] = tostring(values[(row - 1) * 8 + col])
    end
    rows[#rows + 1] = "[" .. table.concat(row_items, ",") .. "]"
  end

  return "{"
      .. "\"ok\":true,"
      .. "\"sensor\":\"DFRobot_MatrixLidar\","
      .. "\"mode\":\"8x8\","
      .. "\"unit\":\"mm\","
      .. "\"data\":[" .. table.concat(rows, ",") .. "]"
      .. "}"
end

local function run()
  local i2c_port = parse_int_arg("i2c_port", DEFAULT_I2C_PORT, 0, 1)
  local sda = parse_int_arg("sda", DEFAULT_SDA, 0, 63)
  local scl = parse_int_arg("scl", DEFAULT_SCL, 0, 63)
  local i2c_freq_hz = parse_int_arg("i2c_freq_hz", DEFAULT_I2C_FREQ_HZ, 10000, 1000000)
  local addr = parse_int_arg("addr", DEFAULT_ADDR, 0x08, 0x77)
  local retry_count = parse_int_arg("retry_count", DEFAULT_RETRY_COUNT, 1, 20)
  local retry_delay_ms = parse_int_arg("retry_delay_ms", DEFAULT_RETRY_DELAY_MS, 0, 1000)
  local packet_timeout_ms = parse_int_arg("packet_timeout_ms", DEFAULT_PACKET_TIMEOUT_MS, 100, 20000)
  local poll_interval_ms = parse_int_arg("poll_interval_ms", DEFAULT_POLL_INTERVAL_MS, 1, 200)

  local bus = nil
  local dev = nil

  local ok, err = xpcall(function()
    bus = i2c.new(i2c_port, sda, scl, i2c_freq_hz)
    dev = bus:device(addr)

    local last_err = nil
    for attempt = 1, retry_count do
      local once_ok, once_err = pcall(function()
        run_cmd_set_mode_8x8(dev, packet_timeout_ms, poll_interval_ms)
        local values = run_cmd_get_all_data(dev, packet_timeout_ms, poll_interval_ms)

        print(string.format(
          "[dfrobot_matrix_lidar_8x8_i2c] ok addr=0x%02X port=%d sda=%d scl=%d freq=%d attempt=%d",
          addr,
          i2c_port,
          sda,
          scl,
          i2c_freq_hz,
          attempt
        ))
        print(matrix_to_json(values))
      end)

      if once_ok then
        return
      end

      last_err = once_err
      if attempt < retry_count and retry_delay_ms > 0 then
        delay.delay_ms(retry_delay_ms)
      end
    end

    error("matrix lidar read failed after retries: " .. tostring(last_err))
  end, debug.traceback)

  cleanup(dev, bus)

  if not ok then
    print("[dfrobot_matrix_lidar_8x8_i2c] ERROR: " .. tostring(err))
    error(err)
  end
end

run()
