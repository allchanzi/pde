local map = vim.keymap.set
local prefs = require("config.prefs")
local pants_enabled = prefs.enabled("ENABLE_PANTS", true)

-- Save file
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })

-- Quit current window
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })

-- Splits
map("n", "<leader>sv", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>sh", "<cmd>split<cr>", { desc = "Horizontal split" })

-- Resize windows
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Telescope keymaps are declared in plugins/core.lua (keys = { ... })
-- so that lazy.nvim can use them as lazy-load triggers.

-- URLs open via the system opener; non-URL paths under the cursor are copied.
map("n", "<C-LeftMouse>", "<LeftMouse><cmd>lua require(\"config.openers\").open_url_or_copy_path_under_cursor()<cr>", { desc = "Open URL or copy path" })

-- File tree
map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file tree" })
map("n", "<leader>o", "<cmd>NvimTreeFocus<cr>", { desc = "Focus file tree" })
map("n", "<Tab>", function()
  if vim.bo.filetype == "NvimTree" then
    vim.cmd("stopinsert")
    vim.cmd("wincmd p")
  else
    require("nvim-tree.api").tree.focus()
  end
end, { desc = "Toggle focus tree/editor" })

-- Search: clear highlight, and keep the match centered while jumping
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
map("n", "n", "nzzzv", { desc = "Next match (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev match (centered)" })
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })

-- Move the current line / selection up and down
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Paste over a selection without clobbering the unnamed register
map("x", "p", "\"_dP", { desc = "Paste without yanking selection" })

-- Git (gitsigns)
map("n", "]c", function() require("gitsigns").next_hunk() end, { desc = "Next hunk" })
map("n", "[c", function() require("gitsigns").prev_hunk() end, { desc = "Prev hunk" })
map("n", "<leader>ghs", function() require("gitsigns").stage_hunk() end,        { desc = "Stage hunk" })
map("n", "<leader>ghr", function() require("gitsigns").reset_hunk() end,        { desc = "Reset hunk" })
map("n", "<leader>ghp", function() require("gitsigns").preview_hunk() end,      { desc = "Preview hunk" })
map("n", "<leader>ghb", function() require("gitsigns").blame_line() end,         { desc = "Blame line (popup)" })
map("n", "<leader>ghB", function() require("gitsigns").toggle_current_line_blame() end, { desc = "Toggle inline blame" })

-- Diagnostics
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics" })
map("n", "<leader>xv", function()
  require("config.diagnostics").toggle()
end, { desc = "Toggle inline diagnostics" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]q", "<cmd>cnext<cr>", { desc = "Next quickfix item" })
map("n", "[q", "<cmd>cprev<cr>", { desc = "Previous quickfix item" })

-- LSP
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gr", vim.lsp.buf.references, { desc = "Go to references" })
map("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
map("n", "gy", vim.lsp.buf.type_definition, { desc = "Go to type definition" })
map("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
map({ "n", "i" }, "<C-k>", vim.lsp.buf.signature_help, { desc = "Signature help" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "<leader>cl", "<cmd>LspRestart<cr>", { desc = "Reset LSP" })
map("n", "<leader>fR", function()
  require("config.project_replace").open()
end, { desc = "Project replace" })
-- Find & replace word under cursor in the current buffer (cursor lands between the slashes)
map("n", "<leader>fw", [[:%s/\<<C-r><C-w>\>//g<Left><Left>]], { desc = "Replace word in buffer" })
map("n", "<leader>br", "<cmd>Telescope registers<cr>", { desc = "Registers" })

-- Formatting (<leader>cf to avoid conflict with <leader>f Find group)
map("n", "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format file" })

-- Cheatsheet popup
map("n", "<leader>h", function()
  require("config.cheatsheet").open()
end, { desc = "Help popup" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Buffer navigation
map("n", "]b", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "[b", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
map("n", "<leader>bd", function()
  require("config.buffers").close_current(false)
end, { desc = "Close buffer" })
map("n", "<leader>bq", function()
  require("config.buffers").close_all(false)
end, { desc = "Close all file buffers" })
map("n", "<leader>bQ", function()
  require("config.buffers").close_all(true)
end, { desc = "Force close all file buffers" })
map("n", "<leader>bo", function()
  require("config.buffers").close_others(false)
end, { desc = "Close other file buffers" })

-- Buffer move
map("n", "<leader>b>", "<cmd>BufferLineMoveNext<cr>", { desc = "Move buffer right" })
map("n", "<leader>b<", "<cmd>BufferLineMovePrev<cr>", { desc = "Move buffer left" })

-- Buffer pin
map("n", "<leader>bp", "<cmd>BufferLineTogglePin<cr>", { desc = "Pin/unpin buffer" })

-- Keep selection after indent
map("v", "<", "<gv", { desc = "Unindent and keep selection" })
map("v", ">", ">gv", { desc = "Indent and keep selection" })

-- Project-specific keymaps (Pants / monorepo) load only when enabled
if pants_enabled then
  require("config.keymaps_pants").setup(map)
end
