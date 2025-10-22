return {
  {
    "gruvw/strudel.nvim",
    build = "npm install",
    config = function()
      require("strudel").setup({
        -- Strudel web user interface related options
        ui = {
          maximise_menu_panel = false,
          hide_menu_panel = true,
          hide_top_bar = true,
          hide_code_editor = false,
          hide_error_display = false,
        },

        update_on_save = true,
        sync_cursor = true,
        report_eval_errors = true,
        -- custom_css_file = "/path/to/your/custom.css",
        browser_exec_path = "/usr/bin/chromium",
      })
    end,
    keys = {
      -- Hush (stop all)
      {
        "<localleader>h",
        function()
          require("strudel").stop()
        end,
        mode = "n",
        desc = "Hush (Stop)",
      },
      -- {
      --   "<c-h>",
      --   function()
      --     require("strudel").stop()
      --   end,
      --   mode = "n",
      --   desc = "Hush (Stop)",
      -- },

      -- Send/Evaluate code (Normal and Visual modes)
      {
        "<c-e>",
        function()
          require("strudel").update()
        end,
        mode = { "n", "v" },
        desc = "Update/Evaluate",
      },
      {
        "<localleader>s",
        function()
          require("strudel").update()
        end,
        mode = { "n", "v" },
        desc = "Send Line/Selection (Updates Buffer)",
      },
      {
        "<localleader>ss",
        function()
          require("strudel").update()
        end,
        mode = "n",
        desc = "Send Paragraph (Updates Buffer)",
      },

      -- STRUDEL-SPECIFIC MANAGEMENT COMMANDS
      {
        "<leader>ml",
        function()
          require("strudel").launch()
        end,
        desc = "Launch Strudel",
      },
      {
        "<leader>mq",
        function()
          require("strudel").quit()
        end,
        desc = "Quit Strudel",
      },
      {
        "<leader>mt",
        function()
          require("strudel").toggle()
        end,
        desc = "Toggle Play/Stop",
      },
      {
        "<leader>mb",
        function()
          require("strudel").set_buffer()
        end,
        desc = "Set Buffer",
      },
      {
        "<leader>mx",
        function()
          require("strudel").execute()
        end,
        desc = "Execute (Set Buffer & Update)",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          "<leader>m", -- [1] This is the key (lhs)
          name = "+music", -- This is the description
          icon = "", -- This is the icon attribute
        },
      },
    },
  },
}
