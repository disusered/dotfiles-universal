return {
  "lervag/vimtex",
  lazy = false, -- we don't want to lazy load VimTeX
  init = function()
    -- vim.g.tex_flavor = "latex"
    -- TODO: Use different viewer for Windows, WSL, Linux, MacOS
    vim.g.vimtex_view_method = "zathura" -- general | zathura | skim
    -- vim.g.vimtex_view_general_viewer = "wslview"
    vim.g.vimtex_quickfix_open_on_warning = 0
    vim.g.vimtex_compiler_method = "latexmk" -- latexmk | tectonic
  end,
}
