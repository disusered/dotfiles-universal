return {
  {
    "benlubas/molten-nvim",
    lazy = false,
    version = "^1.0.0",
    dependencies = {
      "3rd/image.nvim",
      "3rd/diagram.nvim",
      "HakonHarnes/img-clip.nvim",
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
