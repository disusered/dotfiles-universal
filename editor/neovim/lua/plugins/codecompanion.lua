-- TODO: MCP
-- https://codecompanion.olimorris.dev/installation.html#installing-extensions or ACP Gemini

-- TODO: VectorCode
-- https://github.com/Davidyz/VectorCode/blob/main/docs/cli.md#installation
-- https://github.com/Davidyz/VectorCode/blob/main/docs/neovim/README.md
return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    init = function()
      -- Use snacks to create a toggle for CodeCompanion chat
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          local Snacks = require("snacks")

          Snacks.toggle.new({
            id = "codecompanion_chat",
            name = "CodeCompanion Chat",
            notify = false,
            get = function()
              -- Check if a codecompanion buffer is visible in any window
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                local bufnr = vim.api.nvim_win_get_buf(win)
                if vim.bo[bufnr].filetype == "codecompanion" then
                  return true
                end
              end
              return false
            end,
            set = function(enabled)
              -- Use the correct functions to open/close
              if enabled then
                require("codecompanion").chat()
              else
                require("codecompanion").close_last_chat()
              end
            end,
          })
        end,
      })
    end,
    config = function(_, opts)
      local spinner = require("plugins.codecompanion.spinner")
      spinner:init()

      -- Setup the entire opts table
      require("codecompanion").setup(opts)
    end,
    keys = {
      { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
      {
        "<leader>aa",
        function()
          require("snacks").toggle.get("codecompanion_chat"):toggle()
        end,
        desc = "Toggle (CodeCompanion)",
        mode = { "n", "v" },
      },
      {
        "<leader>ax",
        function()
          return require("codecompanion").close_last_chat()
        end,
        mode = { "n", "v" },
      },
      {
        "<leader>av",
        function()
          local selection = vim.fn.expand("%:p")
          if selection and selection ~= "" then
            require("codecompanion").add({ source = selection })
            vim.notify("Added " .. selection .. " to CodeCompanion context")
          else
            vim.notify("No selection to add to context", vim.log.levels.WARN)
          end
        end,
        desc = "Add Selection (CodeCompanion)",
        mode = { "v" },
      },
      {
        "<leader>aq",
        function()
          vim.ui.input({
            prompt = "Quick Chat: ",
          }, function(input)
            if input and input ~= "" then
              require("codecompanion").cmd(input)
            end
          end)
        end,
        desc = "Quick Chat (CodeCompanion)",
        mode = { "n", "v" },
      },
      {
        "<leader>ap",
        function()
          require("codecompanion").actions()
        end,
        desc = "Prompt Actions (CodeCompanion)",
        mode = { "n", "v" },
      },
    },
    opts = {
      -- NOTE: The log_level is in `opts.opts`
      opts = {
        log_level = "DEBUG", -- or "TRACE"
      },

      display = {
        action_palette = {
          -- FIXME: snacks does not work with chat selector
          provider = "default", -- Can be "default", "telescope", "fzf_lua", "mini_pick" or "snacks". If not specified, the plugin will autodetect installed providers.
          opts = {
            show_default_actions = true, -- Show the default actions in the action palette?
            show_default_prompt_library = true, -- Show the default prompt library in the action palette?
            title = "CodeCompanion actions", -- The title of the action palette
          },
        },
      },

      -- Strategies
      strategies = {
        chat = {
          adapter = "gemini_cli",
          keymaps = {
            send = {
              modes = { n = "<CR>", i = "<C-s>" },
              opts = {},
            },
          },
          actions = {
            send = {
              callback = function(chat)
                vim.cmd("stopinsert")
                chat:submit()
                chat:add_buf_message({ role = "llm", content = "" })
              end,
              index = 1,
              description = "Send",
            },
          },
        },
        inline = {
          adapter = "gemini_cli",
        },
        cmd = {
          adapter = "gemini_cli",
        },
      },

      -- Adapters
      adapters = {
        acp = {
          gemini_cli = function()
            return require("codecompanion.adapters").extend("gemini_cli", {
              commands = {
                flash = {
                  "gemini",
                  "--experimental-acp",
                  "-m",
                  "gemini-2.5-flash",
                },
                pro = {
                  "gemini",
                  "--experimental-acp",
                  "-m",
                  "gemini-2.5-pro",
                },
              },
              defaults = {
                -- auth_method = "gemini-api-key", -- "oauth-personal" | "gemini-api-key" | "vertex-ai"
                auth_method = "oauth-personal",
                -- TODO: Update docs
                -- TODO: These should be project-specific, or at least use Gemini's local settings
                mcpServers = {
                  -- Browser control
                  {
                    name = "chrome-mcp-server",
                    command = "npx",
                    args = { "-y", "mcp-remote", "http://127.0.0.1:12306/mcp" },
                    env = {},
                  },
                  -- Confluence/Jira
                  {
                    name = "atlassian",
                    command = "npx",
                    args = { "-y", "mcp-remote", "https://mcp.atlassian.com/v1/sse" },
                    env = {},
                  },
                  -- Postgres for BrillAI
                  {
                    name = "postgres",
                    command = "uv",
                    args = {
                      "tool",
                      "run",
                      "postgres-mcp",
                      "--access-mode=unrestricted",
                    },
                    env = {
                      {
                        name = "DATABASE_URI",
                        value = "postgresql://postgres:admin@localhost:5432/brillai",
                      },
                    },
                  },
                },
              },
            })
          end,
        },
      },
    },
  },
  -- Enable completion with blink
  -- https://codecompanion.olimorris.dev/installation.html#completion
  {
    "saghen/blink.cmp",
    dependencies = {
      "olimorris/codecompanion.nvim",
    },
    opts = {
      sources = {
        per_filetype = {
          codecompanion = { "codecompanion" },
        },
      },
    },
  },
  -- Preview markdown with codecompanion
  -- https://codecompanion.olimorris.dev/installation.html#render-markdown-nvim
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = function()
      return {
        "codecompanion",
      }
    end,
  },
  -- TODO: Paste images
  -- https://codecompanion.olimorris.dev/installation.html#img-clip-nvim
}
