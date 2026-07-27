local function fail(message)
  error(message, 0)
end

local function assert_equal(expected, actual, label)
  if expected ~= actual then
    fail(("%s: expected %q, got %q"):format(label, expected, actual))
  end
end

local function assert_truthy(value, label)
  if not value then
    fail(label)
  end
end

local module = assert(require("neorg").modules.get_module("external.polychrome"))
local module_state = assert(require("neorg.core").modules.loaded_modules["external.polychrome"])
local module_config = module_state.config.public
local dirman = assert(require("neorg").modules.get_module("core.dirman"))
local uv = vim.uv or vim.loop
local test_root = assert(vim.env.POLYCHROME_NEORG_TEST_ROOT)
local first = module.new_black_fragment()
local second = module.new_black_fragment()

assert_truthy(first.path:match("/black/entries/2026/07/26/123456%.norg$"), "first path has the expected chronology")
assert_truthy(second.path:match("/black/entries/2026/07/26/123456%-01%.norg$"), "collision receives -01 suffix")
assert_truthy(vim.uv.fs_stat(first.path), "first entry exists")
assert_truthy(vim.uv.fs_stat(second.path), "second entry exists")
assert_equal("rw-------", vim.fn.getfperm(first.path), "Black entries are private")
assert_equal("rwx------", vim.fn.getfperm(test_root .. "/black"), "Black workspace root is private")

for _, directory in ipairs({
  test_root .. "/black/entries",
  test_root .. "/black/entries/2026",
  test_root .. "/black/entries/2026/07",
  test_root .. "/black/entries/2026/07/26",
}) do
  assert_equal("rwx------", vim.fn.getfperm(directory), "new Black directory is private")
end

local lines = vim.fn.readfile(first.path)
local text = table.concat(lines, "\n")

assert_truthy(text:find("@document.meta", 1, true), "metadata tag exists")
assert_truthy(text:find("polychrome_id: black:20260726T123456", 1, true), "stable ID exists")
assert_truthy(text:find("authors: carlos", 1, true), "author exists")
assert_truthy(text:find("categories: [\n]", 1, true), "categories list exists")
assert_truthy(text:find("visibility: private", 1, true), "private visibility exists")
assert_truthy(text:find("%polychrome:black-body:start%", 1, true), "body start sentinel exists")
assert_truthy(text:find("%polychrome:black-body:end%", 1, true), "body end sentinel exists")
assert_truthy(text:find("%polychrome:connections:start%", 1, true), "connections start sentinel exists")
assert_truthy(text:find("%polychrome:connections:end%", 1, true), "connections end sentinel exists")

local treesitter = assert(require("neorg").modules.get_module("core.integrations.treesitter"))
local metadata = treesitter.get_document_metadata(first.path)
assert_truthy(metadata.polychrome_id:match("^black:20260726T123456"), "Norg metadata parser reads stable ID")
assert_equal("carlos", metadata.authors, "Norg metadata parser reads author")
assert_equal("private", metadata.visibility, "Norg metadata parser reads visibility")
assert_truthy(
  type(metadata.categories) == "table" and vim.tbl_isempty(metadata.categories),
  "categories parse as an empty list"
)

assert_equal(second.path, vim.api.nvim_buf_get_name(0), "new entry is current buffer")
assert_equal(14, vim.api.nvim_win_get_cursor(0)[1], "cursor is on the blank human-body line")

local command = vim.fn.execute("command Neorg")
assert_truthy(command:find("Neorg", 1, true), ":Neorg command exists")

vim.cmd("Neorg polychrome black new")
local third = vim.api.nvim_buf_get_name(0)
assert_truthy(third:match("/black/entries/2026/07/26/123456%-02%.norg$"), ":Neorg command dispatches to capture")

local parser = vim.treesitter.get_parser(0, "norg")
local tree = parser:parse()[1]
assert_truthy(tree and not tree:root():has_error(), "generated entry parses as Norg without syntax errors")

local original_workspace = module_config.workspace
local original_root = module_config.black_root
local original_author = module_config.author

module_config.author = "carlos\n@end"
local malicious_author_ok, malicious_author_error = pcall(module.new_black_fragment)
assert_truthy(not malicious_author_ok, "multiline author is rejected")
assert_truthy(
  tostring(malicious_author_error):find("single-line", 1, true),
  "malicious author rejection explains the constraint"
)
assert_truthy(
  not uv.fs_stat(test_root .. "/black/entries/2026/07/26/123456-03.norg"),
  "rejected author creates no file"
)
module_config.author = original_author

