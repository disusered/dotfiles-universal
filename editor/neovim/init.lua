-- Prepend mise shims to PATH
if vim.loop.os_uname().sysname == "Windows_NT" then
  vim.env.PATH = vim.env.HOME .. "\\AppData\\Local\\mise\\shims:" .. vim.env.PATH
else
  vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH
end

require("config.lazy")

-- Override vim.ui.open
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

-- Add lua debug helper
local function dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then
        k = '"' .. k .. '"'
      end
      s = s .. "[" .. k .. "] = " .. dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

function _G.dump(o)
  vim.notify(dump(o), vim.log.levels.INFO, {
    title = "debug",
  })
end
