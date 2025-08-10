-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
-- my personal keymaps
vim.keymap.set("n", "<leader><enter>", "<cmd>w<CR>", { desc = "Save file", silent = true, noremap = true })

-- remove buffer changing keymaps
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")

-- disable floating terminal keymaps
vim.keymap.del("n", "<leader>fT")
vim.keymap.del("n", "<leader>ft")
vim.keymap.del("n", "<c-/>")
vim.keymap.del("n", "<c-_>")
vim.keymap.del("t", "<C-/>")
vim.keymap.del("t", "<C-_>")

-- disable window keymaps
vim.keymap.del("n", "<leader>wd")
vim.keymap.del("n", "<leader>-")
vim.keymap.del("n", "<leader>|")
