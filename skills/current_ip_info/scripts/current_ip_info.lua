local capability = require("capability")
local json = require("json")

local DEFAULT_TIMEOUT_MS = 15000
local MAX_BODY_BYTES = 8192

local a = type(args) == "table" and args or {}

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
        source_cap = string_arg("source_cap", "current_ip_info"),
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

local function parse_loc(loc)
    if type(loc) ~= "string" then
        return nil, nil
    end
    local lat, lon = loc:match("^%s*([%-%.%d]+)%s*,%s*([%-%.%d]+)%s*$")
    return tonumber(lat), tonumber(lon)
end

local function ipinfo_error(status, body)
    local data = decode_json_body(body)
    if data and type(data.error) == "table" and type(data.error.message) == "string" then
        return string.format("ipinfo.io failed: status=%d message=%s", status or -1, data.error.message)
    end
    if data and type(data.message) == "string" then
        return string.format("ipinfo.io failed: status=%d message=%s", status or -1, data.message)
    end
    return string.format("ipinfo.io failed: status=%s", tostring(status))
end

local function run()
    local ok, out, err = capability.call("http_request", {
        url = "https://ipinfo.io/json",
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
        error(ipinfo_error(status, body))
    end

    local data = decode_json_body(body)
    if not data then
        error("ipinfo.io returned invalid JSON")
    end
    if type(data.ip) ~= "string" or data.ip == "" then
        error("ipinfo.io response missing ip")
    end

    local latitude, longitude = parse_loc(data.loc)
    local result = {
        ok = true,
        ip = data.ip,
        hostname = data.hostname,
        city = data.city,
        region = data.region,
        country = data.country,
        loc = data.loc,
        latitude = latitude,
        longitude = longitude,
        org = data.org,
        postal = data.postal,
        timezone = data.timezone,
    }

    print(string.format(
        "[current_ip_info] ip=%s city=%s region=%s country=%s loc=%s org=%s",
        tostring(result.ip),
        tostring(result.city),
        tostring(result.region),
        tostring(result.country),
        tostring(result.loc),
        tostring(result.org)
    ))
    print(json.encode(result))
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
    print("[current_ip_info] ERROR: " .. tostring(err))
    error(err)
end
