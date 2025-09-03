-- TODO: VectorCode (Done)
-- https://github.com/Davidyz/VectorCode/blob/main/docs/cli.md#installation
-- https://github.com/Davidyz/VectorCode/blob/main/docs/neovim/README.md
return {
  {
    "olimorris/codecompanion.nvim",

    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "Davidyz/VectorCode",
      "folke/noice.nvim",
    },

    -- Use snacks to create a toggle for CodeCompanion chat
    init = function()
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

    -- Route notifications through our custom handler
    config = function(_, opts)
      local notifications = require("plugins.codecompanion.notifications")
      notifications:init()
      require("codecompanion").setup(opts)
    end,

    -- Keymaps
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

    -- Plugin options
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
          adapter = "copilot",
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
          adapter = "copilot",
        },
        cmd = {
          adapter = "copilot",
        },
      },

      -- Adapters
      adapters = {
        acp = {
          gemini_cli = function()
            return require("codecompanion.adapters").extend("gemini_cli", {
              commands = {
                default = {
                  "gemini",
                  "--experimental-acp",
                  "-m",
                  "gemini-1.5-flash", -- Updated to 1.5-flash from 2.5
                },
                pro = {
                  "gemini",
                  "--experimental-acp",
                  "-m",
                  "gemini-1.5-pro", -- Updated to 1.5-pro from 2.5
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
                  -- VectorCode MCP Server
                  -- {
                  --   name = "vectorcode-mcp-server",
                  --   command = "vectorcode-mcp-server",
                  --   args = {},
                  -- },
                },
              },
            })
          end,
        },
      },

      -- VectorCode Integration
      extensions = {
        vectorcode = {
          opts = {
            tool_group = {
              enabled = true,
              extras = {},
              collapse = false,
            },
            tool_opts = {
              ["*"] = {
                -- TODO: Set up with LSP
                -- Use LSP for a better experience (e.g., fidget notifications)
                -- This will be false if `async_backend` in VectorCode setup is not "lsp".
                use_lsp = false,
              },
              query = {
                max_num = { chunk = -1, document = -1 },
                default_num = { chunk = 50, document = 10 },
                no_duplicate = true, -- Avoid retrieving the same files again in a chat
                chunk_mode = false,
                summarise = {
                  enabled = false, -- Can be enabled dynamically by asking the LLM
                  adapter = nil, -- Use the chat adapter by default
                  query_augmented = true,
                },
              },
            },
          },
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
