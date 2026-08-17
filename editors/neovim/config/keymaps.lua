require("config.shared.keymaps")

-- Custom Snacks toggle for Zen Mode
require("snacks").toggle
  .new({
    name = "Zen Mode",
    get = function()
      local state = package.loaded["no-neck-pain.state"]
      return state and state.enabled or false
    end,
    set = function()
      vim.cmd("NoNeckPain")
    end,
  })
  :map("<leader>uz")
