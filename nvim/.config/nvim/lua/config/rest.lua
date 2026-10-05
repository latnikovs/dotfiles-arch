-- REST client for .http files, in the IntelliJ HTTP Client format that
-- kulala, httpyac and VS Code's REST Client read too. The request under the
-- cursor goes through curl and its response opens in a split on the right.
--
--   @base = http://localhost:8080        file variable
--
--   ### Create order                     starts a request; the rest is its name
--   POST {{base}}/orders
--   Content-Type: application/json
--                                        blank line, then the body
--   { "id": 1 }
--
-- {{name}} comes from @name lines in the file, then from the selected
-- environment in http-client.env.json and http-client.private.env.json
-- (secrets go in the private one, which repos gitignore), found from the
-- file's directory upwards. "$shared" in those files applies to every
-- environment. {{$uuid}}, {{$timestamp}} and {{$isoTimestamp}} are built in.
-- "Authorization: Basic user password" is base64-encoded on the way out.
local M = {}

local METHODS = {
  GET = true,
  POST = true,
  PUT = true,
  PATCH = true,
  DELETE = true,
  HEAD = true,
  OPTIONS = true,
  TRACE = true,
  CONNECT = true,
}

-- Session state: the chosen environment, the last request (for replay), the
-- running curl, and the response pane
local state = { env = nil, last = nil, job = nil, buf = nil, response = nil, view = "body" }

local function is_separator(line)
  return line:match("^###") ~= nil
end

local function is_comment(line)
  return line:match("^%s*#") ~= nil or line:match("^%s*//") ~= nil
end

local function is_file_var(line)
  return line:match("^@[%w_.-]+%s*=") ~= nil
end

-- @name = value lines anywhere in the document, in order
function M.file_vars(lines)
  local vars = {}
  for _, line in ipairs(lines) do
    local name, value = line:match("^@([%w_.-]+)%s*=%s*(.-)%s*$")
    if name then
      vars[name] = value
    end
  end
  return vars
end

-- The lines of the request around a 1-based line, and the ### line's name
function M.block(lines, lnum)
  local first, last = 1, #lines
  for i = lnum, 1, -1 do
    if is_separator(lines[i]) then
      first = i
      break
    end
  end
  for i = lnum + 1, #lines do
    if is_separator(lines[i]) then
      last = i - 1
      break
    end
  end
  local name
  if is_separator(lines[first]) then
    name = vim.trim(lines[first]:gsub("^#+", ""))
    first = first + 1
  end
  return vim.list_slice(lines, first, last), name ~= "" and name or nil
end

-- Request line, headers up to the first blank line, then the body. Returns
-- nil when the block has no request line (only comments or variables).
function M.parse(lines)
  local i = 1
  while i <= #lines and (lines[i]:match("^%s*$") or is_comment(lines[i]) or is_file_var(lines[i])) do
    i = i + 1
  end
  if i > #lines then
    return nil
  end
  local method, url = lines[i]:match("^(%u+)%s+(%S+)")
  if not (method and METHODS[method]) then
    method, url = "GET", lines[i]:match("^%s*(%S+)")
  end
  i = i + 1
  -- A long URL can go on in indented ?query / &param lines
  while i <= #lines and lines[i]:match("^%s+[?&]") do
    url = url .. vim.trim(lines[i])
    i = i + 1
  end

  local headers = {}
  while i <= #lines and not lines[i]:match("^%s*$") do
    if not is_comment(lines[i]) then
      local name, value = lines[i]:match("^%s*([^:%s]+)%s*:%s*(.-)%s*$")
      if name then
        table.insert(headers, { name, value })
      end
    end
    i = i + 1
  end

  local body = vim.list_slice(lines, i + 1)
  while #body > 0 and body[#body]:match("^%s*$") do
    table.remove(body)
  end
  return {
    method = method,
    url = url,
    headers = headers,
    body = #body > 0 and table.concat(body, "\n") or nil,
  }
end

