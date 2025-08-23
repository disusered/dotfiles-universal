-- Prepend mise shims to PATH
if vim.loop.os_uname().sysname == "Windows_NT" then
  vim.env.PATH = vim.env.HOME .. "\\AppData\\Local\\mise\\shims:" .. vim.env.PATH
else
  vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH
end
