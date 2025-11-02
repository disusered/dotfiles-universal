return {
  {
    "benlubas/molten-nvim",
    lazy = false,
    version = "^1.0.0",
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
        "<leader>jI",
        function()
          _G.molten_helpers.init()
        end,
        desc = "Initialize kernel",
        ft = "quarto",
      },
      {
        "<leader>j<esc>",
        ":MoltenInterrupt<CR>",
        desc = "Interrupt kernel",
        ft = "quarto",
      },

      -- Evaluate code with operator
      {
        "<leader>jo",
        ":MoltenEvaluateOperator<CR>",
        mode = "n",
        desc = "Evaluate with operator",
        ft = "quarto",
      },
      {
        "<leader>jl",
        ":MoltenEvaluateLine<CR>",
        mode = "n",
        desc = "Evaluate line",
        ft = "quarto",
      },
      {
        "<leader>jr",
        ":MoltenReevaluateCell<CR>",
        mode = "n",
        desc = "Re-evaluate cell",
        ft = "quarto",
      },
      {
        "<leader>jR",
        ":MoltenReevaluateAll<CR>",
        mode = "n",
        desc = "Re-evaluate all cells",
        ft = "quarto",
      },
      {
        "<leader>je",
        ":<C-u>MoltenEvaluateVisual<CR>gv",
        mode = "v",
        desc = "Evaluate visual selection",
        ft = "quarto",
      },

      -- Cell Navigation
      {
        "<leader>jn",
        ":MoltenNext<CR>",
        desc = "Next cell",
        ft = "quarto",
      },
      {
        "<leader>jp",
        ":MoltenPrev<CR>",
        desc = "Previous cell",
        ft = "quarto",
      },

      -- Output Management
      {
        "<leader>jO",
        ":noautocmd MoltenEnterOutput<CR>",
        desc = "Show/enter output",
        ft = "quarto",
      },
      {
        "<leader>jh",
        ":MoltenHideOutput<CR>",
        desc = "Hide output",
        ft = "quarto",
      },
      {
        "<leader>jx",
        ":MoltenImagePopup<CR>",
        desc = "Open image",
        ft = "quarto",
      },

      -- Cell Management
      {
        "<leader>jd",
        ":MoltenDelete<CR>",
        desc = "Delete cell",
        ft = "quarto",
      },
      {
        "<leader>jD",
        ":MoltenDelete!<CR>",
        desc = "Delete all cells",
        ft = "quarto",
      },
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
