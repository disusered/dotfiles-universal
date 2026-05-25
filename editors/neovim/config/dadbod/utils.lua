-- Shared utility functions
local M = {}

local function parse_json(json)
  if type(json) ~= "string" or not json:match("^%s*[%[{]") then
    return nil
  end

  local ok, decoded = pcall(vim.fn.json_decode, json)
  if not ok or type(decoded) ~= "table" then
    return nil
  end

  return decoded
end

---
-- Parses a YAML file for dadbod project detection without requiring vim-rails
-- to load during startup.
-- @param file (string) YAML file path.
-- @return (table|nil) Parsed YAML content or nil on failure.
function M.parse_yaml_file(file)
  local ok, parsed = pcall(vim.fn["rails#yaml_parse_file"], file)
  if ok and type(parsed) == "table" then
    return parsed
  end

  local script = table.concat({
    "path = ARGV.fetch(0)",
    "erb = ARGV[1] == '1'",
    "source = File.read(path)",
    "source = ERB.new(source).result if erb",
    "puts JSON.generate(YAML.load(source))",
  }, "; ")
  local json = vim.fn.system({
    "ruby",
    "-rjson",
    "-ryaml",
    "-rerb",
    "-e",
    script,
    file,
    vim.g.rails_erb_yaml == 1 and "1" or "0",
  })

  if vim.v.shell_error ~= 0 then
    return nil
  end

  return parse_json(json)
end

---
-- Formats a table of connection details into a dadbod URL string.
-- @param details (table) A table with keys like scheme, user, pass, host, port, db.
-- @return (string|nil) The formatted URL or nil on failure.
function M.format_dadbod_url(details)
  if not details or not details.scheme then
    return nil
  end

  if details.scheme == "sqlite" then
    return "sqlite:" .. (details.db or "")
  end

  local user = details.user or ""
  local pass = details.pass or ""
  local host = details.host or "localhost"
  local port = details.port or ""
  local db = details.db or ""
  local auth_part = ""

  if user ~= "" and user ~= vim.NIL then
    auth_part = user
    if pass ~= "" and pass ~= vim.NIL then
      auth_part = auth_part .. ":" .. pass
    end
    auth_part = auth_part .. "@"
  end

  local port_part = ""
  if port ~= "" and port ~= vim.NIL then
    port_part = ":" .. tostring(port)
  end

  return string.format("%s://%s%s%s/%s", details.scheme, auth_part, host, port_part, db)
end

return M
