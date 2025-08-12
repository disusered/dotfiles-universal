return {
  "williamboman/mason.nvim",
  version = "1.11.0",
  opts = function()
    -- Base list of packages to install on all systems
    local ensure_installed = {
      "bash-language-server",
      "css-lsp",
      "html-lsp",
      "eslint-lsp",
      "markdown-toc",
      "markdownlint-cli2",
      "prettier",
      "prettierd",
      "sqlfluff",
    }

    -- Conditionally add 'checkmake' if the OS is not Windows
    if not vim.fn.has("win32") then
      table.insert(ensure_installed, "checkmake")
    end

    return {
      ensure_installed = ensure_installed,
    }
  end,
}
