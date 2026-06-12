local capability = require("capability")
local json = require("json")

local DEFAULT_MID = "538078399"
local DEFAULT_TIMEOUT_MS = 15000
local MAX_BODY_BYTES = 16384

local a = type(args) == "table" and args or {}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function parse_mid(value)
    local spec = trim(value)
    local mid

    if spec == "" then
        return nil
    end

    mid = spec:match("^https?://space%.bilibili%.com/(%d+)")
    if mid then
        return mid
    end

    mid = spec:match("^https?://www%.bilibili%.com/video/[^%s]+.*[?&]mid=(%d+)")
    if mid then
        return mid
    end

    spec = spec:gsub("[#?].*$", "")

    mid = spec:match("^(%d+)$")
    if mid then
        return mid
    end

    return nil
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

local function selected_mid()
    local mid

    if type(a.mid) == "string" and trim(a.mid) ~= "" then
        mid = parse_mid(a.mid)
    elseif type(a.url) == "string" and trim(a.url) ~= "" then
        mid = parse_mid(a.url)
    else
        mid = DEFAULT_MID
    end

    if not mid then
        error("mid must be digits or a space.bilibili.com URL")
    end

    return mid
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
        source_cap = string_arg("source_cap", "bilibili_up_fans"),
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

local function bilibili_error(status, body)
    local data = decode_json_body(body)
    if data and type(data.message) == "string" then
        return string.format("Bilibili API failed: status=%s code=%s message=%s",
            tostring(status), tostring(data.code), data.message)
    end
    return string.format("Bilibili API failed: status=%s", tostring(status))
end

local function run()
    local mid = selected_mid()
    local api_url = "https://api.bilibili.com/x/web-interface/card?mid=" .. mid

    local ok, out, err = capability.call("http_request", {
        url = api_url,
        method = "GET",
        headers = {
            Accept = "application/json",
            Referer = "https://space.bilibili.com/" .. mid,
            ["User-Agent"] = "Mozilla/5.0 esp-clawgent-lua-capability",
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
        error(bilibili_error(status, body))
    end

    local data = decode_json_body(body)
    if not data then
        error("Bilibili API returned invalid JSON")
    end
    if data.code ~= 0 then
        error(bilibili_error(status, body))
    end
    if type(data.data) ~= "table" or type(data.data.card) ~= "table" then
        error("Bilibili API response missing data.card")
    end

    local card = data.data.card
    if type(card.fans) ~= "number" then
        error("Bilibili API response missing data.card.fans")
    end

    local result = {
        ok = true,
        mid = tostring(card.mid or mid),
        name = card.name or "",
        fans = card.fans,
        url = "https://space.bilibili.com/" .. mid,
    }

    print(string.format(
        "[bilibili_up_fans] %s mid=%s fans=%d",
        result.name ~= "" and result.name or result.mid,
        result.mid,
        result.fans
    ))
    print(json.encode(result))
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
    print("[bilibili_up_fans] ERROR: " .. tostring(err))
    error(err)
end
