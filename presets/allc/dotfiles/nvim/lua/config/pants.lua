local M = {}

local project = require("config.project")
local pants_bin_cache
local python_cache = {}
local test_target_cache = {}
local last_output = {
  title = nil,
  lines = nil,
}
local live_output = {
  buf = nil,
  win = nil,
}

local function resolve_existing_path(path, cwd)
  local candidates = { path }

  if not path:match("^/") then
    table.insert(candidates, vim.fs.joinpath(cwd, path))
  end

  for _, candidate in ipairs(candidates) do
    if vim.uv.fs_stat(candidate) then
      return vim.fs.normalize(candidate)
    end
  end

  return nil
end

local function parse_output(output, cwd)
  local items = {}
  local seen = {}

  local function add_item(filename, lnum, col, text)
    local resolved = resolve_existing_path(filename, cwd)
    if not resolved then
      return
    end

    local key = table.concat({ resolved, lnum or 1, col or 1, text or "" }, ":")
    if seen[key] then
      return
    end
    seen[key] = true

    table.insert(items, {
      filename = resolved,
      lnum = lnum or 1,
      col = col or 1,
      text = text or "",
    })
  end

  for line in vim.gsplit(output, "\n", { plain = true }) do
    local parse_path, parse_line, parse_col, parse_text =
      line:match("^error: cannot format ([^:]+): Cannot parse: (%d+):(%d+): (.+)$")

    if parse_path then
      add_item(parse_path, tonumber(parse_line), tonumber(parse_col), parse_text)
    else
      local path, lnum, col, text = line:match("^([^:\n]+):(%d+):(%d+):%s*(.+)$")
      if path then
        add_item(path, tonumber(lnum), tonumber(col), text)
      else
        local changed = line:match("^%s+([^%s][^:\n]+%.[%w]+)%s*$")
        if changed then
          add_item(changed, 1, 1, "Changed by formatter")
        end
      end
    end
  end

  return items
end

