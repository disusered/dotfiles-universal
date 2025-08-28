return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- Define the Code Companion Spinner Component ##
    local code_companion_status = {
      processing = false,
      spinner_index = 1,
      spinner_symbols = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    }

    -- Create autocommands to toggle the spinner's visibility and animation
    local group = vim.api.nvim_create_augroup("CodeCompanionHooks", { clear = true })
    vim.api.nvim_create_autocmd({ "User" }, {
      pattern = "CodeCompanionRequest*",
      group = group,
      callback = function(request)
        if request.match == "CodeCompanionRequestStarted" then
          code_companion_status.processing = true
        elseif request.match == "CodeCompanionRequestFinished" then
          code_companion_status.processing = false
        end
      end,
    })

    -- This is the function that lualine will call to get the spinner's current state
    local function get_spinner()
      if code_companion_status.processing then
        local len = #code_companion_status.spinner_symbols
        code_companion_status.spinner_index = (code_companion_status.spinner_index % len) + 1
        return code_companion_status.spinner_symbols[code_companion_status.spinner_index]
      end
      return "" -- Return an empty string when not processing to hide the component
    end

    opts.options.component_separators = ""
    opts.options.section_separators = { left = "", right = "" }

    -- Move diagnostics to other section
    local lualine_z = {
      LazyVim.lualine.root_dir(),
      { "filetype", icon_only = true, separator = "", padding = { left = 2, right = 0 } },
      { LazyVim.lualine.pretty_path() },
    }
    vim.tbl_deep_extend("force", opts.sections, { lualine_z = lualine_z })

    -- Remove clock
    opts.sections.lualine_z = {}

    -- Remove diagnostics from lualine_c
    if opts.sections.lualine_c then
      local new_lualine_c = {}
      for _, component in ipairs(opts.sections.lualine_c) do
        if not (type(component) == "table" and component[1] == "diagnostics") then
          table.insert(new_lualine_c, component)
        end
      end
      opts.sections.lualine_c = new_lualine_c
    end

    -- Remove progress
    local icons = LazyVim.config.icons
    opts.sections.lualine_y = {
      {
        "diagnostics",
        symbols = {
          error = icons.diagnostics.Error,
          warn = icons.diagnostics.Warn,
          info = icons.diagnostics.Info,
          hint = icons.diagnostics.Hint,
        },
      },
    }

    -- ## 3. Add the Spinner to the 'lualine_x' Section ##
    opts.sections.lualine_x = {
      -- Spinner Component (will only show when active)
      get_spinner,

      -- DAP
      Snacks.profiler.status(),
      {
        function()
          return " " .. require("dap").status()
        end,
        cond = function()
          return package.loaded["dap"] and require("dap").status() ~= ""
        end,
        color = function()
          return { fg = Snacks.util.color("Debug") }
        end,
      },
      -- LazyVim
      {
        require("lazy.status").updates,
        cond = require("lazy.status").has_updates,
        color = function()
          return { fg = Snacks.util.color("Special") }
        end,
      },
      -- Git
      { "diff" },
    }
  end,
}
