return {
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },
    init = function()
      vim.g.db_ui_use_nvim_notify = 1
      require("config.dadbod.main").setup()

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "dbui",
        callback = function()
          local del = vim.keymap.del
          for _, key in ipairs({ "<C-j>", "<C-k>" }) do
            pcall(del, "n", key, { buffer = 0 })
          end
        end,
      })
    end,
  },
  {
    "folke/edgy.nvim",
    optional = true,
    opts = function(_, opts)
      opts.bottom = opts.bottom or {}

      -- Make output window taller by default
      for _, win in ipairs(opts.bottom) do
        if win.ft == "dbout" then
          -- Merge overrides into the existing config
          win.size = { height = 30 }
          break
        end
      end
    end,
  },
}
