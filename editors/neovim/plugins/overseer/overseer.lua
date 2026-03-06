return {
  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerOpen",
      "OverseerClose",
      "OverseerToggle",
      "OverseerRun",
      "OverseerShell",
      "OverseerTaskAction",
    },
    opts = {
      dap = false,
      task_list = {
        direction = "right",
        keymaps = {
          ["<C-h>"] = false,
          ["<C-j>"] = false,
          ["<C-k>"] = false,
          ["<C-l>"] = false,
          ["<C-n>"] = "NextTask",
          ["<C-p>"] = "PrevTask",
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
      { "<leader>W", "<cmd>OverseerToggle<cr>", desc = "Task list" },
      { "<leader>rw", "<cmd>OverseerToggle<cr>", desc = "Task list" },
      { "<leader>ro", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>rt", "<cmd>OverseerTaskAction<cr>", desc = "Task action" },
      {
        "<leader>rq",
        function()
          local overseer = require("overseer")
          local tasks = overseer.list_tasks({ recent_first = true })
          if tasks[1] then
            overseer.run_action(tasks[1])
          end
        end,
        desc = "Action recent task",
      },
      {
        "<leader>rc",
        function()
          require("overseer").clear_task_cache()
          vim.notify("Overseer cache cleared", vim.log.levels.INFO)
        end,
        desc = "Clear cache",
      },
    },
  },
  {
    "catppuccin",
    optional = true,
    opts = {
      integrations = { overseer = true },
    },
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
        pinned = true,
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
}
