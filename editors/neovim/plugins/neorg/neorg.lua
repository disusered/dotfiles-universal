return {
  {
    "nvim-neorg/neorg",
    dependencies = { "benlubas/neorg-interim-ls" },
    lazy = false,
    version = false,
    config = function()
      require("neorg").setup({
        load = {
          ["core.defaults"] = {}, -- Loads default behavior
          ["core.concealer"] = {
            config = {
              icons = {
                todo = {
                  uncertain = {
                    icon = "",
                  },
                  cancelled = {
                    icon = "",
                  },
                  recurring = {
                    icon = "󰔟",
                  },
                },
              },
            },
          },
          ["core.dirman"] = {
            config = {
              workspaces = {
                notes = "~/Documents/notes",
                study = "~/Documents/study",
                projects = "~/Documents/projects",
                blog = "~/Documents/blog",
              },
              default_workspace = "notes",
            },
          },
          ["core.completion"] = {
            config = {
              engine = "nvim-cmp",
              name = "neorg",
            },
          },
          ["core.export"] = {},
          ["core.export.markdown"] = {
            config = {
              extensions = "all",
            },
          },
        },
      })
    end,
    keys = {
      -- Workspace picker
      {
        "<leader>oo",
        function()
          local neorg = require("neorg")
          local dirman = neorg.modules.get_module("core.dirman")
          local workspaces = dirman.get_workspaces()

          -- Build items list for picker (exclude 'default' workspace)
          local items = {}
          for name, _ in pairs(workspaces) do
            if name ~= "default" then
              table.insert(items, { text = name, name = name })
            end
          end

          -- Sort alphabetically
          table.sort(items, function(a, b)
            return a.name < b.name
          end)

          Snacks.picker({
            title = "Neorg Workspaces",
            layout = { preset = "default", preview = false },
            items = items,
            format = function(item)
              return { { item.text } }
            end,
            confirm = function(picker, item)
              picker:close()

              -- Get the target workspace path (returns a PathlibPath object)
              local workspace_path = tostring(dirman.get_workspace(item.name))
              local expanded_target = vim.fn.expand(workspace_path)

              -- Close buffers from other workspaces
              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(buf) then
                  local buf_name = vim.api.nvim_buf_get_name(buf)
                  -- Check if it's a .norg file
                  if buf_name:match("%.norg$") then
                    -- Check if it's NOT in the target workspace
                    if not buf_name:find(expanded_target, 1, true) then
                      vim.api.nvim_buf_delete(buf, { force = false })
                    end
                  end
                end
              end

              vim.cmd("Neorg workspace " .. item.name)
            end,
          })
        end,
        desc = "Open workspace",
      },
      -- Toggle concealer
      {
        "<leader>oc",
        ":Neorg toggle-concealer<CR>",
        desc = "Toggle concealer",
      },
      -- Search notes in current workspace
      {
        "<leader>on",
        function()
          local neorg = require("neorg")
          local dirman = neorg.modules.get_module("core.dirman")
          local current_workspace = dirman.get_current_workspace()

          if current_workspace[1] == "default" then
            vim.notify("Not in a Neorg workspace", vim.log.levels.WARN)
            return
          end

          local workspace_path = current_workspace[2]

          Snacks.picker.files({
            cwd = workspace_path,
            hidden = false,
            glob = "**/*.norg",
          })
        end,
        desc = "Search notes (current workspace)",
      },
      -- Export to markdown
      {
        "<leader>om",
        function()
          local current_file = vim.fn.expand("%:p")
          if not current_file:match("%.norg$") then
            vim.notify("Not a Neorg file", vim.log.levels.WARN)
            return
          end

          -- Get filename without extension
          local filename = vim.fn.fnamemodify(current_file, ":t:r")

          -- Create export directory
          local export_dir = vim.fn.expand("~/Documents/exports")
          vim.fn.mkdir(export_dir, "p")

          -- Build output path
          local output_file = export_dir .. "/" .. filename .. ".md"

          -- Execute export command
          vim.cmd("Neorg export to-file " .. output_file)
          vim.notify("Exported to: " .. output_file, vim.log.levels.INFO)
        end,
        desc = "Export to markdown",
      },
      -- Toggle table of contents
      {
        "<leader>os",
        function()
          -- Check if TOC window is open by looking for a buffer with filetype "norg-toc"
          local toc_open = false
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.api.nvim_buf_get_option(buf, "filetype")
            if ft == "norg-toc" then
              toc_open = true
              break
            end
          end

          if toc_open then
            vim.cmd("Neorg toc close")
          else
            vim.cmd("Neorg toc right")
          end
        end,
        desc = "Toggle table of contents",
      },
      -- Inject metadata
      {
        "<leader>oi",
        ":Neorg inject-metadata<CR>",
        desc = "Inject metadata",
      },
    },
  },

  -- Set icon and text for group
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          "<leader>o",
          name = "+org",
          icon = {
            icon = " ",
            color = "red",
          },
          mode = "nv",
        },
      },
    },
  },

  -- Autocomplete using blink.compat
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        -- enable new provider
        default = { "neorg" },

        providers = {
          -- create provider
          neorg = {
            name = "neorg",
            module = "blink.compat.source",
          },
        },
      },
    },
  },
}