local function read_json(path)
  if not path then
    return {}
  end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(data) ~= "table" then
    vim.notify("Can't read " .. vim.fn.fnamemodify(path, ":~:."), vim.log.levels.ERROR)
    return {}
  end
  return data
end

local function find_up(name, dir)
  return vim.fs.find(name, { path = dir, upward = true, type = "file" })[1]
end

-- Both env files for a directory: public first, then private
local function env_files(dir)
  return {
    read_json(find_up("http-client.env.json", dir)),
    read_json(find_up("http-client.private.env.json", dir)),
  }
end

function M.env_names(files)
  local seen, names = {}, {}
  for _, file in ipairs(files) do
    for name in pairs(file) do
      if not name:match("^%$") and not seen[name] then
        seen[name] = true
        table.insert(names, name)
      end
    end
  end
  table.sort(names)
  return names
end

-- Variables of one environment: $shared, then the environment itself, with
-- private values over public ones at each step
function M.env_vars(files, env)
  local vars = {}
  for _, key in ipairs({ "$shared", env }) do
    for _, file in ipairs(files) do
      for name, value in pairs(type(file[key]) == "table" and file[key] or {}) do
        vars[name] = value
      end
    end
  end
  return vars
end

local function uuid()
  return (
    ("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"):gsub("[xy]", function(c)
      local v = c == "x" and vim.fn.rand() % 16 or 8 + vim.fn.rand() % 4
      return ("%x"):format(v)
    end)
  )
end

local DYNAMIC = {
  ["$uuid"] = uuid,
  ["$random.uuid"] = uuid,
  ["$timestamp"] = function()
    return tostring(os.time())
  end,
  ["$isoTimestamp"] = function()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
  end,
}

-- Replace {{name}} in text; values may use other variables. Names that
-- resolve to nothing are added to missing.
function M.expand(text, vars, missing, depth)
  depth = depth or 0
  return (
    text:gsub("{{%s*(.-)%s*}}", function(name)
      if DYNAMIC[name] then
        return DYNAMIC[name]()
      end
      local value = vars[name]
      if value == nil or depth > 10 then
        missing[name] = true
        return nil
      end
      return M.expand(tostring(value), vars, missing, depth + 1)
    end)
  )
end

-- The request with every variable filled in, or nil and an error
function M.resolve(req, vars)
  local missing = {}
  local out = { method = req.method, headers = {}, name = req.name }
  out.url = M.expand(req.url, vars, missing)
  for _, h in ipairs(req.headers) do
    local value = M.expand(h[2], vars, missing)
    -- "Basic user password" or "Basic user:password", as IntelliJ takes it,
    -- is sent encoded; an already encoded value has neither space nor colon
    local user, password = value:match("^Basic%s+([^%s:]+)[%s:]+(.+)$")
    if h[1]:lower() == "authorization" and user then
      value = "Basic " .. vim.base64.encode(user .. ":" .. password)
    end
    table.insert(out.headers, { h[1], value })
  end
  out.body = req.body and M.expand(req.body, vars, missing)
  local names = vim.tbl_keys(missing)
  if #names > 0 then
    table.sort(names)
    return nil, "unknown variable " .. table.concat(names, ", ")
  end
  return out
end

