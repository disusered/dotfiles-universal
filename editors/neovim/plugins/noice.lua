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
      -- Disable all LSP progress messages
      {
        filter = {
          event = "lsp",
          kind = "progress",
        },
        opts = { skip = true },
      },
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
      -- Send DBUI "Executing query..." to mini, suppress result notifications
      {
        filter = {
          event = "notify",
          find = "Executing query",
        },
        view = "mini",
      },
      {
        filter = {
          event = "notify",
          find = "Done after",
        },
        view = "mini",
      },
      {
        filter = {
          event = "notify",
          find = "Connecting to db",
        },
        view = "mini",
      },
      {
        filter = {
          event = "notify",
          find = "Connected to db",
        },
        view = "mini",
      },
      {
        filter = {
          event = "notify",
          find = "Refreshing",
        },
        view = "mini",
      },
      {
        filter = {
          event = "notify",
          find = "Refreshed",
        },
        opts = { skip = true },
      },
      {
        filter = {
          event = "msg_show",
          find = "DB: Query",
        },
        opts = { skip = true },
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
