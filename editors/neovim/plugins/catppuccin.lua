return {
  "catppuccin/nvim",
  opts = {
    transparent_background = true,
    float = {
      transparent = true,
      solid = false,
    },
    custom_highlights = function(C)
      local primary = vim.fn.system("cfg theme --get secondary"):gsub("%s+", "")
      return {
        FloatBorder = { fg = C[primary] or C.blue, bg = C.none },
      }
    end,
  },
}
