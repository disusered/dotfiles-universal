local M = {}

local spinner = require("plugins.codecompanion.spinner")
local notifier = require("plugins.codecompanion.notifier")

function M:init()
  spinner:init()
  notifier:init()

  vim.api.nvim_create_augroup("CodeCompanionHooks", { clear = true })
  local group = vim.api.nvim_create_augroup("CodeCompanionHooks", {})

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanion*", -- Listen for ALL CodeCompanion events
    group = group,
    callback = function(request)
      local event = request.match
      if event == "CodeCompanionRequestStarted" then
        spinner:start()
        notifier:start()
      elseif event == "CodeCompanionRequestFinished" then
        spinner:stop()
        notifier:stop()
      else
        -- For all other events, use the generic trigger
        notifier:trigger(event)
      end
    end,
  })
end

return M
