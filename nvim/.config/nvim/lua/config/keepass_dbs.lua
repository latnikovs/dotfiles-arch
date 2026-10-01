-- Database connections for dadbod-ui, read from KeePassXC so no URL or
-- password lives in a file. Every entry in the database's "Databases" group is
-- one connection: its title is the name, its URL field the connection URL
-- (postgres://host:5432/db, without the password), and its username and
-- password fields are spliced into that URL. A user already in the URL wins
-- over the username field. Subgroups become name prefixes, so
-- Databases/WMS/Stag shows as "WMS › Stag" and a project's connections sort
-- together (not "/": dadbod-ui makes the name a folder for saved queries).
--
-- KeePassXC's Secret Service is left to gnome-keyring, so this goes through
-- keepassxc-cli, which asks for the master password once per nvim session.
-- The database is the one KeePassXC last had open, or $DBUI_KDBX.
local M = {}

M.group = "Databases"

local function kdbx_path()
  if vim.env.DBUI_KDBX and vim.env.DBUI_KDBX ~= "" then
    return vim.fs.normalize(vim.env.DBUI_KDBX)
  end
  local cache = vim.env.XDG_CACHE_HOME or (vim.env.HOME .. "/.cache")
  local ini = io.open(cache .. "/keepassxc/keepassxc.ini")
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

local function cli(args, master)
  local cmd = { "keepassxc-cli", args[1], "-q" }
  vim.list_extend(cmd, args, 2)
  return vim.system(cmd, { stdin = master .. "\n", text = true })
end

local function encode(s)
  return (s:gsub("[^%w%-._~]", function(c)
    return string.format("%%%02X", c:byte())
  end))
end

-- postgres://host/db + app + secret -> postgres://app:secret@host/db
function M.with_credentials(url, user, password)
  local scheme, rest = url:match("^([%w+.-]+://)(.*)$")
  if not scheme or password == "" and user == "" then
    return url
  end
  local authority = rest:match("^[^/?#]*")
  local userinfo, host = authority:match("^(.*)@([^@]*)$")
  if userinfo then
    user = userinfo:match("^[^:]*")
  else
    user, host = encode(user), authority
  end
  local creds = user .. (password ~= "" and ":" .. encode(password) or "")
  return scheme .. (creds ~= "" and creds .. "@" or "") .. host .. rest:sub(#authority + 1)
end

-- Returns { { name = ..., url = ... } } sorted by name, or nil and an error.
function M.read(kdbx, master)
  local ls = cli({ "ls", "-R", "-f", kdbx, M.group }, master):wait()
  if ls.code ~= 0 then
    if ls.stderr:find("Cannot find group") then
      return nil,
        ('no "%s" group in %s yet: add it, put an entry per database in it, then <leader>D again'):format(
          M.group,
          vim.fn.fnamemodify(kdbx, ":t")
        )
    end
    return nil, vim.trim(ls.stderr)
  end
  -- One keepassxc-cli per entry, all at once: each one pays the KDF on its own
  local jobs = {}
  for path in vim.gsplit(ls.stdout, "\n", { trimempty = true }) do
    -- Skip the group lines ("WMS/") and empty-group markers ("WMS/[empty]")
    if not path:find("/$") and not path:find("%[empty%]$") then
      local name = path:gsub("/", " › ")
      local entry = M.group .. "/" .. path
      jobs[name] = cli({ "show", "-s", "-a", "URL", "-a", "UserName", "-a", "Password", kdbx, entry }, master)
    end
  end
  local dbs = {}
  for name, job in pairs(jobs) do
    local res = job:wait()
    if res.code ~= 0 then
      return nil, name .. ": " .. vim.trim(res.stderr)
    end
    local url, user, password = unpack(vim.split(res.stdout, "\n"))
    if url and url ~= "" then
      table.insert(dbs, { name = name, url = M.with_credentials(url, user or "", password or "") })
    end
  end
  table.sort(dbs, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return dbs
end

-- Unlocks the database and fills g:dbs; false if that did not happen.
function M.load()
  local kdbx = kdbx_path()
  if not kdbx then
    vim.notify("No KeePassXC database: open one in KeePassXC or set $DBUI_KDBX", vim.log.levels.ERROR)
    return false
  end
  local ok, master = pcall(vim.fn.inputsecret, "KeePassXC master password: ")
  vim.cmd.redraw()
  if not ok or master == "" then
    return false
  end
  local dbs, err = M.read(kdbx, master)
  if not dbs then
    vim.notify("KeePassXC: " .. err, vim.log.levels.ERROR)
    return false
  end
  vim.g.dbs = dbs
  M.loaded = true
  return true
end

return M
