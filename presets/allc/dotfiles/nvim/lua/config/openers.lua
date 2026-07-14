local M = {}

local function trim_target(target)
  target = vim.trim(target or "")
  -- Terminal/editor output often leaves punctuation directly after paths/URLs.
  target = target:gsub("[,%.;:]+$", "")
  target = target:gsub("[%)%]%}]+$", "")
  target = target:gsub("^[%(\"']+", "")
  target = target:gsub("[\"']+$", "")
  return target
end

local function is_url(target)
  return target:match("^[%w][%w+.-]*://") ~= nil or target:match("^www%.") ~= nil
end

local function open_url(target)
  if target:match("^www%.") then
    target = "https://" .. target
  end

  if vim.ui and vim.ui.open then
    vim.ui.open(target)
    return
  end

  local opener
  if vim.fn.has("mac") == 1 then
    opener = "open"
  elseif vim.fn.has("unix") == 1 then
    opener = "xdg-open"
  end

  if opener and vim.fn.executable(opener) == 1 then
    vim.fn.jobstart({ opener, target }, { detach = true })
  else
    vim.notify("No system opener found for: " .. target, vim.log.levels.WARN)
  end
end

function M.open_url_or_copy_path_under_cursor()
  local target = trim_target(vim.fn.expand("<cfile>"))

  if target == "" then
    vim.notify("No URL or path under cursor", vim.log.levels.INFO)
    return
  end

  if is_url(target) then
    open_url(target)
    return
  end

  vim.fn.setreg("+", target)
  vim.notify("Copied path: " .. target)
end


function M.find_files_from_clipboard()
  local clipboard = trim_target(vim.fn.getreg("+"))

  require("telescope.builtin").find_files({
    default_text = clipboard,
    prompt_title = clipboard ~= "" and "Find files (clipboard)" or "Find files",
  })
end

-- Deterministic RPC socket for this multiplexer session, so `nvim-remote-open`
-- (see bin/nvim-remote-open) can deliver a path into this exact instance from
-- another pane. The path must match what the shell script computes.
local function session_socket()
  local dir = os.getenv("XDG_RUNTIME_DIR") or os.getenv("TMPDIR") or "/tmp"
  dir = dir:gsub("/+$", "")

  local key
  local zellij = os.getenv("ZELLIJ_SESSION_NAME")
  if zellij and zellij ~= "" then
    key = "zellij-" .. zellij
  elseif os.getenv("TMUX") then
    local name = vim.trim(vim.fn.system({ "tmux", "display-message", "-p", "#S" }) or "")
    if name ~= "" then
      key = "tmux-" .. name
    end
  end

  if not key then
    return nil
  end

  key = key:gsub("[^%w_-]", "-")
  return dir .. "/pde-nvim-" .. key .. ".sock"
end

-- Start listening on the session socket. Called once at startup. A stale socket
-- left by a crashed nvim is cleared before retrying; a live one is left alone so
-- the first editor in the session keeps ownership.
function M.start_session_server()
  local sock = session_socket()
  if not sock then
    return
  end

  for _, addr in ipairs(vim.fn.serverlist()) do
    if addr == sock then
      return
    end
  end

  if pcall(vim.fn.serverstart, sock) then
    return
  end

  local chan = 0
  pcall(function()
    chan = vim.fn.sockconnect("pipe", sock, { rpc = true })
  end)
  if chan and chan ~= 0 then
    pcall(vim.fn.chanclose, chan) -- a live nvim already owns it; leave it
    return
  end

  pcall(os.remove, sock)
  pcall(vim.fn.serverstart, sock)
end

return M
