-- Path where lazy.nvim will be installed
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- If lazy.nvim is not installed → clone it
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end

-- Add lazy.nvim to runtime path
vim.opt.rtp:prepend(lazypath)

-- Setup plugins from lua/plugins folder
require("lazy").setup({
  { import = "plugins" },
}, {
  -- Disable luarocks support (we don't need it → avoids warnings)
  rocks = {
    enabled = false,
  },
})