return {
  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerOpen",
      "OverseerClose",
      "OverseerToggle",
      "OverseerSaveBundle",
      "OverseerLoadBundle",
      "OverseerDeleteBundle",
      "OverseerRunCmd",
      "OverseerRun",
      "OverseerInfo",
      "OverseerBuild",
      "OverseerQuickAction",
      "OverseerTaskAction",
      "OverseerClearCache",
    },
    opts = {
      dap = false,
      task_list = {
        bindings = {
          ["<C-h>"] = false,
          ["<C-j>"] = false,
          ["<C-k>"] = false,
          ["<C-l>"] = false,
        },
      },
      form = {
        win_opts = {
          winblend = 0,
        },
      },
      confirm = {
        win_opts = {
          winblend = 0,
        },
      },
      task_win = {
        win_opts = {
          winblend = 0,
        },
      },
    },
    keys = {
      { "<leader>rw", "<cmd>OverseerToggle<cr>", desc = "Task list" },
      { "<leader>ro", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>rq", "<cmd>OverseerQuickAction<cr>", desc = "Action recent task" },
      { "<leader>ri", "<cmd>OverseerInfo<cr>", desc = "Overseer Info" },
      { "<leader>rb", "<cmd>OverseerBuild<cr>", desc = "Task builder" },
      { "<leader>rt", "<cmd>OverseerTaskAction<cr>", desc = "Task action" },
      { "<leader>rc", "<cmd>OverseerClearCache<cr>", desc = "Clear cache" },
    },
  },
  {
    "catppuccin",
    optional = true,
    opts = {
      integrations = { overseer = true },
    },
    {
      "folke/which-key.nvim",
      optional = true,
      opts = {
        spec = {
          { "<leader>r", group = "overseer" },
        },
      },
    },
    {
      "folke/edgy.nvim",
      optional = true,
      opts = function(_, opts)
        opts.right = opts.right or {}
        table.insert(opts.right, {
          title = "Overseer",
          ft = "OverseerList",
          open = function()
            require("overseer").open()
          end,
        })
      end,
    },
    {
      "nvim-neotest/neotest",
      optional = true,
      opts = function(_, opts)
        opts = opts or {}
        opts.consumers = opts.consumers or {}
        opts.consumers.overseer = require("neotest.consumers.overseer")
      end,
    },
    {
      "mfussenegger/nvim-dap",
      optional = true,
      opts = function()
        require("overseer").enable_dap()
      end,
    },
  },
}
