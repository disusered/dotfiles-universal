local M = {
  processing = false,
}

-- Map events to notification messages and log levels
local event_map = {
  -- These two are somewhat redundant unless we get rid of the start/stop vim.notifys
  -- CodeCompanionChatSubmitted = { msg = "Chat submitted for processing." },
  -- CodeCompanionChatDone = { msg = "Chat response received." },
  CodeCompanionChatStopped = { msg = "Chat stopped by user." },
  CodeCompanionChatPin = { msg = "Context pin updated." },
  CodeCompanionToolsStarted = { msg = "Tools started." },
  CodeCompanionToolsFinished = { msg = "Tools finished." },
  CodeCompanionInlineStarted = { msg = "Inline action started." },
  CodeCompanionInlineFinished = { msg = "Inline action finished." },
}

---Generic function to trigger notifications based on the event map
---@param event_name string The name of the User event
function M:trigger(event_name)
  local event_config = event_map[event_name]
  if event_config then
    print("🤖 " .. event_config.msg)
  end
end

---Special handler for the start of an API request
function M:start()
  self.processing = true
  vim.notify("🤖 Processing...", vim.log.levels.INFO, {
    title = "Code Companion",
    replace = "codecompanion_spinner",
    hide_from_history = true,
  })
end

---Special handler for the end of an API request
function M:stop()
  if not self.processing then
    return
  end
  self.processing = false
  vim.notify("🤖 Request finished.", vim.log.levels.INFO, {
    title = "Code Companion",
    replace = "codecompanion_spinner",
  })
end

function M:init()
  -- No setup needed
end

return M