-- curl arguments for a request, without the output options. When running,
-- the body comes from body_file (an argument can't hold more than 128 KB);
-- a copied command has it inline.
function M.curl_args(req, body_file)
  local args = { "curl", "-sS", "-L", "--compressed" }
  if req.method == "HEAD" then
    table.insert(args, "--head")
  elseif not (req.method == "GET" and not req.body) and not (req.method == "POST" and req.body) then
    vim.list_extend(args, { "-X", req.method })
  end
  for _, h in ipairs(req.headers) do
    vim.list_extend(args, { "-H", h[1] .. ": " .. h[2] })
  end
  if body_file then
    vim.list_extend(args, { "--data-binary", "@" .. body_file })
  elseif req.body then
    vim.list_extend(args, { "--data-raw", req.body })
  end
  table.insert(args, req.url)
  return args
end

-- Response pane ------------------------------------------------------------

local function human_size(bytes)
  if bytes < 1024 then
    return bytes .. " B"
  elseif bytes < 1024 * 1024 then
    return ("%.1f KB"):format(bytes / 1024)
  end
  return ("%.1f MB"):format(bytes / 1024 / 1024)
end

local function escape(text)
  return (text:gsub("%%", "%%%%"))
end

local function pane_buf()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    return state.buf
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "http-response")
  vim.bo[buf].bufhidden = "hide"
  local map = function(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, desc = desc })
  end
  map("q", M.close, "Close Response")
  map("<C-c>", M.cancel, "Cancel Request")
  map("<Tab>", M.toggle_view, "Toggle Headers/Body")
  state.buf = buf
  return buf
end

-- The pane's window in this tab, opened on the right if it isn't there.
-- Focus stays in the .http file.
local function pane_win()
  local buf = pane_buf()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end
  local win = vim.api.nvim_open_win(buf, false, { split = "right", win = 0 })
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  return win
end

local function show(lines, filetype, winbar)
  local buf = pane_buf()
  local win = pane_win()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = filetype
  vim.wo[win].wrap = false -- after the filetype: LazyVim wraps "text"
  vim.wo[win].winbar = winbar
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

local function header(headers, name)
  name = name:lower()
  for _, h in ipairs(headers) do
    if h[1]:lower() == name then
      return h[2]
    end
  end
end

local function body_filetype(content_type)
  content_type = (content_type or ""):lower()
  for pattern, ft in pairs({ ["json"] = "json", ["html"] = "html", ["xml"] = "xml", ["javascript"] = "javascript" }) do
    if content_type:find(pattern, 1, true) then
      return ft
    end
  end
  return "text"
end

local function render()
  local r = state.response
  if not r then
    return
  end
  local hl = r.status >= 400 and "DiagnosticError" or r.status >= 300 and "DiagnosticWarn" or "DiagnosticOk"
  local winbar = ("%%#%s# %d %%* %s · %d ms · %s%s%s"):format(
    hl,
    r.status,
    escape(r.request.method .. " " .. r.request.url),
    r.ms,
    human_size(r.size),
    state.env and (" · " .. escape(state.env)) or "",
    state.view == "headers" and " · headers" or ""
  )
  if state.view == "headers" then
    show(r.header_lines, "http", winbar)
    return
  end
  local ft = body_filetype(header(r.headers, "content-type"))
  local body = r.body
  if ft == "json" and vim.fn.executable("jq") == 1 then
    local res = vim.system({ "jq", "." }, { stdin = body, text = true }):wait()
    if res.code == 0 then
      body = res.stdout
    end
  end
  show(vim.split((body:gsub("\n$", "")), "\n", { plain = true }), ft, winbar)
end

