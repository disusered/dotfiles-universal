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
    -- The init function now just calls the setup from our main module
    init = function()
      require("config.dadbod.main").setup()
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
