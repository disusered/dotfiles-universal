return {
  "knubie/vim-kitty-navigator",
  build = function(plugin)
    local cmd = string.format("cp %s/*.py ~/.config/kitty/", plugin.dir)
    vim.fn.system(cmd)
  end,
  enabled = vim.fn.has("unix") == 1 and vim.env.TERM == "xterm-kitty",
  keys = {
    { "<C-h>", "<cmd>KittyNavigateLeft<cr>", desc = "Navigate left" },
    { "<C-j>", "<cmd>KittyNavigateDown<cr>", desc = "Navigate down" },
    { "<C-k>", "<cmd>KittyNavigateUp<cr>", desc = "Navigate up" },
    { "<C-l>", "<cmd>KittyNavigateRight<cr>", desc = "Navigate right" },
  },
}
