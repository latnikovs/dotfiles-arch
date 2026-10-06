-- Database connections for dadbod-ui, read from KeePassXC so no URL or
-- password lives in a file. Every entry in the database's "Databases" group is
-- one connection: its title is the name, its URL field the connection URL
-- (postgres://host:5432/db, without the password), and its username and
-- password fields are spliced into that URL. A user already in the URL wins
-- over the username field. Subgroups become name prefixes, so
-- Databases/WMS/Stag shows as "WMS › Stag" and a project's connections sort
-- together (not "/": dadbod-ui makes the name a folder for saved queries).
--
-- keepassxc-cli access is in config/keepass.lua; the master password is asked
-- once per nvim session. The database is the one KeePassXC last had open, or
-- $DBUI_KDBX.
local keepass = require("config.keepass")

local M = {}

M.group = "Databases"

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
  local paths, err = keepass.entries(kdbx, master, M.group)
  if not paths then
    if err:find("Cannot find group") then
      return nil,
        ('no "%s" group in %s yet: add it, put an entry per database in it, then <leader>D again'):format(
          M.group,
          vim.fn.fnamemodify(kdbx, ":t")
        )
    end
    return nil, err
  end
  -- One keepassxc-cli per entry, all at once: each one pays the KDF on its own
  local jobs = {}
  for _, path in ipairs(paths) do
    local name = path:gsub("/", " › ")
    local entry = M.group .. "/" .. path
    jobs[name] = keepass.cli({ "show", "-s", "-a", "URL", "-a", "UserName", "-a", "Password", kdbx, entry }, master)
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
  local kdbx = keepass.kdbx_path("DBUI_KDBX")
  if not kdbx then
    vim.notify("No KeePassXC database: open one in KeePassXC or set $DBUI_KDBX", vim.log.levels.ERROR)
    return false
  end
  local master = keepass.ask_master()
  if not master then
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
