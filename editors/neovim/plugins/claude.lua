-- Detect which terminal emulator we're running in
local function detect_terminal()
  -- Check for Kitty
  local kitty_listen = vim.env.KITTY_LISTEN_ON
  local term = vim.env.TERM

  if kitty_listen or (term and term:match("kitty")) then
    return "kitty"
  end

  -- Default to Wezterm
  return "wezterm"
end

-- Create Kitty terminal provider with multi-window safety
local function create_kitty_provider()
  local provider = {}

  provider.setup = function(config)
    -- Initialize state tracking
    vim.g.claudecode_kitty_window_id = nil
  end

  -- Find the current OS window (the one containing Neovim)
  local function find_current_os_window(data)
    for _, os_window in ipairs(data) do
      for _, tab in ipairs(os_window.tabs or {}) do
        for _, window in ipairs(tab.windows or {}) do
          if window.is_self then
            return os_window
          end
        end
      end
    end
    return nil
  end

  provider.open = function(cmd_string, env_table, effective_config, focus)
    if focus == nil then
      focus = true
    end

    -- Get all Kitty windows and tabs
    local ls_cmd = "kitty @ ls"
    local ls_result = vim.fn.system(ls_cmd)
    local ok, data = pcall(vim.fn.json_decode, ls_result)

    if ok and data then
      -- Find the current OS window to scope our search
      local current_os_window = find_current_os_window(data)

      if current_os_window then
        -- Search only within the current OS window's tabs
        for _, tab in ipairs(current_os_window.tabs or {}) do
          for _, window in ipairs(tab.windows or {}) do
            if window.user_vars and window.user_vars.claude_tab == "true" then
              -- Found existing Claude tab in current OS window
              vim.g.claudecode_kitty_window_id = window.id

              if focus then
                local focus_cmd = string.format("kitty @ focus-tab --match id:%d", tab.id)
                vim.fn.system(focus_cmd)
              end

              return
            end
          end
        end
      end
    end

    -- No Claude tab found in current OS window, spawn new one
    local cwd = vim.fn.getcwd()

    -- The cmd_string already contains environment variables and full command
    -- Just like Wezterm provider, pass it directly to the shell
    local spawn_cmd = string.format(
      "kitty @ launch --type=tab --var claude_tab=true --cwd %s -- zsh -lic %s",
      vim.fn.shellescape(cwd),
      vim.fn.shellescape(cmd_string)
    )

    local result = vim.fn.system(spawn_cmd)
    local window_id = tonumber(result:match("%d+"))

    if window_id then
      vim.g.claudecode_kitty_window_id = window_id

      -- Focus the new tab if requested
      if focus then
        -- Get the tab ID for this window
        local ls_result2 = vim.fn.system("kitty @ ls")
        local ok2, data2 = pcall(vim.fn.json_decode, ls_result2)
        if ok2 and data2 then
          for _, os_window in ipairs(data2) do
            for _, tab in ipairs(os_window.tabs or {}) do
              for _, window in ipairs(tab.windows or {}) do
                if window.id == window_id then
                  local focus_cmd = string.format("kitty @ focus-tab --match id:%d", tab.id)
                  vim.fn.system(focus_cmd)
                  return
                end
              end
            end
          end
        end
      end
    end
  end

  provider.close = function()
    local window_id = vim.g.claudecode_kitty_window_id
    if window_id then
      local close_cmd = string.format("kitty @ close-window --match id:%d", window_id)
      vim.fn.system(close_cmd)
      vim.g.claudecode_kitty_window_id = nil
    end
  end

  provider.simple_toggle = function(cmd_string, env_table, effective_config)
    -- Check if Claude tab exists in current OS window
    local ls_cmd = "kitty @ ls"
    local ls_result = vim.fn.system(ls_cmd)
    local ok, data = pcall(vim.fn.json_decode, ls_result)

    if ok and data then
      local current_os_window = find_current_os_window(data)

      if current_os_window then
        for _, tab in ipairs(current_os_window.tabs or {}) do
          for _, window in ipairs(tab.windows or {}) do
            if window.user_vars and window.user_vars.claude_tab == "true" then
              -- Focus existing tab
              local focus_cmd = string.format("kitty @ focus-tab --match id:%d", tab.id)
              vim.fn.system(focus_cmd)
              vim.g.claudecode_kitty_window_id = window.id
              return
            end
          end
        end
      end
    end

    -- No Claude tab found, spawn new one
    provider.open(cmd_string, env_table, effective_config, true)
  end

  provider.focus_toggle = function(cmd_string, env_table, effective_config)
    -- Same as simple_toggle for Kitty
    provider.simple_toggle(cmd_string, env_table, effective_config)
  end

  provider.get_active_bufnr = function()
    -- External terminal, no buffer
    return nil
  end

  provider.is_available = function()
    -- Check if we're in Kitty
    return vim.env.KITTY_LISTEN_ON ~= nil
  end

  return provider
