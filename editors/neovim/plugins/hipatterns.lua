-- Define highlight groups with distinctive Catppuccin colors
local function setup_highlight_groups()
  vim.api.nvim_set_hl(0, "MiniHipatternsFixError", { fg = "#181825", bg = "#f38ba8", bold = true }) -- Red bg
  vim.api.nvim_set_hl(0, "MiniHipatternsTodoInfo", { fg = "#181825", bg = "#89b4fa", bold = true }) -- Blue bg
  vim.api.nvim_set_hl(0, "MiniHipatternsHackWarn", { fg = "#181825", bg = "#f9e2af", bold = true }) -- Yellow bg
  vim.api.nvim_set_hl(0, "MiniHipatternsWarnWarn", { fg = "#181825", bg = "#fab387", bold = true }) -- Peach bg
  vim.api.nvim_set_hl(0, "MiniHipatternsPerfDefault", { fg = "#181825", bg = "#cba6f7", bold = true }) -- Mauve bg
  vim.api.nvim_set_hl(0, "MiniHipatternsNoteHint", { fg = "#181825", bg = "#a6e3a1", bold = true }) -- Green bg
  vim.api.nvim_set_hl(0, "MiniHipatternsTestTest", { fg = "#181825", bg = "#94e2d5", bold = true }) -- Teal bg
end

-- TODO: I don't like this
-- INFO: Why is this black
-- FIXME: Not today
-- HACK: Cookie cutter
-- NOTE: Something else
-- WARN: Again repetitive
-- PERF: Ok I guess
-- TEST: Boring

return {
  { "folke/todo-comments.nvim", enabled = false },
  {
    "nvim-mini/mini.hipatterns",
    version = "*",
    config = function()
      setup_highlight_groups()

      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = setup_highlight_groups,
      })

      require("mini.hipatterns").setup({
        highlighters = {
          -- This pattern highlights the entire line containing the keyword
          fixme = { pattern = "^.*FIXME:.*$", group = "MiniHipatternsFixError" },
          todo = { pattern = "^.*TODO:.*$", group = "MiniHipatternsTodoInfo" },
          info = { pattern = "^.*INFO:.*$", group = "MiniHipatternsTodoInfo" },
          hack = { pattern = "^.*HACK:.*$", group = "MiniHipatternsHackWarn" },
          fix = { pattern = "^.*FIX:.*$", group = "MiniHipatternsFixError" },
          bug = { pattern = "^.*BUG:.*$", group = "MiniHipatternsFixError" },
          warn = { pattern = "^.*WARN:.*$", group = "MiniHipatternsWarnWarn" },
          note = { pattern = "^.*NOTE:.*$", group = "MiniHipatternsNoteHint" },
          perf = { pattern = "^.*PERF:.*$", group = "MiniHipatternsPerfDefault" },
          test = { pattern = "^.*TEST:.*$", group = "MiniHipatternsTestTest" },
        },
      })
    end,
  },
}
