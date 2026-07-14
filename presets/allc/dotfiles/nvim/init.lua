require("config.loader_cache")

require("config.options")
require("config.keymaps")
require("config.lazy")

-- Listen on a per-session RPC socket so bin/nvim-remote-open can reuse this
-- instance from other tmux/zellij panes.
require("config.openers").start_session_server()
