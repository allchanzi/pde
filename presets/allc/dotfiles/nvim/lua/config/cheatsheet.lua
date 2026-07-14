-- Two-column cheatsheet popup with mnemonic highlights (opened via <leader>h).
--
-- Universal keys live in the static columns below. Project-specific sections
-- (e.g. Pants) are contributed as data by their own module and appended here,
-- so this file has no project-specific knowledge and no magic indexes.
local M = {}

local col_w = 46 -- display width of each column
local sep = " │ "

local function section(title)
  local prefix = "  ── " .. title .. " "
  local bars = col_w - vim.fn.strdisplaywidth(prefix)
  return prefix .. string.rep("─", math.max(0, bars))
end

local function e(key, desc)
  return string.format("  %-14s %s", key, desc)
end

function M.open()
  local prefs = require("config.prefs")
  local theme = require("config.theme")
  local p = theme.palette
  local popup_bg = p.base

  -- ── Left column ──────────────────────────────────────────
  local left = {
    section("FIND"),
    e("SPC f f", "[F]ind [F]iles"),
    e("SPC f g", "[F]ind by [G]rep"),
    e("SPC f p", "[F]ind by grep + [P]ath"),
    e("SPC f r", "[F]ind [R]ecent"),
    e("SPC f R", "[F]ind + [R]eplace (project)"),
    e("SPC f w", "[F]ind + replace [W]ord (buffer)"),
    e("SPC f s", "[F]ind [S]tring (cursor)"),
    e("SPC f c", "[F]ind in [C]urrent buf"),
    e("SPC f b", "[F]ind [B]uffers"),
    e("SPC f B", "[F]ind current tab [B]uffers"),
    e("SPC f h", "[F]ind [H]elp tags"),
    e("SPC f d", "[F]ind [D]iagnostics"),
    "",
    section("GIT"),
    e("SPC g s", "[G]it [S]tatus"),
    e("SPC g l", "[G]it [L]og"),
    e("SPC g c", "[G]it [C]hanges / branches"),
    e("] c / [ c", "Next / prev [C]hange (hunk)"),
    e("SPC g h s", "[G]it [H]unk [S]tage"),
    e("SPC g h r", "[G]it [H]unk [R]eset"),
    e("SPC g h p", "[G]it [H]unk [P]review"),
    e("SPC g h b", "[G]it [H]unk [B]lame popup"),
    e("SPC g h B", "[G]it [H]unk [B]lame inline toggle"),
    "",
    section("CODE"),
    e("SPC c a", "[C]ode [A]ction"),
    e("SPC c f", "[C]ode [F]ormat"),
    e("SPC c r", "[C]ode [R]ename symbol"),
    e("SPC c d", "[C]ode line [D]iagnostics"),
    e("SPC c l", "[C]ode reset [L]SP"),
    e("SPC r n", "[R]e[n]ame symbol alias"),
    e("SPC r", "[R]egisters"),
    "",
    section("BUFFERS"),
    e("SPC b d", "[B]uffer [D]elete"),
    e("SPC b q", "[B]uffers [Q]uit all"),
    e("SPC b Q", "[B]uffers force [Q]uit all"),
    e("SPC b o", "[B]uffer close [O]thers"),
    e("SPC b r", "[B]uffer [R]egisters"),
    e("] b / [ b", "Next / prev [B]uffer"),
    e("SPC b >/<", "[B]uffer move right / left"),
    e("SPC b p", "[B]uffer [P]in / unpin"),
    "",
    section("FILE TREE"),
    e("SPC e", "Toggle [E]xplorer"),
    e("SPC o", "F[o]cus explorer"),
    e("Tab", "Toggle focus tree / editor"),
    e("a / d / r", "[A]dd  [D]elete  [R]ename"),
    e("c / x / p", "[C]opy  cut  [P]aste"),
    e("m + bd/bt", "[M]ark then bulk ops"),
    e("R", "[R]efresh tree"),
  }

  -- ── Right column ─────────────────────────────────────────
  local right = {
    section("MOVEMENT"),
    e("h j k l", "Move left / down / up / right"),
    e("gg / G", "Top / bottom of file"),
    e("0 / ^ / $", "Line start / text start / end"),
    e("w / b", "Next / prev word"),
    e("e / ge", "End / prev end of word"),
    e("{ / }", "Prev / next paragraph"),
    e("Ctrl-u/Ctrl-d", "Half page up / down (centered)"),
    e("Ctrl-b/Ctrl-f", "Page up / down"),
    e("n / N", "Next / prev match (centered)"),
    e("%", "Jump matching bracket"),
    e("Ctrl-o/Ctrl-i", "Jump back / forward"),
    e("Esc", "Clear search highlight"),
    "",
    section("EDITING"),
    e("A", "Insert at end of line"),
    e("o / O", "New line below / above"),
    e("dd / yy", "[D]elete / [Y]ank line"),
    e("p", "[P]aste"),
    e("Alt-j/Alt-k", "Move line / selection down / up"),
    e("p (visual)", "Paste over, keep register"),
    e("u / Ctrl-r", "[U]ndo / [R]edo"),
    e("< / >", "Un/indent selection"),
    e("i / v / Esc", "[I]nsert  [V]isual  Normal"),
    "",
    section("LSP"),
    e("g d", "[G]o to [D]efinition"),
    e("g r", "[G]o to [R]eferences"),
    e("g i", "[G]o to [I]mplementation"),
    e("g y", "[G]o to t[Y]pe definition"),
    e("g D", "[G]o to [D]eclaration"),
    e("K", "Hover docs"),
    e("Ctrl-k", "Signature help"),
    "",
    section("WINDOWS & SPLITS"),
    e("SPC s v", "[S]plit [V]ertical"),
    e("SPC s h", "[S]plit [H]orizontal"),
    e("Ctrl-h/j/k/l", "Navigate windows"),
    e("Ctrl-arrows", "Resize window"),
    "",
    section("DIAGNOSTICS"),
    e("SPC x x", "Toggle diagnostics panel"),
    e("SPC x v", "Toggle inline diagnostics"),
    e("] d / [ d", "Next / prev [D]iagnostic"),
    e("] q / [ q", "Next / prev [Q]uickfix"),
  }

  -- Project-specific sections are appended before the write/quit footer.
  if prefs.enabled("ENABLE_PANTS", true) then
    local ok, pants_km = pcall(require, "config.keymaps_pants")
    if ok then
      local s = pants_km.cheatsheet_section()
      table.insert(right, "")
      table.insert(right, section(s.title))
      for _, entry in ipairs(s.entries) do
        table.insert(right, e(entry[1], entry[2]))
      end
    end
  end

  table.insert(right, "")
  table.insert(right, e("SPC w", "[W]rite / save"))
  table.insert(right, e("SPC q", "[Q]uit window"))

  -- ── Merge into lines ──────────────────────────────────────
  local sep_w = vim.fn.strdisplaywidth(sep)
  local total_w = col_w * 2 + sep_w

  local title = "NVIM CHEATSHEET"
  local title_pad = math.floor((total_w - #title) / 2)
  local footer = "j/k scroll  ·  q close"
  local footer_pad = math.floor((total_w - #footer) / 2)

  local lines = {
    string.rep(" ", title_pad) .. title,
    string.rep("─", total_w),
  }

  local n = math.max(#left, #right)
  for i = 1, n do
    local l = left[i] or ""
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

  local height = math.min(#lines, vim.o.lines - 4)
  local win_row = math.floor((vim.o.lines - height) / 2)
  local win_col = math.floor((vim.o.columns - total_w) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = total_w,
    height = height,
    row = win_row,
    col = win_col,
    style = "minimal",
    border = "rounded",
  })

  vim.api.nvim_set_hl(0, "HelpPopupNormal", { fg = p.text, bg = popup_bg })
  vim.api.nvim_set_hl(0, "HelpPopupBorder", { fg = p.blue, bg = popup_bg })
  vim.api.nvim_set_hl(0, "HelpPopupTitle", { fg = p.lavender, bg = popup_bg, bold = true })
  vim.api.nvim_set_hl(0, "HelpPopupSection", { fg = p.blue, bg = popup_bg, bold = true })
  vim.api.nvim_set_hl(0, "HelpPopupKey", { fg = p.yellow, bg = popup_bg, bold = true })
  vim.api.nvim_set_hl(0, "HelpPopupMnemonic", { fg = p.green, bg = popup_bg, bold = true })
  vim.api.nvim_set_hl(0, "HelpPopupComment", { fg = p.subtle, bg = popup_bg })

  vim.wo[win].winhighlight = table.concat({
    "Normal:HelpPopupNormal",
    "FloatBorder:HelpPopupBorder",
    "EndOfBuffer:HelpPopupNormal",
  }, ",")

  -- ── Syntax highlighting ───────────────────────────────────
  local ns = vim.api.nvim_create_namespace("help_popup")

  for i, line in ipairs(lines) do
    local row0 = i - 1

    if line:find("NVIM CHEATSHEET", 1, true) then
      vim.api.nvim_buf_add_highlight(buf, ns, "HelpPopupTitle", row0, 0, -1)

    elseif line:match("^─") or line:match("^%s*[·j]") then
      -- horizontal rules and footer
      vim.api.nvim_buf_add_highlight(buf, ns, "HelpPopupComment", row0, 0, -1)

    elseif line:match("^  ──") then
      -- section headers
      vim.api.nvim_buf_add_highlight(buf, ns, "HelpPopupSection", row0, 0, -1)

    else
      -- entry lines: highlight keys and mnemonics
      local sep_b1 = line:find("│", 1, true) -- 1-indexed byte pos
      if sep_b1 then
        local sep_b0 = sep_b1 - 1 -- 0-indexed

        -- separator glyph
        vim.api.nvim_buf_add_highlight(buf, ns, "HelpPopupComment", row0, sep_b0, sep_b0 + 3)

        -- left key (bytes 2..15, 0-indexed)
        if line:sub(3, 16):match("%S") then
          vim.api.nvim_buf_add_highlight(buf, ns, "HelpPopupKey", row0, 2, 16)
        end

        -- right key (after │ [3 bytes] + space [1] + indent [2] = +6)
        local rk_start = sep_b0 + 6
        local rk_end = rk_start + 14
        if rk_end <= #line and line:sub(rk_start + 1, rk_end):match("%S") then
          vim.api.nvim_buf_add_highlight(buf, ns, "HelpPopupKey", row0, rk_start, rk_end)
        end
      end

      -- [X] mnemonic letters → Bold
      local pos = 1
      while true do
        local s, e_ = line:find("%[.%]", pos)
        if not s then break end
        vim.api.nvim_buf_add_highlight(buf, ns, "HelpPopupMnemonic", row0, s - 1, e_)
        pos = e_ + 1
      end
    end
  end

  vim.bo[buf].modifiable = false

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, silent = true })
end

return M
