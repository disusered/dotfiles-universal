return {
  "folke/which-key.nvim",
  opts = {
    preset = "helix", -- "classic", "modern", "helix"
    -- Configure the floating window options
    win = {
      -- Position the window in the top left corner.
      -- `row` and `col` are 0-indexed.
      row = 0,
      col = math.huge,
    },
  },
}
