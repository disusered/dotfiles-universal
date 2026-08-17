if vim.env.NVIM_APPNAME ~= "nvim-notebook" then
  return {}
end

return {
  {
    "benlubas/molten-nvim",
    lazy = false,
    version = "^1.0.0",
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_auto_init_behavior = "raise"
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
    end,
    config = function()
      local group = vim.api.nvim_create_augroup("CourseNotebooks", { clear = true })

      local function initialize(kernel_name)
        if kernel_name and kernel_name ~= "" then
          vim.cmd("MoltenInit " .. vim.fn.fnameescape(kernel_name))
        else
          vim.cmd("MoltenInit")
        end
      end

      local function metadata_kernel(path)
        local file = io.open(path, "r")
        if not file then
          return nil
        end

        local contents = file:read("*a")
        file:close()

        local ok, notebook = pcall(vim.json.decode, contents)
        if not ok or type(notebook) ~= "table" then
          return nil
        end

        local metadata = notebook.metadata
        local kernelspec = type(metadata) == "table" and metadata.kernelspec or nil
        return type(kernelspec) == "table" and kernelspec.name or nil
      end

      local function initialize_notebook(event)
        if vim.b[event.buf].course_kernel_initialized then
          return
        end

        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(event.buf) then
            return
          end

          local ok, kernels = pcall(vim.fn.MoltenAvailableKernels)
          local kernel_name = metadata_kernel(event.file)
          if not ok or type(kernels) ~= "table" then
            vim.notify("Molten kernels are not available", vim.log.levels.WARN)
            return
          end

          if kernel_name and vim.tbl_contains(kernels, kernel_name) then
            initialize(kernel_name)
            vim.b[event.buf].course_kernel_initialized = true
          else
            vim.notify(
              ("Notebook kernel is unavailable: %s"):format(kernel_name or "<missing metadata>"),
              vim.log.levels.WARN
            )
          end
        end)
      end

      _G.molten_helpers = {
        init = initialize,
      }

      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "quarto",
        callback = function()
          vim.wo.relativenumber = true
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "MoltenInitPost",
        callback = function()
          if vim.bo.filetype == "quarto" and vim.fn.exists(":QuartoActivate") == 2 then
            vim.cmd("QuartoActivate")
          end
        end,
      })

      vim.api.nvim_create_autocmd("BufAdd", {
        group = group,
        pattern = "*.ipynb",
        callback = initialize_notebook,
      })

      vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        pattern = "*.ipynb",
        callback = function(event)
          if vim.api.nvim_get_vvar("vim_did_enter") ~= 1 then
            initialize_notebook(event)
          end
        end,
      })
    end,
    keys = {
      {
        "<leader>ji",
        function()
          _G.molten_helpers.init()
        end,
        desc = "Initialize kernel",
        ft = "quarto",
      },
      {
        "<leader>jI",
        "<cmd>MoltenImportOutput<CR>",
        desc = "Import notebook outputs",
        ft = "quarto",
      },
      {
        "<leader>jE",
        "<cmd>MoltenExportOutput!<CR>",
        desc = "Export notebook outputs",
        ft = "quarto",
      },
      {
        "<leader>j<esc>",
        "<cmd>MoltenInterrupt<CR>",
        desc = "Interrupt kernel",
        ft = "quarto",
      },
      {
        "<leader>jo",
        "<cmd>MoltenEvaluateOperator<CR>",
        desc = "Evaluate with operator",
        ft = "quarto",
      },
      {
        "<leader>jr",
        "<cmd>MoltenReevaluateCell<CR>",
        desc = "Re-evaluate cell",
        ft = "quarto",
      },
      {
        "<leader>jR",
        "<cmd>MoltenReevaluateAll<CR>",
        desc = "Re-evaluate all cells",
        ft = "quarto",
      },
      {
        "<leader>jK",
        "<cmd>MoltenRestart<CR>",
        desc = "Restart kernel",
        ft = "quarto",
      },
      {
        "<leader>je",
        ":<C-u>MoltenEvaluateVisual<CR>gv",
        mode = "v",
        desc = "Evaluate selection",
        ft = "quarto",
      },
      {
        "<leader>jn",
        "<cmd>MoltenNext<CR>",
        desc = "Next cell",
        ft = "quarto",
      },
      {
        "<leader>jp",
        "<cmd>MoltenPrev<CR>",
        desc = "Previous cell",
        ft = "quarto",
      },
      {
        "<leader>jO",
        "<cmd>noautocmd MoltenEnterOutput<CR>",
        desc = "Enter output",
        ft = "quarto",
      },
      {
        "<leader>jh",
        "<cmd>MoltenHideOutput<CR>",
        desc = "Hide output",
        ft = "quarto",
      },
      {
        "<leader>jx",
        "<cmd>MoltenImagePopup<CR>",
        desc = "Open image",
        ft = "quarto",
      },
      {
        "<leader>jd",
        "<cmd>MoltenDelete<CR>",
        desc = "Delete cell",
        ft = "quarto",
      },
      {
        "<leader>jD",
        "<cmd>MoltenDelete!<CR>",
        desc = "Delete all cells",
        ft = "quarto",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        {
          "<leader>j",
          name = "+jupyter",
          icon = {
            icon = "",
            color = "orange",
          },
          mode = "nv",
        },
      },
    },
  },
}
