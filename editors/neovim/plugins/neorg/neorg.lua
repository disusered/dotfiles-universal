return {
  {
    "nvim-neorg/neorg",
    dependencies = { "benlubas/neorg-interim-ls" },
    lazy = false,
    version = false,
    init = function()
      local Snacks = require("snacks")

      -- Helper function to check if ToC is open and get the window
      local function get_toc_state()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          local buf_name = vim.api.nvim_buf_get_name(buf)
          if buf_name:match("^neorg://toc%-") then
            return true, win
          end
        end
        return false, nil
      end

      Snacks.toggle
        .new({
          name = "Table of Contents",
          get = function()
            local is_open, _ = get_toc_state()
            return is_open
          end,
          set = function(enabled)
            local is_open, toc_win = get_toc_state()
            if enabled and not is_open then
              vim.cmd("Neorg toc right")
            elseif not enabled and is_open then
              vim.api.nvim_win_close(toc_win, false)
            end
          end,
        })
        :map("<leader>os")
    end,
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
          ["core.summary"] = {},
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
      -- Toggle table of contents (handled via init function below)
      -- This placeholder ensures Which Key registers the keybinding
      -- Inject metadata
      {
        "<leader>oi",
        ":Neorg inject-metadata<CR>",
        desc = "Inject metadata",
      },
      -- Generate workspace summary
      {
        "<leader>ou",
        ":Neorg generate-workspace-summary<CR>",
        desc = "Generate workspace summary",
      },
      -- Neorg actions picker
      {
        "<leader>oa",
        function()
          local actions = {
            {
              text = "Generate Workspace Summary",
              action = function()
                vim.cmd("Neorg generate-workspace-summary")
              end,
            },
            {
              text = "Generate Summary (with metadata injection)",
              action = function()
                vim.cmd("Neorg inject-metadata")
                vim.defer_fn(function()
                  vim.cmd("Neorg generate-workspace-summary")
                end, 100)
              end,
            },
            {
              text = "Inject Metadata",
              action = function()
                vim.cmd("Neorg inject-metadata")
              end,
            },
            {
              text = "Export to Markdown",
              action = function()
                local current_file = vim.fn.expand("%:p")
                if not current_file:match("%.norg$") then
                  vim.notify("Not a Neorg file", vim.log.levels.WARN)
                  return
                end
                local filename = vim.fn.fnamemodify(current_file, ":t:r")
                local export_dir = vim.fn.expand("~/Documents/exports")
                vim.fn.mkdir(export_dir, "p")
                local output_file = export_dir .. "/" .. filename .. ".md"
                vim.cmd("Neorg export to-file " .. output_file)
                vim.notify("Exported to: " .. output_file, vim.log.levels.INFO)
              end,
            },
            {
              text = "Toggle Concealer",
              action = function()
                vim.cmd("Neorg toggle-concealer")
              end,
            },
            {
              text = "Paste Image",
              action = function()
                vim.cmd("PasteImage")
              end,
            },
          }

          Snacks.picker({
            title = "Neorg Actions",
            layout = { preset = "default", preview = false },
            items = actions,
            format = function(item)
              return { { item.text } }
            end,
            confirm = function(picker, item)
              picker:close()
              item.action()
            end,
          })
        end,
        desc = "Neorg actions",
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
