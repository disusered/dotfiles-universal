-- Detects SQLite database files in the project
local utils = require("config.dadbod.utils")

local M = {}

---
-- Finds SQLite .db files in the project directory.
-- Respects .gitignore patterns via vim.fn.glob's nosuf parameter.
-- @return (table|nil) A list of connections if found, otherwise nil.
function M.find()
  local files = vim.fn.glob("**/*.db", false, true)
  if #files == 0 then
    return nil
  end

  local connections = {}
  for _, file in ipairs(files) do
    local abs_path = vim.fn.fnamemodify(file, ":p")
    local url = utils.format_dadbod_url({ scheme = "sqlite", db = abs_path })
    if url then
      table.insert(connections, { name = file, url = url })
    end
  end

  if #connections > 0 then
    table.sort(connections, function(a, b)
      return a.name < b.name
    end)
    local conn_noun = #connections == 1 and "connection" or "connections"
    vim.notify(
      "Found " .. #connections .. " SQLite " .. conn_noun .. ".",
      vim.log.levels.INFO,
      { title = "vim-dadbod-ui" }
    )
    return connections
  end

  return nil
end

return M