local function mkdir_with_mode(path, mode)
  local created, mkdir_error = uv.fs_mkdir(path, mode)
  assert_truthy(created, ("create test directory %s: %s"):format(path, mkdir_error or "unknown error"))
end

local function mkdir_private(path)
  mkdir_with_mode(path, 448)
end

local function configure_workspace(name, root)
  assert_truthy(dirman.add_workspace(name, root), "add isolated escape-test workspace")
  module_config.workspace = name
  module_config.black_root = root
end

local existing_root = test_root .. "/black-existing-modes"
mkdir_with_mode(existing_root, 493)
local existing_directory = existing_root

for _, component in ipairs({ "entries", "2026", "07", "26" }) do
  existing_directory = existing_directory .. "/" .. component
  mkdir_with_mode(existing_directory, 493)
end

configure_workspace("black_existing_modes", existing_root)
local existing_modes_entry = module.new_black_fragment()
assert_equal("rw-------", vim.fn.getfperm(existing_modes_entry.path), "entry in existing chronology is private")

local hardened_directory = existing_root

for _, component in ipairs({ "entries", "2026", "07", "26" }) do
  assert_equal("rwx------", vim.fn.getfperm(hardened_directory), "pre-existing Black directory is restricted")
  hardened_directory = hardened_directory .. "/" .. component
end

assert_equal("rwx------", vim.fn.getfperm(existing_directory), "pre-existing chronology leaf is restricted")

local symlink_root_target = test_root .. "/black-root-target"
local symlink_root = test_root .. "/black-root-link"
mkdir_private(symlink_root_target)
local linked_root, linked_root_error = uv.fs_symlink(symlink_root_target, symlink_root, { dir = true })
assert_truthy(linked_root, "create Black root symlink: " .. tostring(linked_root_error))
configure_workspace("black_root_symlink", symlink_root)

local symlink_root_ok, symlink_root_capture_error = pcall(module.new_black_fragment)
assert_truthy(not symlink_root_ok, "symlinked Black root is rejected")
assert_truthy(
  tostring(symlink_root_capture_error):find("must not be a symlink", 1, true),
  "symlinked Black root reports the privacy boundary"
)
assert_truthy(not uv.fs_stat(symlink_root_target .. "/entries"), "symlinked Black root creates nothing in its target")

local entries_root = test_root .. "/black-entries-escape"
local entries_outside = test_root .. "/entries-outside"
mkdir_private(entries_root)
mkdir_private(entries_outside)
local linked_entries, linked_entries_error = uv.fs_symlink(entries_outside, entries_root .. "/entries", { dir = true })
assert_truthy(linked_entries, "create entries escape symlink: " .. tostring(linked_entries_error))
configure_workspace("black_entries_escape", entries_root)

local entries_escape_ok, entries_escape_error = pcall(module.new_black_fragment)
assert_truthy(not entries_escape_ok, "symlinked entries directory is rejected")
assert_truthy(tostring(entries_escape_error):find("must not be a symlink", 1, true), "entries escape reports symlink")
assert_truthy(not uv.fs_stat(entries_outside .. "/2026"), "entries escape creates nothing outside Black")

local date_root = test_root .. "/black-date-escape"
local date_outside = test_root .. "/date-outside"
mkdir_private(date_root)
mkdir_private(date_root .. "/entries")
mkdir_private(date_root .. "/entries/2026")
mkdir_private(date_outside)
local linked_date, linked_date_error = uv.fs_symlink(date_outside, date_root .. "/entries/2026/07", { dir = true })
assert_truthy(linked_date, "create date escape symlink: " .. tostring(linked_date_error))
configure_workspace("black_date_escape", date_root)

local date_escape_ok, date_escape_error = pcall(module.new_black_fragment)
assert_truthy(not date_escape_ok, "symlinked date directory is rejected")
assert_truthy(tostring(date_escape_error):find("must not be a symlink", 1, true), "date escape reports symlink")
assert_truthy(not uv.fs_stat(date_outside .. "/26"), "date escape creates nothing outside Black")

module_config.workspace = original_workspace
module_config.black_root = original_root
module_config.author = original_author

print("polychrome Neorg capture tests passed")
