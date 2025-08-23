return {
  "folke/snacks.nvim",
  opts = {
    dashboard = { enabled = false },
    indent = { enabled = false },       -- replaced by mini.indentscope
    input = { enabled = true },         -- replaced dressing.nvim
    notifier = { enabled = true },      -- replaced nvim-notify
    scope = { enabled = true },         -- ii/ai objects for scope
    scroll = { enabled = false },       -- no smooth scrolling
    statuscolumn = { enabled = false }, -- we set this in options.lua
    words = { enabled = true },
    bigfile = { notify = true },
    terminal = { enabled = false }, -- do not use snacks terminal
    lazygit = {
      configure = false,
    },
  },
  keys = {
    {
      "<leader>q",
      function()
        Snacks.bufdelete()
      end,
      desc = "Delete Buffer",
    },
  },
}
