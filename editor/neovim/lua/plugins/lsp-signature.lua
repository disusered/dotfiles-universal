return {
  "ray-x/lsp_signature.nvim",
  event = "InsertEnter",
  opts = {
    bind = true,
    floating_window = true, -- show hint in a floating window
    hint_enable = false,    -- virtual text hint disabled
    handler_opts = {
      border = "single",    -- double, rounded, single, shadow, none, or a table of borders
    },
  },
}
