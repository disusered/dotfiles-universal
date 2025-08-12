-- Prepend mise shims to PATH
vim.env.PATH = vim.env.HOME .. "\\AppData\\Local\\mise\\shims:" .. vim.env.PATH

require("config.lazy")
