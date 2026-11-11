-- Copy to the terminal clipboard using OSC 52.
-- vim.ui.clipboard.osc52 only exists in Neovim >= 0.10; fall back to a manual
-- implementation on older versions.
local function osc52_copy(_)
  return function(lines)
    local text = table.concat(lines, "\n")
    local b64
    if vim.base64 then
      b64 = vim.base64.encode(text)
    else
      b64 = vim.fn.system({ "base64", "-w0" }, text)
    end
    if b64 then
      b64 = b64:gsub("%s", "")
      vim.fn.chansend(vim.v.stderr, "\027]52;c;" .. b64 .. "\007")
    end
  end
end

local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
vim.g.clipboard = {
  name = "OSC 52",
  copy = {
    ["+"] = ok and osc52.copy("+") or osc52_copy("+"),
    ["*"] = ok and osc52.copy("*") or osc52_copy("*"),
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