local function open_command_output(title, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"

  vim.cmd("botright split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_set_name(buf, title)
end

local function focus_live_output()
  if live_output.win and vim.api.nvim_win_is_valid(live_output.win) then
    vim.api.nvim_set_current_win(live_output.win)
    return true
  end

  if live_output.buf and vim.api.nvim_buf_is_valid(live_output.buf) then
    vim.cmd("botright split")
    vim.api.nvim_win_set_buf(0, live_output.buf)
    live_output.win = vim.api.nvim_get_current_win()
    return true
  end

  return false
end

local function store_output(title, output)
  if not output or output == "" then
    return
  end

  last_output.title = title
  last_output.lines = vim.split(vim.trim(output), "\n", { plain = true })
end

local function clone_list(items)
  return vim.deepcopy(items or {})
end

local function run_shell_command(opts)
  vim.notify("Running " .. opts.label .. "...", vim.log.levels.INFO)

  vim.system({ "zsh", "-ic", opts.command }, { text = true, cwd = opts.cwd }, function(result)
    local output = table.concat({
      result.stdout or "",
      result.stderr or "",
    }, "")

    local items = parse_output(output, opts.cwd)
    store_output(opts.title .. " Output", output)

    vim.schedule(function()
      if #items > 0 then
        vim.fn.setqflist({}, "r", {
          title = opts.title,
          items = items,
        })
        vim.cmd("copen")
      end

      if opts.open_output_on_error and result.code ~= 0 and output ~= "" then
        open_command_output(opts.title .. " Output", vim.split(vim.trim(output), "\n", { plain = true }))
      elseif #items == 0 and output ~= "" then
        open_command_output(opts.title .. " Output", vim.split(vim.trim(output), "\n", { plain = true }))
      end

      if result.code == 0 then
        vim.notify(opts.label .. " finished successfully", vim.log.levels.INFO)
      else
        vim.notify(opts.label .. " finished with errors", vim.log.levels.WARN)
      end
    end)
  end)
end

local function run_live_terminal_command(opts)
  vim.notify("Running " .. opts.label .. ": " .. opts.target, vim.log.levels.INFO)
  local previous_win = vim.api.nvim_get_current_win()

  if live_output.win and vim.api.nvim_win_is_valid(live_output.win) then
    vim.api.nvim_win_close(live_output.win, true)
  end

  vim.cmd("botright 14split")
  vim.cmd("enew")
  live_output.win = vim.api.nvim_get_current_win()
  live_output.buf = vim.api.nvim_get_current_buf()

  local buf = live_output.buf
  local win = live_output.win

  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_name(buf, opts.title .. " " .. opts.target)

  local command = string.format(
    "printf 'Running %s: %s\\n\\n'; exec %s",
    opts.label,
    opts.target,
    opts.command
  )

  vim.fn.termopen({ "zsh", "-ic", command }, {
    cwd = opts.cwd,
    on_exit = function(_, code)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local output = table.concat(lines, "\n")
      local items = parse_output(output, opts.cwd)

      store_output(opts.title .. " " .. opts.target, output)

      vim.schedule(function()
        if code ~= 0 and #items > 0 then
          vim.fn.setqflist({}, "r", {
            title = opts.title,
            items = items,
          })
          vim.cmd("copen")
        end

        if code == 0 then
          vim.notify(opts.label .. " finished successfully: " .. opts.target, vim.log.levels.INFO)
        else
          vim.notify(opts.label .. " finished with errors: " .. opts.target, vim.log.levels.WARN)
        end

        if win and vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
        end

        if opts.on_exit then
          opts.on_exit({
            code = code,
            output = output,
            items = items,
          })
        end
      end)
    end,
  })

  if previous_win and vim.api.nvim_win_is_valid(previous_win) then
    vim.api.nvim_set_current_win(previous_win)
  end
end

local function pants_bin()
  if pants_bin_cache then
    return pants_bin_cache
  end

  local local_bin = vim.fn.expand("~/.local/bin/pants")
  if vim.fn.executable(local_bin) == 1 then
    pants_bin_cache = local_bin
    return pants_bin_cache
  end

  pants_bin_cache = "pants"
  return pants_bin_cache
end

local function run_pants(args, opts, on_exit)
  local root = opts.cwd
  local command = vim.list_extend({ pants_bin() }, args)

  vim.system(command, { text = true, cwd = root }, function(result)
    vim.schedule(function()
      on_exit(result)
    end)
  end)
end

local function emit_python_ready()
  vim.schedule(function()
    vim.api.nvim_exec_autocmds("User", { pattern = "PantsPythonReady", modeline = false })
  end)
end

local function discover_python_sync(root)
  local venv_root = root .. "/dist/export/python/virtualenvs"
  if vim.fn.isdirectory(venv_root) == 0 then
    return nil, {}
  end

  local candidates = vim.fn.globpath(venv_root, "*/**/bin/python", false, true)
  if not candidates or #candidates == 0 then
    return nil, {}
  end

  table.sort(candidates)
  local python_path = candidates[#candidates]
  local extra_paths = vim.fn.glob(
    vim.fn.fnamemodify(python_path, ":h:h") .. "/lib/python*/site-packages",
    false,
    true
  )

  return python_path, extra_paths or {}
end

local function ensure_python_cache(root)
  python_cache[root] = python_cache[root] or {
    python_path = nil,
    extra_paths = {},
    loading = false,
    export_running = false,
    export_failed = false,
    resolve_name = nil,
  }
  return python_cache[root]
end

local function default_resolve(root)
  local cache = ensure_python_cache(root)
  if cache.resolve_name ~= nil then
    return cache.resolve_name or nil
  end

  local pants_toml = vim.fs.joinpath(root, "pants.toml")
  if vim.fn.filereadable(pants_toml) == 0 then
    cache.resolve_name = false
    return nil
  end

  for _, line in ipairs(vim.fn.readfile(pants_toml, "", 160)) do
    local resolve_name = line:match('^%s*default_resolve%s*=%s*"([^"]+)"')
    if resolve_name then
      cache.resolve_name = resolve_name
      return resolve_name
    end

    resolve_name = line:match("^%s*default_resolve%s*=%s*'([^']+)'")
    if resolve_name then
      cache.resolve_name = resolve_name
      return resolve_name
    end
  end

  cache.resolve_name = false
  return nil
end

local function restart_basedpyright(root)
  local buffers = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == "python" then
      local path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
      if path == root or vim.startswith(path, root .. "/") then
        table.insert(buffers, bufnr)
      end
    end
  end

  for _, client in ipairs(vim.lsp.get_clients({ name = "basedpyright" })) do
    if client.config.root_dir == root then
      vim.lsp.stop_client(client.id)
    end
  end

  if vim.tbl_isempty(buffers) then
    return
  end

  vim.defer_fn(function()
    for _, bufnr in ipairs(buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
        vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr, modeline = false })
      end
    end
  end, 200)
end

local function maybe_export_python(root)
  local cache = ensure_python_cache(root)
  if cache.export_running or cache.export_failed then
    return false
  end

  local resolve_name = default_resolve(root)
  if not resolve_name then
    return false
  end

  cache.loading = true
  cache.export_running = true

  vim.notify(
    "Pants Python venv missing. Running export for " .. resolve_name .. "...",
    vim.log.levels.INFO
  )

  run_pants({
    "export",
    "--py-resolve-format=symlinked_immutable_virtualenv",
    "--resolve=" .. resolve_name,
  }, { cwd = root }, function(result)
    local output = table.concat({
      result.stdout or "",
      result.stderr or "",
    }, "")
    local python_path, extra_paths = discover_python_sync(root)

    if output ~= "" then
      store_output("PantsExport Output", output)
    end

    cache.export_running = false

    if result.code == 0 and python_path then
      cache.python_path = python_path
      cache.extra_paths = extra_paths or {}
      cache.loading = false
      cache.export_failed = false
      vim.notify("Pants Python venv ready: " .. resolve_name, vim.log.levels.INFO)
      emit_python_ready()
      restart_basedpyright(root)
      return
    end

    cache.python_path = false
    cache.extra_paths = {}
    cache.loading = false
    cache.export_failed = true
    vim.notify("pants export failed. See :PantsOutput", vim.log.levels.WARN)
    emit_python_ready()
  end)

  return true
end

local function ensure_target_cache(root)
  test_target_cache[root] = test_target_cache[root] or {
    addresses = nil,
    loading = false,
    callbacks = {},
  }
  return test_target_cache[root]
end

function M.is_available(path)
  return project.is_pants_project(path)
end

function M.root(path)
  return project.pants_root(path)
end

function M.current_python(path)
  local root = project.pants_root(path)
  if not root then
    return nil, {}
  end

  local cache = ensure_python_cache(root)
  if cache.loading or cache.python_path ~= nil then
    return cache.python_path or nil, cache.extra_paths
  end

  local python_path, extra_paths = discover_python_sync(root)
  if python_path then
    cache.python_path = python_path
    cache.extra_paths = extra_paths or {}
    return python_path, cache.extra_paths
  end

  if maybe_export_python(root) then
    return nil, {}
  end

  cache.python_path = false
  cache.extra_paths = {}

  return nil, cache.extra_paths
end

function M.current_python_label(path)
  local root = project.pants_root(path)
  if not root then
    return ""
  end

  local python_path, extra_paths = M.current_python(root)
  if not python_path then
    return "none"
  end

  local version = nil
  for _, extra_path in ipairs(extra_paths or {}) do
    version = extra_path:match("/lib/python([%d%.]+)/site%-packages$")
    if version then
      break
    end
  end

  local relative = vim.fs.relpath(root, python_path) or python_path
  relative = relative:gsub("^dist/export/python/virtualenvs/", "")

  if version then
    return string.format("%s:%s", version, relative)
  end

  return relative
end

function M.invalidate_python_cache(path)
  local root = project.pants_root(path)
  if not root then
    return
  end

  local cache = ensure_python_cache(root)
  cache.python_path = nil
  cache.extra_paths = {}
  cache.loading = false
end

function M.prewarm_python(path)
  local root = project.pants_root(path)
  if not root then
    return
  end

  local cache = ensure_python_cache(root)
  if cache.loading or cache.python_path ~= nil then
    return
  end

  local python_path, extra_paths = discover_python_sync(root)
  if python_path then
    cache.python_path = python_path
    cache.extra_paths = extra_paths or {}
    emit_python_ready()
    return
  end

  if maybe_export_python(root) then
    return
  end

  local venv_root = root .. "/dist/export/python/virtualenvs"
  if vim.fn.isdirectory(venv_root) == 0 then
    cache.python_path = false
    cache.extra_paths = {}
    emit_python_ready()
    return
  end

  cache.loading = true

  local command = string.format(
    "find %s -type f -path '*/bin/python' | sort | tail -n 1",
    vim.fn.shellescape(venv_root)
  )

  vim.system({ "zsh", "-lc", command }, { text = true }, function(result)
    local python_path = vim.trim(result.stdout or "")
    local extra_paths = {}

    if result.code == 0 and python_path ~= "" then
      extra_paths = vim.fn.glob(
        vim.fn.fnamemodify(python_path, ":h:h") .. "/lib/python*/site-packages",
        false,
        true
      )
      cache.python_path = python_path
      cache.extra_paths = extra_paths or {}
    else
      cache.python_path = false
      cache.extra_paths = {}
    end

    cache.loading = false
    emit_python_ready()
  end)
end

-- Like current_python_label but returns nil when discovery hasn't completed yet.
-- Safe to call from the statusline: never triggers synchronous filesystem operations.
function M.current_python_label_if_cached(path)
  local root = project.pants_root(path)
  if not root then
    return ""
  end

  local cache = python_cache[root]
  if not cache or cache.python_path == nil then
    return nil  -- prewarm still in progress
  end

  local python_path = cache.python_path
  if not python_path then
    return "none"
  end

  local extra_paths = cache.extra_paths or {}
  local version = nil
  for _, extra_path in ipairs(extra_paths) do
    version = extra_path:match("/lib/python([%d%.]+)/site%-packages$")
    if version then
      break
    end
  end

  local relative = vim.fs.relpath(root, python_path) or python_path
  relative = relative:gsub("^dist/export/python/virtualenvs/", "")

  if version then
    return string.format("%s:%s", version, relative)
  end

  return relative
end

function M.run_prepush()
  local root = project.pants_root(vim.fn.getcwd())
  if not root then
    vim.notify("No pants.toml found in current project", vim.log.levels.WARN)
    return
  end

  run_shell_command({
    cwd = root,
    command = "pre-push",
    label = "pre-push",
    title = "PrePush",
  })
end

function M.list_test_targets(callback)
  local root = project.pants_root(vim.fn.getcwd())
  if not root then
    vim.notify("No pants.toml found in current project", vim.log.levels.WARN)
    return
  end

  local cache = ensure_target_cache(root)
  if cache.addresses then
    callback(root, clone_list(cache.addresses))
    return
  end

  table.insert(cache.callbacks, callback)
  if cache.loading then
    return
  end

  cache.loading = true

  run_pants({
    "--filter-target-type=python_test",
    "--filter-granularity=file",
    "list",
    "::",
  }, { cwd = root }, function(result)
    if result.code ~= 0 then
      local output = table.concat({
        result.stdout or "",
        result.stderr or "",
      }, "")
      store_output("PantsTests Output", output)
      vim.notify("pants list failed", vim.log.levels.WARN)
      if output ~= "" then
        open_command_output("PantsTests Output", vim.split(vim.trim(output), "\n", { plain = true }))
      end
      cache.loading = false
      cache.callbacks = {}
      return
    end

    local addresses = {}
    for line in vim.gsplit(result.stdout or "", "\n", { plain = true }) do
      local address = vim.trim(line)
      if address ~= "" then
        table.insert(addresses, address)
      end
    end

    cache.loading = false
    cache.addresses = addresses

    local callbacks = cache.callbacks
    cache.callbacks = {}
    for _, cb in ipairs(callbacks) do
      cb(root, clone_list(addresses))
    end
  end)
end

function M.prewarm_test_targets(path)
  local root = project.pants_root(path)
  if not root then
    return
  end

  local cache = ensure_target_cache(root)
  if cache.loading or cache.addresses then
    return
  end

  M.list_test_targets(function() end)
end

function M.prewarm(path)
  local root = project.pants_root(path or vim.fn.getcwd())
  if not root then
    return
  end

  M.prewarm_python(root)
  M.prewarm_test_targets(root)
end

function M.run_test(address, opts)
  local root = project.pants_root(vim.fn.getcwd())
  if not root then
    vim.notify("No pants.toml found in current project", vim.log.levels.WARN)
    return
  end

  run_live_terminal_command({
    cwd = root,
    command = string.format("%s test %s", vim.fn.shellescape(pants_bin()), vim.fn.shellescape(address)),
    label = "pants test",
    title = "PantsTest",
    target = address,
    on_exit = opts and opts.on_exit or nil,
  })
end

function M.show_last_output()
  if focus_live_output() then
    return
  end

  if not last_output.lines or vim.tbl_isempty(last_output.lines) then
    vim.notify("No Pants output captured yet", vim.log.levels.INFO)
    return
  end

  open_command_output(last_output.title or "Pants Output", last_output.lines)
end

function M.export_python(path)
  local root = project.pants_root(path or vim.fn.getcwd())
  if not root then
    vim.notify("No pants.toml found in current project", vim.log.levels.WARN)
    return
  end

  local cache = ensure_python_cache(root)
  if cache.export_running then
    vim.notify("pants export already running", vim.log.levels.INFO)
    return
  end

  cache.python_path = nil
  cache.extra_paths = {}
  cache.loading = false
  cache.export_failed = false

  if maybe_export_python(root) then
    return
  end

  vim.notify("Could not determine Pants default_resolve", vim.log.levels.WARN)
end

function M.setup_commands()
  vim.api.nvim_create_user_command("PantsInfo", function()
    local root = project.pants_root(vim.fn.getcwd())
    if not root then
      vim.notify("No pants.toml found", vim.log.levels.WARN)
      return
    end

    local pants_python, _ = M.current_python(root)

    local lsp_python = nil
    local clients = vim.lsp.get_clients({ name = "basedpyright" })
    if clients[1] then
      local s = clients[1].config.settings
      lsp_python = s and s.python and s.python.pythonPath or nil
    end

    local match = pants_python and lsp_python and (pants_python == lsp_python)
    local lines = {
      "Pants root:    " .. root,
      "Pants python:  " .. (pants_python or "not found"),
      "LSP python:    " .. (lsp_python   or "not configured"),
      "",
      match == true  and "✓ Match" or
      match == false and "✗ Mismatch" or
                         "? LSP not attached",
    }
    vim.notify(table.concat(lines, "\n"), match == false and vim.log.levels.WARN or vim.log.levels.INFO)
  end, {})

  vim.api.nvim_create_user_command("PrePush", function()
    M.run_prepush()
  end, {})
  vim.api.nvim_create_user_command("PantsTests", function()
    require("config.pants_tests").open()
  end, {})
  vim.api.nvim_create_user_command("PantsOutput", function()
    M.show_last_output()
  end, {})
  vim.api.nvim_create_user_command("PantsExportPython", function()
    M.export_python()
  end, {})
end

return M
