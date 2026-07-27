local temp_root = assert(vim.env.POLYCHROME_NEORG_TEST_ROOT, "POLYCHROME_NEORG_TEST_ROOT is required")
local module_root = assert(vim.env.POLYCHROME_NEORG_MODULE_ROOT, "POLYCHROME_NEORG_MODULE_ROOT is required")

vim.opt.runtimepath:prepend("/home/carlos/.local/share/nvim/lazy/nvim-treesitter")
vim.opt.runtimepath:prepend("/home/carlos/.local/share/nvim/lazy/neorg")
vim.opt.runtimepath:prepend(module_root)

local rocks = "/home/carlos/.local/share/nvim/lazy-rocks/neorg"
package.path = table.concat({
  rocks .. "/share/lua/5.1/?.lua",
  rocks .. "/share/lua/5.1/?/init.lua",
  package.path,
}, ";")
package.cpath = table.concat({
  rocks .. "/lib/lua/5.1/?.so",
  package.cpath,
}, ";")

require("neorg").setup({
  lazy_loading = false,
  load = {
    ["core.defaults"] = {},
    ["core.dirman"] = {
      config = {
        workspaces = {
          black = temp_root .. "/black",
        },
        default_workspace = "black",
      },
    },
    ["external.polychrome"] = {
      config = {
        workspace = "black",
        black_root = temp_root .. "/black",
        author = "carlos",
        start_insert = false,
        clock = function()
          return os.time({
            year = 2026,
            month = 7,
            day = 26,
            hour = 12,
            min = 34,
            sec = 56,
          })
        end,
      },
    },
  },
})
