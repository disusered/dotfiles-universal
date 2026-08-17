vim.keymap.set("n", "<leader><enter>", "<cmd>w<CR>", {
  desc = "Save file",
  silent = true,
  noremap = true,
})

local function delete(mode, lhs)
  pcall(vim.keymap.del, mode, lhs)
end

delete("n", "<S-h>")
delete("n", "<S-l>")

delete("n", "<leader>fT")
delete("n", "<leader>ft")
delete("n", "<c-/>")
delete("n", "<c-_>")
delete("t", "<C-/>")
delete("t", "<C-_>")

delete("n", "<leader>wd")
delete("n", "<leader>-")
delete("n", "<leader>|")
delete("n", "<leader>uz")
