return {
  {
    "benlubas/molten-nvim",
    lazy = false,
    version = "^1.0.0",
    dependencies = {
      "3rd/image.nvim",
      {
        "quarto-dev/quarto-nvim",
        dependencies = {
          "jmbuhr/otter.nvim",
          "nvim-treesitter/nvim-treesitter",
        },
      },
    },
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
    end,
    config = function()
      -- Helper function: Initialize kernel with venv detection
      local function molten_init()
        local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
        if venv ~= nil then
          venv = string.match(venv, "/.+/(.+)")
          vim.cmd(("MoltenInit"):format(venv))
        else
          vim.cmd("MoltenInit python3")
        end
      end

      -- Helper function: Evaluate current code block using treesitter
      local function eval_code_block()
        local ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
        if not ok then
          vim.notify("Treesitter not available, falling back to line evaluation", vim.log.levels.WARN)
          vim.cmd("MoltenEvaluateLine")
          return
        end

        local node = ts_utils.get_node_at_cursor()
        if not node then
          vim.cmd("MoltenEvaluateLine")
          return
        end

        -- Walk up the tree to find a fenced_code_block
        while node do
          local node_type = node:type()
          if node_type == "fenced_code_block" or node_type == "code_block" then
            local start_row, _, end_row, _ = node:range()
            -- Convert from 0-indexed to 1-indexed and exclude fence markers
            -- start_row is the ```{python} line (0-indexed)
            -- end_row is exclusive, pointing just after the closing ```
            local start_line = start_row + 2 -- Skip opening fence
            local end_line = end_row - 1 -- Exclude closing fence

            vim.fn.MoltenEvaluateRange(start_line, end_line)
            return
          end
          node = node:parent()
        end

        -- Fallback to line if no code block found
        vim.notify("No code block found, evaluating current line", vim.log.levels.INFO)
        vim.cmd("MoltenEvaluateLine")
      end

      -- Store functions globally for keymap access
      _G.molten_helpers = {
        init = molten_init,
        eval_block = eval_code_block,
      }
    end,
    -- TODO: https://github.com/quarto-dev/quarto-nvim
    -- TODO: Review Treesitter/block command
    -- TODO: Review keybinds
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
        "<leader>jR",
        ":MoltenRestart<CR>",
        desc = "Restart kernel",
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
        "<leader>jb",
        function()
          _G.molten_helpers.eval_block()
        end,
        mode = "n",
        desc = "Evaluate code block",
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
        "<leader>jr",
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
