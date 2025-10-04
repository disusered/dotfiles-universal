-- Detects database connections from a Rails database.yml file
local utils = require("config.dadbod.utils")

local M = {}

---
-- Tries to set up connections from a Ruby on Rails `database.yml` file.
-- Requires `tpope/vim-rails` for its YAML parsing function.
-- @return (table|nil) A list of connections if found, otherwise nil.
function M.find()
  local db_config_path = vim.fn.findfile("config/database.yml", ".;")
  if not db_config_path or db_config_path == "" then
    return nil -- Not a Rails project
  end

  -- This relies on vim-rails being installed for `rails#yaml_parse_file`
  local ok, configs = pcall(vim.fn["rails#yaml_parse_file"], "config/database.yml")
  if not ok or type(configs) ~= "table" then
    vim.notify("vim-dadbod-ui: Could not parse database.yml. Is vim-rails installed?", vim.log.levels.WARN)
    return nil
  end

  local connections = {}
  local adapter_map = { postgresql = "postgresql", mysql2 = "mysql", sqlite3 = "sqlite" }

  for name, config in pairs(configs) do
    local scheme = adapter_map[config.adapter]
    if scheme then
      local url = utils.format_dadbod_url({
        scheme = scheme,
        user = config.username,
        pass = config.password,
        host = config.host,
        port = config.port,
        db = config.database,
      })
      if url then
        table.insert(connections, { name = name, url = url })
      end
    end
  end

  if #connections > 0 then
    table.sort(connections, function(a, b)
      return a.name < b.name
    end)
    vim.notify(
      "Found " .. #connections .. " Rails database connections.",
      vim.log.levels.INFO,
      { title = "vim-dadbod-ui" }
    )
    return connections
  end

  return nil
end

return M
