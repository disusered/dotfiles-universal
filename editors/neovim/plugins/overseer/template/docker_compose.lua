---@param opts overseer.SearchParams
---@return nil|string
local function get_compose_file(opts)
  return vim.fs.find({ "docker-compose.yml", "compose.yml" }, { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return get_compose_file(opts)
  end,
  generator = function(opts)
    local compose_file = get_compose_file(opts)
    if not compose_file then
      return "No docker-compose.yml or compose.yml found"
    end
    local cwd = vim.fs.dirname(compose_file)
    return {
      {
        name = "docker compose up",
        builder = function()
          return { cmd = { "docker", "compose", "up" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose up -d",
        builder = function()
          return { cmd = { "docker", "compose", "up", "-d" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose down",
        builder = function()
          return { cmd = { "docker", "compose", "down" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose build",
        builder = function()
          return { cmd = { "docker", "compose", "build" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose logs",
        builder = function()
          return { cmd = { "docker", "compose", "logs" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose logs -f",
        builder = function()
          return { cmd = { "docker", "compose", "logs", "-f" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose exec",
        params = {
          service = { type = "string", order = 1 },
          command = { type = "string", default = "sh", order = 2 },
        },
        builder = function(params)
          return { cmd = { "docker", "compose", "exec", params.service, params.command }, cwd = cwd }
        end,
      },
      {
        name = "docker compose ps",
        builder = function()
          return { cmd = { "docker", "compose", "ps" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose restart",
        builder = function()
          return { cmd = { "docker", "compose", "restart" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose pull",
        builder = function()
          return { cmd = { "docker", "compose", "pull" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose stop",
        builder = function()
          return { cmd = { "docker", "compose", "stop" }, cwd = cwd }
        end,
      },
      {
        name = "docker compose run",
        params = {
          service = { type = "string", order = 1 },
          command = { type = "string", optional = true, order = 2 },
        },
        builder = function(params)
          local cmd = { "docker", "compose", "run", params.service }
          if params.command then
            table.insert(cmd, params.command)
          end
          return { cmd = cmd, cwd = cwd }
        end,
      },
    }
  end,
}
