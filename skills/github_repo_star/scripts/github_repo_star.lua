local capability = require("capability")
local json = require("json")

local DEFAULT_OWNER = "espressif"
local DEFAULT_REPO = "esp-claw"
local DEFAULT_TIMEOUT_MS = 15000
local MAX_BODY_BYTES = 8192

local a = type(args) == "table" and args or {}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function strip_git_suffix(value)
    return (value:gsub("%.git$", ""))
end

local function parse_repo_spec(value)
    local spec = trim(value)
    local owner, repo

    if spec == "" then
        return nil, nil
    end

    spec = spec:gsub("[#?].*$", "")

    owner, repo = spec:match("^https?://github%.com/([^/%s]+)/([^/%s]+)")
    if owner and repo then
        return owner, strip_git_suffix(repo)
    end

    owner, repo = spec:match("^https?://api%.github%.com/repos/([^/%s]+)/([^/%s]+)")
    if owner and repo then
        return owner, strip_git_suffix(repo)
    end

    owner, repo = spec:match("^([^/%s]+)/([^/%s]+)$")
    if owner and repo then
        return owner, strip_git_suffix(repo)
    end

    return nil, nil
end

local function validate_repo_part(name, value)
    if type(value) ~= "string" or value == "" then
        error(name .. " must not be empty")
    end
    if not value:match("^[%w%._%-]+$") then
        error(name .. " contains unsupported characters: " .. tostring(value))
    end
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

local function selected_repo()
    local owner, repo

    if type(a.repo) == "string" and trim(a.repo) ~= "" then
        owner, repo = parse_repo_spec(a.repo)
    elseif type(a.url) == "string" and trim(a.url) ~= "" then
        owner, repo = parse_repo_spec(a.url)
    else
        owner, repo = DEFAULT_OWNER, DEFAULT_REPO
    end

    if not owner or not repo then
        error("repo must be owner/name or a github.com repository URL")
    end

    validate_repo_part("owner", owner)
    validate_repo_part("repo", repo)
    return owner, repo
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
        source_cap = string_arg("source_cap", "github_repo_star"),
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

local function github_error(status, body)
    local data = decode_json_body(body)
    if data and type(data.message) == "string" then
        return string.format("GitHub API failed: status=%d message=%s", status or -1, data.message)
    end
    return string.format("GitHub API failed: status=%s", tostring(status))
end

local function run()
    local owner, repo = selected_repo()
    local api_url = string.format("https://api.github.com/repos/%s/%s", owner, repo)

    local ok, out, err = capability.call("http_request", {
        url = api_url,
        method = "GET",
        headers = {
            Accept = "application/vnd.github+json",
            ["User-Agent"] = "esp-clawgent-lua-capability",
            ["X-GitHub-Api-Version"] = "2022-11-28",
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
        error(github_error(status, body))
    end

    local data = decode_json_body(body)
    if not data then
        error("GitHub API returned invalid JSON")
    end
    if type(data.stargazers_count) ~= "number" then
        error("GitHub API response missing stargazers_count")
    end

    local result = {
        ok = true,
        owner = owner,
        repo = repo,
        full_name = data.full_name or (owner .. "/" .. repo),
        stars = data.stargazers_count,
        url = data.html_url or ("https://github.com/" .. owner .. "/" .. repo),
    }

    print(string.format(
        "[github_repo_star] %s stars=%d url=%s",
        result.full_name,
        result.stars,
        result.url
    ))
    print(json.encode(result))
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
    print("[github_repo_star] ERROR: " .. tostring(err))
    error(err)
end
