local M = {}

local prefixes = {
  "Search:  ",
  "Replace: ",
  "Path:    ",
}

local function parse_field(line, prefix)
  if vim.startswith(line, prefix) then
    return line:sub(#prefix + 1)
  end

  local stripped = line:gsub("^.-:%s*", "", 1)
  return stripped
end

local function build_rg_args(search, path_filter)
  local args = {
    "rg",
    "--vimgrep",
    "--fixed-strings",
    "--smart-case",
  }

  if path_filter ~= "" then
    local expanded = vim.fn.fnamemodify(vim.fn.expand(path_filter), ":p")
    if vim.fn.isdirectory(expanded) == 1 or vim.fn.filereadable(expanded) == 1 then
      table.insert(args, "--")
      table.insert(args, search)
      table.insert(args, path_filter)
      return args
    end

    table.insert(args, "-g")
    table.insert(args, path_filter)
  end

  table.insert(args, "--")
  table.insert(args, search)
  return args
end

local function parse_vimgrep(lines)
  local items = {}

  for _, line in ipairs(lines) do
    local filename, lnum, col, text = line:match("^([^:]+):(%d+):(%d+):(.*)$")
    if filename then
      items[#items + 1] = {
        filename = filename,
        lnum = tonumber(lnum),
        col = tonumber(col),
        text = text,
      }
    end
  end

  return items
end

local function lua_pattern_escape(text)
  return text:gsub("(%W)", "%%%1")
end

local function replace_in_line(line, search, replacement)
  local pattern = lua_pattern_escape(search)
  return (line:gsub(pattern, replacement, 1))
end

local function replace_in_lines(lines, search, replacement)
  local changed = false

  for index, line in ipairs(lines) do
    local updated = replace_in_line(line, search, replacement)
    if updated ~= line then
      lines[index] = updated
      changed = true
    end
  end

  return changed
end

local function save_buffer_if_needed(buf)
  if not vim.bo[buf].modified then
    return
  end

  vim.api.nvim_buf_call(buf, function()
    vim.cmd("silent noautocmd write")
  end)
end

local function replace_all_files(items, search, replacement)
  local seen = {}

  for _, item in ipairs(items) do
    if not seen[item.filename] then
      seen[item.filename] = true

      local buf = vim.fn.bufadd(item.filename)
      vim.fn.bufload(buf)

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      if replace_in_lines(lines, search, replacement) then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        save_buffer_if_needed(buf)
      end
    end
  end
end

local function replace_in_file(filename, search, replacement)
  local buf = vim.fn.bufadd(filename)
  vim.fn.bufload(buf)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if replace_in_lines(lines, search, replacement) then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    save_buffer_if_needed(buf)
  end
end

local function replace_selected_occurrence(item, search, replacement)
  local buf = vim.fn.bufadd(item.filename)
  vim.fn.bufload(buf)

  local lines = vim.api.nvim_buf_get_lines(buf, item.lnum - 1, item.lnum, false)
  local line = lines[1]
  if line == nil then
    return
  end

  local updated = replace_in_line(line, search, replacement)
  if updated == line then
    return
  end

  vim.api.nvim_buf_set_lines(buf, item.lnum - 1, item.lnum, false, { updated })
  save_buffer_if_needed(buf)
end

function M.open()
  local state = {
    values = { "", "", "" },
    field = 1,
  }

  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.min(76, math.max(52, vim.o.columns - 8))
  local height = 6
  local row = math.floor((vim.o.lines - height) / 2) - 1
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = width,
    height = height,
    row = math.max(row, 1),
    col = math.max(col, 0),
    title = " Project Replace ",
    title_pos = "center",
  })

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "projectreplace"

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  local function render()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      prefixes[1] .. state.values[1],
      prefixes[2] .. state.values[2],
      prefixes[3] .. state.values[3],
      "",
      "<Tab> next field, <S-Tab> previous, <Enter> stage replace, <Esc> close",
      "Uses rg for matches, opens quickfix, then pre-fills a confirm-each :cdo replace.",
    })
  end

  local function sync_state()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, 3, false)
    for i = 1, 3 do
      state.values[i] = vim.trim(parse_field(lines[i] or "", prefixes[i]))
    end
  end

  local function focus_field(field)
    state.field = field
    render()
    vim.api.nvim_win_set_cursor(win, { field, #prefixes[field] })
    vim.cmd.startinsert()
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function submit()
    sync_state()

    local search = state.values[1]
    local replacement = state.values[2]
    local path_filter = state.values[3]

    if search == "" then
      vim.notify("Search field cannot be empty", vim.log.levels.WARN)
      focus_field(1)
      return
    end

    local result = vim.system(build_rg_args(search, path_filter), { text = true }):wait()
    if result.code ~= 0 and (not result.stdout or result.stdout == "") then
      vim.notify("No matches found for project replace", vim.log.levels.INFO)
      focus_field(1)
      return
    end

    local items = parse_vimgrep(vim.split(result.stdout or "", "\n", { trimempty = true }))
    if vim.tbl_isempty(items) then
      vim.notify("No matches found for project replace", vim.log.levels.INFO)
      focus_field(1)
      return
    end

    close()
    M.open_results(search, replacement, path_filter, items)
  end

  local function next_field(delta)
    sync_state()
    local field = state.field + delta
    if field < 1 then
      field = 3
    elseif field > 3 then
      field = 1
    end
    focus_field(field)
  end

  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, nowait = true })
  end

  map({ "n", "i" }, "<Tab>", function() next_field(1) end)
  map({ "n", "i" }, "<S-Tab>", function() next_field(-1) end)
  map({ "n", "i" }, "<CR>", submit)
  map({ "n", "i" }, "<Esc>", close)
  map("n", "q", close)

  render()
  focus_field(1)
