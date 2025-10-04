return {
  "bfredl/nvim-luadev",
  ft = "lua",
  keys = {
    {
      "<leader>cl",
      "Luadev",
      desc = "Lua REPL",
    },
    {
      "<leader>cr",
      "<Plug>(Luadev-Run)",
      desc = "Run Lua code",
      mode = { "v" },
    },
  },
}
