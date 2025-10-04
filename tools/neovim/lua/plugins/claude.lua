return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      -- Server Configuration
      port_range = { min = 10000, max = 65535 },
      auto_start = true,
      log_level = "info", -- "trace", "debug", "info", "warn", "error"
      terminal_cmd = "/home/carlos/.local/share/mise/installs/node/24.7.0/bin/claude",
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

        -- Custom Wezterm provider
        provider = (function()
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
      { "<leader>a", nil, desc = "AI/Claude Code" },
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
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
}
