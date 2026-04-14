local function cache_dir()
  return (vim.env.XDG_CACHE_HOME or (vim.env.HOME .. "/.cache")) .. "/nvim-servers"
end

local function entry_path()
  return cache_dir() .. "/" .. vim.fn.getpid() .. ".json"
end

local function git_root_of(cwd)
  local out = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then
    return out[1]
  end
  return cwd
end

local started_at = os.time()

local function write_entry()
  local socket = vim.v.servername
  if not socket or socket == "" then
    return
  end
  local cwd = vim.fn.getcwd()
  local entry = {
    pid = vim.fn.getpid(),
    socket = socket,
    cwd = cwd,
    git_root = git_root_of(cwd),
    started_at = started_at,
  }
  vim.fn.mkdir(cache_dir(), "p")
  local fd = io.open(entry_path(), "w")
  if fd then
    fd:write(vim.fn.json_encode(entry))
    fd:close()
  end
end

local function remove_entry()
  pcall(os.remove, entry_path())
end

local group = vim.api.nvim_create_augroup("ParentNvimRegistry", { clear = true })

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  nested = false,
  callback = write_entry,
})

vim.api.nvim_create_autocmd("DirChanged", {
  group = group,
  callback = write_entry,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = remove_entry,
})

return {}
