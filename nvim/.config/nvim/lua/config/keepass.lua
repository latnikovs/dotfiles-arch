-- keepassxc-cli access shared by the database connections (keepass_dbs.lua)
-- and the http.nvim secrets (keepass_http.lua). KeePassXC's Secret Service is
-- left to gnome-keyring, so this goes through keepassxc-cli with the master
-- password on stdin. Callers ask for it once per nvim session and don't keep
-- it after reading what they need.
local M = {}

-- The database: $<override> if set, else the one KeePassXC last had open
function M.kdbx_path(override)
  local forced = override and vim.env[override]
  if forced and forced ~= "" then
    return vim.fs.normalize(forced)
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

-- keepassxc-cli <command> -q <args…>, unlocked with master; returns the
-- vim.system handle
function M.cli(args, master)
  local cmd = { "keepassxc-cli", args[1], "-q" }
  vim.list_extend(cmd, args, 2)
  return vim.system(cmd, { stdin = master .. "\n", text = true })
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

-- Entry paths under a group, recursively ("Sub/Entry"), without the group
-- lines and empty-group markers; nil and an error if listing failed
function M.entries(kdbx, master, group)
  local ls = M.cli({ "ls", "-R", "-f", kdbx, group }, master):wait()
  if ls.code ~= 0 then
    -- -q also silences "Invalid credentials"
    local err = vim.trim(ls.stderr)
    return nil, err ~= "" and err or "wrong master password, or the database can't be read"
  end
  local paths = {}
  for path in vim.gsplit(ls.stdout, "\n", { trimempty = true }) do
    if not path:find("/$") and not path:find("%[empty%]$") then
      table.insert(paths, path)
    end
  end
  return paths
end

return M
