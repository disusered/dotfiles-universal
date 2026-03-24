---@param opts overseer.SearchParams
---@return nil|string, string|nil
local function get_dotnet_marker(opts)
  local sln_pred = function(name)
    return name:match("%.slnx?$")
  end

  local sln = vim.fs.find(sln_pred, { upward = true, path = opts.dir })[1]
  if sln then return sln, "sln" end

  sln = vim.fs.find(sln_pred, { path = opts.dir })[1]
  if sln then return sln, "sln" end

  local csproj = vim.fs.find(function(name)
    return name:match("%.csproj$")
  end, { upward = true, path = opts.dir })[1]
  if csproj then return csproj, "csproj" end

  return nil, nil
end

---@param sln_path string
---@return {name: string, path: string, dir: string}[]
local function get_projects_from_sln(sln_path)
  local projects = {}
  local sln_dir = vim.fs.dirname(sln_path)
  for _, line in ipairs(vim.fn.readfile(sln_path)) do
    local csproj_rel = line:match('Project%(.-%)%s*=%s*"[^"]*"%s*,%s*"([^"]*%.csproj)"')
    if csproj_rel then
      local normalized = csproj_rel:gsub("\\", "/")
      local full_path = sln_dir .. "/" .. normalized
      table.insert(projects, {
        name = vim.fn.fnamemodify(normalized, ":t:r"),
        path = full_path,
        dir = vim.fs.dirname(full_path),
      })
    end
  end
  return projects
end

---@param slnx_path string
---@return {name: string, path: string, dir: string}[]
local function get_projects_from_slnx(slnx_path)
  local projects = {}
  local sln_dir = vim.fs.dirname(slnx_path)
  for _, line in ipairs(vim.fn.readfile(slnx_path)) do
    local csproj_rel = line:match('Path="([^"]*%.csproj)"')
    if csproj_rel then
      local normalized = csproj_rel:gsub("\\", "/")
      local full_path = sln_dir .. "/" .. normalized
      table.insert(projects, {
        name = vim.fn.fnamemodify(normalized, ":t:r"),
        path = full_path,
        dir = vim.fs.dirname(full_path),
      })
    end
  end
  return projects
end

---@param marker string
---@return {name: string, path: string, dir: string}[]
local function get_projects(marker)
  if marker:match("%.slnx$") then
    return get_projects_from_slnx(marker)
  end
  return get_projects_from_sln(marker)
end

--- Find the main project: first with launchSettings.json, then name match, then first.
---@param marker string
---@param projects {name: string, path: string, dir: string}[]
---@return string
local function find_main_project(marker, projects)
  if #projects == 0 then return marker end

  for _, p in ipairs(projects) do
    if vim.uv.fs_stat(p.dir .. "/Properties/launchSettings.json") then
      return p.path
    end
  end

  local sln_name = vim.fn.fnamemodify(marker, ":t:r")
  for _, p in ipairs(projects) do
    if p.name == sln_name then return p.path end
  end

  return projects[1].path
end

--- Parse launch profiles from Properties/launchSettings.json
---@param project_dir string
---@return {name: string, env: table<string, string>}[]
local function get_launch_profiles(project_dir)
  local path = project_dir .. "/Properties/launchSettings.json"
  local stat = vim.uv.fs_stat(path)
  if not stat then return {} end

  local ok, json = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or not json or not json.profiles then return {} end

  local profiles = {}
  for name, profile in pairs(json.profiles) do
    if profile.commandName == "Project" then
      table.insert(profiles, {
        name = name,
        env = profile.environmentVariables or {},
      })
    end
  end
  return profiles
end

--- Collect launch profiles from all projects in the solution
---@param projects {name: string, path: string, dir: string}[]
---@return {name: string, env: table<string, string>, project_name: string, project_path: string}[]
local function get_all_launch_profiles(projects)
  local all = {}
  for _, p in ipairs(projects) do
    for _, profile in ipairs(get_launch_profiles(p.dir)) do
      table.insert(all, {
        name = profile.name,
        env = profile.env,
        project_name = p.name,
        project_path = p.path,
      })
    end
  end
  return all
end

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return get_dotnet_marker(opts)
  end,
  generator = function(opts)
    local marker, kind = get_dotnet_marker(opts)
    if not marker then
      return "No .sln, .slnx, or .csproj found"
    end

    local cwd = vim.fs.dirname(marker)
    local projects = kind == "sln" and get_projects(marker) or {}
    local main = find_main_project(marker, projects)
    local tasks = {}

    table.insert(tasks, {
      name = "dotnet build",
      builder = function()
        return { cmd = { "dotnet", "build", main }, cwd = cwd }
      end,
    })

    table.insert(tasks, {
      name = "dotnet run",
      builder = function()
        return {
          cmd = { "dotnet", "run", "--no-launch-profile", "--project", main },
          cwd = cwd,
        }
      end,
    })

    table.insert(tasks, {
      name = "dotnet watch",
      builder = function()
        return {
          cmd = { "dotnet", "watch", "--project", main },
          cwd = cwd,
          env = { DOTNET_WATCH_SUPPRESS_LAUNCH_BROWSER = "1" },
        }
      end,
    })

    for _, profile in ipairs(get_all_launch_profiles(projects)) do
      local label = profile.name .. " (" .. profile.project_name .. ")"

      table.insert(tasks, {
        name = "dotnet run: " .. label,
        builder = function()
          return {
            cmd = { "dotnet", "run", "--launch-profile", profile.name, "--project", profile.project_path },
            cwd = cwd,
            env = profile.env,
          }
        end,
      })

      table.insert(tasks, {
        name = "dotnet watch: " .. label,
        builder = function()
          return {
            cmd = { "dotnet", "watch", "--launch-profile", profile.name, "--project", profile.project_path },
            cwd = cwd,
            env = vim.tbl_extend("force", { DOTNET_WATCH_SUPPRESS_LAUNCH_BROWSER = "1" }, profile.env),
          }
        end,
      })
    end

    -- Format tasks: fix (actual run) and check (dry run with diagnostics)
    local format_check_components = {
      {
        "on_output_parse",
        parser = function(line)
          local fname, lnum, col, severity, msg =
            line:match("^(.+)%((%d+),(%d+)%): (%w+) (.+)$")
          if fname then
            local type_map = { error = "E", warning = "W", info = "I" }
            return {
              filename = fname,
              lnum = tonumber(lnum),
              col = tonumber(col),
              type = type_map[severity] or "E",
              text = msg:gsub("%s*%[.-%]$", ""),
            }
          end
        end,
      },
      { "on_result_diagnostics_quickfix", open = true },
      "default",
    }

    for _, sub in ipairs({ "", " whitespace", " style", " analyzers" }) do
      local label = "dotnet format" .. sub

      table.insert(tasks, {
        name = label,
        builder = function()
          local cmd = { "dotnet", "format" }
          if sub ~= "" then table.insert(cmd, vim.trim(sub)) end
          table.insert(cmd, marker)
          return { cmd = cmd, cwd = cwd }
        end,
      })

      table.insert(tasks, {
        name = label .. " --verify-no-changes",
        builder = function()
          local cmd = { "dotnet", "format" }
          if sub ~= "" then table.insert(cmd, vim.trim(sub)) end
          table.insert(cmd, marker)
          table.insert(cmd, "--verify-no-changes")
          table.insert(cmd, "--verbosity")
          table.insert(cmd, "normal")
          return { cmd = cmd, cwd = cwd, components = format_check_components }
        end,
      })
    end

    return tasks
  end,
}
