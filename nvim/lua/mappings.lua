require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

local mode = "n"

map(mode, "<S-s>", ":w<CR>", { desc = "Save file", noremap = true })
map(mode, "<S-q>", ":q<CR>", { desc = "Quit file", noremap = true })

map(mode, "sd", ":set splitright<CR>:vsplit<CR>", { desc = "Split window right", noremap = true })
map(mode, "<LEADER><RIGHT>", "<C-w>l", { desc = "Move to right window", noremap = true })
map(mode, "<LEADER><LEFT>", "<C-w>h", { desc = "Move to left window", noremap = true })
map(mode, "<LEADER><DOWN>", "<C-w>j", { desc = "Move to below window", noremap = true })
map(mode, "<LEADER><UP>", "<C-w>k", { desc = "Move to upper window", noremap = true })

map(mode, "<LEADER>fr", ":lua require'telescope.builtin'.lsp_document_symbols{}<CR>", { desc = "Document symbols", noremap = true })

map(mode, "==", "$", { desc = "End of line", noremap = true })
map(mode, "--", "0", { desc = "Start of line", noremap = true })
map(mode, "gl", vim.diagnostic.open_float, { desc = 'Show line diagnostics', noremap = true })
