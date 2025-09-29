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
  local spawn_cmd = string.format(
    "WEZTERM_LOG=error wezterm.exe cli spawn --domain-name WSL:Fedora --cwd %s -- zsh -lic 'lazygit' 2>/dev/null",
    vim.fn.shellescape(cwd)
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
          open_lazygit_in_wezterm(git_root)
        end,
        desc = "Lazygit (Root Dir)",
      },
      {
        "<leader>gG",
        function()
          open_lazygit_in_wezterm()
        end,
        desc = "Lazygit (cwd)",
      },
    },
  },
}