end

function M.open_results(search, replacement, path_filter, items)
  local state = {
    items = items,
    index = 1,
    search = search,
    replacement = replacement,
    path_filter = path_filter,
  }

  local width = math.max(80, math.min(vim.o.columns - 6, 140))
  local height = math.max(14, math.min(vim.o.lines - 6, 36))
  local left_width = math.floor(width * 0.42)
  local right_width = width - left_width - 1
  local row = math.floor((vim.o.lines - height) / 2) - 1
  local col = math.floor((vim.o.columns - width) / 2)

  local left_buf = vim.api.nvim_create_buf(false, true)
  local right_buf = vim.api.nvim_create_buf(false, true)
  local preview_ns = vim.api.nvim_create_namespace("project_replace_preview")

  local left_win = vim.api.nvim_open_win(left_buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = left_width,
    height = height,
    row = math.max(row, 1),
    col = math.max(col, 0),
    title = " Matches ",
    title_pos = "center",
  })

  local right_win = vim.api.nvim_open_win(right_buf, false, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = right_width,
    height = height,
    row = math.max(row, 1),
    col = math.max(col + left_width + 1, 0),
    title = " Preview ",
    title_pos = "center",
  })

  for _, buf in ipairs({ left_buf, right_buf }) do
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
  end

  vim.wo[left_win].wrap = false
  vim.wo[left_win].cursorline = true
  vim.wo[right_win].wrap = false
  vim.wo[right_win].cursorline = false

  local function close()
    for _, win in ipairs({ left_win, right_win }) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
  end

  local function preview_item(item)
    if item == nil then
      vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, { "No selection" })
      return
    end

    local ok, lines = pcall(vim.fn.readfile, item.filename)
    if not ok then
      vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, { "Could not read file" })
      return
    end

    local start_line = math.max(1, item.lnum - 4)
    local finish_line = math.min(#lines, item.lnum + 4)
    local preview = {
      ("File: %s"):format(item.filename),
      ("Line: %d  Col: %d"):format(item.lnum, item.col),
      ("Search: %s"):format(state.search),
      ("Replace: %s"):format(state.replacement),
      "",
    }

    for i = start_line, finish_line do
      local prefix = i == item.lnum and "> " or "  "
      preview[#preview + 1] = ("%s%4d  %s"):format(prefix, i, lines[i] or "")
    end

    vim.bo[right_buf].modifiable = true
    vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, preview)
    vim.bo[right_buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(right_buf, preview_ns, 0, -1)
    vim.api.nvim_buf_add_highlight(right_buf, preview_ns, "Title", 0, 0, -1)
  end

  local function render()
    local lines = {
      ("Search: %s"):format(state.search),
      ("Replace: %s"):format(state.replacement),
      ("Path: %s"):format(state.path_filter ~= "" and state.path_filter or "(all files)"),
      "",
      "Actions: <Enter> jump  a replace all  f replace file  r replace hit  q close",
      "",
    }

    for index, item in ipairs(state.items) do
      local marker = index == state.index and "> " or "  "
      lines[#lines + 1] = ("%s%s:%d:%d %s"):format(marker, item.filename, item.lnum, item.col, item.text)
    end

    vim.bo[left_buf].modifiable = true
    vim.api.nvim_buf_set_lines(left_buf, 0, -1, false, lines)
    vim.bo[left_buf].modifiable = false
    vim.api.nvim_win_set_cursor(left_win, { math.min(state.index + 6, #lines), 0 })
    preview_item(state.items[state.index])
  end

  local function selected_item()
    return state.items[state.index]
  end

  local function open_selected()
    local item = selected_item()
    if item == nil then
      return
    end

    close()
    vim.cmd("edit " .. vim.fn.fnameescape(item.filename))
    vim.api.nvim_win_set_cursor(0, { item.lnum, math.max(item.col - 1, 0) })
  end

  local function do_replace_all()
    replace_all_files(state.items, state.search, state.replacement)
    close()
    vim.notify("Project replace: all matches updated", vim.log.levels.INFO)
  end

  local function do_replace_file()
    local item = selected_item()
    if item == nil then
      return
    end

    replace_in_file(item.filename, state.search, state.replacement)
    close()
    vim.notify(("Project replace: updated %s"):format(item.filename), vim.log.levels.INFO)
  end

  local function do_replace_hit()
    local item = selected_item()
    if item == nil then
      return
    end

    replace_selected_occurrence(item, state.search, state.replacement)
    close()
    vim.notify(("Project replace: updated one match in %s"):format(item.filename), vim.log.levels.INFO)
  end

  local function move(delta)
    local index = state.index + delta
    if index < 1 then
      index = #state.items
    elseif index > #state.items then
      index = 1
    end
    state.index = index
    render()
  end

  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = left_buf, silent = true, nowait = true, remap = false })
    vim.keymap.set(mode, lhs, rhs, { buffer = right_buf, silent = true, nowait = true, remap = false })
  end

  map("n", "q", close)
  map("n", "<Esc>", close)
  map("n", "<CR>", open_selected)
  map("n", "j", function() move(1) end)
  map("n", "k", function() move(-1) end)
  map("n", "a", do_replace_all)
  map("n", "f", do_replace_file)
  map("n", "r", do_replace_hit)

  render()
  vim.api.nvim_set_current_win(left_win)
end

return M
