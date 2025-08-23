return {
  "kristijanhusak/vim-dadbod-ui",
  dependencies = {
    { "tpope/vim-dadbod",                     lazy = true },
    { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
  },
  cmd = {
    "DBUI",
    "DBUIToggle",
    "DBUIAddConnection",
    "DBUIFindBuffer",
  },
  init = function()
    -- Set any initial dadbod-ui settings here
    vim.g.db_ui_use_nerd_fonts = 1

    -- Session-level cache to store connections for each project root.
    local project_connections_cache = {}

    -- This function contains the core logic for setting up DB connections.
    local function setup_project_databases()
      -- 1. Find the project root by locating config/database.yml
      local db_config_path = vim.fn.findfile("config/database.yml", ".;")
      if not db_config_path or db_config_path == "" then
        return -- Not a Rails project, so we do nothing.
      end

      local project_root = vim.fn.fnamemodify(db_config_path, ":h:h")

      -- 2. If this project's connections are already cached, we're done.
      if project_connections_cache[project_root] ~= nil then
        return
      end

      -- 3. Safely call the vim-rails function. pcall prevents errors.
      local ok, configs = pcall(vim.fn["rails#yaml_parse_file"], "config/database.yml")
      if not ok or type(configs) ~= "table" then
        project_connections_cache[project_root] = false -- Cache the failure.
        return
      end

      -- 4. Helper to build a dadbod URL from a Rails config table.
      local function format_dadbod_url(config)
        -- This logic remains the same as before...
        if not config or not config.adapter then
          return nil
        end
        local adapter_map = { postgresql = "postgresql", mysql2 = "mysql", sqlite3 = "sqlite" }
        local scheme = adapter_map[config.adapter]
        if not scheme then
          return nil
        end
        if scheme == "sqlite" then
          return "sqlite:" .. (config.database or "")
        end
        local user = config.username or ""
        local pass = config.password or ""
        local host = config.host or "localhost"
        local port = config.port or ""
        local db = config.database or ""
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
        return string.format("%s://%s%s%s/%s", scheme, auth_part, host, port_part, db)
      end

      -- 5. Iterate configs, build the connection list, and sort it.
      local connections = {}
      for name, config in pairs(configs) do
        local url = format_dadbod_url(config)
        if url then
          table.insert(connections, { name = name, url = url })
        end
      end
      table.sort(connections, function(a, b)
        return a.name < b.name
      end)

      -- 6. Set the global `g:dbs` variable and cache the result.
      vim.g.dbs = connections
      project_connections_cache[project_root] = connections

      -- This notification now only appears once when a new project is detected.
      vim.notify("Found " .. #connections .. " database connections for this project.", vim.log.levels.INFO, {
        title = "vim-dadbod-ui (Rails)",
      })
    end

    -- Create a dedicated autocommand group to ensure no conflicts.
    local rails_db_group = vim.api.nvim_create_augroup("RailsDbSetup", { clear = true })

    -- Run the setup logic only on startup and when changing directories.
    vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
      group = rails_db_group,
      pattern = "*",
      callback = setup_project_databases,
    })
  end,
}
