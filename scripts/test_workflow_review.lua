local root = vim.fn.getcwd()
local module = dofile(root .. "/bin/core/pde/workflow_review.lua")
local path = vim.fn.tempname()
vim.fn.writefile({ vim.json.encode({
  format = "pde.review/v1",
  repository = { provider = "GitHub", path = "a/b" },
  number = 7, title = "Feature", head_sha = "abc",
  files = { { path = "new.rs", old_path = "old.rs", partial = false, lines = {
    { text = "@@ -4 +8 @@", old = vim.NIL, new = vim.NIL },
    { text = "-old", old = 4, new = vim.NIL },
    { text = "+new", old = vim.NIL, new = 8 },
  } } },
  threads = { { path = "new.rs", line = vim.NIL, resolved = false, comments = { { author = vim.NIL, body = "outdated" } } } },
}) }, path)
assert(module.open(path))
local review = vim.api.nvim_get_current_buf()
assert(vim.bo[review].filetype == "diff")
assert(not vim.bo[review].modifiable)
local lines = vim.api.nvim_buf_get_lines(review, 0, -1, false)
local added
for i, line in ipairs(lines) do if line == "+new" then added = i end end
assert(added)
assert(vim.tbl_contains(lines, "# OPEN new.rs:") and vim.tbl_contains(lines, "# ?: outdated"), "null line/author must render")
vim.api.nvim_win_set_cursor(0, { added, 0 })
vim.fn.maparg("gc", "n", false, true).callback()
local draft = vim.api.nvim_get_current_buf()
assert(draft ~= review and vim.bo[draft].buftype == "acwrite")
vim.api.nvim_buf_set_lines(draft, 0, -1, false, { "Fix this guard" })
local calls = 0
local confirm = 2
vim.fn.confirm = function() return confirm end
local succeed = false
vim.system = function(args, options, callback)
  calls = calls + 1
  assert(args[1] == "gtui" and args[2] == "--workflow-comment")
  assert(args[6] == "0" and args[8] == "2")
  assert(vim.fn.readfile(args[10])[1] == "Fix this guard")
  callback({ code = succeed and 0 or 1, stderr = "head changed" })
end
vim.cmd("PostComment")
assert(calls == 0, "Cancel must not post")
confirm = 1
vim.cmd("PostComment")
vim.wait(100, function() return vim.bo[draft].modifiable end)
assert(calls == 1)
assert(vim.api.nvim_buf_is_valid(draft), "Failed post must retain draft")
assert(vim.api.nvim_buf_get_lines(draft, 0, -1, false)[1] == "Fix this guard")
succeed = true
vim.cmd("PostComment")
vim.wait(100, function() return not vim.api.nvim_buf_is_valid(draft) end)
assert(calls == 2 and not vim.api.nvim_buf_is_valid(draft))
vim.fn.delete(path)
print("Neovim review: mapping, Cancel, retained draft and successful post passed")
vim.cmd("qa!")

