return {
  -- add blink.compat
  {
    "saghen/blink.compat",
    version = "2.*",
    lazy = true,
    opts = {},
  },

  -- Base blink config
  {
    "saghen/blink.cmp",
    opts = {
      signature = { enabled = true },
    },
  },
}
