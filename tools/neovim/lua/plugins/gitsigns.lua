return {
  "lewis6991/gitsigns.nvim",
  opts = {
    signs = {
      add = { text = "+" },
      change = { text = "▎" },
      delete = { text = "_" },
      topdelete = { text = "‾" },
      changedelete = { text = "~" },
      untracked = { text = "▎" },
    },
  },

  keys = function()
    local gitsigns = require("gitsigns")
    return {
      {
        "<leader>gw",
        gitsigns.stage_buffer,
        desc = "Stage Buffer",
      },
      {
        "<leader>gr",
        gitsigns.reset_buffer,
        desc = "Reset Buffer",
      },
      {
        "<leader>gI",
        gitsigns.preview_hunk_inline,
        desc = "Preview Hunk Inline",
      },
    }
  end,
}
