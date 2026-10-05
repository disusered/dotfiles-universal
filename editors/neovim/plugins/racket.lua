-- Racket / Scheme for SICP.
--
-- REPL: Conjure (the Clojure tool, now multi-language) with its Racket stdio
-- client. Evaluate the form under the cursor, the root form, or the buffer,
-- with results inline and in a log buffer.
--
--   <localleader>ee  eval current form        <localleader>er  eval root form
--   <localleader>eb  eval buffer               <localleader>E   eval visual selection
--   <localleader>lv  open log in a vsplit      <localleader>lq  close log
--   <localleader>cs  (re)start the REPL        <localleader>cS  stop it
--
-- Inside a directory whose path contains "sicp" the REPL starts as
-- `racket -I sicp`, so `nil`, `inc`, `dec`, `error` and the picture language
-- exist at the prompt exactly as in the book. Elsewhere it is plain `racket`.
--
-- Structure: parinfer is installed but off by default (parens are typed by
-- hand; rainbow-delimiters shows depth). :ParinferOn enables it per buffer.
-- Formatting (raco fmt) is on demand only, <leader>cf, never on save.
--
-- Tooling installed by the rotz dot languages/racket: racket, the `sicp`
-- language, `racket-langserver`, and `fmt` (raco fmt).

-- No format-on-save while learning: raco fmt re-flows expressions and hides
-- the indentation structure parinfer relies on. <leader>cf formats on demand.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "racket", "scheme" },
  callback = function()
    vim.b.autoformat = false
  end,
})

local function racket_command()
  if vim.fn.getcwd():lower():find("sicp", 1, true) then
    return "racket -I sicp"
  end
  return "racket"
end

return {
  {
    "Olical/conjure",
    ft = { "racket", "scheme" },
    init = function()
      vim.g["conjure#filetypes"] = { "racket", "scheme" }
      vim.g["conjure#filetype#scheme"] = "conjure.client.racket.stdio"
      vim.g["conjure#client#racket#stdio#command"] = racket_command()
      vim.g["conjure#log#hud#enabled"] = true
      vim.g["conjure#log#hud#width"] = 0.42
      vim.g["conjure#mapping#doc_word"] = false -- keep K for LSP hover
      vim.g["conjure#highlight#enabled"] = true
    end,
  },

  {
    -- Off by default: closing parens are typed by hand and checked with the
    -- rainbow colours. :ParinferOn turns it on for a buffer when wanted.
    "gpanders/nvim-parinfer",
    ft = { "racket", "scheme" },
    init = function()
      vim.g.parinfer_enabled = false
    end,
  },

  {
    "HiPhish/rainbow-delimiters.nvim",
    ft = { "racket", "scheme" },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed, { "racket", "scheme" })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        racket_langserver = {
          mason = false, -- installed with `raco pkg install racket-langserver`
          filetypes = { "racket", "scheme" },
        },
      },
    },
  },

  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        racket = { "raco_fmt" },
      },
      formatters = {
        raco_fmt = {
          command = "raco",
          args = { "fmt" },
          stdin = true,
        },
      },
    },
  },
}
