local M = {}

local pants_root_cache = {}
local poetry_root_cache = {}

local function normalize(path)
  if not path or path == "" then
    return nil
  end

  return vim.fs.normalize(path)
end

local function cached_root(root_cache, marker, start_path)
  local path = normalize(start_path) or vim.fn.getcwd()

  if root_cache[path] ~= nil then
    return root_cache[path] or nil
  end

  local root = M.root_with(marker, path)
  root_cache[path] = root or false
  return root
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
  return cached_root(pants_root_cache, "pants.toml", start_path)
end

function M.is_pants_project(start_path)
  return M.pants_root(start_path) ~= nil
end

function M.poetry_root(start_path)
  return cached_root(poetry_root_cache, "pyproject.toml", start_path)
end

function M.is_poetry_project(start_path)
  local root = M.poetry_root(start_path)
  if not root then
    return false
  end

  local pyproject = vim.fs.joinpath(root, "pyproject.toml")
  if vim.fn.filereadable(pyproject) == 0 then
    return false
  end

  local lines = vim.fn.readfile(pyproject, "", 40)
  for _, line in ipairs(lines) do
    if line:match("^%s*%[tool%.poetry%]%s*$") then
      return true
    end
  end

  return false
end

function M.invalidate_cache()
  pants_root_cache = {}
  poetry_root_cache = {}
end

-- BufEnter excluded: root dir doesn't change between buffers in same session
vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    M.invalidate_cache()
  end,
})

return M
