return {
  "echasnovski/mini.files",
  opts = {
    windows = {
      preview = true,
      width_focus = 40,
      width_preview = 80,
    },
    mappings = {
      -- Make 'l' (go_in) behave like 'L' (go_in_plus), which closes on file open
      go_in = "L",
      -- Optional: swap 'L' to do the original 'l' behavior (stay open)
      go_in_plus = "l",
    },
  },

  -- 1. Add the global keymap for `-` to open the explorer.
  keys = {
    {
      "-",
      function()
        local mini_files = require("mini.files")
        -- Only open if the explorer isn't already active
        if not mini_files.get_explorer_state() then
          local path = vim.api.nvim_buf_get_name(0)
          mini_files.open(path ~= "" and path or vim.uv.cwd(), true)
        end
      end,
      desc = "Open mini.files",
    },
  },

  -- 2. The config function sets your custom buffer-local keymaps.
  config = function(_, opts)
    -- This ensures the default setup from LazyVim still runs
    require("mini.files").setup(opts)

    -- Create an autocommand to set keymaps only inside the explorer buffer
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesBufferCreate",
      callback = function(args)
        local buf_id = args.data.buf_id
        local minifiles = require("mini.files")

        -- Close the explorer with `<Esc>`
        vim.keymap.set("n", "<Esc>", minifiles.close, { buffer = buf_id, desc = "Close explorer" })

        -- `-` to go up to the parent directory (this overrides the global keymap)
        vim.keymap.set("n", "-", minifiles.go_out, { buffer = buf_id, desc = "Go up directory" })

        -- `gh` to toggle showing hidden files (dotfiles)
        local show_dotfiles = true
        local filter_show = function(fs_entry)
          return true
        end
        local filter_hide = function(fs_entry)
          return not vim.startswith(fs_entry.name, ".")
        end
        local toggle_dotfiles = function()
          show_dotfiles = not show_dotfiles
          local new_filter = show_dotfiles and filter_show or filter_hide
          minifiles.refresh({ content = { filter = new_filter } })
        end
        vim.keymap.set("n", "gh", toggle_dotfiles, { buffer = buf_id, desc = "Toggle hidden files" })

        -- `<CR>` or `o` to open a file and close the explorer
        local go_in_and_close = function()
          minifiles.go_in({ close_on_file = true })
        end
        vim.keymap.set("n", "<CR>", go_in_and_close, { buffer = buf_id, desc = "Open and close" })

        -- Helper for split mappings that also closes the explorer
        local map_split_and_close = function(lhs, direction)
          local rhs = function()
            local state = minifiles.get_explorer_state()
            if state and state.target_window then
              local new_target = vim.api.nvim_win_call(state.target_window, function()
                vim.cmd("belowright " .. direction .. " split")
                return vim.api.nvim_get_current_win()
              end)
              minifiles.set_target_window(new_target)
              minifiles.go_in({ close_on_file = true })
            end
          end
          vim.keymap.set("n", lhs, rhs, { buffer = buf_id, desc = "Open in " .. direction .. " split" })
        end

        -- I am using the standard CTRL-s/v/t but you can change them
        map_split_and_close("<C-s>", "horizontal")
        map_split_and_close("<C-v>", "vertical")

        -- `<C-t>` to open in a new tab and close
        local open_in_tab = function()
          local entry = minifiles.get_fs_entry()
          if entry and entry.path and entry.fs_type == "file" then
            vim.cmd.tabedit(vim.fn.fnameescape(entry.path))
            minifiles.close()
          elseif entry and entry.fs_type == "directory" then
            minifiles.go_in()
          end
        end
        vim.keymap.set("n", "<C-t>", open_in_tab, { buffer = buf_id, desc = "Open in tab" })
      end,
    })
  end,
}
