local capability = require("capability")
local json = require("json")

local DEFAULT_LOCATION = "Singapore"
local DEFAULT_LATITUDE = 1.3521
local DEFAULT_LONGITUDE = 103.8198
local DEFAULT_TIMEOUT_MS = 15000
local MAX_BODY_BYTES = 12288

local a = type(args) == "table" and args or {}

local WEATHER_CODES = {
    [0] = "Clear sky",
    [1] = "Mainly clear",
    [2] = "Partly cloudy",
    [3] = "Overcast",
    [45] = "Fog",
    [48] = "Depositing rime fog",
    [51] = "Light drizzle",
    [53] = "Moderate drizzle",
    [55] = "Dense drizzle",
    [56] = "Light freezing drizzle",
    [57] = "Dense freezing drizzle",
    [61] = "Slight rain",
    [63] = "Moderate rain",
    [65] = "Heavy rain",
    [66] = "Light freezing rain",
    [67] = "Heavy freezing rain",
    [71] = "Slight snow fall",
    [73] = "Moderate snow fall",
    [75] = "Heavy snow fall",
    [77] = "Snow grains",
    [80] = "Slight rain showers",
    [81] = "Moderate rain showers",
    [82] = "Violent rain showers",
    [85] = "Slight snow showers",
    [86] = "Heavy snow showers",
    [95] = "Thunderstorm",
    [96] = "Thunderstorm with slight hail",
    [99] = "Thunderstorm with heavy hail",
}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function selected_number(key, default, min_value, max_value)
    local value = a[key]
    if type(value) ~= "number" then
        return default
    end
    if value < min_value or value > max_value then
        error(key .. " must be between " .. tostring(min_value) .. " and " .. tostring(max_value))
    end
    return value
end

local function selected_location()
    if type(a.location) == "string" and trim(a.location) ~= "" then
        return trim(a.location)
    end
    return DEFAULT_LOCATION
end

local function selected_timezone()
    if type(a.timezone) == "string" and trim(a.timezone) ~= "" then
        local value = trim(a.timezone)
        if not value:match("^[%w_/%+%-]+$") then
            error("timezone contains unsupported characters")
        end
        return value
    end
    return "auto"
end

local function request_timeout()
    local value = a.timeout_ms
    if type(value) ~= "number" then
        return DEFAULT_TIMEOUT_MS
    end
    value = math.floor(value)
    if value < 1 then
        return 1
    end
    if value > 120000 then
        return 120000
    end
    return value
end

local function string_arg(key, default)
    local value = a[key]
    if type(value) == "string" and value ~= "" then
        return value
    end
    return default
end

local function build_opts()
    local opts = {
        source_cap = string_arg("source_cap", "current_weather"),
    }

    local session_id = string_arg("session_id", nil)
    if session_id then
        opts.session_id = session_id
    end

    return opts
end

local function split_http_response(out)
    local status_text, body = tostring(out or ""):match("^(HTTP [^\n]*)\n(.*)$")
    if not status_text then
        return nil, nil
    end

    local status = tonumber(status_text:match("^HTTP%s+(%d+)"))
    return status, body or ""
end

local function decode_json_body(body)
    local ok, data = pcall(json.decode, body or "")
    if not ok or type(data) ~= "table" then
        return nil
    end
    return data
end

local function open_meteo_error(status, body)
    local data = decode_json_body(body)
    if data and type(data.reason) == "string" then
        return string.format("Open-Meteo API failed: status=%d reason=%s", status or -1, data.reason)
    end
    return string.format("Open-Meteo API failed: status=%s", tostring(status))
end

local function first_array_value(value)
    if type(value) == "table" then
        return value[1]
    end
    return nil
end

local function build_url(latitude, longitude, timezone)
    return string.format(
        "https://api.open-meteo.com/v1/forecast?latitude=%.6f&longitude=%.6f&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=%s&forecast_days=1",
        latitude,
        longitude,
        timezone
    )
end

local function run()
    local latitude = selected_number("latitude", DEFAULT_LATITUDE, -90, 90)
    local longitude = selected_number("longitude", DEFAULT_LONGITUDE, -180, 180)
    local location = selected_location()
    local timezone = selected_timezone()

    local ok, out, err = capability.call("http_request", {
        url = build_url(latitude, longitude, timezone),
        method = "GET",
        headers = {
            Accept = "application/json",
            ["User-Agent"] = "esp-clawgent-lua-capability",
        },
        timeout_ms = request_timeout(),
        max_body_bytes = MAX_BODY_BYTES,
    }, build_opts())

    if not ok then
        error(string.format("http_request failed: %s", tostring(err or out)))
    end

    local status, body = split_http_response(out)
    if not status then
        error("http_request returned an unexpected response")
    end
    if status ~= 200 then
        error(open_meteo_error(status, body))
    end

    local data = decode_json_body(body)
    if not data then
        error("Open-Meteo API returned invalid JSON")
    end
    if type(data.current) ~= "table" then
        error("Open-Meteo API response missing current weather")
    end

    local current = data.current
    local daily = type(data.daily) == "table" and data.daily or {}
    local code = current.weather_code
    local result = {
        ok = true,
        location = location,
        latitude = latitude,
        longitude = longitude,
        timezone = data.timezone or timezone,
        time = current.time,
        temperature_c = current.temperature_2m,
        apparent_temperature_c = current.apparent_temperature,
        relative_humidity_pct = current.relative_humidity_2m,
        wind_speed_kmh = current.wind_speed_10m,
        weather_code = code,
        condition = WEATHER_CODES[code] or ("Weather code " .. tostring(code)),
        rain_probability_pct = first_array_value(daily.precipitation_probability_max),
        daily_high_c = first_array_value(daily.temperature_2m_max),
        daily_low_c = first_array_value(daily.temperature_2m_min),
    }

    if type(result.temperature_c) ~= "number" then
        error("Open-Meteo API response missing temperature_2m")
    end

    print(string.format(
        "[current_weather] %s temp=%sC apparent=%sC condition=%s humidity=%s%% wind=%skm/h rain_prob=%s%% time=%s",
        result.location,
        tostring(result.temperature_c),
        tostring(result.apparent_temperature_c),
        result.condition,
        tostring(result.relative_humidity_pct),
        tostring(result.wind_speed_kmh),
        tostring(result.rain_probability_pct),
        tostring(result.time)
    ))
    print(json.encode(result))
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
    print("[current_weather] ERROR: " .. tostring(err))
    error(err)
end
