local M = {
  processing = false,
  spinner_index = 1,
  namespace_id = nil,
  timer = nil,
  spinner_symbols = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  filetype = "codecompanion",
}

function M:_get_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == self.filetype then
      return buf
    end
  end
  return nil
end

function M:_update()
  if not self.processing then
    self:stop()
    return
  end

  self.spinner_index = (self.spinner_index % #self.spinner_symbols) + 1
  local buf = self:_get_buf()
  if not buf then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, self.namespace_id, 0, -1)
  local last_line = vim.api.nvim_buf_line_count(buf) - 1
  vim.api.nvim_buf_set_extmark(buf, self.namespace_id, last_line, 0, {
    virt_lines = { { { self.spinner_symbols[self.spinner_index] .. " Processing...", "Comment" } } },
  })
end

function M:start()
  self.processing = true
  self.spinner_index = 0
  if self.timer then
    self.timer:stop()
    self.timer:close()
  end
  self.timer = vim.loop.new_timer()
  self.timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      self:_update()
    end)
  )
end

function M:stop()
  self.processing = false
  if self.timer then
    self.timer:stop()
    self.timer:close()
    self.timer = nil
  end
  local buf = self:_get_buf()
  if buf then
    vim.api.nvim_buf_clear_namespace(buf, self.namespace_id, 0, -1)
  end
end

function M:init()
  self.namespace_id = vim.api.nvim_create_namespace("CodeCompanionSpinner")
end

return M
