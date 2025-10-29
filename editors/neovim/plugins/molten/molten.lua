return {
  {
    "benlubas/molten-nvim",
    lazy = false,
    version = "^1.0.0",
    dependencies = {
      {
        -- see the image.nvim readme for more information about configuring this plugin
        "3rd/image.nvim",
        opts = {
          backend = "kitty", -- whatever backend you would like to use
          max_width = 100,
          max_height = 12,
          max_height_window_percentage = math.huge,
          max_width_window_percentage = math.huge,
          window_overlap_clear_enabled = true, -- toggles images when windows are overlapped
          window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "snacks_notif" },
          integrations = {
            markdown = {
              enabled = true,
              download_remote_images = true,
              filetypes = { "markdown", "vimwiki", "quarto" }, -- markdown extensions (ie. quarto) can go here
              clear_in_insert_mode = false,
              only_render_image_at_cursor = true,
              only_render_image_at_cursor_mode = "inline", -- "inline" or "popup"
            },
            html = {
              enabled = true,
              clear_in_insert_mode = false,
              only_render_image_at_cursor = true,
              only_render_image_at_cursor_mode = "inline", -- "inline" or "popup"
            },
          },
        },
      },
      {
        "folke/snacks.nvim",
        keys = {
          -- Disable default snacks bind for icons
          { "<leader>si", false },
        },
      },
      {
        "LazyVim/LazyVim",
        keys = {
          -- Update binding to non-clashing uppercase I
          {
            "<leader>sI",
            function()
              Snacks.picker.pick("icons")
            end,
            mode = "n",
            desc = "Icons",
          },
          -- Add search for image
          {
            "<leader>si",
            function()
              Snacks.picker.files({
                ft = { "jpg", "jpeg", "png", "webp" },
                confirm = function(self, item, _)
                  self:close()
                  require("img-clip").paste_image({}, "./" .. item.file) -- ./ is necessary for img-clip to recognize it as path
                end,
              })
            end,
            -- TODO: Check if img-clip loaded
            mode = "n",
            desc = "Search images",
          },
        },
      },
      { -- paste an image from the clipboard or drag-and-drop
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- https://github.com/hakonharnes/img-clip.nvim?tab=readme-ov-file#setup
          {
            default = {
              -- file and directory options
              use_absolute_path = false, ---@type boolean | fun(): boolean
              relative_to_current_file = false, ---@type boolean | fun(): boolean

              -- logging options
              verbose = false, ---@type boolean | fun(): boolean

              -- image options
              -- TODO: Image optimization/minification
              -- process_cmd = "", ---@type string | fun(): string
              -- copy_images = false, ---@type boolean | fun(): boolean
              -- download_images = true, ---@type boolean | fun(): boolean
              -- formats = { "jpeg", "jpg", "png" }, ---@type string[]

              -- drag and drop options
              drag_and_drop = {
                enabled = true, ---@type boolean | fun(): boolean
                insert_mode = false, ---@type boolean | fun(): boolean
              },
            },

            -- filetype specific options
            filetypes = {
              markdown = {
                url_encode_path = true, ---@type boolean | fun(): boolean
                template = "![$CURSOR]($FILE_PATH)", ---@type string | fun(context: table): string
                download_images = false, ---@type boolean | fun(): boolean
              },

              quarto = {
                url_encode_path = true, ---@type boolean | fun(): boolean
                template = "![$CURSOR]($FILE_PATH)", ---@type string | fun(context: table): string
                download_images = false, ---@type boolean | fun(): boolean
              },

              html = {
                template = '<img src="$FILE_PATH" alt="$CURSOR">', ---@type string | fun(context: table): string
              },

              tex = {
                relative_template_path = false, ---@type boolean | fun(): boolean
                template = [[
\begin{figure}[h]
  \centering
  \includegraphics[width=0.8\textwidth]{$FILE_PATH}
  \caption{$CURSOR}
  \label{fig:$LABEL}
\end{figure}
    ]], ---@type string | fun(context: table): string

                formats = { "jpeg", "jpg", "png", "pdf" }, ---@type table
              },

              typst = {
                template = [[
#figure(
  image("$FILE_PATH", width: 80%),
  caption: [$CURSOR],
) <fig-$LABEL>
    ]], ---@type string | fun(context: table): string
              },
            },

            -- file, directory, and custom triggered options
            files = {}, ---@type table | fun(): table
            dirs = {}, ---@type table | fun(): table
            custom = {}, ---@type table | fun(): table
          },
        },
        keys = {
          {
            "<leader>ji",
            ":PasteImage<cr>",
            mode = "n",
            desc = "Paste image",
            ft = "quarto",
          },
        },
      },
    },
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
    end,
    config = function()
      -- Enable relative line numbers for Quarto files
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "quarto",
        group = vim.api.nvim_create_augroup("UserQuartoSettings", { clear = true }),
        callback = function()
          vim.wo.relativenumber = true
        end,
        desc = "Enable relative line numbers for Quarto",
      })

      -- Helper function: Initialize kernel (shows picker)
      local function molten_init()
        local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
        if venv ~= nil then
          vim.cmd("MoltenInit")
        else
          vim.notify("No virtualenv loaded", vim.log.levels.ERROR, { title = "Molten Init" })
        end

        -- FIXME: Update with Quarto
        -- vim.cmd("MoltenInit")
        -- -- Auto-activate Quarto if in a quarto file
        -- if vim.bo.filetype == "quarto" then
        --   vim.cmd("QuartoActivate")
        -- end
      end

      -- Helper functi
      -- Store functions globally for keymap access
      _G.molten_helpers = {
        init = molten_init,
      }
    end,
    keys = {
      -- Kernel Management
      {
        "<leader>jI",
        function()
          _G.molten_helpers.init()
        end,
        desc = "Initialize kernel",
        ft = "quarto",
      },
      {
        "<leader>j<esc>",
        ":MoltenInterrupt<CR>",
        desc = "Interrupt kernel",
        ft = "quarto",
      },

      -- Evaluate code with operator
      {
        "<leader>jo",
        ":MoltenEvaluateOperator<CR>",
        mode = "n",
        desc = "Evaluate with operator",
        ft = "quarto",
      },
      {
        "<leader>jl",
        ":MoltenEvaluateLine<CR>",
        mode = "n",
        desc = "Evaluate line",
        ft = "quarto",
      },
      {
        "<leader>jr",
        ":MoltenReevaluateCell<CR>",
        mode = "n",
        desc = "Re-evaluate cell",
        ft = "quarto",
      },
      {
        "<leader>jR",
        ":MoltenReevaluateAll<CR>",
        mode = "n",
        desc = "Re-evaluate all cells",
        ft = "quarto",
      },
      {
        "<leader>je",
        ":<C-u>MoltenEvaluateVisual<CR>gv",
        mode = "v",
        desc = "Evaluate visual selection",
        ft = "quarto",
      },

      -- Cell Navigation
      {
        "<leader>jn",
        ":MoltenNext<CR>",
        desc = "Next cell",
        ft = "quarto",
      },
      {
        "<leader>jp",
        ":MoltenPrev<CR>",
        desc = "Previous cell",
        ft = "quarto",
      },

      -- Output Management
      {
        "<leader>jO",
        ":noautocmd MoltenEnterOutput<CR>",
        desc = "Show/enter output",
        ft = "quarto",
      },
      {
        "<leader>jh",
        ":MoltenHideOutput<CR>",
        desc = "Hide output",
        ft = "quarto",
      },
      {
        "<leader>jx",
        ":MoltenImagePopup<CR>",
        desc = "Open image",
        ft = "quarto",
      },

      -- Cell Management
      {
        "<leader>jd",
        ":MoltenDelete<CR>",
        desc = "Delete cell",
        ft = "quarto",
      },
      {
        "<leader>jD",
        ":MoltenDelete!<CR>",
        desc = "Delete all cells",
        ft = "quarto",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          "<leader>j",
          name = "+jupyter",
          icon = {
            icon = "",
            color = "orange",
          },
          mode = "nv",
        },
      },
    },
  },
}
