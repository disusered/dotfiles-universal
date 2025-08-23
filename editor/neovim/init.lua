require("config.shims")
require("config.lazy")
require("config.open")

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
