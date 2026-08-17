vim.g.maplocalleader = "\\"
vim.g.python3_host_prog = vim.fn.expand("~/.local/share/virtualenvs/neovim/bin/python3")
vim.g.snacks_animate = false

vim.o.winborder = "rounded"
vim.opt.conceallevel = 0
vim.opt.cursorline = false
vim.opt.softtabstop = 2
vim.opt.gdefault = true
vim.opt.wildignore:append({ ".git*", ".hg*", ".svn*", "node_modules/**" })
vim.opt.relativenumber = false

vim.cmd("command! WQ wq")
vim.cmd("command! Wq wq")
vim.cmd("command! Wqa wqa")
vim.cmd("command! W w")
vim.cmd("command! Q q")

vim.opt.diffopt:append("vertical")
vim.o.winminheight = 0
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.showbreak = " …"
vim.opt.colorcolumn = "80"
vim.opt.splitbelow = false

vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.lsp.log.set_level("OFF")

vim.o.undofile = true
vim.o.formatoptions = "jncql"
vim.opt.spelllang = { "en_us", "es" }
vim.opt.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]
vim.opt.autoread = true
vim.opt.exrc = true
vim.opt.secure = false

if vim.fn.system("uname -a"):match("WSL") then
  vim.g.clipboard = {
    name = "win32yank-wsl",
    copy = {
      ["+"] = "win32yank.exe -i --crlf",
      ["*"] = "win32yank.exe -i --crlf",
    },
    paste = {
      ["+"] = "win32yank.exe -o --lf",
      ["*"] = "win32yank.exe -o --lf",
    },
    cache_enabled = 1,
  }
end
