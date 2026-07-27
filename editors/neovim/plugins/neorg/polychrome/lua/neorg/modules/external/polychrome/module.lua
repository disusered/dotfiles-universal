local neorg = require("neorg.core")
local modules = neorg.modules

local module = modules.create("external.polychrome")

local BODY_START = "%polychrome:black-body:start%"
local BODY_END = "%polychrome:black-body:end%"
local CONNECTIONS_START = "%polychrome:connections:start%"
local CONNECTIONS_END = "%polychrome:connections:end%"
local PRIVATE_DIRECTORY_MODE = 448
local PRIVATE_FILE_MODE = 384
local PERMISSION_MASK = 511

local function absolute_path(path)
  local expanded = vim.fn.fnamemodify(vim.fn.expand(path), ":p")

  if expanded ~= "/" then
    expanded = expanded:gsub("/+$", "")
  end

  return expanded
end

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

local function same_node(left, right)
  return left
    and right
    and left.dev == right.dev
    and left.ino == right.ino
    and left.type == right.type
end

local function harden_private_directory(path, label, workspace_root)
  local uv = vim.uv or vim.loop
  local named, lstat_error = uv.fs_lstat(path)

  if not named then
    error(("unable to inspect %s %q: %s"):format(label, path, lstat_error or "unknown error"))
  end

  if named.type == "link" then
    error(("%s must not be a symlink: %q"):format(label, path))
  end

  if named.type ~= "directory" then
    error(("%s is not a directory: %q"):format(label, path))
  end

  local resolved = canonical_path(path, label)

  if workspace_root and not is_within(workspace_root, resolved) then
    error(("%s escapes configured workspace: %q resolves to %q"):format(label, path, resolved))
  end

  local fd, open_error = uv.fs_open(path, "r", 0)

  if not fd then
    error(("unable to open %s %q securely: %s"):format(label, path, open_error or "unknown error"))
  end

  local opened, fstat_error = uv.fs_fstat(fd)

  if not opened or not same_node(named, opened) then
    uv.fs_close(fd)
    error(("%s changed while it was being opened: %q (%s)"):format(label, path, fstat_error or "identity mismatch"))
  end

  local chmod_ok, chmod_error = uv.fs_fchmod(fd, PRIVATE_DIRECTORY_MODE)
  local hardened, hardened_error = uv.fs_fstat(fd)
  local close_ok, close_error = uv.fs_close(fd)

  if not chmod_ok then
    error(("unable to restrict %s %q to 0700: %s"):format(label, path, chmod_error or "unknown error"))
  end

  if not hardened or bit.band(hardened.mode, PERMISSION_MASK) ~= PRIVATE_DIRECTORY_MODE then
    error(("%s did not retain mode 0700: %q (%s)"):format(label, path, hardened_error or "unsafe mode"))
  end

  if not close_ok then
    error(("unable to close %s %q after permission hardening: %s"):format(label, path, close_error or "unknown error"))
  end

  local final_named, final_error = uv.fs_lstat(path)

  if not final_named or final_named.type == "link" or not same_node(named, final_named) then
    error(("%s changed while permissions were hardened: %q (%s)"):format(label, path, final_error or "identity mismatch"))
  end

  if bit.band(final_named.mode, PERMISSION_MASK) ~= PRIVATE_DIRECTORY_MODE then
    error(("%s must have mode 0700: %q"):format(label, path))
  end

  if canonical_path(path, label) ~= resolved then
    error(("%s changed canonical identity while permissions were hardened: %q"):format(label, path))
  end

  return resolved
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
    local created, mkdir_error = uv.fs_mkdir(path, PRIVATE_DIRECTORY_MODE)

    if not created then
      error(("unable to create private Black entry directory %q: %s"):format(path, mkdir_error or "unknown error"))
    end
  else
    error(("unable to inspect Black entry directory %q: %s"):format(path, lstat_error or "unknown error"))
  end

  return harden_private_directory(path, "Black entry directory component", workspace_root)
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
  local fd, open_error, open_error_name = uv.fs_open(path, "wx", PRIVATE_FILE_MODE)

  if not fd then
    if open_error_name == "EEXIST" or tostring(open_error):find("EEXIST", 1, true) then
      return false, "exists"
    end

    return false, open_error or "unable to create entry"
  end

  local chmod_ok, chmod_error = uv.fs_fchmod(fd, PRIVATE_FILE_MODE)

  if not chmod_ok then
    uv.fs_close(fd)
    uv.fs_unlink(path)
    return false, chmod_error or "unable to restrict new Black entry to 0600"
  end

  local content = table.concat(lines, "\n")
  local bytes_written, write_error = uv.fs_write(fd, content, 0)
  local sync_ok, sync_error = uv.fs_fsync(fd)
  local opened, fstat_error = uv.fs_fstat(fd)
  local close_ok, close_error = uv.fs_close(fd)

  if
    bytes_written ~= #content
    or not sync_ok
    or not opened
    or opened.type ~= "file"
    or bit.band(opened.mode, PERMISSION_MASK) ~= PRIVATE_FILE_MODE
    or not close_ok
  then
    uv.fs_unlink(path)
    return false, write_error
      or sync_error
      or fstat_error
      or close_error
      or "new Black entry did not retain mode 0600"
  end

  local node, node_error = uv.fs_lstat(path)

  if
    not node
    or node.type ~= "file"
    or not same_node(opened, node)
    or bit.band(node.mode, PERMISSION_MASK) ~= PRIVATE_FILE_MODE
  then
    uv.fs_unlink(path)
    return false, node_error or "new Black entry is not the private regular file that was created"
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

  validate_author(module.config.public.author)

  local configured_root = absolute_path(module.config.public.black_root)
  local workspace_path = absolute_path(tostring(workspace))
  local expected_root = harden_private_directory(configured_root, "configured Black root")
  local workspace_root = harden_private_directory(workspace_path, "Neorg Black workspace")

  if workspace_root ~= expected_root then
    error(
      ("Neorg workspace %q resolves to %q, not configured Black root %q"):format(
        module.config.public.workspace,
        workspace_root,
        expected_root
      )
    )
  end

  if not dirman.set_workspace(module.config.public.workspace) then
    error(("unable to activate Neorg workspace %q"):format(module.config.public.workspace))
  end

  workspace_root = harden_private_directory(workspace_path, "Neorg Black workspace")

  if workspace_root ~= expected_root then
    error(("Neorg Black workspace changed while it was activated: %q"):format(workspace_path))
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
