local shared_mason_root = vim.fn.expand("~/.local/share/nvim/mason")
local warned_roots = {}

local function course_python(root)
  if type(root) ~= "string" or root == "" then
    return nil
  end

  for _, name in ipairs({ "python", "python3" }) do
    local path = vim.fs.joinpath(root, ".venv", "bin", name)
    if vim.fn.executable(path) == 1 then
      return path
    end
  end
end

local function configure_pyright(event)
  local client = event.data and vim.lsp.get_client_by_id(event.data.client_id)
  if not client or client.name ~= "pyright" then
    return
  end

  local root = client.config.root_dir
  local python = course_python(root)
  if not python then
    if root and not warned_roots[root] then
      warned_roots[root] = true
      vim.notify(("Course Python environment not found: %s/.venv"):format(root), vim.log.levels.WARN)
    end
    return
  end

  client.settings = client.settings or {}
  client.settings.python = vim.tbl_deep_extend("force", client.settings.python or {}, {
    pythonPath = python,
  })
  client:notify("workspace/didChangeConfiguration", { settings = nil })
  vim.b[event.buf].course_python_path = python
end

local function retrigger_otter_python_buffers()
  local ok, keeper = pcall(require, "otter.keeper")
  if not ok then
    return false
  end

  local found = false
  for _, raft in pairs(keeper.rafts) do
    local buffer = raft.buffers and raft.buffers.python
    if buffer and vim.api.nvim_buf_is_valid(buffer) then
      found = true
      vim.api.nvim_exec_autocmds("FileType", {
        buf = buffer,
        modeline = false,
      })
    end
  end
  return found
end

local function watch_mason_installs()
  local registry = require("mason-registry")
  registry:on("package:install:success", function(package)
    if package.name ~= "pyright" and package.name ~= "ruff" then
      return
    end

    vim.defer_fn(function()
      local found = retrigger_otter_python_buffers()
      if found and vim.fn.executable("pyright-langserver") == 1 and vim.fn.executable("ruff") == 1 then
        vim.notify("Python notebook code intelligence is ready", vim.log.levels.INFO)
      end
    end, 100)
  end)
end

local function watch_plugin_load(name, callback)
  local plugin = require("lazy.core.config").plugins[name]
  if plugin and plugin._.loaded then
    callback()
    return
  end

  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyLoad",
    callback = function(event)
      if event.data == name then
        callback()
        return true
      end
    end,
  })
end

return {
  {
    "mason-org/mason.nvim",
    opts = {
      install_root_dir = shared_mason_root,
    },
    init = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("CourseNotebookPython", { clear = true }),
        callback = configure_pyright,
      })
      watch_plugin_load("mason.nvim", watch_mason_installs)
    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = { "pyright", "ruff" },
    },
  },
}
