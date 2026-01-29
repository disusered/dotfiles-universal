return {
  "stevearc/conform.nvim",
  ---@param opts table
  opts = function(_, opts)
    -- Ensure the formatters and formatters_by_ft tables exist
    opts.formatters = opts.formatters or {}
    opts.formatters_by_ft = opts.formatters_by_ft or {}

    -- Define the custom powershell formatter
    opts.formatters["ps_formatter"] = {
      command = "pwsh",
      args = {
        "-NoProfile",
        "-Command",
        "Invoke-Formatter -ScriptDefinition ($input | Join-String -Separator `n)",
      },
      stdin = true,
    }

    -- Define the custom xmlformat formatter
    opts.formatters["xmlformat"] = {
      command = "xmlformat",
      args = { "--selfclose", "--blanks", "-" },
      stdin = true,
    }

    -- Assign formatters to filetypes
    opts.formatters_by_ft["sql"] = vim.list_extend(opts.formatters_by_ft["sql"] or {}, { "sqlfluff" })
    opts.formatters_by_ft["ps1"] = { "ps_formatter" }
    opts.formatters_by_ft["xml"] = { "xmlformat" }

    -- Use LSP formatting for .NET
    opts.formatters_by_ft["cs"] = {}
    opts.formatters_by_ft["fsharp"] = {}
  end,
}
