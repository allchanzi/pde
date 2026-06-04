local M = {}

local prefixes = {
  "Search: ",
  "Path:   ",
}

local function parse_field(line, prefix)
  if vim.startswith(line, prefix) then
    return line:sub(#prefix + 1)
  end

  local stripped = line:gsub("^.-:%s*", "", 1)
  return stripped
end

local function build_opts(query, path_filter)
  local opts = {
    default_text = query,
    prompt_title = "Live grep",
  }

  if path_filter == "" then
    return opts
  end

  opts.prompt_title = ("Live grep (%s)"):format(path_filter)

  local expanded = vim.fn.fnamemodify(vim.fn.expand(path_filter), ":p")
  if vim.fn.isdirectory(expanded) == 1 or vim.fn.filereadable(expanded) == 1 then
    opts.search_dirs = { path_filter }
  else
    opts.additional_args = function()
      return { "-g", path_filter }
    end
  end

  return opts
end

function M.open()
  local state = {
    values = { "", "" },
    field = 1,
  }

  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.min(70, math.max(46, vim.o.columns - 8))
  local height = 5
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
    title = " Grep In Path ",
    title_pos = "center",
  })

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "grepform"

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  local function render()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      prefixes[1] .. state.values[1],
      prefixes[2] .. state.values[2],
      "",
      "<Tab> next field, <S-Tab> previous, <Enter> run, <Esc> close",
      "Path accepts a directory, file, or ripgrep glob.",
    })
  end

  local function sync_state()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, 2, false)
    state.values[1] = vim.trim(parse_field(lines[1] or "", prefixes[1]))
    state.values[2] = vim.trim(parse_field(lines[2] or "", prefixes[2]))
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

    if state.values[1] == "" then
      vim.notify("Search field cannot be empty", vim.log.levels.WARN)
      focus_field(1)
      return
    end

    close()
    require("telescope.builtin").live_grep(build_opts(state.values[1], state.values[2]))
  end

  local function next_field(delta)
    sync_state()
    local field = state.field + delta
    if field < 1 then
      field = 2
    elseif field > 2 then
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