-- The last header block that curl wrote (redirects each add one)
local function parse_headers(text)
  local blocks = vim.split(vim.trim(text:gsub("\r", "")), "\n%s*\n")
  local lines = vim.split(blocks[#blocks], "\n", { plain = true })
  local headers = {}
  for i = 2, #lines do
    local name, value = lines[i]:match("^([^:]+):%s*(.*)$")
    if name then
      table.insert(headers, { name, value })
    end
  end
  return lines, headers
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then
    return ""
  end
  local text = f:read("*a")
  f:close()
  return text
end

function M.send(req)
  M.cancel()
  local files = { body = vim.fn.tempname(), headers = vim.fn.tempname(), out = vim.fn.tempname() }
  if req.body then
    local f = assert(io.open(files.body, "wb"))
    f:write(req.body)
    f:close()
  end
  local args = M.curl_args(req, req.body and files.body)
  local url = table.remove(args)
  vim.list_extend(
    args,
    { "-D", files.headers, "-o", files.out, "-w", "%{http_code} %{time_total} %{size_download}", url }
  )

  state.last = req
  show({}, "text", " Sending " .. escape(req.method .. " " .. req.url) .. " … (<C-c> cancels)")
  local job
  job = vim.system(args, { text = true }, function(res)
    vim.schedule(function()
      local header_text, body = read_file(files.headers), read_file(files.out)
      for _, path in pairs(files) do
        os.remove(path)
      end
      if state.job ~= job then
        return -- replaced by a newer request
      end
      state.job = nil
      if res.signal ~= 0 or res.code ~= 0 then
        local msg = res.signal ~= 0 and "Cancelled" or vim.trim(res.stderr)
        show(vim.split(msg, "\n"), "text", " %#DiagnosticError#" .. escape(req.method .. " " .. req.url) .. "%*")
        return
      end
      local status, seconds, size = res.stdout:match("(%d+) ([%d.]+) (%d+)")
      local header_lines, headers = parse_headers(header_text)
      state.response = {
        request = req,
        status = tonumber(status) or 0,
        ms = math.floor((tonumber(seconds) or 0) * 1000 + 0.5),
        size = tonumber(size) or 0,
        header_lines = header_lines,
        headers = headers,
        body = body,
      }
      render()
    end)
  end)
  state.job = job
end

-- Environments -------------------------------------------------------------

local function pick_env(files, on_pick)
  local names = M.env_names(files)
  if #names == 0 then
    on_pick(nil)
  elseif #names == 1 then
    on_pick(names[1])
  else
    vim.ui.select(names, { prompt = "Environment" }, function(choice)
      if choice then
        on_pick(choice)
      end
    end)
  end
end

function M.select_env()
  local files = env_files(vim.fn.expand("%:p:h"))
  local names = M.env_names(files)
  if #names == 0 then
    vim.notify("No http-client.env.json found", vim.log.levels.WARN)
    return
  end
  vim.ui.select(names, { prompt = "Environment" }, function(choice)
    if choice then
      state.env = choice
      vim.notify("Environment: " .. choice)
    end
  end)
end

-- The request under the cursor, resolved, passed to fn
local function with_request(fn)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local block, name = M.block(lines, vim.fn.line("."))
  local req = M.parse(block)
  if not req then
    vim.notify("No request under the cursor", vim.log.levels.WARN)
    return
  end
  req.name = name
  local files = env_files(vim.fn.expand("%:p:h"))
  local function go(env)
    state.env = env
    local vars = env and M.env_vars(files, env) or {}
    for k, v in pairs(M.file_vars(lines)) do
      vars[k] = v
    end
    local resolved, err = M.resolve(req, vars)
    if not resolved then
      vim.notify(err .. (env and (" (environment " .. env .. ")") or ""), vim.log.levels.ERROR)
      return
    end
    fn(resolved)
  end
  if state.env and vim.tbl_contains(M.env_names(files), state.env) then
    go(state.env)
  else
    pick_env(files, go)
  end
end

-- Commands -----------------------------------------------------------------

function M.run()
  with_request(M.send)
end

function M.replay()
  if not state.last then
    vim.notify("No request sent yet", vim.log.levels.WARN)
    return
  end
  M.send(state.last)
end

function M.copy_curl()
  with_request(function(req)
    local cmd = table.concat(
      vim.tbl_map(function(arg)
        return arg:match("^[%w_./:=@%%+-]+$") and arg or vim.fn.shellescape(arg)
      end, M.curl_args(req)),
      " "
    )
    vim.fn.setreg("+", cmd)
    vim.notify("Copied curl command")
  end)
end

function M.cancel()
  if state.job then
    state.job:kill("sigterm")
  end
end

function M.toggle_view()
  state.view = state.view == "body" and "headers" or "body"
  render()
end

function M.close()
  if not state.buf then
    return
  end
  for _, win in ipairs(vim.fn.win_findbuf(state.buf)) do
    pcall(vim.api.nvim_win_close, win, false)
  end
end

function M.jump(forward)
  vim.fn.search("^###", forward and "W" or "bW")
end

return M
