-- Leader key (main key for shortcuts, e.g. <leader>ff)
vim.g.mapleader = " "

vim.filetype.add({
  extension = {
    FCMacro = "python",
    fcmacro = "python",
  },
})

-- Disable unused providers
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_python3_provider = 0

local opt = vim.opt
local prefs = require("config.prefs")
local pants_enabled = prefs.enabled("ENABLE_PANTS", true)
local pants = pants_enabled and require("config.pants") or nil
local default_diagnostic_config = {
  virtual_text = false,
  virtual_lines = false,
  underline = true,
  signs = true,
  severity_sort = true,
  update_in_insert = false,
  float = {
    border = "rounded",
    source = "if_many",
  },
}
local python_diagnostic_config = vim.tbl_deep_extend("force", default_diagnostic_config, {
  virtual_text = {
    spacing = 2,
    source = "if_many",
    prefix = "●",
  },
})

-- Show line numbers
opt.number = true

-- Show relative line numbers
opt.relativenumber = true

-- Enable mouse support
opt.mouse = "a"
opt.mousemodel = "popup_setpos"

-- Use system clipboard
opt.clipboard = "unnamedplus"

-- Search settings
opt.ignorecase = true
opt.smartcase = true

-- Enable true colors
opt.termguicolors = true

-- Always show sign column
opt.signcolumn = "yes"

-- Faster updates
opt.updatetime = 200

-- Split behavior
opt.splitright = true
opt.splitbelow = true

-- Highlight current line
opt.cursorline = true

-- Use spaces instead of tabs
opt.expandtab = true

-- Default indentation: 4 spaces
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4

-- Smart indentation
opt.smartindent = true

-- Disable line wrapping
opt.wrap = false

-- Keep context around cursor
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Confirm before closing unsaved buffers
opt.confirm = true

-- Persistent undo
opt.undofile = true

local mode_labels = {
  n       = "NORMAL",
  no      = "N·PENDING",
  i       = "INSERT",
  ic      = "INSERT",
  v       = "VISUAL",
  V       = "V·LINE",
  ["\22"] = "V·BLOCK",
  c       = "COMMAND",
  R       = "REPLACE",
  Rv      = "REPLACE",
  s       = "SELECT",
  S       = "S·LINE",
  t       = "TERMINAL",
  ["!"]   = "SHELL",
}

local function mode_label()
  return " " .. (mode_labels[vim.fn.mode(1)] or vim.fn.mode(1):upper()) .. " "
end

-- Statusline state: pre-computed strings updated asynchronously.
-- Statusline functions only read these — no blocking calls during render.
local sl = { branch = "", pants_python = "" }

local function update_branch_async()
  local cwd = vim.fn.getcwd()
  vim.system({ "git", "-C", cwd, "branch", "--show-current" }, { text = true }, function(result)
    local branch = ""
    if result.code == 0 and result.stdout then
      branch = vim.trim(result.stdout)
    end
    local new_val = branch ~= "" and " branch:" .. branch or ""
    if new_val ~= sl.branch then
      sl.branch = new_val
      vim.schedule(function() vim.cmd("redrawstatus") end)
    end
  end)
end

local function update_pants_python()
  if not pants then
    sl.pants_python = ""
    return
  end

  local label = pants.current_python_label_if_cached(vim.fn.getcwd())
  if label == nil then return end  -- prewarm still running, try again on PantsPythonReady
  local new_val = label ~= "" and "  py:" .. label or ""
  if new_val ~= sl.pants_python then
    sl.pants_python = new_val
    vim.cmd("redrawstatus")
  end
end

local function current_branch()
  return sl.branch
end

local function current_pants_python()
  return sl.pants_python
end

local function refresh_project_caches()
  update_branch_async()
  if pants then
    pants.invalidate_python_cache(vim.fn.getcwd())
    update_pants_python()
  end
end

-- Populate branch on startup without blocking
vim.schedule(update_branch_async)

-- Update statusline once async python discovery completes
if pants then
  vim.api.nvim_create_autocmd("User", {
    pattern = "PantsPythonReady",
    callback = update_pants_python,
  })
end

local function apply_diagnostic_config(bufnr)
  local filetype = vim.bo[bufnr].filetype

  if filetype == "python" then
    vim.diagnostic.config(python_diagnostic_config)
    return
  end

  vim.diagnostic.config(default_diagnostic_config)
