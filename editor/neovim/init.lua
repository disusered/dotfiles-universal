require("config.shims")
require("config.lazy")
require("config.open")

---
-- Creates a global dump function to inspect Lua objects with multi-line formatting.
-- It uses a recursive helper to "pretty-print" tables with proper indentation.
-- @param o The Lua object to display.
--
function _G.dump(o)
  ---
  -- Recursively formats a Lua value into a readable, indented string.
  -- @local
  -- @param val The value to format.
  -- @param indent_level The current indentation level (number of spaces).
  -- @return A formatted string representation of the value.
  --
  local function pretty_print(val, indent_level)
    indent_level = indent_level or 0
    local indent = string.rep("  ", indent_level)
    local next_indent = string.rep("  ", indent_level + 1)

    -- Handle non-table types first
    if type(val) == "string" then
      return string.format("%q", val) -- Properly quotes strings
    end
    if type(val) ~= "table" then
      return tostring(val)
    end

    -- Handle table type
    local lines = { "{" }
    for k, v in pairs(val) do
      -- Format the key (e.g., ["key"] or [1])
      local key_str = type(k) == "string" and string.format("[%q]", k) or string.format("[%s]", tostring(k))

      -- Recursively call for the value, increasing the indent level
      local value_str = pretty_print(v, indent_level + 1)

      table.insert(lines, string.format("%s%s = %s,", next_indent, key_str, value_str))
    end
    table.insert(lines, indent .. "}")

    -- Join all lines with a newline character
    return table.concat(lines, "\n")
  end

  -- Call the pretty-printer and display the result in a notification
  local formatted_string = pretty_print(o)
  print(formatted_string)
end
