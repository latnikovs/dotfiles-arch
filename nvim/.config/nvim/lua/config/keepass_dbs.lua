-- Database connections for dadbod-ui, read from KeePassXC so no URL or
-- password lives in a file. Every entry in the database's "Databases" group is
-- one connection: its title is the name, its URL field the connection URL
-- (postgres://host:5432/db, without the password), and its username and
-- password fields are spliced into that URL. A user already in the URL wins
-- over the username field. Subgroups become name prefixes, so
-- Databases/WMS/Stag shows as "WMS › Stag" and a project's connections sort
-- together (not "/": dadbod-ui makes the name a folder for saved queries).
--
-- The drawer shows one project's connections: the top-level group named like
-- the folder nvim runs in (~/Work/wms shows Databases/WMS/*, case ignored).
-- Only that folder counts, not the ones above it. A folder with no group of
-- its own shows them all; a in the drawer switches to all and back.
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

-- Returns { { name = ..., url = ..., project = ... } } sorted by name, or nil
-- and an error. project is the top-level group, nil for an entry right in
-- Databases.
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
  local projects = {}
  for _, path in ipairs(paths) do
    local name = path:gsub("/", " › ")
    local entry = M.group .. "/" .. path
    jobs[name] = keepass.cli({ "show", "-s", "-a", "URL", "-a", "UserName", "-a", "Password", kdbx, entry }, master)
    projects[name] = path:match("^([^/]+)/")
  end
  local dbs = {}
  for name, job in pairs(jobs) do
    local res = job:wait()
    if res.code ~= 0 then
      return nil, name .. ": " .. vim.trim(res.stderr)
    end
    local url, user, password = unpack(vim.split(res.stdout, "\n"))
    if url and url ~= "" then
      table.insert(dbs, {
        name = name,
        url = M.with_credentials(url, user or "", password or ""),
        project = projects[name],
      })
    end
  end
  table.sort(dbs, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return dbs
end

-- The connections of the project nvim runs in, or all of them; the second
-- value names the project, nil when showing all
function M.filter(dbs, all)
  local folder = vim.fs.basename(vim.fn.getcwd()):lower()
  local mine = vim.tbl_filter(function(db)
    return db.project ~= nil and db.project:lower() == folder
  end, dbs)
  if all or #mine == 0 then
    return dbs
  end
  return mine, mine[1].project
end

-- Fills g:dbs from M.all for the current folder. True if that changed what
-- the drawer shows, which then has to be rebuilt (db_ui#reset_state).
function M.apply()
  local dbs, project = M.filter(M.all, M.show_all)
  local key = project or "*"
  if key == M.shown then
    return false
  end
  M.shown = key
  vim.g.dbs = vim.tbl_map(function(db)
    return { name = db.name, url = db.url }
  end, dbs)
  if project then
    vim.notify(("Databases: %s (%d of %d), a for all"):format(project, #dbs, #M.all))
  elseif M.show_all then
    vim.notify(("Databases: all %d, a for the project's"):format(#dbs))
  end
  return true
end

-- Between the project's connections and all of them, for the session; true
-- if the drawer has to be rebuilt
function M.toggle_all()
  M.show_all = not M.show_all
  if M.apply() then
    return true
  end
  vim.notify(("Databases: no group for %s, so all of them"):format(vim.fs.basename(vim.fn.getcwd())))
  return false
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
  M.all = dbs
  M.shown = nil
  M.apply()
  M.loaded = true
  return true
end

return M
