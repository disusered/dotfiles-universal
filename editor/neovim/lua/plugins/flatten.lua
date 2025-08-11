---@type LazySpec
return {
  {
    "brianhuster/unnest.nvim",

    -- Ensure that it runs first to minimize delay when opening file from terminal
    lazy = false,
    priority = 1001,
  },
}
