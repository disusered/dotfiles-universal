return {
  {
    "benlubas/molten-nvim",
    lazy = false, -- we don't want to lazy load VimTeX
    version = "^1.0.0", -- use version <2.0.0 to avoid breaking changes
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
    end,
    config = function()
      vim.keymap.set("n", "<localleader>ip", function()
        -- Get the active virtual environment path
        local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
        if venv ~= nil then
          -- Extract the last part of the path (e.g., "neovim" or ".venv")
          -- This logic works for both ~/.virtualenvs/my-env and /path/to/project/.venv
          venv = string.match(venv, "/.+/(.+)")
          vim.cmd(("MoltenInit"):format(venv))
        else
          -- Fallback to the default python3 kernel if no venv is active
          vim.cmd("MoltenInit python3")
        end
      end, { desc = "Initialize Molten for python3", silent = true })
    end,
  },
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
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    },
  },
}
