if vim.loop.os_uname().sysname == "Windows_NT" then
  -- Prepend mise shims to PATH
  vim.env.PATH = vim.env.HOME .. "\\AppData\\Local\\mise\\shims:" .. vim.env.PATH
else
  -- Additional paths for non-Windows systems
  local mise_path = "/.local/share/mise/shims:"
  local mason_path = vim.fn.stdpath("data") .. "/mason:"
  local rocks_path = vim.fn.stdpath("data") .. "/lazy-rocks/hererocks/bin:"

  local path_parts = {
    vim.env.HOME .. "/.local/share/mise/shims",
    rocks_path,
    mason_path,
    -- retain the existing PATH
    vim.env.PATH,
  }

  -- Prepend mise shims, lazy-rocks, and mason to PATH
  vim.env.PATH = table.concat(path_parts, ":")
end
