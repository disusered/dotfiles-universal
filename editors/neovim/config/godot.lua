local function find_godot_project()
  local cwd = vim.fn.getcwd()
  local paths_to_check = {
    cwd,
    vim.fs.dirname(cwd),
  }

  for _, path in ipairs(paths_to_check) do
    if path and vim.uv.fs_stat(path .. "/project.godot") then
      return vim.fs.normalize(path)
    end
  end
end

local project_path = find_godot_project()
if not project_path then
  return
end

vim.g.is_godot_project = true
vim.g.godot_project_path = project_path
vim.g.godot_server_pipe = project_path .. "/server.pipe"

local function server_is_registered(pipe)
  for _, server in ipairs(vim.fn.serverlist()) do
    if server == pipe then
      return true
    end
  end

  return false
end

if not server_is_registered(vim.g.godot_server_pipe) then
  local ok, err = pcall(vim.fn.serverstart, vim.g.godot_server_pipe)
  if not ok then
    vim.notify("Unable to start Godot Neovim server: " .. tostring(err), vim.log.levels.WARN)
  end
end
