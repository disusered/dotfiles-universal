return {
  {
    "dhruvasagar/vim-table-mode",
    ft = { "markdown", "norg", "quarto" },
    init = function()
      -- Disable all built-in mappings
      vim.g.table_mode_disable_mappings = 1
      vim.g.table_mode_disable_tableize_mappings = 1

      -- Table formatting options
      vim.g.table_mode_corner = "|"
      vim.g.table_mode_corner_corner = "|"
      vim.g.table_mode_header_fillchar = "="
      vim.g.table_mode_align_char = ":"
      vim.g.table_mode_auto_align = 1

      -- Register Snacks.toggle for table mode
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          require("snacks").toggle
            .new({
              name = "Table Mode",
              get = function()
                return vim.fn["tablemode#IsActive"]() == 1
              end,
              set = function(enabled)
                if enabled then
                  vim.cmd("TableModeEnable")
                else
                  vim.cmd("TableModeDisable")
                end
              end,
            })
            :map("<leader>ctt")
        end,
      })
    end,
    keys = {
      -- Realign
      {
        "<leader>ctr",
        "<cmd>TableModeRealign<CR>",
        desc = "Realign table",
        ft = { "markdown", "norg", "quarto" },
      },
      -- Sort
      {
        "<leader>cts",
        "<cmd>TableSort<CR>",
        desc = "Sort by column",
        ft = { "markdown", "norg", "quarto" },
      },
      -- Tableize (visual)
      {
        "<leader>ctc",
        "<cmd>Tableize<CR>",
        desc = "Convert to table",
        mode = "v",
        ft = { "markdown", "norg", "quarto" },
      },
      -- Motions
      {
        "[|",
        "<cmd>call tablemode#spreadsheet#cell#Motion('h')<CR>",
        desc = "Previous cell",
        ft = { "markdown", "norg", "quarto" },
      },
      {
        "]|",
        "<cmd>call tablemode#spreadsheet#cell#Motion('l')<CR>",
        desc = "Next cell",
        ft = { "markdown", "norg", "quarto" },
      },
      {
        "{|",
        "<cmd>call tablemode#spreadsheet#cell#Motion('k')<CR>",
        desc = "Cell above",
        ft = { "markdown", "norg", "quarto" },
      },
      {
        "}|",
        "<cmd>call tablemode#spreadsheet#cell#Motion('j')<CR>",
        desc = "Cell below",
        ft = { "markdown", "norg", "quarto" },
      },
      -- Text objects
      {
        "a|",
        "<cmd>call tablemode#spreadsheet#cell#TextObject(0)<CR>",
        desc = "Around cell",
        mode = { "o", "x" },
        ft = { "markdown", "norg", "quarto" },
      },
      {
        "i|",
        "<cmd>call tablemode#spreadsheet#cell#TextObject(1)<CR>",
        desc = "Inner cell",
        mode = { "o", "x" },
        ft = { "markdown", "norg", "quarto" },
      },
    },
  },
  -- WhichKey group definition
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>ct", name = "+table", icon = { icon = "󰓫", color = "cyan" } },
      },
    },
  },
}
