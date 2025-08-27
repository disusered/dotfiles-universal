return {
  "folke/noice.nvim",
  enabled = true,
  opts = {
    -- Don't auto open the signature help window
    lsp_signature = {
      auto_open = { enabled = false },
    },
    -- Use bottom cmdline instead of floating window
    cmdline = {
      enabled = true,
      view = "cmdline",
    },
    presets = {
      -- Don't use Noice's rename prompt
      inc_rename = false,
    },
  },
  keys = {
    {
      "<leader>cP",
      function()
        vim.lsp.buf.signature_help()
      end,
      desc = "Parameter help",
    },
  },
}
