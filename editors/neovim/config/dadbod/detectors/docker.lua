local utils = require("config.dadbod.utils")

local M = {}

-- Helper to find a value from Docker's environment config, which can be a list or a map.
local function get_env_value(env_data, key)
  if not env_data then
    return nil
  end
  -- Handle map format: { FOO = "bar" }
  if type(env_data) == "table" and env_data[key] then
    return env_data[key]
  end
  -- Handle list format: { "FOO=bar" }
  if type(env_data) == "table" then
    for _, line in ipairs(env_data) do
      local k, v = line:match("([^=]+)=(.*)")
      if k == key then
        return v
      end
    end
  end
  return nil
end

-- Find all docker-compose files in a directory (base + environment-specific)
local function find_compose_files(dir)
  local files = {}

  -- Check for base docker-compose.yml/yaml
  for _, basename in ipairs({ "docker-compose.yml", "docker-compose.yaml" }) do
    local path = dir .. "/" .. basename
    if vim.fn.filereadable(path) == 1 then
      table.insert(files, path)
      break
    end
  end

  -- Find docker-compose.*.yml/yaml files (e.g., docker-compose.development.yml)
  local glob_patterns = { dir .. "/docker-compose.*.yml", dir .. "/docker-compose.*.yaml" }
  for _, pattern in ipairs(glob_patterns) do
    local matches = vim.fn.glob(pattern, false, true)
    for _, match in ipairs(matches) do
      -- Avoid duplicates
      local already_added = false
      for _, f in ipairs(files) do
        if f == match then
          already_added = true
          break
        end
      end
      if not already_added then
        table.insert(files, match)
      end
    end
  end

  return files
end

-- Merge services from multiple compose files (later files override earlier ones)
local function merge_services(files)
  local merged = {}
  for _, file in ipairs(files) do
    local ok, data = pcall(vim.fn["rails#yaml_parse_file"], file)
    if ok and type(data) == "table" then
      local services = data.services or data
      if type(services) == "table" then
        for name, config in pairs(services) do
          merged[name] = config
        end
      end
    end
  end
  return merged
end

function M.find()
  -- Find project root by looking for docker-compose files
  local compose_path = vim.fn.findfile("docker-compose.yml", ".;")
  if not compose_path or compose_path == "" then
    compose_path = vim.fn.findfile("docker-compose.yaml", ".;")
  end
  -- Also try finding environment-specific compose files
  if not compose_path or compose_path == "" then
    local glob_result = vim.fn.glob("**/docker-compose.*.yml", false, true)
    if #glob_result > 0 then
      compose_path = glob_result[1]
    end
  end

  if not compose_path or compose_path == "" then
    print("  No docker-compose files found in current or parent directories.")
    return nil
  end

  local compose_dir = vim.fn.fnamemodify(compose_path, ":h")
  local compose_files = find_compose_files(compose_dir)

  if #compose_files == 0 then
    print("  No docker-compose files found.")
    return nil
  end

  local services = merge_services(compose_files)
  if type(services) ~= "table" or vim.tbl_isempty(services) then
    return nil
  end

  local connections = {}
  local added_urls = {} -- FIX: Keep track of URLs to prevent duplicates

  local supported_dbs = {
    postgres = {
      scheme = "postgresql",
      user_var = "POSTGRES_USER",
      pass_var = "POSTGRES_PASSWORD",
      db_var = "POSTGRES_DB",
      default_port = "5432",
    },
    mysql = {
      scheme = "mysql",
      user_var = "MYSQL_USER",
      pass_var = "MYSQL_PASSWORD",
      root_pass_var = "MYSQL_ROOT_PASSWORD",
      db_var = "MYSQL_DATABASE",
      default_port = "3306",
    },
    mariadb = {
      scheme = "mysql",
      user_var = "MARIADB_USER",
      pass_var = "MARIADB_PASSWORD",
      root_pass_var = "MARIADB_ROOT_PASSWORD",
      db_var = "MARIADB_DATABASE",
      default_port = "3306",
    },
  }

  for service_name, config in pairs(services) do
    if type(config) == "table" and config.image then
      for db_type, db_config in pairs(supported_dbs) do
        if config.image:match(db_type) then
          local user = get_env_value(config.environment, db_config.user_var)
          local pass = get_env_value(config.environment, db_config.pass_var)
            or (db_config.root_pass_var and get_env_value(config.environment, db_config.root_pass_var))
          local db = get_env_value(config.environment, db_config.db_var)

          if user and pass and db then
            local external_port = db_config.default_port
            if config.ports and type(config.ports) == "table" then
              for _, port_mapping in ipairs(config.ports) do
                local host_port = port_mapping:match("^(%d+):" .. db_config.default_port)
                if host_port then
                  external_port = host_port
                  break
                end
              end
            end

            local url = utils.format_dadbod_url({
              scheme = db_config.scheme,
              user = user,
              pass = pass,
              host = "localhost",
              port = external_port,
              db = db,
            })

            if url and not added_urls[url] then
              table.insert(connections, { name = service_name .. " (Docker)", url = url })
              added_urls[url] = true
            end
          end
          break
        end
      end
    end
  end

  if #connections > 0 then
    table.sort(connections, function(a, b)
      return a.name < b.name
    end)
    local file_count = #compose_files
    local file_noun = file_count == 1 and "file" or "files"
    local conn_noun = #connections == 1 and "connection" or "connections"
    vim.notify(
      "  Found " .. #connections .. " " .. conn_noun .. " in " .. file_count .. " docker-compose " .. file_noun .. ".",
      vim.log.levels.INFO,
      { title = "Database UI" }
    )
    return connections, nil
  end

  return nil
end

return M