end

-- Create Wezterm terminal provider (existing implementation)
local function create_wezterm_provider()
  local provider = {}

  provider.setup = function(config)
    -- Initialize state tracking
    vim.g.claudecode_wezterm_pane_id = nil
  end

  provider.open = function(cmd_string, env_table, effective_config, focus)
    if focus == nil then
      focus = true
    end

    -- Check if Claude tab already exists and reuse it
    local tab_info = vim.fn.system("wezterm.exe cli list --format json")
    local ok, tabs = pcall(vim.fn.json_decode, tab_info)

    if ok then
      for _, tab in ipairs(tabs) do
        if tab.tab_title == "Claude Code" then
          -- Focus the existing tab if requested
          if focus then
            local focus_cmd = string.format("wezterm.exe cli activate-tab --tab-id %d", tab.tab_id)
            vim.fn.system(focus_cmd)
          end

          vim.g.claudecode_wezterm_pane_id = tab.pane_id
          return
        end
      end
    end

    -- No Claude tab found, spawn new one
    local cwd = vim.fn.getcwd()
    local spawn_cmd = string.format(
      "WEZTERM_LOG=error wezterm.exe cli spawn --domain-name WSL:Fedora --cwd %s -- zsh -lic '%s' 2>/dev/null",
      vim.fn.shellescape(cwd),
      cmd_string:gsub("'", "'\\''") -- Escape single quotes
    )

    -- Spawn the new tab
    local result = vim.fn.system(spawn_cmd)
    local pane_id = tonumber(result:match("%d+"))

    if pane_id then
      vim.g.claudecode_wezterm_pane_id = pane_id

      -- Get tab_id from pane_id
      local tab_id = nil
      local list_cmd = "wezterm.exe cli list --format json"
      local list_result = vim.fn.system(list_cmd)
      local ok, tabs = pcall(vim.fn.json_decode, list_result)
      if ok then
        for _, tab in ipairs(tabs) do
          if tab.pane_id == pane_id then
            tab_id = tab.tab_id
            break
          end
        end
      end

      -- Set tab title for identification using tab_id
      if tab_id then
        local title_cmd = string.format('wezterm.exe cli set-tab-title --tab-id %d "Claude Code"', tab_id)
        vim.fn.system(title_cmd)

        -- Focus the tab if requested
        if focus then
          local focus_cmd = string.format("wezterm.exe cli activate-tab --tab-id %d", tab_id)
          vim.fn.system(focus_cmd)
        end
      else
        -- Fallback: try to focus using pane_id if tab_id not found
        if focus then
          local tab_info = vim.fn.system("wezterm.exe cli list --format json")
          local ok, tabs = pcall(vim.fn.json_decode, tab_info)
          if ok then
            for _, tab in ipairs(tabs) do
              if tab.pane_id == pane_id then
                local focus_cmd = string.format("wezterm.exe cli activate-tab --tab-id %d", tab.tab_id)
                vim.fn.system(focus_cmd)
                break
              end
            end
          end
        end
      end
    end
  end

  provider.close = function()
    local pane_id = vim.g.claudecode_wezterm_pane_id
    if pane_id then
      local kill_cmd = string.format("wezterm.exe cli kill-pane --pane-id %d", pane_id)
      vim.fn.system(kill_cmd)
      vim.g.claudecode_wezterm_pane_id = nil
    end
  end

  provider.simple_toggle = function(cmd_string, env_table, effective_config)
    -- Check if Claude tab exists
    local tab_info = vim.fn.system("wezterm.exe cli list --format json")
    local ok, tabs = pcall(vim.fn.json_decode, tab_info)

    if ok then
      for _, tab in ipairs(tabs) do
        if tab.tab_title == "Claude Code" then
          -- Activate existing tab
          local focus_cmd = string.format("wezterm.exe cli activate-tab --tab-id %d", tab.tab_id)
          vim.fn.system(focus_cmd)
          vim.g.claudecode_wezterm_pane_id = tab.pane_id
          return
        end
      end
    end

    -- No Claude tab found, spawn new one
    provider.open(cmd_string, env_table, effective_config, true)
  end

  provider.focus_toggle = function(cmd_string, env_table, effective_config)
    -- Same as simple_toggle for Wezterm (no hide functionality)
    provider.simple_toggle(cmd_string, env_table, effective_config)
  end

  provider.get_active_bufnr = function()
    -- External terminal, no buffer
    return nil
  end

  provider.is_available = function()
    -- Check if wezterm.exe exists
    local result = vim.fn.system("which wezterm.exe")
    return vim.v.shell_error == 0 and result:match("/.*wezterm%.exe")
  end

  return provider
