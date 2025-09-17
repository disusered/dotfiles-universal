return {
  "mason-org/mason.nvim",
  opts = function(_, opts)
    -- Guard clause to ensure opts and opts.ensure_installed are tables
    opts.ensure_installed = opts.ensure_installed or {}

    vim.list_extend(opts.ensure_installed, {
      -- Astro
      "astro-language-server",
      -- Bash / Shell
      "bash-language-server",
      "shfmt", -- Formatter
      -- C#
      "csharpier", -- Formatter
      -- CSS / HTML
      "css-lsp",
      "html-lsp",
      "emmet-language-server", -- HTML/CSS abbreviation expander
      -- Docker
      "hadolint", -- Linter
      -- Elixir
      "elixir-ls",
      -- JavaScript / TypeScript
      "eslint-lsp",
      "js-debug-adapter",
      -- JSON
      "json-lsp",
      -- Lua
      "lua-language-server",
      "stylua", -- Formatter
      -- Markdown
      "markdown-toc", -- Table of contents generator
      "markdownlint-cli2", -- Linter
      -- Makefiles
      "checkmake", -- Linter
      -- Python
      "pyright", -- Language server
      "ruff", -- Linter and formatter
      "black", -- Formatter
      "isort", -- Import sorter
      "flake8", -- Linter
      "debugpy", -- Debugger
      -- Ruby
      "solargraph", -- Language server
      "erb-lint", -- ERB linter
      "erb-formatter", -- ERB formatter
      -- Rust
      "rust-analyzer",
      -- "rustfmt", -- Formatter, installed via rustup now
      -- SQL
      "sqlfluff", -- Linter and formatter
      -- TOML
      "taplo", -- Formatter and linter
      -- Vue
      "vue-language-server",
      -- Web Development Formatters
      "prettier", -- General purpose formatter
      "prettierd", -- Daemonized for speed
    })

    -- Conditionally add 'checkmake' if the OS is not Windows
    if not vim.fn.has("win32") then
      vim.list_extend(opts.ensure_installed, { "checkmake" })
    end
  end,
}
