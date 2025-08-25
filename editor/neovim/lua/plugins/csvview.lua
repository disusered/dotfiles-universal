return {
  "hat0uma/csvview.nvim",
  cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
  init = function()
    -- Create a dedicated augroup to organize our autocommands
    local csv_augroup = vim.api.nvim_create_augroup("CsvViewCursorline", { clear = true })

    -- When csvview attaches to a buffer, enable cursorline for that window
    vim.api.nvim_create_autocmd("User", {
      pattern = "CsvViewAttach",
      group = csv_augroup,
      callback = function()
        vim.wo.cursorline = true
      end,
      desc = "Enable cursorline for csvview",
    })

    -- When csvview detaches, disable cursorline
    vim.api.nvim_create_autocmd("User", {
      pattern = "CsvViewDetach",
      group = csv_augroup,
      callback = function()
        vim.wo.cursorline = false
      end,
      desc = "Disable cursorline for csvview",
    })
  end,
  ---@module "csvview"
  ---@type CsvView.Options
  opts = {
    parser = { comments = { "#", "//" } },
    view = {
      display_mode = "border",
    },
    keymaps = {
      textobject_field_inner = { "if", mode = { "o", "x" } },
      textobject_field_outer = { "af", mode = { "o", "x" } },
      jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
      jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
      jump_next_row = { "<Enter>", mode = { "n", "v" } },
      jump_prev_row = { "<S-Enter>", mode = { "n", "v" } },
    },
  },
  keys = function()
    local csvview = require("csvview")
    local wk = require("which-key")
    wk.add({
      {
        "<leader>uv",
        function()
          if csvview.is_enabled() then
            csvview.disable()
          else
            csvview.enable()
          end
        end,
        desc = function()
          return csvview.is_enabled() and "Disable CSV View" or "Enable CSV View"
        end,
        icon = function()
          if csvview.is_enabled() then
            return { icon = "", color = "green" }
          else
            return { icon = "", color = "yellow" }
          end
        end,
      },
    })
  end,
}
