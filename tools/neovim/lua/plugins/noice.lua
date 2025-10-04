return {
  "folke/noice.nvim",
  enabled = true,
  opts = {
    -- Don't auto open the signature help window
    lsp_signature = {
      auto_open = { enabled = false },
    },
    -- Use bottom cmdline instead of floating window
    cmdline = {
      enabled = true,
      view = "cmdline",
    },
    messages = {
      enabled = true,
    },
    presets = {
      -- Don't use Noice's rename prompt
      inc_rename = false,
    },
    routes = {
      {
        filter = {
          event = "notify",
          find = "^🤖",
        },
        view = "mini",
      },
      {
        filter = {
          event = "msg_show",
          find = "^🤖",
        },
        view = "mini",
      },
      -- Send docker-compose DB notifications to mini view
      {
        filter = {
          event = "msg_show",
          find = "docker%-compose%.yml",
        },
        view = "mini",
      },
      {
        filter = {
          event = "notify",
          find = "docker%-compose%.yml",
        },
        view = "mini",
      },
      -- Send long print messages to popup view
      {
        filter = {
          event = "msg_show",
          min_height = 10,
        },
        view = "popup",
      },
    },
  },
  keys = {
    {
      "<leader>cP",
      function()
        vim.lsp.buf.signature_help()
      end,
      desc = "Parameter help",
    },
  },
}