end

-- Autosave when losing focus or leaving buffer
vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" then
      vim.cmd("silent! write")
    end
  end,
})

-- Invalidate cached branch when the working tree may have changed
-- BufEnter excluded: too frequent and causes git calls on every buffer switch
vim.api.nvim_create_autocmd({ "DirChanged", "BufWritePost", "ShellCmdPost" }, {
  callback = refresh_project_caches,
})

vim.diagnostic.config(default_diagnostic_config)

-- FileType alone is sufficient — filetype doesn't change between BufEnter events
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    apply_diagnostic_config(args.buf)
  end,
})

-- Per-filetype indentation
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "dart" },
  callback = function(args)
    local indent = args.match == "dart" and 2 or 4
    vim.bo.expandtab = true
    vim.bo.shiftwidth = indent
    vim.bo.tabstop = indent
    vim.bo.softtabstop = indent
  end,
})

-- Open the file tree automatically when starting Neovim on a directory
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function(data)
    local directory = vim.fn.isdirectory(data.file) == 1
    if directory then
      vim.cmd("NvimTreeOpen")
      vim.schedule(function()
        if pants then
          local cwd = vim.fn.getcwd()
          -- Python discovery is fast (async find); run immediately
          pants.prewarm_python(cwd)
          -- pants list :: can be very slow on monorepos; delay to avoid
          -- competing with LSP and initial file loading
          vim.defer_fn(function()
            pants.prewarm_test_targets(cwd)
          end, 5000)
        end
      end)
    end
  end,
})

opt.laststatus = 2

opt.statusline = table.concat({
  "%{v:lua.mode_label()}",  -- current mode
  " %f",                    -- file path
  "%m",                     -- modified flag
  "%r",                     -- readonly flag
  "%=",
  " branch:%{v:lua.current_branch()}",
  "%{v:lua.current_pants_python()}",
  "  cwd:%{fnamemodify(getcwd(), ':~')}",
  "  %l:%c ",
})

_G.mode_label       = mode_label
_G.current_branch   = current_branch
_G.current_pants_python = current_pants_python

vim.api.nvim_create_user_command("GitBranch", function()
  print(current_branch())
end, {})
if pants then
  pants.setup_commands()
end

-- Extend the right-click popup menu with common actions.
vim.cmd([[
  silent! aunmenu PopUp.Nvim
  amenu <silent> PopUp.Nvim.Save :write<CR>
  amenu <silent> PopUp.Nvim.Format :lua require("conform").format({ async = true, lsp_fallback = true })<CR>
  amenu <silent> PopUp.Nvim.-Sep1- :
  amenu <silent> PopUp.Nvim.Split\ Vertical :vsplit<CR>
  amenu <silent> PopUp.Nvim.Split\ Horizontal :split<CR>
  amenu <silent> PopUp.Nvim.-Sep2- :
  amenu <silent> PopUp.Nvim.Find\ Files :Telescope find_files<CR>
  amenu <silent> PopUp.Nvim.Live\ Grep :Telescope live_grep<CR>
  amenu <silent> PopUp.Nvim.Buffers :Telescope buffers<CR>
  amenu <silent> PopUp.Nvim.-Sep3- :
  amenu <silent> PopUp.Nvim.Toggle\ Tree :NvimTreeToggle<CR>
  amenu <silent> PopUp.Nvim.Focus\ Tree :NvimTreeFocus<CR>
  amenu <silent> PopUp.Nvim.-Sep4- :
  amenu <silent> PopUp.Nvim.Go\ to\ Definition :lua vim.lsp.buf.definition()<CR>
  amenu <silent> PopUp.Nvim.Go\ to\ References :lua vim.lsp.buf.references()<CR>
  amenu <silent> PopUp.Nvim.Code\ Action :lua vim.lsp.buf.code_action()<CR>
  amenu <silent> PopUp.Nvim.Rename\ Symbol :lua vim.lsp.buf.rename()<CR>
  amenu <silent> PopUp.Nvim.-Sep5- :
  amenu <silent> PopUp.Nvim.Diagnostics :Trouble diagnostics toggle<CR>
  amenu <silent> PopUp.Nvim.Help :lua vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Space>h", true, false, true), "n", false)<CR>
]])
