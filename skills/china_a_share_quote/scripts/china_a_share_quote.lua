local capability = require("capability")
local json = require("json")

local DEFAULT_SYMBOL = "sh688018"
local DEFAULT_TIMEOUT_MS = 15000
local MAX_BODY_BYTES = 8192

local a = type(args) == "table" and args or {}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function selected_symbol()
    local symbol = DEFAULT_SYMBOL

    if type(a.symbol) == "string" and trim(a.symbol) ~= "" then
        symbol = trim(a.symbol):lower()
    end

    symbol = symbol:gsub("%s+", "")

    if not symbol:match("^[a-z][a-z]%d%d%d%d%d%d$") then
        error("symbol must be a Tencent A-share symbol such as sh688018 or sz000001")
    end

    return symbol
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
        source_cap = string_arg("source_cap", "china_a_share_quote"),
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

local function split_fields(value)
    local fields = {}
    for field in (tostring(value or "") .. "~"):gmatch("(.-)~") do
        fields[#fields + 1] = field
        if #fields > 120 then
            break
        end
    end
    return fields
end

local function tonumber_or_nil(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return tonumber(value)
end

local function parse_quote_body(symbol, body)
    local payload = tostring(body or ""):match('v_' .. symbol .. '="(.-)";?%s*$')
    if not payload then
        error("Tencent quote response did not contain symbol " .. symbol)
    end

    local fields = split_fields(payload)
    if #fields < 35 or fields[1] == "" then
        error("Tencent quote response has an unexpected field count")
    end
    if fields[1] == "51" or fields[4] == "" then
        error("Tencent quote response has no quote data for " .. symbol)
    end

    return {
        ok = true,
        symbol = symbol,
        code = fields[3],
        price = tonumber_or_nil(fields[4]),
        previous_close = tonumber_or_nil(fields[5]),
        open = tonumber_or_nil(fields[6]),
        volume = tonumber_or_nil(fields[7]),
        datetime = fields[31],
        change = tonumber_or_nil(fields[32]),
        change_pct = tonumber_or_nil(fields[33]),
        high = tonumber_or_nil(fields[34]),
        low = tonumber_or_nil(fields[35]),
        amount = tonumber_or_nil(fields[38]),
    }
end

local function run()
    local symbol = selected_symbol()
    local api_url = "https://qt.gtimg.cn/q=" .. symbol

    local ok, out, err = capability.call("http_request", {
        url = api_url,
        method = "GET",
        headers = {
            Accept = "text/plain,*/*",
            Referer = "https://gu.qq.com/" .. symbol,
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
        error("Tencent quote API failed: status=" .. tostring(status))
    end

    local result = parse_quote_body(symbol, body)

    print(string.format(
        "[china_a_share_quote] %s price=%s change=%s pct=%s%% high=%s low=%s time=%s",
        result.symbol,
        tostring(result.price),
        tostring(result.change),
        tostring(result.change_pct),
        tostring(result.high),
        tostring(result.low),
        tostring(result.datetime)
    ))
    print(json.encode(result))
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
    print("[china_a_share_quote] ERROR: " .. tostring(err))
    error(err)
end
