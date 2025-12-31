return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "razor",
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      },
      ensure_installed = {
        "roslyn",
      },
    },
  },
  {
    "seblyng/roslyn.nvim",
    ---@module 'roslyn.config'
    ---@type RoslynNvimConfig
    opts = {
      -- "auto" | "roslyn" | "off"
      --
      -- - "auto": Does nothing for filewatching, leaving everything as default
      -- - "roslyn": Turns off neovim filewatching which will make roslyn do the filewatching
      -- - "off": Hack to turn off all filewatching. (Can be used if you notice performance issues)
      filewatching = "auto",
    },
    -- config = function()
    --   vim.lsp.config("roslyn", {
    --     settings = {
    --       ["csharp|inlay_hints"] = {
    --         csharp_enable_inlay_hints_for_implicit_object_creation = true,
    --         csharp_enable_inlay_hints_for_implicit_variable_types = true,
    --         csharp_enable_inlay_hints_for_lambda_parameter_types = true,
    --         csharp_enable_inlay_hints_for_types = true,
    --         dotnet_enable_inlay_hints_for_indexer_parameters = true,
    --         dotnet_enable_inlay_hints_for_literal_parameters = true,
    --         dotnet_enable_inlay_hints_for_object_creation_parameters = true,
    --         dotnet_enable_inlay_hints_for_other_parameters = true,
    --         dotnet_enable_inlay_hints_for_parameters = true,
    --         dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
    --         dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
    --         dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
    --       },
    --       ["csharp|code_lens"] = {
    --         dotnet_enable_references_code_lens = true,
    --       },
    --     },
    --   })
    -- end,
  },
  {
    "folke/trouble.nvim",
    opts = {
      modes = {
        diagnostics = {
          filter = function(items)
            return vim.tbl_filter(function(item)
              return not string.match(item.basename, [[%__virtual.cs$]])
            end, items)
          end,
        },
      },
    },
  },
}
