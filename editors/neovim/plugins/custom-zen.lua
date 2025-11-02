return {
  -- Plugin to center current pane
  {
    "shortcuts/no-neck-pain.nvim",

    config = function()
      local NoNeckPain = require("no-neck-pain")

      -- State storage for restoring settings when exiting zen mode
      local zen_state = {
        laststatus = nil,
        toggles = {},
      }

      --- NoNeckPain's buffer `vim.wo` options.
      ---@see window options `:h vim.wo`
      ---
      ---@type table
      --- Default values:
      ---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
      NoNeckPain.bufferOptionsWo = {
        ---@type boolean
        cursorline = false,
        ---@type boolean
        cursorcolumn = false,
        ---@type string
        colorcolumn = "0",
        ---@type boolean
        number = false,
        ---@type boolean
        relativenumber = false,
        ---@type boolean
        foldenable = false,
        ---@type boolean
        list = false,
        ---@type boolean
        wrap = true,
        ---@type boolean
        linebreak = true,
      }

      --- NoNeckPain's buffer `vim.bo` options.
      ---@see buffer options `:h vim.bo`
      ---
      ---@type table
      --- Default values:
      ---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
      NoNeckPain.bufferOptionsBo = {
        ---@type string
        filetype = "no-neck-pain",
        ---@type string
        buftype = "nofile",
        ---@type string
        bufhidden = "hide",
        ---@type boolean
        buflisted = false,
        ---@type boolean
        swapfile = false,
      }

      --- NoNeckPain's scratchPad buffer options.
      ---
      --- Leverages the side buffers as notepads, which work like any Neovim buffer and automatically saves its content at the given `location`.
      --- note: quitting an unsaved scratchPad buffer is non-blocking, and the content is still saved.
      ---
      ---@type table
      --- Default values:
      ---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
      NoNeckPain.bufferOptionsScratchPad = {
        -- When `true`, automatically sets the following options to the side buffers:
        -- - `autowriteall`
        -- - `autoread`.
        ---@type boolean
        enabled = false,
        -- The name of the generated file. See `location` for more information.
        -- /!\ deprecated /!\ use `pathToFile` instead.
        ---@type string
        ---@example: `no-neck-pain-left.norg`
        ---@deprecated: use `pathToFile` instead.
        fileName = "no-neck-pain",
        -- By default, files are saved at the same location as the current Neovim session.
        -- note: filetype is defaulted to `norg` (https://github.com/nvim-neorg/neorg), but can be changed in `buffers.bo.filetype` or |NoNeckPain.bufferOptions| for option scoped to the `left` and/or `right` buffer.
        -- /!\ deprecated /!\ use `pathToFile` instead.
        ---@type string?
        ---@example: `no-neck-pain-left.norg`
        ---@deprecated: use `pathToFile` instead.
        location = nil,
        -- The path to the file to save the scratchPad content to and load it in the buffer.
        ---@type string?
        ---@example: `~/notes.norg`
        pathToFile = "",
      }

      --- NoNeckPain's buffer color options.
      ---
      ---@type table
      --- Default values:
      ---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
      NoNeckPain.bufferOptionsColors = {
        -- Hexadecimal color code to override the current background color of the buffer. (e.g. #24273A)
        -- Transparent backgrounds are supported by default.
        -- popular theme are supported by their name:
        -- - catppuccin-frappe
        -- - catppuccin-frappe-dark
        -- - catppuccin-latte
        -- - catppuccin-latte-dark
        -- - catppuccin-macchiato
        -- - catppuccin-macchiato-dark
        -- - catppuccin-mocha
        -- - catppuccin-mocha-dark
        -- - github-nvim-theme-dark
        -- - github-nvim-theme-dimmed
        -- - github-nvim-theme-light
        -- - rose-pine
        -- - rose-pine-dawn
        -- - rose-pine-moon
        -- - tokyonight-day
        -- - tokyonight-moon
        -- - tokyonight-night
        -- - tokyonight-storm
        ---@type string?
        background = nil,
        -- Brighten (positive) or darken (negative) the side buffers background color. Accepted values are [-1..1].
        ---@type integer
        blend = 0,
        -- Hexadecimal color code to override the current text color of the buffer. (e.g. #7480c2)
        ---@type string?
        text = nil,
      }

      --- NoNeckPain's buffer side buffer option.
      ---
      ---@type table
      --- Default values:
      ---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
      NoNeckPain.bufferOptions = {
        -- When `false`, the buffer won't be created.
        ---@type boolean
        enabled = true,
        ---@see NoNeckPain.bufferOptionsColors `:h NoNeckPain.bufferOptionsColors`
        colors = NoNeckPain.bufferOptionsColors,
        ---@see NoNeckPain.bufferOptionsBo `:h NoNeckPain.bufferOptionsBo`
        bo = NoNeckPain.bufferOptionsBo,
        ---@see NoNeckPain.bufferOptionsWo `:h NoNeckPain.bufferOptionsWo`
        wo = NoNeckPain.bufferOptionsWo,
        ---@see NoNeckPain.bufferOptionsScratchPad `:h NoNeckPain.bufferOptionsScratchPad`
        scratchPad = NoNeckPain.bufferOptionsScratchPad,
      }

      NoNeckPain.setup({
        -- The width of the focused window that will be centered. When the terminal width is less than the `width` option, the side buffers won't be created.
        ---@type integer|"textwidth"|"colorcolumn"
        width = 120,

        -- Disables the plugin if the last valid buffer in the list have been closed.
        ---@type boolean
        disableOnLastBuffer = true,

        -- When `true`, deleting the main no-neck-pain buffer with `:bd`, `:bdelete` does not disable the plugin, it fallbacks on the newly focused window and refreshes the state by re-creating side-windows if necessary.
        ---@type boolean
        fallbackOnBufferDelete = false,

        --- Allows you to provide custom code to run before (pre) and after (post) no-neck-pain steps (e.g. enabling).
        --- See |NoNeckPain.callbacks|
        ---@type table
        callbacks = {
          postEnable = function(state)
            local Snacks = require("snacks")

            -- Save and hide statusline
            zen_state.laststatus = vim.opt.laststatus:get()
            vim.opt.laststatus = 0

            -- Save and disable UI elements
            zen_state.toggles.dim = Snacks.toggle.dim():get()
            Snacks.toggle.dim():set(false)

            zen_state.toggles.diagnostics = Snacks.toggle.diagnostics():get()
            Snacks.toggle.diagnostics():set(false)

            zen_state.toggles.inlay_hints = Snacks.toggle.inlay_hints():get()
            Snacks.toggle.inlay_hints():set(false)

            local gitsigns_ok, gitsigns = pcall(require, "gitsigns")
            if gitsigns_ok and gitsigns.toggle_signs then
              zen_state.toggles.git_signs = true
              gitsigns.toggle_signs(false)
            end

            zen_state.toggles.wrap = vim.opt.wrap
            vim.opt.wrap = true

            zen_state.toggles.colorcolumn = vim.opt.colorcolumn
            vim.opt.colorcolumn = 0

            -- Increase Kitty font size and line height
            vim.fn.system('kitten @ load-config --override modify_font="cell_height 120%"')
            vim.fn.system("kitten @ set-font-size +4")
          end,

          postDisable = function(state)
            local Snacks = require("snacks")

            -- Restore statusline
            vim.opt.laststatus = zen_state.laststatus

            -- Restore toggles
            Snacks.toggle.dim():set(zen_state.toggles.dim)
            Snacks.toggle.diagnostics():set(zen_state.toggles.diagnostics)
            Snacks.toggle.inlay_hints():set(zen_state.toggles.inlay_hints)

            local gitsigns_ok, gitsigns = pcall(require, "gitsigns")
            if gitsigns_ok and gitsigns.toggle_signs then
              gitsigns.toggle_signs(zen_state.toggles.git_signs)
            end

            vim.opt.wrap = zen_state.toggles.wrap
            vim.opt.colorcolumn = zen_state.toggles.colorcolumn

            -- Reset Kitty font size and line height
            vim.fn.system('kitten @ load-config --override modify_font="cell_height 100%"')
            vim.fn.system("kitten @ set-font-size 0")

            -- Clear state
            zen_state = {
              laststatus = nil,
              toggles = {},
            }
          end,
        },

        --- Common options that are set to both side buffers.
        --- See |NoNeckPain.bufferOptions| for option scoped to the `left` and/or `right` buffer.
        ---@type table
        buffers = {
          colors = {
            background = "catppuccin-mocha",
            blend = -0.1, -- Darken side buffers
          },

          -- Vim buffer-scoped options: any `vim.bo` options is accepted here.
          ---@see NoNeckPain.bufferOptionsBo `:h NoNeckPain.bufferOptionsBo`
          bo = NoNeckPain.bufferOptionsBo,

          -- Vim window-scoped options: any `vim.wo` options is accepted here.
          ---@see NoNeckPain.bufferOptionsWo `:h NoNeckPain.bufferOptionsWo`
          ---
          wo = NoNeckPain.bufferOptionsWo,
        },
      })

      -- Reset Kitty settings on Neovim exit (in case zen mode wasn't properly disabled)
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          vim.fn.system('kitten @ load-config --override modify_font="cell_height 100%"')
          vim.fn.system("kitten @ set-font-size 0")
        end,
      })
    end,
  },
}
