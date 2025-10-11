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

local function open_lazygit_in_kitty(cwd)
  if not cwd then
    cwd = vim.fn.getcwd()
  end

  -- Get Neovim server name for lazygit integration
  local nvim_addr = vim.v.servername

  -- Check if lazygit tab already exists using user variable
  local ls_cmd = "kitty @ ls"
  local ls_result = vim.fn.system(ls_cmd)
  local ok, data = pcall(vim.fn.json_decode, ls_result)

  if ok and data then
    -- Find the current OS window first (multi-window safety)
    local current_os_window = nil
    for _, os_window in ipairs(data) do
      for _, tab in ipairs(os_window.tabs or {}) do
        for _, window in ipairs(tab.windows or {}) do
          if window.is_self then
            current_os_window = os_window
            break
          end
        end
        if current_os_window then
          break
        end
      end
      if current_os_window then
        break
      end
    end

    -- Search for lazygit tab only within the current OS window
    if current_os_window then
      for _, tab in ipairs(current_os_window.tabs or {}) do
        for _, window in ipairs(tab.windows or {}) do
          -- Check if this window has the lazygit_tab user variable
          if window.user_vars and window.user_vars.lazygit_tab == "true" then
            -- Focus the existing tab
            local focus_cmd = string.format("kitty @ focus-tab --match id:%d", tab.id)
            vim.fn.system(focus_cmd)
            return
          end
        end
      end
    end
  end

  -- No lazygit tab found, spawn new one
  local spawn_cmd = string.format(
    "kitty @ launch --type=tab --tab-title=git --var lazygit_tab=true --env NVIM=%s --cwd %s -- zsh -lic 'lazygit'",
    vim.fn.shellescape(nvim_addr),
    vim.fn.shellescape(cwd)
  )

  vim.fn.system(spawn_cmd)
end

local function open_lazygit_in_wezterm(cwd)
  if not cwd then
    cwd = vim.fn.getcwd()
  end

  -- Check if git tab already exists and reuse it
  local tab_info = vim.fn.system("wezterm.exe cli list --format json")
  local ok, tabs = pcall(vim.fn.json_decode, tab_info)

  if ok then
    for _, tab in ipairs(tabs) do
      if tab.tab_title == "git" then
        -- Focus the existing tab
        local focus_cmd = string.format("wezterm.exe cli activate-tab --tab-id %d", tab.tab_id)
        vim.fn.system(focus_cmd)
        return
      end
    end
  end

  -- No git tab found, spawn new one
  local nvim_addr = vim.v.servername
  local spawn_cmd = string.format(
    "WEZTERM_LOG=error wezterm.exe cli spawn --domain-name WSL:Fedora --cwd %s -- zsh -lic 'export NVIM=\"%s\"; lazygit' 2>/dev/null",
    vim.fn.shellescape(cwd),
    nvim_addr:gsub('"', '\\"')
  )

  -- Spawn the new tab
  local result = vim.fn.system(spawn_cmd)
  local pane_id = tonumber(result:match("%d+"))

  if pane_id then
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
      local title_cmd = string.format('wezterm.exe cli set-tab-title --tab-id %d "git"', tab_id)
      vim.fn.system(title_cmd)

      -- Focus the tab
      local focus_cmd = string.format("wezterm.exe cli activate-tab --tab-id %d", tab_id)
      vim.fn.system(focus_cmd)
    end
  end
end

-- Main dispatcher function that detects terminal and calls appropriate handler
local function open_lazygit(cwd)
  local terminal = detect_terminal()

  if terminal == "kitty" then
    open_lazygit_in_kitty(cwd)
  else
    open_lazygit_in_wezterm(cwd)
  end
end

return {
  {
    "LazyVim/LazyVim",
    keys = {
      -- Disable default lazygit keymaps
      { "<leader>gg", false },
      { "<leader>gG", false },
      -- Add our custom ones
      {
        "<leader>gg",
        function()
          local git_root = LazyVim.root.git()
          open_lazygit(git_root)
        end,
        desc = "Lazygit (Root Dir)",
      },
      {
        "<leader>gG",
        function()
          open_lazygit()
        end,
        desc = "Lazygit (cwd)",
      },
    },
  },
}
