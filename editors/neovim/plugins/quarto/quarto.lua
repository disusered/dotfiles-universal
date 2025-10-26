return {
  {
    "quarto-dev/quarto-nvim",
    ft = { "quarto", "markdown" },
    dependencies = {
      "jmbuhr/otter.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    init = function()
      -- Register quarto filetype to use markdown treesitter parser
      vim.treesitter.language.register("markdown", { "quarto", "rmd" })

      -- Detect and configure local venv for Quarto
      local function find_venv_python()
        -- Check for activated venv
        local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
        if venv then
          return venv .. "/bin/python3"
        end

        -- Check for local .venv
        local venv_path = vim.fn.getcwd() .. "/.venv/bin/python3"
        if vim.fn.filereadable(venv_path) == 1 then
          return venv_path
        end

        return nil
      end

      local venv_python = find_venv_python()
      if venv_python then
        vim.env.QUARTO_PYTHON = venv_python
      end
    end,
    config = function()
      require("quarto").setup({
        debug = false,
        closePreviewOnExit = true,
        lspFeatures = {
          enabled = true,
          chunks = "curly",
          languages = { "r", "python", "julia", "bash", "html" },
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
          default_method = "molten", -- "molten", "slime", "iron" or <function>
          ft_runners = {}, -- filetype to runner, ie. `{ python = "molten" }`.
          -- Takes precedence over `default_method`
          never_run = { "yaml" }, -- filetypes which are never sent to a code runner
        },
      })
    end,
    keys = {
      -- Quarto code execution via runner
      {
        "<leader>jc",
        function()
          require("quarto.runner").run_cell()
        end,
        mode = "n",
        desc = "Run cell",
        ft = "quarto",
      },
      {
        "<leader>jl",
        function()
          require("quarto.runner").run_line()
        end,
        mode = "n",
        desc = "Run line",
        ft = "quarto",
      },
      {
        "<leader>ja",
        function()
          require("quarto.runner").run_all(true)
        end,
        mode = "n",
        desc = "Run all cells",
        ft = "quarto",
      },
      -- Quarto preview
      {
        "<leader>jP",
        function()
          local quarto = require("quarto")
          quarto.setup()
          vim.notify("Starting quarto preview", vim.log.levels.INFO)
          quarto.quartoPreview()
        end,
        mode = "n",
        desc = "Start preview",
        ft = "quarto",
      },
      {
        "<leader>jq",
        function()
          require("quarto").quartoClosePreview()
        end,
        mode = "n",
        desc = "Stop preview",
        ft = "quarto",
      },
    },
  },
}
