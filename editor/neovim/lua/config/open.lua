-- Save the original vim.ui.open function
local original_ui_open = vim.ui.open

-- Override vim.ui.open if wslview is available
vim.ui.open = function(url, opts)
  -- Check if wslview is available and if the input is a URL
  if vim.fn.executable("wslview") == 1 and url:match("^https?://") then
    -- Use wslview to open the URL in the default Windows browser
    -- jobstart is used to run the command asynchronously without blocking Neovim
    vim.fn.jobstart({ "wslview", url }, { detach = true })
  else
    -- Fallback to the original function for local files or other cases
    original_ui_open(url, opts)
  end
end
