local cell_query

local function executable_cells(buf)
  cell_query = cell_query or vim.treesitter.query.parse("markdown", "(fenced_code_block) @cell")

  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then
    return {}
  end

  local cells = {}
  local tree = parser:parse()[1]
  if not tree then
    return cells
  end

  for _, node in cell_query:iter_captures(tree:root(), buf, 0, -1) do
    local start_row, _, end_row = node:range()
    local opener = vim.api.nvim_buf_get_lines(buf, start_row, start_row + 1, false)[1] or ""
    if opener:match("^%s*[`~]+%s*{[%w_+%.%-]+") then
      cells[#cells + 1] = {
        first = start_row,
        last = end_row - 1,
        target = math.min(start_row + 1, end_row - 1),
      }
    end
  end

  return cells
end

local function move_cell(direction)
  local buf = vim.api.nvim_get_current_buf()
  local cells = executable_cells(buf)
  if #cells == 0 then
    vim.notify("No executable Quarto cells found", vim.log.levels.WARN)
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local current
  for index, cell in ipairs(cells) do
    if row >= cell.first and row <= cell.last then
      current = index
      break
    end
  end

  local count = vim.v.count1
  local target
  if current then
    target = current + direction * count
  elseif direction > 0 then
    target = 1
    for index, cell in ipairs(cells) do
      if cell.first > row then
        target = index
        break
      end
    end
    target = target + count - 1
  else
    target = #cells
    for index = #cells, 1, -1 do
      if cells[index].last < row then
        target = index
        break
      end
    end
    target = target - count + 1
  end

  target = (target - 1) % #cells + 1
  vim.api.nvim_win_set_cursor(0, { cells[target].target + 1, 0 })
end

return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.quarto = { "injected" }
      opts.formatters = opts.formatters or {}
      opts.formatters.injected = vim.tbl_deep_extend("force", opts.formatters.injected or {}, {
        options = {
          ignore_errors = true,
          lang_to_formatters = {
            python = { "ruff_format" },
          },
        },
      })
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "quarto" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-mini/mini.icons",
    },
    opts = {
      file_types = { "quarto" },
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
        border = "thin",
      },
      heading = {
        sign = false,
        icons = {},
      },
      checkbox = {
        enabled = false,
      },
      latex = {
        enabled = false,
      },
    },
    keys = {
      {
        "<leader>um",
        function()
          require("render-markdown").toggle()
        end,
        desc = "Render Markdown",
        ft = "quarto",
      },
    },
  },
  {
    "3rd/image.nvim",
    ft = { "quarto" },
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "snacks_notif" },
      integrations = {
        markdown = {
          enabled = true,
          download_remote_images = false,
          filetypes = { "quarto" },
          clear_in_insert_mode = false,
          only_render_image_at_cursor = false,
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "markdown", "markdown_inline", "python", "yaml" },
    },
  },
  {
    "quarto-dev/quarto-nvim",
    optional = true,
    keys = {
      {
        "<leader>jn",
        function()
          move_cell(1)
        end,
        desc = "Next cell",
        ft = "quarto",
      },
      {
        "<leader>jp",
        function()
          move_cell(-1)
        end,
        desc = "Previous cell",
        ft = "quarto",
      },
    },
  },
}
