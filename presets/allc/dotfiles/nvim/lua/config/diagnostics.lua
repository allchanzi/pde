-- Diagnostic configuration with a persistent inline (virtual text) toggle.
--
-- vim.diagnostic.config() is global, so the FileType autocmd re-applies the
-- right config whenever the focused filetype changes. `inline_override` lets a
-- manual toggle stick across those switches instead of being reset back to the
-- per-filetype default.
local M = {}

M.base = {
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

M.virtual_text_opts = {
  spacing = 2,
  source = "if_many",
  prefix = "●",
}

-- nil = follow the per-filetype default; true/false = sticky user override
local inline_override = nil

-- Whether inline virtual text is on by default for a given filetype
local function filetype_default(filetype)
  return filetype == "python"
end

local function config_for(bufnr)
  local inline = inline_override
  if inline == nil then
    inline = filetype_default(vim.bo[bufnr].filetype)
  end

  return vim.tbl_deep_extend("force", M.base, {
    virtual_text = inline and M.virtual_text_opts or false,
  })
end

-- Apply the effective diagnostic config for a buffer's filetype
function M.apply(bufnr)
  vim.diagnostic.config(config_for(bufnr))
end

-- Flip inline diagnostics and make the choice persist across filetype switches
function M.toggle()
  local currently_on = vim.diagnostic.config().virtual_text ~= false
  inline_override = not currently_on
  M.apply(vim.api.nvim_get_current_buf())
  vim.notify(
    "Inline diagnostics: " .. (inline_override and "on" or "off"),
    vim.log.levels.INFO
  )
end

return M
