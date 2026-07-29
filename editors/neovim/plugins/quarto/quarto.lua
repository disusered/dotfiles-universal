if vim.env.NVIM_APPNAME ~= "nvim-notebook" then
  return {}
end

return {
  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto", "rmd" },
    dependencies = {
      "jmbuhr/otter.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    init = function()
      vim.treesitter.language.register("markdown", { "quarto", "rmd" })
    end,
    opts = {
      debug = false,
      closePreviewOnExit = true,
      lspFeatures = {
        enabled = true,
        chunks = "curly",
        languages = { "python" },
        diagnostics = {
          enabled = true,
          triggers = { "BufWritePost" },
        },
        completion = {
          enabled = true,
        },
      },
      codeRunner = {
        enabled = true,
        default_method = "molten",
        ft_runners = { python = "molten" },
        never_run = { "yaml" },
      },
    },
    keys = {
      {
        "<leader>jc",
        function()
          require("quarto.runner").run_cell()
        end,
        desc = "Run cell",
        ft = "quarto",
      },
      {
        "<leader>jl",
        function()
          require("quarto.runner").run_line()
        end,
        desc = "Run line",
        ft = "quarto",
      },
      {
        "<leader>ja",
        function()
          require("quarto.runner").run_all()
        end,
        desc = "Run all cells",
        ft = "quarto",
      },
    },
  },
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    opts = {
      custom_language_formatting = {
        python = {
          extension = "qmd",
          style = "quarto",
          force_ft = "quarto",
        },
      },
    },
  },
}
