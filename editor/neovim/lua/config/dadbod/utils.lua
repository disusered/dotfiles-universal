-- Shared utility functions
local M = {}

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
