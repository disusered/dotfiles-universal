return {
  "tpope/vim-eunuch",
  vscode = true,
  cond = function()
    return vim.loop.os_uname().sysname == "Linux"
  end,
}
