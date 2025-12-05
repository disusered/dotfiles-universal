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

    -- Define the custom csharpier formatter, preserving your logic
    opts.formatters["csharpier"] = function()
      local command
      if vim.fn.executable("csharpier") == 1 then
        command = "csharpier"
      elseif vim.fn.executable("dotnet") == 1 then
        command = "dotnet csharpier"
      else
        vim.notify("[conform] csharpier or dotnet not found in path", vim.log.levels.WARN)
        return
      end

      local version_out = vim.fn.system(command .. " --version")
      if vim.v.shell_error ~= 0 then
        vim.notify("[conform] csharpier not found or returned an error for command: " .. command, vim.log.levels.WARN)
        return
      end

      local major_version = tonumber((version_out or ""):match("^(%d+)")) or 0
      local is_new = major_version >= 1

      local args = is_new and { "format", "$FILENAME" } or { "--write-stdout" }

      return {
        command = command,
        args = args,
        stdin = not is_new,
        require_cwd = false,
      }
    end

    -- Define the custom xmlformat formatter
    opts.formatters["xmlformat"] = {
      command = "xmlformat",
      args = { "--selfclose", "--blanks", "-" },
      stdin = true,
    }

    -- Assign formatters to filetypes
    opts.formatters_by_ft["sql"] = vim.list_extend(opts.formatters_by_ft["sql"] or {}, { "sqlfluff" })
    opts.formatters_by_ft["cs"] = vim.list_extend(opts.formatters_by_ft["cs"] or {}, { "csharpier" })
    opts.formatters_by_ft["ps1"] = { "ps_formatter" }
    opts.formatters_by_ft["xml"] = { "xmlformat" }
  end,
}
