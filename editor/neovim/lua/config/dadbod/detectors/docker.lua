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

function M.find()
  local compose_path = vim.fn.findfile("docker-compose.yml", ".;") or vim.fn.findfile("docker-compose.yaml", ".;")
  if not compose_path or compose_path == "" then
    print("  No docker-compose.yml found in current or parent directories.")
    return nil
  end

  local ok, compose_data = pcall(vim.fn["rails#yaml_parse_file"], compose_path)
  if not ok or type(compose_data) ~= "table" then
    print("  Failed to parse docker-compose.yml. Check file format.")
    return nil
  end

  local services = compose_data.services or compose_data
  if type(services) ~= "table" then
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
    local noun = #connections == 1 and "connection" or "connections"
    vim.notify(
      "  Found " .. #connections .. " " .. noun .. " in docker-compose.yml.",
      vim.log.levels.INFO,
      { title = "Database UI" }
    )
    return connections, nil
  end

  return nil
end

return M
