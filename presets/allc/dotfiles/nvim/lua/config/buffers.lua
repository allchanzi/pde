local M = {}

local excluded_filetypes = {
  NvimTree = true,
  Trouble = true,
  help = true,
  qf = true,
}

local function is_regular_buffer(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr)
    and vim.bo[bufnr].buflisted
    and vim.bo[bufnr].buftype == ""
    and not excluded_filetypes[vim.bo[bufnr].filetype]
end

local function regular_buffers()
  return vim.tbl_filter(is_regular_buffer, vim.api.nvim_list_bufs())
end

local function buffer_entry_name(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return "[No Name]"
  end

  return vim.fn.fnamemodify(name, ":~:.")
end

local function delete_buffer(bufnr, force)
  vim.cmd((force and "bdelete! " or "bdelete ") .. bufnr)
end

function M.close_current(force)
  local bufnr = vim.api.nvim_get_current_buf()
  if not is_regular_buffer(bufnr) then
    vim.notify("Current window is not a regular buffer", vim.log.levels.INFO)
    return
  end

  delete_buffer(bufnr, force)
end

function M.close_all(force)
  local current = vim.api.nvim_get_current_buf()
  local buffers = regular_buffers()

  if #buffers == 0 then
    return
  end

  for _, bufnr in ipairs(buffers) do
    if bufnr ~= current then
      delete_buffer(bufnr, force)
    end
  end

  if is_regular_buffer(current) then
    vim.cmd("enew")
    delete_buffer(current, force)
  end
end

function M.close_others(force)
  local current = vim.api.nvim_get_current_buf()

  for _, bufnr in ipairs(regular_buffers()) do
    if bufnr ~= current then
      delete_buffer(bufnr, force)
    end
  end
end

function M.open_all()
  require("telescope.builtin").buffers({
    sort_mru = true,
    ignore_current_buffer = false,
  })
end

function M.open_current_tab()
  local buffers = {}
  local seen = {}

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    if not seen[bufnr] then
      seen[bufnr] = true
      buffers[#buffers + 1] = {
        bufnr = bufnr,
        name = buffer_entry_name(bufnr),
      }
    end
  end

  require("telescope.pickers").new({}, {
    prompt_title = "Current Tab Buffers",
    finder = require("telescope.finders").new_table({
      results = buffers,
      entry_maker = function(entry)
        return {
          value = entry.bufnr,
          display = entry.name,
          ordinal = entry.name,
          bufnr = entry.bufnr,
        }
      end,
    }),
    sorter = require("telescope.config").values.generic_sorter({}),
    previewer = false,
    attach_mappings = function(prompt_bufnr, map)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")

      map("i", "<CR>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection ~= nil then
          vim.api.nvim_set_current_buf(selection.bufnr)
        end
      end)

      return true
    end,
  }):find()
end

return M
