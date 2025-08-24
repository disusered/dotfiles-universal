return {
  "stevearc/quicker.nvim",
  event = "FileType qf",
  ---@module "quicker"
  ---@type quicker.SetupOptions
  opts = {},
  -- FIXME: keymaps that dont conflict with other plugins
  keys = {
    -- {
    --   ">",
    --   function()
    --     require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
    --   end,
    --   desc = "Expand quickfix context",
    -- },
    -- {
    --   "<",
    --   function()
    --     require("quicker").collapse()
    --   end,
    --   desc = "Collapse quickfix context",
    -- },
  },
}
