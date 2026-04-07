local M = {}

local root_cache = {}

local function normalize(path)
  if not path or path == "" then
    return nil
  end

  return vim.fs.normalize(path)
end

function M.find_upward(marker, start_path)
  local path = normalize(start_path) or vim.fn.getcwd()
  local found = vim.fs.find(marker, { path = path, upward = true })[1]

  if not found then
    return nil
  end

  return vim.fs.normalize(found)
end

function M.root_with(marker, start_path)
  local found = M.find_upward(marker, start_path)
  if not found then
    return nil
  end

  return vim.fs.dirname(found)
end

function M.pants_root(start_path)
  local path = normalize(start_path) or vim.fn.getcwd()

  if root_cache[path] ~= nil then
    return root_cache[path] or nil
  end

  local root = M.root_with("pants.toml", path)
  root_cache[path] = root or false
  return root
end

function M.is_pants_project(start_path)
  return M.pants_root(start_path) ~= nil
end

function M.invalidate_cache()
  root_cache = {}
end

-- BufEnter excluded: root dir doesn't change between buffers in same session
vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    M.invalidate_cache()
  end,
})

return M
