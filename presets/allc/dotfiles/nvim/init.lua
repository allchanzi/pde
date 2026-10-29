-- Copy to the terminal clipboard using OSC 52.
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
    ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
  },
  paste = {
    ["+"] = function() return vim.fn.getreg("0", 1, true) end,
    ["*"] = function() return vim.fn.getreg("0", 1, true) end,
  },
}
vim.opt.clipboard = "unnamedplus"

require("config.loader_cache")

require("config.options")
require("config.keymaps")
require("config.lazy")

-- Listen on a per-session RPC socket so bin/nvim-remote-open can reuse this
-- instance from other tmux/zellij panes.
require("config.openers").start_session_server()
