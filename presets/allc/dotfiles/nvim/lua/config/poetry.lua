local M = {}

local project = require("config.project")
local poetry_bin_cache
local python_cache = {}

local function poetry_bin()
  if poetry_bin_cache then
    return poetry_bin_cache
  end

  if vim.fn.executable("poetry") == 1 then
    poetry_bin_cache = "poetry"
    return poetry_bin_cache
  end

  poetry_bin_cache = false
  return nil
end

local function ensure_python_cache(root)
  python_cache[root] = python_cache[root] or {
    python_path = nil,
    extra_paths = {},
    loading = false,
  }
  return python_cache[root]
end

local function discover_python_sync(root)
  local bin = poetry_bin()
  if not bin then
    return nil, {}
  end

  local result = vim.system({ bin, "env", "info", "-p" }, { text = true, cwd = root }):wait()
  local venv_root = vim.trim(result.stdout or "")
  if result.code ~= 0 or venv_root == "" then
    return nil, {}
  end

  local python_path = vim.fs.joinpath(venv_root, "bin", "python")
  if vim.fn.executable(python_path) == 0 then
    return nil, {}
  end

  local extra_paths = vim.fn.glob(
    vim.fs.joinpath(venv_root, "lib/python*/site-packages"),
    false,
    true
  )

  return python_path, extra_paths or {}
end

function M.is_available(path)
  return project.is_poetry_project(path) and poetry_bin() ~= nil
end

function M.root(path)
  return project.poetry_root(path)
end

function M.current_python(path)
  local root = project.poetry_root(path)
  if not root then
    return nil, {}
  end

  local cache = ensure_python_cache(root)
  if cache.python_path ~= nil then
    return cache.python_path, cache.extra_paths
  end

  local python_path, extra_paths = discover_python_sync(root)
  cache.python_path = python_path or false
  cache.extra_paths = extra_paths or {}

  return python_path, cache.extra_paths
end

function M.current_python_label(path)
  local root = project.poetry_root(path)
  if not root then
    return ""
  end

  local python_path, extra_paths = M.current_python(root)
  if not python_path then
    return "loading"
  end

  local version
  for _, extra_path in ipairs(extra_paths or {}) do
    version = extra_path:match("/lib/python([%d%.]+)/site%-packages$")
    if version then
      break
    end
  end

  local relative = vim.fs.relpath(root, python_path) or python_path

  if version then
    return string.format("%s:%s", version, relative)
  end

  return relative
end

function M.current_python_label_if_cached(path)
  local root = project.poetry_root(path)
  if not root then
    return ""
  end

  local cache = python_cache[root]
  if not cache or cache.python_path == nil then
    return nil
  end

  local python_path = cache.python_path
  if not python_path then
    return "none"
  end

  local extra_paths = cache.extra_paths or {}
  local version
  for _, extra_path in ipairs(extra_paths) do
    version = extra_path:match("/lib/python([%d%.]+)/site%-packages$")
    if version then
      break
    end
  end

  local relative = vim.fs.relpath(root, python_path) or python_path

  if version then
    return string.format("%s:%s", version, relative)
  end

  return relative
end

function M.invalidate_python_cache(path)
  local root = project.poetry_root(path)
  if not root then
    return
  end

  python_cache[root] = nil
end

function M.prewarm_python(path)
  local root = project.poetry_root(path)
  if not root then
    return
  end

  local cache = ensure_python_cache(root)
  if cache.loading or cache.python_path ~= nil then
    return
  end

  M.current_python(root)
end

return M
