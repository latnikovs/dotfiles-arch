-- Secrets for http.nvim from KeePassXC. Every entry under HTTP/<project> is
-- one environment, named by its path below that group: HTTP/wms/stag/toplog
-- holds the "stag/toplog" credentials of the wms project (the folder that
-- contains http/). Its UserName and Password become {{username}} and
-- {{password}}; extra attributes (Advanced › Additional attributes) become
-- variables under their own names.
--
-- The master password is asked on the first request that needs a secret, the
-- values are kept for the nvim session (by http.nvim), the password is not.
-- The database is the one KeePassXC last had open, or $HTTP_KDBX.
local keepass = require("config.keepass")

local M = {}

M.group = "HTTP"

-- Variables from `keepassxc-cli show -s --all`: UserName and Password, then
-- the custom attributes, which come after the Tags line (multi-line Notes
-- come before it, so a "key: value" line in the notes isn't taken)
function M.parse(text)
  local vars = {}
  local lines = vim.split(text, "\n", { plain = true })
  local custom = false
  local last
  for _, line in ipairs(lines) do
    if custom then
      local name, value = line:match("^([^:%s][^:]*): (.*)$")
      if name then
        vars[name] = value
        last = name
      elseif last and line ~= "" then
        vars[last] = vars[last] .. "\n" .. line
      end
    else
      local user = line:match("^UserName: (.*)$")
      local password = line:match("^Password: (.*)$")
      if user and vars.username == nil then
        vars.username = user
      elseif password and vars.password == nil then
        vars.password = password
      elseif line:match("^Tags:") then
        custom = true
      end
    end
  end
  for _, name in ipairs({ "username", "password" }) do
    if vars[name] == "" then
      vars[name] = nil
    end
  end
  return vars
end

-- { [env] = vars } for a project, or nil and an error
function M.read(kdbx, master, project)
  local group = M.group .. "/" .. project
  local paths, err = keepass.entries(kdbx, master, group)
  if not paths then
    return nil, err
  end
  -- One keepassxc-cli per entry, all at once: each one pays the KDF on its own
  local jobs = {}
  for _, path in ipairs(paths) do
    jobs[path] = keepass.cli({ "show", "-s", "--all", kdbx, group .. "/" .. path }, master)
  end
  local secrets = {}
  for path, job in pairs(jobs) do
    local res = job:wait()
    if res.code ~= 0 then
      return nil, path .. ": " .. vim.trim(res.stderr)
    end
    secrets[path] = M.parse(res.stdout)
  end
  return secrets
end

-- The http.nvim hook: callback(secrets), or callback(nil, err)
function M.secrets(project, callback)
  local kdbx = keepass.kdbx_path("HTTP_KDBX")
  if not kdbx then
    return callback(nil, "no KeePassXC database: open one in KeePassXC or set $HTTP_KDBX")
  end
  local master = keepass.ask_master()
  if not master then
    return callback(nil)
  end
  local secrets, err = M.read(kdbx, master, project.name)
  if not secrets then
    if err:find("Cannot find group") then
      -- Nothing for this project yet: env files still work
      vim.notify(
        ("No %s/%s group in %s"):format(M.group, project.name, vim.fn.fnamemodify(kdbx, ":t")),
        vim.log.levels.WARN
      )
      return callback({})
    end
    return callback(nil, err)
  end
  callback(secrets)
end

return M
