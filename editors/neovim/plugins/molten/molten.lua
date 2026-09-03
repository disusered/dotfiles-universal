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
      vim.g.molten_auto_open_output = false
      vim.g.molten_enter_output_behavior = "open_and_enter"
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_image_location = "both"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_virt_lines_off_by_1 = true
      vim.g.molten_virt_text_max_lines = 12
      vim.g.molten_virt_text_output = true
      vim.g.molten_wrap_output = true
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
        if vim.b[event.buf].course_kernel_initialized or vim.b[event.buf].course_kernel_initializing then
          return
        end

        vim.b[event.buf].course_kernel_initializing = true
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(event.buf) then
            return
          end

          vim.api.nvim_buf_call(event.buf, function()
            local ok, kernels = pcall(vim.fn.MoltenAvailableKernels)
            local kernel_name = metadata_kernel(vim.api.nvim_buf_get_name(event.buf))
            if not ok or type(kernels) ~= "table" then
              vim.b[event.buf].course_kernel_initializing = false
              vim.notify("Molten kernels are not available", vim.log.levels.WARN)
              return
            end

            if kernel_name and vim.tbl_contains(kernels, kernel_name) then
              local initialized, error_message = pcall(initialize, kernel_name)
              vim.b[event.buf].course_kernel_initialized = initialized
              vim.b[event.buf].course_kernel_initializing = false
              if not initialized then
                vim.notify(("Notebook kernel failed to initialize: %s"):format(error_message), vim.log.levels.ERROR)
              end
            else
              vim.b[event.buf].course_kernel_initializing = false
              vim.notify(
                ("Notebook kernel is unavailable: %s"):format(kernel_name or "<missing metadata>"),
                vim.log.levels.WARN
              )
            end
          end)
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
        "<leader>jb",
        "<cmd>MoltenOpenInBrowser<CR>",
        desc = "Open HTML output",
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
