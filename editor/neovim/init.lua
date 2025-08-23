-- Prepend mise shims to PATH
-- TODO: Only do this for windows
vim.env.PATH = vim.env.HOME .. "\\AppData\\Local\\mise\\shims:" .. vim.env.PATH

require("config.lazy")

-- Add lua debug helper
local function dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then
        k = '"' .. k .. '"'
      end
      s = s .. "[" .. k .. "] = " .. dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

function _G.dump(o)
  vim.notify(dump(o), vim.log.levels.INFO, {
    title = "debug",
  })
end
