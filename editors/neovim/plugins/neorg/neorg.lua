return {
  {
    "nvim-neorg/neorg",
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
        },
      })
    end,
    keys = {
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
    },
  },

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
}
