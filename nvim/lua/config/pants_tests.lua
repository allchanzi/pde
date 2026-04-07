local M = {}

local pants = require("config.pants")
local namespace = vim.api.nvim_create_namespace("pants-tests")
local redraw

local state = {
  buf = nil,
  win = nil,
  entries = {},
  root = nil,
  line_offset = 0,
  addresses = {},
  statuses = {},
  expanded_dirs = {},
  spinner_timer = nil,
  spinner_index = 1,
}

local spinner_frames = { "⏳", "⌛" }

local function parse_address(address)
  local path, target = address:match("^(.-):(.+)$")
  if not path then
    path = address
    target = address
  end

  if path:sub(1, 2) == "./" then
    path = path:sub(3)
  end

  return path, target
end

local function nearest_test_index(entries, current_file)
  if not current_file or current_file == "" then
    return nil
  end

  local normalized = vim.fs.normalize(current_file)
  local current_parts = vim.split(normalized, "/", { plain = true, trimempty = true })
  local best_index
  local best_score = math.huge

  for index, entry in ipairs(entries) do
    if entry.kind == "file" then
      if normalized == entry.abs_path then
        return index
      end

      local parts = vim.split(entry.abs_path, "/", { plain = true, trimempty = true })
      local common = 0

      while common < #parts and common < #current_parts and parts[common + 1] == current_parts[common + 1] do
        common = common + 1
      end

      local distance = (#parts - common) + (#current_parts - common)
      if distance < best_score then
        best_score = distance
        best_index = index
      end
    end
  end

  return best_index
end

local function nearest_test_path(addresses, root, current_file)
  if not current_file or current_file == "" then
    return nil
  end

  local normalized = vim.fs.normalize(current_file)
  local current_parts = vim.split(normalized, "/", { plain = true, trimempty = true })
  local best_path
  local best_score = math.huge

  for _, address in ipairs(addresses) do
    local path = parse_address(address)
    if path and path ~= "" then
      local rel_path = vim.fs.normalize(path)
      local abs_path = vim.fs.joinpath(root, rel_path)

      if normalized == abs_path then
        return rel_path
      end

      local parts = vim.split(abs_path, "/", { plain = true, trimempty = true })
      local common = 0

      while common < #parts and common < #current_parts and parts[common + 1] == current_parts[common + 1] do
        common = common + 1
      end

      local distance = (#parts - common) + (#current_parts - common)
      if distance < best_score then
        best_score = distance
        best_path = rel_path
      end
    end
  end

  return best_path
end

local function expand_branch_to_file(rel_path)
  state.expanded_dirs = {}

  if not rel_path or rel_path == "" then
    return
  end

  local parent = vim.fs.dirname(rel_path)
  while parent and parent ~= "." and parent ~= "/" and parent ~= "" do
    state.expanded_dirs[parent] = true
    local next_parent = vim.fs.dirname(parent)
    if next_parent == parent then
      break
    end
    parent = next_parent
  end
end

local function render_status_icon(address)
  local status = state.statuses[address]
  if not status or status.state == "idle" then
    return "  "
  end

  if status.state == "running" then
    return spinner_frames[state.spinner_index]
  end

  if status.state == "passed" then
    return "✅"
  end

  if status.state == "failed" then
    return "❌"
  end

  return "  "
end

local function render_summary()
  local total = #state.addresses
  local passed = 0
  local failed = 0
  local running = 0

  for _, status in pairs(state.statuses) do
    if status.state == "passed" then
      passed = passed + 1
    elseif status.state == "failed" then
      failed = failed + 1
    elseif status.state == "running" then
      running = running + 1
    end
  end

  return string.format(
    "Summary   total %d   ✅ %d   ❌ %d   ⏳ %d",
    total,
    passed,
    failed,
    running
  )
end

local function render_entries(root, addresses)
  root = root or vim.fn.getcwd()
  local tree = {
    children = {},
  }

  for _, address in ipairs(addresses) do
    local path = parse_address(address)
    if path and path ~= "" then
      local rel_path = vim.fs.normalize(path)
      local parts = vim.split(rel_path, "/", { plain = true, trimempty = true })
      local node = tree

      for index = 1, #parts - 1 do
        local part = parts[index]
        node.children[part] = node.children[part] or {
          kind = "dir",
          label = part,
          rel_path = table.concat(vim.list_slice(parts, 1, index), "/"),
          abs_path = vim.fs.joinpath(root, table.concat(vim.list_slice(parts, 1, index), "/")),
          children = {},
        }
        node = node.children[part]
      end

      local filename = parts[#parts]
      node.children[filename] = {
        kind = "file",
        label = filename,
        rel_path = rel_path,
        abs_path = vim.fs.joinpath(root, rel_path),
        address = address,
      }
    end
  end

  local entries = {}
  local lines = {
    "󰙅 Pants Tests",
    "  <Enter>/l toggle/open   h collapse   r run   o output   q close",
    render_summary(),
    "",
    "󰉋 " .. vim.fs.basename(root) .. "/",
  }
  local line_offset = #lines

  local function render_node(node, prefix)
    local names = vim.tbl_keys(node.children)
    table.sort(names, function(a, b)
      local left = node.children[a]
      local right = node.children[b]

      if left.kind ~= right.kind then
        return left.kind == "dir"
      end

      return a < b
    end)

    for index, name in ipairs(names) do
      local child = node.children[name]
      local is_last = index == #names
      local connector = is_last and "└─ " or "├─ "
      local next_prefix = prefix .. (is_last and "   " or "│  ")
      table.insert(entries, child)

      if child.kind == "dir" then
        local icon = state.expanded_dirs[child.rel_path] and "󰉋" or "󰉖"
        child.line = prefix .. connector .. icon .. " " .. child.label .. "/"
        table.insert(lines, child.line)
        if state.expanded_dirs[child.rel_path] then
          render_node(child, next_prefix)
        end
      else
        local status = render_status_icon(child.address)
        child.line = prefix .. connector .. status .. " 󰈙 " .. child.label
        child.status_icon = status
        child.status_col = #prefix + #connector
        table.insert(lines, child.line)
      end
    end
  end

  render_node(tree, "")

  if #entries == 0 then
    table.insert(lines, "  No Pants test targets found.")
  end

  return lines, entries, line_offset
end

local function apply_highlights(buf, entries, line_offset)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)

  vim.api.nvim_buf_add_highlight(buf, namespace, "PantsTestsHeader", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, namespace, "PantsTestsHint", 1, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, namespace, "PantsTestsSummary", 2, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, namespace, "PantsTestsRoot", 4, 0, -1)

  for index, entry in ipairs(entries) do
    local line_nr = line_offset + index - 1

    if entry.kind == "dir" then
      vim.api.nvim_buf_add_highlight(buf, namespace, "PantsTestsDirectory", line_nr, 0, -1)
    else
      vim.api.nvim_buf_add_highlight(buf, namespace, "PantsTestsFile", line_nr, 0, -1)

      local status_group = "PantsTestsIdle"
      local status = state.statuses[entry.address]
      if status then
        if status.state == "running" then
          status_group = "PantsTestsRunning"
        elseif status.state == "passed" then
          status_group = "PantsTestsPassed"
        elseif status.state == "failed" then
          status_group = "PantsTestsFailed"
        end
      end

      vim.api.nvim_buf_add_highlight(
        buf,
        namespace,
        status_group,
        line_nr,
        entry.status_col,
        entry.status_col + #entry.status_icon
      )
    end
  end
end

local function close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.entries = {}
  state.root = nil
  state.addresses = {}
  state.statuses = {}
  state.expanded_dirs = {}
  state.spinner_index = 1

  if state.spinner_timer then
    state.spinner_timer:stop()
    state.spinner_timer:close()
    state.spinner_timer = nil
  end
end

local function has_running_tests()
  for _, status in pairs(state.statuses) do
    if status.state == "running" then
      return true
    end
  end

  return false
end

local function update_spinner()
  if has_running_tests() then
    if not state.spinner_timer then
      state.spinner_timer = vim.uv.new_timer()
      state.spinner_timer:start(0, 250, vim.schedule_wrap(function()
        state.spinner_index = (state.spinner_index % #spinner_frames) + 1
        redraw()
      end))
    end
  elseif state.spinner_timer then
    state.spinner_timer:stop()
    state.spinner_timer:close()
    state.spinner_timer = nil
    state.spinner_index = 1
  end
end

redraw = function()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  local cursor = { 1, 0 }
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    cursor = vim.api.nvim_win_get_cursor(state.win)
  end

  local lines, entries, line_offset = render_entries(state.root, state.addresses)
  state.entries = entries
  state.line_offset = line_offset

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  apply_highlights(state.buf, entries, line_offset)

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    local max_line = math.max(1, vim.api.nvim_buf_line_count(state.buf))
    vim.api.nvim_win_set_cursor(state.win, { math.min(cursor[1], max_line), 0 })
  end
end

local function selected_entry()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return state.entries[line - state.line_offset]
end

local function jump_to_entry()
  local entry = selected_entry()
  if not entry then
    return
  end

  if entry.kind == "dir" then
    state.expanded_dirs[entry.rel_path] = not state.expanded_dirs[entry.rel_path]
    redraw()
    return
  end

  close()
  vim.cmd("edit " .. vim.fn.fnameescape(entry.abs_path))
end

local function run_selected_test()
  local entry = selected_entry()
  if not entry or entry.kind ~= "file" then
    return
  end

  state.statuses[entry.address] = { state = "running" }
  update_spinner()
  redraw()

  pants.run_test(entry.address, {
    on_exit = function(result)
      if result.code == 0 then
        state.statuses[entry.address] = { state = "passed" }
      else
        state.statuses[entry.address] = { state = "failed" }
      end
      update_spinner()
      redraw()
    end,
  })
end

local function show_last_output()
  pants.show_last_output()
end

local function set_buffer_keymaps(buf)
  local opts = { buffer = buf, silent = true, nowait = true }

  vim.keymap.set("n", "q", close, opts)
  vim.keymap.set("n", "<Esc>", close, opts)
  vim.keymap.set("n", "<CR>", jump_to_entry, opts)
  vim.keymap.set("n", "l", jump_to_entry, opts)
  vim.keymap.set("n", "h", function()
    local entry = selected_entry()
    if entry and entry.kind == "dir" and state.expanded_dirs[entry.rel_path] then
      state.expanded_dirs[entry.rel_path] = nil
      redraw()
    end
  end, opts)
  vim.keymap.set("n", "r", run_selected_test, opts)
  vim.keymap.set("n", "o", show_last_output, opts)
end

local function open_window(lines, entries)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  local width = math.max(60, math.floor(vim.o.columns * 0.45))
  local height = math.max(18, math.min(#lines + 2, math.floor(vim.o.lines * 0.75)))
  local row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "pants-tests"

  vim.api.nvim_set_hl(0, "PantsTestsHeader", { link = "Title" })
  vim.api.nvim_set_hl(0, "PantsTestsHint", { link = "Comment" })
  vim.api.nvim_set_hl(0, "PantsTestsSummary", { link = "Constant" })
  vim.api.nvim_set_hl(0, "PantsTestsRoot", { link = "Directory" })
  vim.api.nvim_set_hl(0, "PantsTestsDirectory", { link = "Directory" })
  vim.api.nvim_set_hl(0, "PantsTestsFile", { link = "Normal" })
  vim.api.nvim_set_hl(0, "PantsTestsIdle", { fg = "#7f849c" })
  vim.api.nvim_set_hl(0, "PantsTestsRunning", { fg = "#f9e2af", bold = true })
  vim.api.nvim_set_hl(0, "PantsTestsPassed", { fg = "#a6e3a1", bold = true })
  vim.api.nvim_set_hl(0, "PantsTestsFailed", { fg = "#f38ba8", bold = true })

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  apply_highlights(buf, entries, #lines - #entries)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Tests ",
    title_pos = "center",
  })

  state.buf = buf
  state.win = win
  state.entries = entries
  state.line_offset = #lines - #entries

  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winhighlight = table.concat({
    "Normal:NormalFloat",
    "FloatBorder:FloatBorder",
    "CursorLine:Visual",
  }, ",")

  set_buffer_keymaps(buf)
end

function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    close()
    return
  end

  if not pants.is_available(vim.fn.getcwd()) then
    vim.notify("No pants.toml found in current project", vim.log.levels.WARN)
    return
  end

  pants.list_test_targets(function(root, addresses)
    local current_file = vim.api.nvim_buf_get_name(0)
    state.root = root
    state.addresses = addresses
    state.statuses = {}
    expand_branch_to_file(nearest_test_path(addresses, root, current_file))

    local lines, entries, line_offset = render_entries(root, addresses)
    open_window(lines, entries)
    state.line_offset = line_offset

    local selected = nearest_test_index(entries, current_file)
    if selected then
      vim.api.nvim_win_set_cursor(state.win, { selected + state.line_offset, 0 })
    elseif #entries > 0 then
      vim.api.nvim_win_set_cursor(state.win, { state.line_offset + 1, 0 })
    end
  end)
end

return M
