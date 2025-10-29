return {
  "folke/snacks.nvim",
  opts = {
    dashboard = { enabled = false },
    indent = { enabled = false }, -- replaced by mini.indentscope
    input = { enabled = true }, -- replaced dressing.nvim
    notifier = { enabled = true }, -- replaced nvim-notify
    scope = { enabled = true }, -- ii/ai objects for scope
    scroll = { enabled = false }, -- no smooth scrolling
    statuscolumn = { enabled = false }, -- we set this in options.lua
    words = { enabled = true },
    bigfile = { notify = true },
    terminal = { enabled = false }, -- do not use snacks terminal
    lazygit = { enabled = false },
    zen = {
      enabled = true,
      toggles = {
        dim = false,
        git_signs = false,
        mini_diff_signs = false,
        diagnostics = false,
        inlay_hints = false,
        wrap = true,
      },
      show = {
        statusline = false,
        tabline = false,
      },
      on_open = function()
        vim.fn.system("kitten @ set-font-size +2")
      end,
      on_close = function()
        vim.fn.system("kitten @ set-font-size 0")
      end,
    },
    styles = {
      zen = {
        width = 100,
        wo = {
          colorcolumn = "",
        },
      },
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
