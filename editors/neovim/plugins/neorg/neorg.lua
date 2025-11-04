return {
  {
    "nvim-neorg/neorg",
    dependencies = { "benlubas/neorg-interim-ls" },
    lazy = false,
    version = false,
    config = function()
      require("neorg").setup({
        load = {
          ["core.defaults"] = {},
          ["core.concealer"] = {},
          ["core.dirman"] = {
            config = {
              workspaces = {
                notes = "~/Documents/notes",
              },
              default_workspace = "notes",
            },
          },
          ["core.completion"] = {
            config = {
              engine = "nvim-cmp",
              name = "neorg",
            },
          },
        },
      })
    end,
    keys = {
      -- Neorg command picker
      {
        "<leader>oo",
        function()
          local items = {
            { idx = 1, text = "Index: Open Workspace", action = ":Neorg index" },
            { idx = 2, text = "Workspace: Query Current", action = ":Neorg workspace" },
            { idx = 3, text = "Toggle Concealer", action = ":Neorg toggle-concealer" },
          }

          Snacks.picker({
            title = "Neorg Commands",
            layout = { preset = "default", preview = false },
            items = items,
            format = function(item)
              return { { item.text } }
            end,
            confirm = function(picker, item)
              picker:close()
              vim.cmd(item.action:sub(2))
            end,
          })
        end,
        desc = "Neorg Commands",
      },
      -- Show outline
      {
        "<leader>os",
        ":Neorg toc right<CR>",
        desc = "Table of contents",
      },
      -- Inject metadata
      {
        "<leader>oi",
        ":Neorg inject-metadata<CR>",
        desc = "Inject metadata",
      },
    },
  },

  -- Set icon and text for group
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          "<leader>o",
          name = "+org",
          icon = {
            icon = " ",
            color = "red",
          },
          mode = "nv",
        },
      },
    },
  },

  -- Autocomplete using blink.compat
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        -- enable new provider
        default = { "neorg" },

        providers = {
          -- create provider
          neorg = {
            name = "neorg",
            module = "blink.compat.source",
          },
        },
      },
    },
  },
}
