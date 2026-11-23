local M = {}

local function draft(snapshot_path, anchor, label)
  vim.cmd("botright 8new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, "PDE comment " .. label .. " " .. buf)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_create_user_command(buf, "PostComment", function()
    if vim.fn.confirm("Post this inline comment to " .. label .. "?", "&Post\n&Cancel", 2) ~= 1 then
      return
    end
    local body = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if vim.trim(body) == "" then
      vim.notify("Comment is empty", vim.log.levels.WARN)
      return
    end
    local path = vim.fn.tempname()
    vim.fn.writefile(vim.split(body, "\n", { plain = true }), path)
    vim.fn.setfperm(path, "rw-------")
    vim.bo[buf].modifiable = false
    vim.system({
      "gtui", "--workflow-comment", "--snapshot", snapshot_path,
      "--file", tostring(anchor.file), "--line", tostring(anchor.line), "--body-file", path,
    }, { text = true, timeout = 75000 }, function(result)
      vim.schedule(function()
        vim.fn.delete(path)
        if not vim.api.nvim_buf_is_valid(buf) then return end
        vim.bo[buf].modifiable = true
        if result.code ~= 0 then
          vim.notify("Comment kept locally: " .. ((result.stderr or "") ~= "" and result.stderr or "unknown outcome; check the remote"), vim.log.levels.ERROR)
          return
        end
        vim.bo[buf].modified = false
        vim.api.nvim_buf_delete(buf, {})
        vim.notify("Inline comment posted. FleetUI feedback refresh will pick it up.")
      end)
    end)
  end, {})
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      vim.api.nvim_buf_call(buf, function() vim.cmd("PostComment") end)
    end,
  })
  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    vim.cmd("stopinsert")
    vim.cmd("PostComment")
  end, { buffer = buf, desc = "Post inline review comment" })
  vim.notify("Write the comment, then :write or Ctrl+s. Cancel with :bd! to discard.")
end

function M.open(path)
  local snapshot = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"), { luanil = { object = true, array = true } })
  assert(snapshot.format == "pde.review/v1", "Unsupported PDE review format")
  local label = snapshot.repository.provider .. " " .. snapshot.repository.path .. " #" .. snapshot.number
  local text = {
    "# " .. label .. " — " .. snapshot.title,
    "# Head: " .. snapshot.head_sha,
    "# gc comment on line | ]f / [f next/previous file | q close review",
    "# Comments are posted to the provider only after explicit confirmation.",
    "",
  }
  local anchors, headings = {}, {}
  for file_index, file in ipairs(snapshot.files) do
    headings[#headings + 1] = #text + 1
    text[#text + 1] = "diff --git a/" .. file.old_path .. " b/" .. file.path
    if file.partial then
      text[#text + 1] = "# PARTIAL / BINARY: unavailable content cannot be reviewed here."
    end
    for line_index, line in ipairs(file.lines) do
      text[#text + 1] = line.text
      if type(line.old) == "number" or type(line.new) == "number" then
        anchors[#text] = { file = file_index - 1, line = line_index - 1 }
      end
    end
    text[#text + 1] = ""
  end
  text[#text + 1] = "# Review threads"
  for _, thread in ipairs(snapshot.threads) do
    text[#text + 1] = "# " .. (thread.resolved and "RESOLVED " or "OPEN ") .. (thread.path or "?") .. ":" .. tostring(thread.line or "")
    for _, comment in ipairs(thread.comments) do
      for _, line in ipairs(vim.split(comment.body, "\n", { plain = true })) do
        text[#text + 1] = "# " .. (comment.author or "?") .. ": " .. line
      end
    end
  end
  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, "PDE review " .. label .. " " .. buf)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "diff"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.b[buf].pde_review_anchors = anchors
  vim.keymap.set("n", "gc", function()
    local anchor = anchors[vim.api.nvim_win_get_cursor(0)[1]]
    if not anchor then
      vim.notify("Choose a changed or context line inside a diff hunk", vim.log.levels.WARN)
      return
    end
    draft(path, anchor, label)
  end, { buffer = buf, desc = "Comment on reviewed diff line" })
  for key, forward in pairs({ ["]f"] = true, ["[f"] = false }) do
    vim.keymap.set("n", key, function()
      local current = vim.api.nvim_win_get_cursor(0)[1]
      local target
      for _, row in ipairs(headings) do
        if forward and row > current then target = row; break end
        if not forward and row < current then target = row end
      end
      if target then vim.api.nvim_win_set_cursor(0, { target, 0 }) end
    end, { buffer = buf, desc = forward and "Next review file" or "Previous review file" })
  end
  vim.keymap.set("n", "q", function() vim.cmd("tabclose") end, { buffer = buf, desc = "Close review" })
  return true
end

return M

