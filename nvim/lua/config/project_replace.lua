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

local function ex_escape_search(text)
  return vim.fn.escape(text, [[\/]])
end

local function ex_escape_replace(text)
  return vim.fn.escape(text, [[\/&]])
end

local function open_replace_command(search, replacement)
  local cmd = ("cdo %%s/\\V%s/%s/gce | update"):format(
    ex_escape_search(search),
    ex_escape_replace(replacement)
  )
  local keys = vim.api.nvim_replace_termcodes(":" .. cmd, true, false, true)
  vim.api.nvim_feedkeys(keys, "n", false)
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

    vim.fn.setqflist({}, "r", {
      title = ("Project Replace: %s"):format(search),
      items = items,
    })

    close()
    vim.cmd.copen()
    open_replace_command(search, replacement)
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

return M
