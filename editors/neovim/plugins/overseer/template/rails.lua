---@param opts overseer.SearchParams
---@return nil|string
local function get_gemfile(opts)
  return vim.fs.find("Gemfile", { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return get_gemfile(opts)
  end,
  generator = function(opts)
    local gemfile = get_gemfile(opts)
    if not gemfile then
      return "No Gemfile found"
    end
    local cwd = vim.fs.dirname(gemfile)
    return {
      {
        name = "rails server",
        builder = function()
          return { cmd = { "bundle", "exec", "rails", "server" }, cwd = cwd }
        end,
      },
      {
        name = "rails console",
        builder = function()
          return { cmd = { "bundle", "exec", "rails", "console" }, cwd = cwd }
        end,
      },
      {
        name = "rake db:migrate",
        builder = function()
          return { cmd = { "bundle", "exec", "rake", "db:migrate" }, cwd = cwd }
        end,
      },
      {
        name = "rake db:seed",
        builder = function()
          return { cmd = { "bundle", "exec", "rake", "db:seed" }, cwd = cwd }
        end,
      },
      {
        name = "rake db:reset",
        builder = function()
          return { cmd = { "bundle", "exec", "rake", "db:reset" }, cwd = cwd }
        end,
      },
    }
  end,
}
