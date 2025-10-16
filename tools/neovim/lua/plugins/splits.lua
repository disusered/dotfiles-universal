return {
  "mrjones2014/smart-splits.nvim",
  lazy = false,
  build = "./kitty/install-kittens.bash",
  opts = {
    at_edge = "stop",
    multiplexer_integration = "kitty",
  },
  keys = function()
    local smart_splits = require("smart-splits")
    return {
      { "<C-h>", smart_splits.move_cursor_left, "Go to the left pane" },
      { "<C-j>", smart_splits.move_cursor_down, "Go to the down pane" },
      { "<C-k>", smart_splits.move_cursor_up, "Go to the up pane" },
      { "<C-l>", smart_splits.move_cursor_right, "Go to the right pane" },
      { "<A-h>", smart_splits.resize_left, "Resize the left pane" },
      { "<A-j>", smart_splits.resize_down, "Resize the down pane" },
      { "<A-k>", smart_splits.resize_up, "Resize the up pane" },
      { "<A-l>", smart_splits.resize_right, "Resize the right pane" },
    }
  end,
}
