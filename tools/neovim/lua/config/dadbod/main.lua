-- Orchestrates the different database detection strategies.
local rails_detector = require("config.dadbod.detectors.rails")
local docker_detector = require("config.dadbod.detectors.docker")

-- Session-level cache to store connections for each project root.
local project_connections_cache = {}

---
-- Main orchestrator function to detect and set up DB connections.
local function setup_project_connections()
  local project_root_marker = vim.fn.finddir(".git", ".;")
    or vim.fn.findfile("config/database.yml", ".;")
    or vim.fn.findfile("docker-compose.yml", ".;")
    or vim.fn.findfile("docker-compose.yaml", ".;")

  if not project_root_marker or project_root_marker == "" then
    return
  end
  local project_root = vim.fn.fnamemodify(project_root_marker, ":h")

  -- **Reset dadbod overrides for the new project context**
  vim.g.dadbod_db_type_overrides = nil

  -- Use cached results if available for the current project
  if project_connections_cache[project_root] ~= nil then
    local cached_data = project_connections_cache[project_root]
    if type(cached_data) == "table" then
      vim.g.dbs = cached_data.connections
      -- Restore cached overrides
      vim.g.dadbod_db_type_overrides = cached_data.overrides
    end
    return
  end

  -- Attempt to find connections using different detectors
  local connections, command_overrides
  connections = rails_detector.find()
  if not connections then
    connections, command_overrides = docker_detector.find()
  end

  -- If connections are found, apply them and cache the result
  if connections and #connections > 0 then
    vim.g.dbs = connections
    if command_overrides then
      vim.g.dadbod_db_type_overrides = command_overrides
      vim.notify("Set dadbod command overrides for Docker (Exec)", vim.log.levels.INFO, { title = "vim-dadbod-ui" })
    end
    project_connections_cache[project_root] = { connections = connections, overrides = command_overrides }
  else
    -- Cache failure to avoid re-running detection unnecessarily
    project_connections_cache[project_root] = false
  end
end

local M = {}

---
-- Sets up the autocmd to trigger connection detection.
function M.setup()
  -- Use Nerd Fonts for icons (optional)
  vim.g.db_ui_use_nerd_fonts = 1

  local db_setup_group = vim.api.nvim_create_augroup("ProjectDbSetup", { clear = true })
  vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
    group = db_setup_group,
    pattern = "*",
    callback = setup_project_connections,
  })
end

return M
