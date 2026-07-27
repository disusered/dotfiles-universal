local function assert_truthy(value, label)
  if not value then
    error(label, 0)
  end
end

local seed_entry = assert(vim.env.POLYCHROME_NEORG_SEED_ENTRY, "POLYCHROME_NEORG_SEED_ENTRY is required")
local text = table.concat(vim.fn.readfile(seed_entry), "\n")

assert_truthy(text:find("@document.meta", 1, true), "seed has outer metadata")
local _, nested_count = text:gsub("@document%.meta", "")
assert_truthy(nested_count == 2, "seed retains its nested original metadata")

vim.cmd("edit " .. vim.fn.fnameescape(seed_entry))

local parser = vim.treesitter.get_parser(0, "norg")
local tree = parser:parse()[1]
assert_truthy(tree and not tree:root():has_error(), "seed with nested metadata parses as Norg without syntax errors")

local treesitter = assert(require("neorg").modules.get_module("core.integrations.treesitter"))
local metadata = treesitter.get_document_metadata(0)

assert_truthy(
  metadata.polychrome_id == "black:20251107T132035-0800-index",
  "outer polychrome_id survives nested metadata"
)
assert_truthy(metadata.authors == "carlos", "outer author survives nested metadata")
assert_truthy(metadata.visibility == "private", "outer privacy survives nested metadata")

for _, sentinel in ipairs({
  "%polychrome:black-body:start%",
  "%polychrome:black-body:end%",
  "%polychrome:connections:start%",
  "%polychrome:connections:end%",
}) do
  assert_truthy(text:find(sentinel, 1, true), "seed contains exact sentinel " .. sentinel)
end

print("nested seed import parses with canonical Polychrome contract")
