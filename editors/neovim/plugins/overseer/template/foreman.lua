---@param opts overseer.SearchParams
---@return nil|string
local function get_procfile(opts)
  return vim.fs.find("Procfile", { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return get_procfile(opts)
  end,
  generator = function(opts)
    local procfile = get_procfile(opts)
    if not procfile then
      return "No Procfile found"
    end
    local cwd = vim.fs.dirname(procfile)
    return {
      {
        name = "foreman start",
        builder = function()
          return { cmd = { "foreman", "start" }, cwd = cwd }
        end,
      },
      {
        name = "foreman start <process>",
        params = {
          process = { type = "string", order = 1 },
        },
        builder = function(params)
          return { cmd = { "foreman", "start", params.process }, cwd = cwd }
        end,
      },
      {
        name = "foreman check",
        builder = function()
          return { cmd = { "foreman", "check" }, cwd = cwd }
        end,
      },
    }
  end,
}
