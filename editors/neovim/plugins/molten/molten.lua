return {
  {
    "benlubas/molten-nvim",
    lazy = false,
    version = "^1.0.0",
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
    end,
    config = function()
      -- Enable relative line numbers for Quarto files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "quarto",
        group = vim.api.nvim_create_augroup("UserQuartoSettings", { clear = true }),
        callback = function()
          vim.wo.relativenumber = true
        end,
        desc = "Enable relative line numbers for Quarto",
      })

      -- Helper function: Initialize kernel (shows picker)
      local function molten_init()
        vim.cmd("MoltenInit")
        -- Auto-activate Quarto if in a quarto file
        if vim.bo.filetype == "quarto" then
          vim.cmd("QuartoActivate")
        end
      end

      -- Helper functi
      -- Store functions globally for keymap access
      _G.molten_helpers = {
        init = molten_init,
      }
    end,
    keys = {
      -- Kernel Management
      {
        "<leader>ji",
        function()
          _G.molten_helpers.init()
        end,
        desc = "Initialize kernel",
      },
      {
        "<leader>jI",
        ":MoltenInterrupt<CR>",
        desc = "Interrupt kernel",
      },

      -- Evaluate code with operator
      {
        "<leader>jo",
        ":MoltenEvaluateOperator<CR>",
        mode = "n",
        desc = "Evaluate with operator",
      },
      {
        "<leader>jl",
        ":MoltenEvaluateLine<CR>",
        mode = "n",
        desc = "Evaluate line",
      },
      {
        "<leader>jr",
        ":MoltenReevaluateCell<CR>",
        mode = "n",
        desc = "Re-evaluate cell",
      },
      {
        "<leader>jR",
        ":MoltenReevaluateAll<CR>",
        mode = "n",
        desc = "Re-evaluate all cells",
      },
      {
        "<leader>je",
        ":<C-u>MoltenEvaluateVisual<CR>gv",
        mode = "v",
        desc = "Evaluate visual selection",
      },

      -- Cell Navigation
      {
        "<leader>jn",
        ":MoltenNext<CR>",
        desc = "Next cell",
      },
      {
        "<leader>jp",
        ":MoltenPrev<CR>",
        desc = "Previous cell",
      },

      -- Output Management
      {
        "<leader>jO",
        ":noautocmd MoltenEnterOutput<CR>",
        desc = "Show/enter output",
      },
      {
        "<leader>jh",
        ":MoltenHideOutput<CR>",
        desc = "Hide output",
      },

      -- Cell Management
      {
        "<leader>jd",
        ":MoltenDelete<CR>",
        desc = "Delete cell",
      },
      {
        "<leader>jD",
        ":MoltenDelete!<CR>",
        desc = "Delete all cells",
      },
    },
  },
  {
    -- see the image.nvim readme for more information about configuring this plugin
    "3rd/image.nvim",
    opts = {
      backend = "kitty", -- whatever backend you would like to use
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true, -- toggles images when windows are overlapped
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          "<leader>j",
          name = "+jupyter",
          icon = {
            icon = "",
            color = "orange",
          },
          mode = "nv",
        },
      },
    },
  },
}
