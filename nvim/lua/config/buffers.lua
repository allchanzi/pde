local M = {}

local function buffer_entry_name(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return "[No Name]"
  end

  return vim.fn.fnamemodify(name, ":~:.")
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
