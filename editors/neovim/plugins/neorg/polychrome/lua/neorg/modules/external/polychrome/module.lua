local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("external.polychrome")

local BODY_START = "%polychrome:black-body:start%"
local BODY_END = "%polychrome:black-body:end%"
local CONNECTIONS_START = "%polychrome:connections:start%"
local CONNECTIONS_END = "%polychrome:connections:end%"

local function canonical_path(path, label)
  local uv = vim.uv or vim.loop
  local resolved, resolve_error = uv.fs_realpath(path)

  if not resolved then
    error(("unable to resolve %s %q: %s"):format(label, path, resolve_error or "unknown error"))
  end

  return resolved
end

local function is_within(root, target)
  if target == root then
    return true
  end

  return target:sub(1, #root + 1) == root .. "/"
end

local function ensure_private_directory(parent, name, workspace_root)
  local uv = vim.uv or vim.loop
  local path = parent .. "/" .. name
  local existing, lstat_error, lstat_error_name = uv.fs_lstat(path)

  if existing then
    if existing.type == "link" then
      error(("Black entry directory component must not be a symlink: %q"):format(path))
    end

    if existing.type ~= "directory" then
      error(("Black entry directory component is not a directory: %q"):format(path))
    end
  elseif lstat_error_name == "ENOENT" or tostring(lstat_error):find("ENOENT", 1, true) then
    local created, mkdir_error = uv.fs_mkdir(path, 448)

    if not created then
      error(("unable to create private Black entry directory %q: %s"):format(path, mkdir_error or "unknown error"))
    end
  else
    error(("unable to inspect Black entry directory %q: %s"):format(path, lstat_error or "unknown error"))
  end

  local node, node_error = uv.fs_lstat(path)

  if not node or node.type ~= "directory" then
    error(("Black entry directory component changed unexpectedly %q: %s"):format(path, node_error or "not a directory"))
  end

  local resolved = canonical_path(path, "Black entry directory")
  local stat, stat_error = uv.fs_stat(resolved)

  if not stat or stat.type ~= "directory" then
    error(("Black entry path %q is not a directory: %s"):format(path, stat_error or stat and stat.type or "missing"))
  end

  if not is_within(workspace_root, resolved) then
    error(("Black entry directory escapes configured workspace: %q resolves to %q"):format(path, resolved))
  end

  return resolved
end

local function validate_author(author)
  if type(author) ~= "string" or author == "" or author:find("[%c]") then
    error("Black entry author must be a non-empty, single-line string without control characters")
  end
end

local function timestamp_parts(epoch)
  return {
    day_path = os.date("%Y/%m/%d", epoch),
    filename = os.date("%H%M%S", epoch),
    id = os.date("%Y%m%dT%H%M%S%z", epoch),
    title = os.date("%Y-%m-%d %H:%M:%S", epoch),
    metadata = os.date("%Y-%m-%dT%H:%M:%S%z", epoch),
  }
end

local function entry_lines(parts, suffix)
  local suffix_text = suffix == 0 and "" or ("-%02d"):format(suffix)
  local id = ("black:%s%s"):format(parts.id, suffix_text)

  local lines = {
    "@document.meta",
    "polychrome_id: " .. id,
    "title: Black " .. parts.title,
    "authors: " .. module.config.public.author,
    "categories: [",
    "]",
    "created: " .. parts.metadata,
    "updated: " .. parts.metadata,
    "visibility: private",
    "version: " .. module.public.version,
    "@end",
    "",
    BODY_START,
    "",
    BODY_END,
    "",
    "* Connections",
    "",
    CONNECTIONS_START,
    CONNECTIONS_END,
    "",
  }

  return lines, id
end

local function write_exclusive(path, lines, workspace_root)
  local uv = vim.uv or vim.loop
  local fd, open_error, open_error_name = uv.fs_open(path, "wx", 384)

  if not fd then
    if open_error_name == "EEXIST" or tostring(open_error):find("EEXIST", 1, true) then
      return false, "exists"
    end

    return false, open_error or "unable to create entry"
  end

  local content = table.concat(lines, "\n")
  local bytes_written, write_error = uv.fs_write(fd, content, 0)
  local sync_ok, sync_error = uv.fs_fsync(fd)
  local close_ok, close_error = uv.fs_close(fd)

  if bytes_written ~= #content or not sync_ok or not close_ok then
    uv.fs_unlink(path)
    return false, write_error or sync_error or close_error or "short write"
  end

  local node, node_error = uv.fs_lstat(path)

  if not node or node.type ~= "file" then
    uv.fs_unlink(path)
    return false, node_error or "new Black entry is not a regular file"
  end

  local resolved, resolve_error = uv.fs_realpath(path)

  if not resolved or not is_within(workspace_root, resolved) then
    uv.fs_unlink(path)
    return false,
      resolve_error or ("new Black entry escapes configured workspace: %q resolves to %q"):format(path, resolved)
  end

  return true
end

local function place_cursor_in_body()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  for index, line in ipairs(lines) do
    if line == BODY_START then
      vim.api.nvim_win_set_cursor(0, { index + 1, 0 })
      return
    end
  end

  error("new Black entry is missing its human-body sentinel")
end

module.setup = function()
  return {
    success = true,
    requires = {
      "core.dirman",
      "core.neorgcmd",
    },
  }
end

module.config.public = {
  workspace = "black",
  black_root = "~/Development/ME/herding-cats/black",
  author = "carlos",
  start_insert = true,
  clock = os.time,
}

module.public.new_black_fragment = function()
  local dirman = module.required["core.dirman"]
  local workspace = dirman.get_workspace(module.config.public.workspace)

  if not workspace then
    error(("Neorg workspace %q is not configured"):format(module.config.public.workspace))
  end

  if not dirman.set_workspace(module.config.public.workspace) then
    error(("unable to activate Neorg workspace %q"):format(module.config.public.workspace))
  end

  validate_author(module.config.public.author)

  local configured_root = vim.fn.fnamemodify(vim.fn.expand(module.config.public.black_root), ":p")
  local workspace_root = canonical_path(tostring(workspace), "Neorg Black workspace")
  local expected_root = canonical_path(configured_root, "configured Black root")

  if workspace_root ~= expected_root then
    error(
      ("Neorg workspace %q resolves to %q, not configured Black root %q"):format(
        module.config.public.workspace,
        workspace_root,
        expected_root
      )
    )
  end

  local parts = timestamp_parts(module.config.public.clock())
  local directory = ensure_private_directory(workspace_root, "entries", workspace_root)

  for component in parts.day_path:gmatch("[^/]+") do
    directory = ensure_private_directory(directory, component, workspace_root)
  end

  local suffix = 0

  while true do
    local suffix_text = suffix == 0 and "" or ("-%02d"):format(suffix)
    local path = ("%s/%s%s.norg"):format(directory, parts.filename, suffix_text)
    local lines, id = entry_lines(parts, suffix)
    local created, reason = write_exclusive(path, lines, workspace_root)

    if created then
      vim.cmd("edit " .. vim.fn.fnameescape(path))
      place_cursor_in_body()

      if module.config.public.start_insert then
        vim.cmd.startinsert()
      end

      return {
        id = id,
        path = path,
        body_line = vim.api.nvim_win_get_cursor(0)[1],
      }
    end

    if reason ~= "exists" then
      error(("unable to create Black entry %s: %s"):format(path, reason))
    end

    suffix = suffix + 1
  end
end

module.load = function()
  module.required["core.neorgcmd"].add_commands_from_table({
    polychrome = {
      subcommands = {
        black = {
          subcommands = {
            new = {
              args = 0,
              name = "polychrome.black.new",
            },
          },
        },
      },
    },
  })
end

module.on_event = function(event)
  if event.type ~= "core.neorgcmd.events.polychrome.black.new" then
    return
  end

  local ok, result = pcall(module.public.new_black_fragment)

  if not ok then
    vim.notify("Unable to create Black fragment: " .. result, vim.log.levels.ERROR)
  end
end

module.events.subscribed = {
  ["core.neorgcmd"] = {
    ["polychrome.black.new"] = true,
  },
}

return module
