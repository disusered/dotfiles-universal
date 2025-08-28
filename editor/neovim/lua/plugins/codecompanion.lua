-- TODO: MCPhub
-- https://codecompanion.olimorris.dev/installation.html#installing-extensions

-- TODO: ACP
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      -- NOTE: The log_level is in `opts.opts`
      opts = {
        log_level = "DEBUG", -- or "TRACE"
      },
    },
  },
  -- Enable completion with blink
  -- https://codecompanion.olimorris.dev/installation.html#completion
  {
    "saghen/blink.cmp",
    dependencies = {
      "olimorris/codecompanion.nvim",
    },
    opts = {
      sources = {
        per_filetype = {
          codecompanion = { "codecompanion" },
        },
      },
    },
  },
  -- Preview markdown with codecompanion
  -- https://codecompanion.olimorris.dev/installation.html#render-markdown-nvim
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = {
      -- "markdown",
      "codecompanion",
    },
  },
  -- TODO: Paste images
  -- https://codecompanion.olimorris.dev/installation.html#img-clip-nvim
}
