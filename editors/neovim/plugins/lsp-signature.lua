return {
  "ray-x/lsp_signature.nvim",
  event = "LspAttach",
  config = function()
    local cfg = {
      bind = true,
      floating_window = true,
      hint_enable = false,
      handler_opts = {
        border = "single",
      },
    }

    local excluded = { cs = true, razor = true }

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local bufnr = args.buf
        local ft = vim.bo[bufnr].filetype
        if excluded[ft] then
          return
        end
        require("lsp_signature").on_attach(cfg, bufnr)
      end,
    })
  end,
}
