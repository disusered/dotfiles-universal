local function detect_terminal()
  local kitty_listen = vim.env.KITTY_LISTEN_ON
  local term = vim.env.TERM
  if kitty_listen or (term and term:match("kitty")) then
    return "kitty"
  end
  return "terminal"
end

local function run_in_kitty_tab(task_name)
  local cwd = vim.fn.getcwd()
  local inner = string.format('cfg run "%s"', task_name:gsub("'", "'\\''"))
  local spawn = string.format(
    "kitty @ launch --type=tab --tab-title %s --cwd %s -- zsh -lic '%s'",
    vim.fn.shellescape(task_name),
    vim.fn.shellescape(cwd),
    inner
  )
  vim.fn.system(spawn)
end

local function pick_and_run()
  vim.system({ "cfg", "run", "--list", "--json" }, { text = true }, function(obj)
    if obj.code ~= 0 then
      vim.schedule(function()
        vim.notify("cfg run --list failed: " .. (obj.stderr or ""), vim.log.levels.ERROR)
      end)
      return
    end

    local ok, data = pcall(vim.fn.json_decode, obj.stdout)
    if not ok or not data.tasks then
      vim.schedule(function()
        vim.notify("Failed to parse cfg tasks", vim.log.levels.ERROR)
      end)
      return
    end

    if #data.tasks == 0 then
      vim.schedule(function()
        vim.notify("No cfg tasks found", vim.log.levels.WARN)
      end)
      return
    end

    local names = {}
    for _, task in ipairs(data.tasks) do
      table.insert(names, task.name)
    end

    vim.schedule(function()
      Snacks.picker.select(names, { prompt = "cfg run" }, function(choice)
        if not choice then return end
        if detect_terminal() == "kitty" then
          run_in_kitty_tab(choice)
        else
          vim.cmd("botright 15split | terminal cfg run " .. vim.fn.shellescape(choice))
        end
      end)
    end)
  end)
end

return {
  {
    "folke/snacks.nvim",
    optional = true,
    keys = {
      { "<leader>rr", pick_and_run, desc = "Run task (cfg)" },
      {
        "<leader>ru",
        function()
          vim.system({ "cfg", "up" }, { text = true }, function(obj)
            vim.schedule(function()
              local msg = obj.code == 0 and "cfg up started" or "cfg up failed: " .. (obj.stderr or "")
              vim.notify(msg, obj.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
            end)
          end)
        end,
        desc = "Start processes (cfg up)",
      },
      {
        "<leader>rd",
        function()
          vim.system({ "cfg", "down" }, { text = true }, function(obj)
            vim.schedule(function()
              local msg = obj.code == 0 and "cfg down" or "cfg down failed: " .. (obj.stderr or "")
              vim.notify(msg, obj.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
            end)
          end)
        end,
        desc = "Stop processes (cfg down)",
      },
    },
  },
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>r", group = "run" },
      },
    },
  },
}
