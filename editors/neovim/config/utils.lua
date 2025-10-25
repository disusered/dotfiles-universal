-- A reusable Lua module to find files with ripgrep and add them to a list of stylesheets.

local M = {}

--- Finds the best available ripgrep executable.
-- Prefers the Homebrew version if available, otherwise falls back to the PATH.
-- @return string|nil The path to the rg executable, or nil if not found.
local function find_rg_executable()
  -- Prefer the Homebrew-installed version of rg if available.
  local homebrew_prefix = os.getenv("HOMEBREW_PREFIX")
  if homebrew_prefix then
    local homebrew_rg = homebrew_prefix .. "/bin/rg"
    if vim.fn.executable(homebrew_rg) == 1 then
      return homebrew_rg
    end
  end

  -- Fallback to rg in the system's PATH.
  if vim.fn.executable("rg") == 1 then
    return "rg"
  end

  return nil
end

function M.print()
  print("utils module loaded")
end

--- Builds a list of stylesheets by combining a base list with files found via a glob pattern.
-- @param opts table A table of options with the following keys:
--   - base_sheets (table): A list of initial stylesheet paths.
--   - glob_pattern (string): The glob pattern to search for with ripgrep.
-- @return table, number The combined list of stylesheets and the number of files added.
function M.build_stylesheet_list(opts)
  opts = opts or {}
  local base_sheets = opts.base_sheets or {}
  local glob_pattern = opts.glob_pattern or ""
  local files_added = 0

  -- Create a new table to avoid modifying the original base_sheets table.
  local final_sheets = {}
  for _, sheet in ipairs(base_sheets) do
    table.insert(final_sheets, sheet)
  end

  if glob_pattern == "" then
    return final_sheets, files_added
  end

  local rg_executable = find_rg_executable()

  if not rg_executable then
    print("Warning: ripgrep (rg) not found. Skipping dynamic file search for glob: " .. glob_pattern)
    return final_sheets, files_added
  end

  local find_command = string.format("%s --files --glob '%s'", rg_executable, glob_pattern)
  local pipe = io.popen(find_command)

  if pipe then
    for file_path in pipe:lines() do
      file_path = file_path:match("^%s*(.-)%s*$")
      if file_path and file_path ~= "" then
        table.insert(final_sheets, file_path)
        files_added = files_added + 1
      end
    end
    pipe:close()
  else
    print("Error: Failed to execute rg command for glob: " .. glob_pattern)
  end

  return final_sheets, files_added
end

-- Creates a global dump function to inspect Lua objects with multi-line formatting.
-- It uses a recursive helper to "pretty-print" tables with proper indentation.
-- @param o The Lua object to display.
--
function M.dump(o)
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

return M
