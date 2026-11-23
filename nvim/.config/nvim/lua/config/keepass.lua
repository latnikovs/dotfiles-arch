-- keepassxc-cli access shared by the database connections (keepass_dbs.lua)
-- and the http.nvim secrets (keepass_http.lua). KeePassXC's Secret Service is
-- left to gnome-keyring, so this goes through keepassxc-cli with the master
-- password on stdin. Callers ask for it once per nvim session and don't keep
-- it after reading what they need.
--
-- Everything a caller reads goes through one `keepassxc-cli open` session, so
-- the KDF (about 1 s for an Argon2 database) is paid once, not once per entry.
-- That interactive mode only reads commands from a terminal, so it runs in a
-- pty. The session is closed as soon as the caller is done, and the process
-- gets SIGHUP if nvim dies before that, so no unlocked keepassxc-cli is left
-- behind.
local M = {}

-- Seconds to wait for the unlock (the KDF) and for one command
M.unlock_timeout = 60
M.command_timeout = 10

-- The database: $<override> if set, else the one KeePassXC last had open
function M.kdbx_path(override)
  local forced = override and vim.env[override]
  if forced and forced ~= "" then
    return vim.fs.normalize(forced)
  end
  -- KeePassXC 2.8 keeps it in the state dir, 2.7 in the cache dir
  local state = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
  local cache = vim.env.XDG_CACHE_HOME or (vim.env.HOME .. "/.cache")
  local ini = io.open(state .. "/keepassxc/keepassxc.ini") or io.open(cache .. "/keepassxc/keepassxc.ini")
  if not ini then
    return nil
  end
  local path
  for line in ini:lines() do
    path = path or line:match("^LastActiveDatabase=(.+)$")
  end
  ini:close()
  return path
end

-- The master password, or nil if the prompt was cancelled or left empty
function M.ask_master()
  local ok, master = pcall(vim.fn.inputsecret, "KeePassXC master password: ")
  vim.cmd.redraw()
  if not ok or master == "" then
    return nil
  end
  return master
end

-- The pty turns "\n" into "\r\n"; nothing else is touched, as TERM=dumb keeps
-- readline from sending escape codes (and a secret may well contain a "\r")
local function lines(s)
  return (s:gsub("\r\n", "\n"))
end

-- An argument as the interactive prompt splits it: a backslash before blanks,
-- quotes and backslashes. nil for control characters, which readline would
-- take as keys (a newline would even start a second command).
local function quote(arg)
  if arg:find("%c") then
    return nil
  end
  return (arg:gsub('[ "\\]', "\\%0"))
end

local Session = {}
Session.__index = Session

-- Unlocks kdbx in a new session, or returns nil and an error. Nothing that is
-- printed before the first prompt ever leaves this function: the pty echoes
-- the master password if it arrives before keepassxc-cli turns echo off.
function M.open(kdbx, master)
  local s = setmetatable({ buf = "" }, Session)
  local id = vim.fn.jobstart({ "keepassxc-cli", "open", "-q", kdbx }, {
    pty = true,
    -- Wide enough that readline never wraps or scrolls a command line
    width = 4096,
    env = { TERM = "dumb", INPUTRC = "/dev/null" },
    on_stdout = function(_, data)
      s.buf = s.buf .. table.concat(data, "\n")
    end,
    on_exit = function()
      s.exited = true
    end,
  })
  if id <= 0 then
    return nil, "can't run keepassxc-cli"
  end
  s.id = id
  vim.fn.chansend(id, master .. "\n")
  -- The prompt is the database's name, or its file name if it has none, then
  -- "> "; wait for that, then a moment for the rest of it if "> " is in the name
  local ready = vim.wait(M.unlock_timeout * 1000, function()
    return s.exited or lines(s.buf):find("> $") ~= nil
  end, 10)
  if s.exited then
    s.buf = ""
    -- -q also silences "Invalid credentials"
    return nil, "wrong master password, or the database can't be read"
  end
  if not ready then
    s:close()
    return nil, "timed out unlocking the database"
  end
  vim.wait(50)
  s.prompt = lines(s.buf):match("[^\n]*$")
  s.buf = ""
  return s
end

-- The output of one command, args as on the command line, without the echoed
-- command and the next prompt; nil and an error if the session failed, which
-- also closes it. A command's own errors (no such entry) are output too.
function Session:run(args)
  if self.exited then
    return nil, "keepassxc-cli quit"
  end
  local quoted = {}
  for i, arg in ipairs(args) do
    quoted[i] = quote(arg)
    if not quoted[i] then
      return nil, "control character in a keepassxc-cli argument"
    end
  end
  self.buf = ""
  vim.fn.chansend(self.id, table.concat(quoted, " ") .. "\n")
  local tail = "\n" .. self.prompt
  local done = vim.wait(M.command_timeout * 1000, function()
    return self.exited or vim.endswith(lines(self.buf), tail)
  end, 5)
  if self.exited or not done then
    local why = self.exited and "quit" or "timed out"
    self:close()
    return nil, ("keepassxc-cli %s %s"):format(args[1], why)
  end
  local out = lines(self.buf)
  self.buf = ""
  return out:sub(out:find("\n", 1, true) + 1, #out - #tail)
end

-- Ends the session; a keepassxc-cli that doesn't exit is killed
function Session:close()
  self.buf = ""
  if self.exited then
    return
  end
  pcall(vim.fn.chansend, self.id, "exit\n")
  if vim.fn.jobwait({ self.id }, 1000)[1] == -1 then
    vim.fn.jobstop(self.id)
  end
  self.exited = true
end

-- fn(session) in an unlocked session that is closed afterwards, whatever
-- happens in fn. Returns what fn returns: a value, or nil and an error.
function M.with_session(kdbx, master, fn)
  local s, err = M.open(kdbx, master)
  if not s then
    return nil, err
  end
  local ok, value, fn_err = pcall(fn, s)
  s:close()
  if not ok then
    error(value, 0)
  end
  return value, fn_err
end

-- Entry paths under a group, recursively ("Sub/Entry"), without the group
-- lines and empty-group markers; nil and an error if listing failed
function M.entries(session, group)
  local out, err = session:run({ "ls", "-R", "-f", group })
  if not out then
    return nil, err
  end
  if out == ("Cannot find group %s."):format(group) then
    return nil, out
  end
  local paths = {}
  for path in vim.gsplit(out, "\n", { trimempty = true }) do
    if not path:find("/$") and not path:find("%[empty%]$") then
      table.insert(paths, path)
    end
  end
  return paths
end

-- `show -s --all` of an entry: Title, UserName, Password, URL, Notes, Uuid,
-- Tags, then the custom attributes. nil and an error if it isn't that; the
-- error never quotes unexpected output, which could hold a secret.
function M.show(session, path)
  local out, err = session:run({ "show", "-s", "--all", path })
  if not out then
    return nil, err
  end
  if not vim.startswith(out, "Title: ") then
    return nil, out:match("^Could not find entry[^\n]*") or (path .. ": unexpected keepassxc-cli output")
  end
  return out
end
return M
