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
    opts = {
      -- NOTE: The log_level is in `opts.opts`
      opts = {
        log_level = "DEBUG", -- or "TRACE"
      },

      display = {
        action_palette = {
          provider = "snacks", -- Can be "default", "telescope", "fzf_lua", "mini_pick" or "snacks". If not specified, the plugin will autodetect installed providers.
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
    ft = {
      -- "markdown",
      "codecompanion",
    },
  },
  -- TODO: Paste images
  -- https://codecompanion.olimorris.dev/installation.html#img-clip-nvim
}
