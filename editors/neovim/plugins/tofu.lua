return {
  {
    "mason-org/mason.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      for i, name in ipairs(opts.ensure_installed) do
        if name == "tflint" then
          table.remove(opts.ensure_installed, i)
          break
        end
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        hcl = { "tofu_fmt" },
        terraform = { "tofu_fmt" },
        tf = { "tofu_fmt" },
        ["terraform-vars"] = { "tofu_fmt" },
      },
    },
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local null_ls = require("null-ls")
      local sources = {}
      for _, source in ipairs(opts.sources or {}) do
        if source ~= null_ls.builtins.formatting.terraform_fmt then
          table.insert(sources, source)
        end
      end
      opts.sources = sources
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        terraform = { "tofu" },
        tf = { "tofu" },
      },
    },
  },
}
