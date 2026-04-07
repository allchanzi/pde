local map = vim.keymap.set
local prefs = require("config.prefs")
local pants_enabled = prefs.enabled("ENABLE_PANTS", true)
local pants_tests = pants_enabled and require("config.pants_tests") or nil

-- Save file
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })

-- Quit current window
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })

-- Splits
map("n", "<leader>sv", "<cmd>vsplit<cr>", { desc = "Vertical split" })
map("n", "<leader>sh", "<cmd>split<cr>", { desc = "Horizontal split" })

-- Telescope keymaps are declared in plugins/core.lua (keys = { ... })
-- so that lazy.nvim can use them as lazy-load triggers.

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

if pants_enabled then
  -- Project checks
  map("n", "<leader>pp", "<cmd>PrePush<cr>", { desc = "Run pre-push" })
  map("n", "<leader>t", pants_tests.open, { desc = "Open Pants tests" })
end

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
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })

-- LSP
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gr", vim.lsp.buf.references, { desc = "Go to references" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })

-- Formatting (<leader>cf to avoid conflict with <leader>f Find group)
map("n", "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format file" })

-- Two-column cheatsheet popup with mnemonic highlights
map("n", "<leader>h", function()
  local col_w = 46  -- display width of each column
  local sep   = " │ "

  local function section(title)
    local prefix = "  ── " .. title .. " "
    local bars = col_w - vim.fn.strdisplaywidth(prefix)
    return prefix .. string.rep("─", math.max(0, bars))
  end

  local function e(key, desc)
    return string.format("  %-14s %s", key, desc)
  end

  -- ── Left column ──────────────────────────────────────────
  local left = {
    section("FIND"),
    e("SPC f f",    "[F]ind [F]iles"),
    e("SPC f g",    "[F]ind by [G]rep"),
    e("SPC f r",    "[F]ind [R]ecent"),
    e("SPC f s",    "[F]ind [S]tring (cursor)"),
    e("SPC f c",    "[F]ind in [C]urrent buf"),
    e("SPC f b",    "[F]ind [B]uffers"),
    e("SPC f h",    "[F]ind [H]elp tags"),
    e("SPC f d",    "[F]ind [D]iagnostics"),
    "",
    section("GIT"),
    e("SPC g s",    "[G]it [S]tatus"),
    e("SPC g l",    "[G]it [L]og"),
    e("SPC g c",    "[G]it [C]hanges / branches"),
    e("] c / [ c",  "Next / prev [C]hange (hunk)"),
    e("SPC g h s",  "[G]it [H]unk [S]tage"),
    e("SPC g h r",  "[G]it [H]unk [R]eset"),
    e("SPC g h p",  "[G]it [H]unk [P]review"),
    e("SPC g h b",  "[G]it [H]unk [B]lame popup"),
    e("SPC g h B",  "[G]it [H]unk [B]lame inline toggle"),
    "",
    section("CODE"),
    e("SPC c a",    "[C]ode [A]ction"),
    e("SPC c f",    "[C]ode [F]ormat"),
    e("SPC r n",    "[R]e[n]ame symbol"),
    "",
    section("BUFFERS"),
    e("SPC b d",    "[B]uffer [D]elete"),
    e("] b / [ b",  "Next / prev [B]uffer"),
    e("SPC b >/<",  "[B]uffer move right / left"),
    e("SPC b p",    "[B]uffer [P]in / unpin"),
    "",
    section("FILE TREE"),
    e("SPC e",      "Toggle [E]xplorer"),
    e("SPC o",      "F[o]cus explorer"),
    e("Tab",        "Toggle focus tree / editor"),
    e("a / d / r",  "[A]dd  [D]elete  [R]ename"),
    e("c / x / p",  "[C]opy  cut  [P]aste"),
    e("m + bd/bt",  "[M]ark then bulk ops"),
    e("R",          "[R]efresh tree"),
  }

  -- ── Right column ─────────────────────────────────────────
  local right = {
    section("MOVEMENT"),
    e("h j k l",       "Move left / down / up / right"),
    e("gg / G",        "Top / bottom of file"),
    e("w / b",         "Next / prev word"),
    e("Ctrl-o / Ctrl-i","Jump back / forward"),
    "",
    section("EDITING"),
    e("dd / yy",       "[D]elete / [Y]ank line"),
    e("p",             "[P]aste"),
    e("u / Ctrl-r",    "[U]ndo / [R]edo"),
    e("< / >",         "Un/indent selection"),
    e("i / v / Esc",   "[I]nsert  [V]isual  Normal"),
    "",
    section("LSP"),
    e("g d",           "[G]o to [D]efinition"),
    e("g r",           "[G]o to [R]eferences"),
    e("K",             "Hover docs"),
    "",
    section("WINDOWS & SPLITS"),
    e("SPC s v",       "[S]plit [V]ertical"),
    e("SPC s h",       "[S]plit [H]orizontal"),
    e("Ctrl-h/j/k/l",  "Navigate windows"),
    "",
    section("DIAGNOSTICS"),
    e("SPC x x",       "Toggle diagnostics panel"),
    e("] d / [ d",     "Next / prev [D]iagnostic"),
    "",
    e("SPC w",         "[W]rite / save"),
    e("SPC q",         "[Q]uit window"),
  }

  if pants_enabled then
    table.insert(right, #right - 2, "")
    table.insert(right, #right - 2, section("PROJECT"))
    table.insert(right, #right - 2, e("SPC p p", "[P]re-[P]ush check"))
    table.insert(right, #right - 2, e("SPC t",   "Pants [T]ests browser"))
  end

  -- ── Merge into lines ──────────────────────────────────────
  local sep_w  = vim.fn.strdisplaywidth(sep)
  local total_w = col_w * 2 + sep_w

  local title      = "NVIM CHEATSHEET"
  local title_pad  = math.floor((total_w - #title) / 2)
  local footer     = "j/k scroll  ·  q close"
  local footer_pad = math.floor((total_w - #footer) / 2)

  local lines = {
    string.rep(" ", title_pad) .. title,
    string.rep("─", total_w),
  }

  local n = math.max(#left, #right)
  for i = 1, n do
    local l = left[i]  or ""
    local r = right[i] or ""
    local pad = math.max(0, col_w - vim.fn.strdisplaywidth(l))
    table.insert(lines, l .. string.rep(" ", pad) .. sep .. r)
  end

  table.insert(lines, string.rep("─", total_w))
  table.insert(lines, string.rep(" ", footer_pad) .. footer)

  -- ── Window ───────────────────────────────────────────────
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"

  local height  = math.min(#lines, vim.o.lines - 4)
  local win_row = math.floor((vim.o.lines   - height)  / 2)
  local win_col = math.floor((vim.o.columns - total_w) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width    = total_w,
    height   = height,
    row      = win_row,
    col      = win_col,
    style    = "minimal",
    border   = "rounded",
  })

  -- ── Syntax highlighting ───────────────────────────────────
  local ns = vim.api.nvim_create_namespace("help_popup")

  for i, line in ipairs(lines) do
    local row0 = i - 1

    if line:find("NVIM CHEATSHEET", 1, true) then
      vim.api.nvim_buf_add_highlight(buf, ns, "Title", row0, 0, -1)

    elseif line:match("^─") or line:match("^%s*[·j]") then
      -- horizontal rules and footer
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", row0, 0, -1)

    elseif line:match("^  ──") then
      -- section headers
      vim.api.nvim_buf_add_highlight(buf, ns, "Statement", row0, 0, -1)

    else
      -- entry lines: highlight keys and mnemonics
      local sep_b1 = line:find("│", 1, true)  -- 1-indexed byte pos
      if sep_b1 then
        local sep_b0 = sep_b1 - 1  -- 0-indexed

        -- separator glyph
        vim.api.nvim_buf_add_highlight(buf, ns, "Comment", row0, sep_b0, sep_b0 + 3)

        -- left key (bytes 2..15, 0-indexed)
        if line:sub(3, 16):match("%S") then
          vim.api.nvim_buf_add_highlight(buf, ns, "Special", row0, 2, 16)
        end

        -- right key (after │ [3 bytes] + space [1] + indent [2] = +6)
        local rk_start = sep_b0 + 6
        local rk_end   = rk_start + 14
        if rk_end <= #line and line:sub(rk_start + 1, rk_end):match("%S") then
          vim.api.nvim_buf_add_highlight(buf, ns, "Special", row0, rk_start, rk_end)
        end
      end

      -- [X] mnemonic letters → Bold
      local pos = 1
      while true do
        local s, e = line:find("%[.%]", pos)
        if not s then break end
        vim.api.nvim_buf_add_highlight(buf, ns, "Bold", row0, s - 1, e)
        pos = e + 1
      end
    end
  end

  vim.bo[buf].modifiable = false

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, silent = true })
end, { desc = "Help popup" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to bottom window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to top window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Buffer navigation
map("n", "]b", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
map("n", "[b", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>",     { desc = "Close buffer" })

-- Buffer move
map("n", "<leader>b>", "<cmd>BufferLineMoveNext<cr>", { desc = "Move buffer right" })
map("n", "<leader>b<", "<cmd>BufferLineMovePrev<cr>", { desc = "Move buffer left" })

-- Buffer pin
map("n", "<leader>bp", "<cmd>BufferLineTogglePin<cr>", { desc = "Pin/unpin buffer" })

-- Keep selection after indent
vim.keymap.set("v", "<", "<gv", { desc = "Unindent and keep selection" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent and keep selection" })