end

return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      -- Server Configuration
      port_range = { min = 10000, max = 65535 },
      auto_start = true,
      log_level = "info", -- "trace", "debug", "info", "warn", "error"
      terminal_cmd = "/home/carlos/.local/share/mise/installs/node/24.10.0/bin/claude",
      -- For local installations: "~/.claude/local/claude"
      -- For native binary: use output from 'which claude'

      -- Send/Focus Behavior
      -- When true, successful sends will focus the Claude terminal if already connected
      focus_after_send = false,

      -- Selection Tracking
      track_selection = true,
      visual_demotion_delay_ms = 50,

      -- Terminal Configuration
      terminal = {
        split_side = "right", -- "left" or "right"
        split_width_percentage = 0.30,
        auto_close = true,
        snacks_win_opts = {}, -- Opts to pass to `Snacks.terminal.open()` - see Floating Window section below

        -- Select provider based on terminal type
        provider = (function()
          local terminal_type = detect_terminal()
          if terminal_type == "kitty" then
            return create_kitty_provider()
          else
            return create_wezterm_provider()
          end
        end)(),
      },

      -- Diff Integration
      diff_opts = {
        auto_close_on_accept = true,
        vertical_split = true,
        open_in_current_tab = true,
        keep_terminal_focus = false, -- If true, moves focus back to terminal after diff opens
      },
    },

    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      {
        "<leader>as",
        function()
          local filename = vim.fn.expand("%:t")
          vim.cmd("ClaudeCodeAdd %")
          vim.notify(filename, vim.log.levels.INFO, { title = "Sent to Claude" })
        end,
        desc = "Send buffer to Claude",
      },
      {
        "<leader>as",
        function()
          local filename = vim.fn.expand("%:t")
          vim.cmd("ClaudeCodeSend")
          vim.notify("Selection from " .. filename, vim.log.levels.INFO, { title = "Sent to Claude" })
        end,
        mode = "v",
        desc = "Send selection to Claude",
      },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles" },
      },
      -- Diff management
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          "<leader>a",
          name = "+ai",
          mode = "nv",
        },
      },
    },
  },
}
