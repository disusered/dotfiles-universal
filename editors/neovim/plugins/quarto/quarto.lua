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
          ft_runners = { python = "molten" }, -- filetype to runner, ie. `{ python = "molten" }`.
          never_run = { "yaml" }, -- filetypes which are never sent to a code runner
        },
      })
    end,
    keys = {
      -- Kernel Management via Quarto
      -- Enhances Molten's default init
      {
        "<leader>jI",
        function()
          local initialized = _G.molten_helpers.init()
          if initialized ~= nil then
            if vim.bo.filetype == "quarto" then
              vim.cmd("QuartoActivate")
              vim.notify("Quarto activated", vim.log.levels.INFO, { title = "Quarto activation" })
            else
              vim.notify(
                "Quarto can not be activated, not in a quarto file",
                vim.log.evels.ERROR,
                { title = "Quarto activation" }
              )
            end
          end
        end,
        desc = "Initialize kernel",
        ft = "quarto",
      },
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
          require("quarto.runner").run_all()
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

  -- Open jupyter notebooks as plaintext (quarto)
  {
    "GCBallesteros/jupytext.nvim",
    config = true,
    lazy = false,
    opts = {
      custom_language_formatting = {
        python = {
          extension = "qmd",
          style = "quarto",
          force_ft = "quarto",
        },
        r = {
          extension = "qmd",
          style = "quarto",
          force_ft = "quarto",
        },
      },
    },
  },

  -- "Prettier" rendering of Markdown
  {
    "MeanderingProgrammer/render-markdown.nvim",
    enabled = true,
    ft = { "quarto" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.icons" }, -- if you use standalone mini plugins
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      -- Filetypes this plugin will run on.
      file_types = { "quarto" },

      -- Pre configured settings that will attempt to mimic various target user experiences.
      -- User provided settings will take precedence.
      -- | obsidian | mimic Obsidian UI                                          |
      -- | lazy     | will attempt to stay up to date with LazyVim configuration |
      -- | none     | does nothing
      preset = "lazy",

      -- This enables hiding added text on the line the cursor is on.
      anti_conceal = { enabled = false },
    },
  },
}
