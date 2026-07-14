-- Clear the vim.loader byte-compilation cache whenever the Neovim version changes.
--
-- lazy.nvim enables vim.loader, which caches compiled Lua keyed to the current
-- $VIMRUNTIME path. After a Neovim upgrade the old runtime directory is gone, so
-- stale cache entries point at paths that no longer exist and lazily-required core
-- modules fail to load (e.g. "module 'vim.ui' not found" when deleting a file in
-- nvim-tree). Wiping the cache on version bumps forces a clean recompile.
--
-- Must run before config.lazy (which enables the loader).

local version = tostring(vim.version())
local stamp = vim.fn.stdpath("cache") .. "/nvim_version"

-- readfile() throws if the stamp doesn't exist yet (first run) → treat as changed.
local ok, prev = pcall(function()
  return table.concat(vim.fn.readfile(stamp), "\n")
end)
if not ok or prev ~= version then
  vim.fn.delete(vim.fn.stdpath("cache") .. "/luac", "rf")
  vim.fn.writefile({ version }, stamp)
end
