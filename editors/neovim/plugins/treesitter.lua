return {
  "nvim-treesitter/nvim-treesitter",
  dependencies = {
    "RRethy/nvim-treesitter-endwise",
  },
  opts = function(_, opts)
    vim.list_extend(opts.ensure_installed, {
      "c",
      "cpp",
      "cmake",
      "css",
      "graphql",
      "query",
      "lua",
      "latex",
      "make",
      "scss",
      "toml",
      "vue",
      "yaml",
      "astro",
      "sql",
      "rust",
      "ruby",
      "c_sharp",
      "json",
      "jsonc",
      "gitcommit",
      "git_rebase",
      "terraform",
      "html",
      "latex",
      "markdown",
      "markdown_inline",
      "typst",
      "powershell",
      -- TODO: Built automatically, current install was manually built in shell
      -- "norg", -- Manually built, see build script at ~/.cache/nvim/tree-sitter-norg/build.sh
      -- "norg_meta", -- Also requires manual build due to treesitter 2 incompatibility
      "svelte",
      "vim",
      "vimdoc",
    })
  end,
}
