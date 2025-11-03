return {
  "linux-cultist/venv-selector.nvim",
  dependencies = {
    "neovim/nvim-lspconfig",
  },
  ft = "python", -- Load when opening Python files
  keys = {
    {
      "<leader>cv",
      "<cmd>VenvSelect<cr>",
      desc = "Virtual environment selector",
    },
  },
  opts = { -- this can be an empty lua table - just showing below for clarity.
    search = {}, -- if you add your own searches, they go here.
    options = {}, -- if you add plugin options, they go here.
  },
}
