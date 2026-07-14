-- Pants / project-specific keymaps.
--
-- Loaded from config.keymaps only when ENABLE_PANTS is on, so the universal
-- keymaps stay portable to any project. Keep anything Pants- or monorepo-
-- specific here rather than in config.keymaps.
local M = {}

-- Register the project keymaps. `map` is passed in so this shares the exact
-- vim.keymap.set wrapper used by the universal keymaps.
function M.setup(map)
  local pants_tests = require("config.pants_tests")

  map("n", "<leader>pp", "<cmd>PrePush<cr>", { desc = "Run pre-push" })
  map("n", "<leader>t", pants_tests.open, { desc = "Open Pants tests" })
end

-- Section appended to the cheatsheet popup's right column (see config.cheatsheet).
function M.cheatsheet_section()
  return {
    title = "PROJECT",
    entries = {
      { "SPC p p", "[P]re-[P]ush check" },
      { "SPC t", "Pants [T]ests browser" },
    },
  }
end

return M
