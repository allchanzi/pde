local M = {}

local cache = nil
local prefs_paths = {
  vim.fn.expand("~/.config/pde/prefs"),
  vim.fn.expand("~/.config/config/prefs"),
  vim.fn.expand("~/.config/shell/prefs"),
}

local function parse_value(value)
  value = vim.trim(value or "")

  if value:sub(1, 1) == "'" and value:sub(-1) == "'" then
    return value:sub(2, -2)
  end

  if value:sub(1, 1) == '"' and value:sub(-1) == '"' then
    return value:sub(2, -2)
  end

  value = value:gsub("\\ ", " ")
  value = value:gsub("\\=", "=")
  return value
end

local function load()
  if cache ~= nil then
    return cache
  end

  cache = {}

  for _, path in ipairs(prefs_paths) do
    if vim.uv.fs_stat(path) then
      for line in io.lines(path) do
        local key, value = line:match("^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
        if key then
          cache[key] = parse_value(value)
        end
      end
      break
    end
  end

  return cache
end

function M.get(key, default)
  local prefs = load()
  local value = prefs[key]
  if value == nil or value == "" then
    return default
  end
  return value
end

function M.enabled(key, default)
  local fallback = default and "1" or "0"
  local value = M.get(key, fallback)
  return value == "1" or value == "true" or value == "yes" or value == "on"
end

return M
