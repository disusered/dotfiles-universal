return {
  "stevearc/conform.nvim",
  ---@param opts table
  opts = function(_, opts)
    -- Ensure the formatters_by_ft table exists before modifying it.
    opts.formatters_by_ft = opts.formatters_by_ft or {}

    -- TODO: See how to add these without overriding extras configs
    -- Use vim.list_extend to safely add formatters to the global fallback list (*).
    -- This appends to any existing list or creates a new one.
    -- opts.formatters_by_ft["*"] =
    --   vim.list_extend(opts.formatters_by_ft["*"] or {}, { "trim_whitespace", "trim_newlines" })

    -- Add formatters for specific filetypes.
    opts.formatters_by_ft["sql"] = vim.list_extend(opts.formatters_by_ft["sql"] or {}, { "sqlfluff" })
    opts.formatters_by_ft["cs"] = vim.list_extend(opts.formatters_by_ft["cs"] or {}, { "csharpier" })

    -- Ensure the formatters definition table exists.
    opts.formatters = opts.formatters or {}

    -- Define a custom 'csharpier' formatter with dynamic command resolution.
    -- This is necessary to handle different installation methods (standalone vs. dotnet tool).
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

      --NOTE: system command returns the command as the first line of the result, need to get the version number on the final line
      -- local version_result = version_out[#version_out]
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
  end,
}
