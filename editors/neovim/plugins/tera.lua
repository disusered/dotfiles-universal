vim.filetype.add({
  pattern = {
    [".*/arch/hypr[^/]+/.+%.conf"] = "hyprlang",
    [".*/tools/kitty/.+%.conf"] = "kitty",
    [".*/tools/mako/config"] = "dosini",
    [".*/arch/waybar/config"] = "jsonc",
    [".*/arch/dolphin/.+"] = "dosini",
  },
})

vim.treesitter.language.register("bash", "kitty")

local function setup_tera_injection(event)
  local bufnr = event.buf
  local base_path = vim.fn.expand("%:p"):match("(.+)%.tera$")

  local language = "html"
  if base_path then
    local ft = vim.filetype.match({ filename = base_path })
    if ft then
      language = vim.treesitter.language.get_lang(ft) or ft
    else
      local ext = base_path:match("%.(%w+)$")
      if ext then
        language = ext
      end
    end
  end

  local injection_query =
    string.format('((content) @injection.content (#set! injection.language "%s") (#set! injection.combined))', language)

  vim.treesitter.stop(bufnr)
  vim.treesitter.query.set("tera", "injections", injection_query)
  vim.treesitter.start(bufnr, "tera")
end

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.tera",
  callback = setup_tera_injection,
  desc = "Setup TreeSitter language injection for .tera template files",
})

return {}
