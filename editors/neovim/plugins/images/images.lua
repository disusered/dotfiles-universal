return {
  -- Image rendering in Neovim
  {
    "3rd/image.nvim",
    opts = {
      backend = "kitty",
      processor = "magick_rock", -- "magick_cli" or "magick_rock"
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
          filetypes = { "markdown", "vimwiki", "quarto" },
          clear_in_insert_mode = false,
          only_render_image_at_cursor = false,
          only_render_image_at_cursor_mode = "inline", -- "inline" or "popup"
        },
        neorg = {
          enabled = true,
          download_remote_images = true,
          filetypes = { "norg" },
          clear_in_insert_mode = false,
          only_render_image_at_cursor = false,
          only_render_image_at_cursor_mode = "inline", -- "inline" or "popup"
        },
        html = {
          enabled = true,
          download_remote_images = true,
          filetypes = { "html", "xhtml", "htm", "markdown", "quarto" },
          clear_in_insert_mode = false,
          only_render_image_at_cursor = false,
          only_render_image_at_cursor_mode = "inline", -- "inline" or "popup"
        },
      },
    },
  },
  {
    -- Diagram rendering in Neovim
    "3rd/diagram.nvim",
    dependencies = { "3rd/image.nvim" },
    config = function()
      -- Extend markdown integration with Quarto filetype
      local markdown_integration = require("diagram.integrations.markdown")
      table.insert(markdown_integration.filetypes, "quarto")

      require("diagram").setup({
        integrations = {
          markdown_integration,
          require("diagram.integrations.neorg"),
        },
        renderer_options = {
          mermaid = {
            theme = "default",
          },
          plantuml = {
            charset = "utf-8",
          },
          d2 = {
            theme_id = 1,
          },
          gnuplot = {
            theme = "dark",
            size = "800,600",
          },
        },
      })
    end,
    keys = {
      {
        "K",
        function()
          require("diagram").show_diagram_hover()
        end,
        mode = "n",
        ft = { "markdown", "quarto", "norg" },
        desc = "Show diagram in new tab",
      },
    },
  },

  -- Paste an image from the clipboard or drag-and-drop
  {
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

          norg = {
            url_encode_path = false, ---@type boolean | fun(): boolean
            template = ".image $FILE_PATH", ---@type string | fun(context: table): string
            download_images = false, ---@type boolean | fun(): boolean
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
      {
        "<leader>oI",
        ":PasteImage<cr>",
        mode = "n",
        desc = "Paste image",
        ft = "norg",
      },
    },
  },

  -- Add keymap for selecting an image
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>si", false },
    },
  },
  {
    "LazyVim/LazyVim",
    keys = {
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
}
