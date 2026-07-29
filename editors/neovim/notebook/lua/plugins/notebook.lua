return {
  {
    "3rd/image.nvim",
    ft = { "quarto" },
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "snacks_notif" },
      integrations = {
        markdown = {
          enabled = true,
          download_remote_images = false,
          filetypes = { "quarto" },
          clear_in_insert_mode = false,
          only_render_image_at_cursor = false,
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "markdown", "markdown_inline", "python", "yaml" },
    },
  },
}
