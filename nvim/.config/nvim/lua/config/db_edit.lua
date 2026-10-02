-- cc on a cell in a Postgres result pane: change that one value, as in a
-- DataGrip grid. It works out the table from the query behind the result
-- (a single SELECT from one table, as the drawer's List helper runs), finds
-- the row by the table's primary key, asks for the new value with the
-- current one filled in, updates exactly that row and runs the query again.
-- As in a spreadsheet, what you type is the value (Postgres casts it to the
-- column's type), NULL is NULL and a leading = makes it SQL: =now(),
-- =upper(note), =E'two\nlines'.
local M = {}

local SEP = "\31"

-- The query behind the result, if it is one SELECT from one table without
-- joins, grouping or set operations; returns the table as written there
function M.table_of(sql)
  sql = sql:gsub("%-%-[^\n]*", ""):gsub("/%*.-%*/", "")
  sql = vim.trim(sql:gsub("%s+", " ")):gsub("%s*;%s*$", "")
  if sql:find(";") or not sql:lower():find("^select ") then
    return nil
  end
  local lower = sql:lower()
  for _, word in ipairs({ "join", "group by", "union", "intersect", "except", "distinct", "from %(" }) do
    if lower:find("%f[%w_]" .. word) then
      return nil
    end
  end
  local ident = '"[^"]+"'
  local start = lower:find(" from ")
  if not start or lower:find(" from ", start + 1) then
    return nil
  end
  local rest = sql:sub(start + 6)
  local name = rest:match("^(" .. ident .. "%." .. ident .. ")")
    or rest:match("^(" .. ident .. "%.[%w_$]+)")
    or rest:match("^([%w_$]+%." .. ident .. ")")
    or rest:match("^([%w_$]+%.[%w_$]+)")
    or rest:match("^(" .. ident .. ")")
    or rest:match("^([%w_$]+)")
  if not name then
    return nil
  end
  -- No second table after a comma (an old-style join)
  local after = rest:sub(#name + 1)
  if after:match("^%s*[%w_]*%s*,") or after:match("^%s+as%s+[%w_]+%s*,") then
    return nil
  end
  return name
end

-- Split a line into display columns; psql pads by display width, so wide
-- characters take two cells
local function by_display(line)
  local chars, col = {}, 0
  for _, ch in ipairs(vim.fn.split(line, "\\zs")) do
    local w = vim.fn.strdisplaywidth(ch)
    table.insert(chars, { ch = ch, from = col + 1, to = col + w })
    col = col + w
  end
  return chars
end

local function cell(chars, range)
  local out = {}
  for _, c in ipairs(chars) do
    if c.from >= range.from and c.to <= range.to then
      table.insert(out, c.ch)
    end
  end
  -- A trailing + marks a value that goes on in the next line
  return vim.trim((table.concat(out):gsub("%+$", "")))
end

-- The result table around the cursor: column names and ranges from the
-- ---+--- line, the row's cells (going up from a wrapped value's next
-- lines) and the column under the cursor
function M.grid(lines, lnum, vcol)
  local here = lines[lnum] or ""
  if vim.trim(here) == "" or here:match("^%(%d+ rows?%)$") then
    return nil
  end
  local sep
  for i = lnum - 1, 2, -1 do
    local line = lines[i]
    if line:match("^%-[-+]*$") then
      sep = i
      break
    end
    if vim.trim(line) == "" or line:match("^%(%d+ rows?%)$") then
      return nil
    end
  end
  if not sep then
    return nil
  end
  local ranges, from = {}, 1
  local sepline = lines[sep]
  for i = 1, #sepline + 1 do
    if i > #sepline or sepline:sub(i, i) == "+" then
      table.insert(ranges, { from = from, to = i - 1 })
      from = i + 1
    end
  end
  local header = by_display(lines[sep - 1])
  local names = {}
  for _, r in ipairs(ranges) do
    table.insert(names, cell(header, r))
  end
  local col
  for i, r in ipairs(ranges) do
    -- The | before a column counts as part of it
    if vcol >= r.from - 1 and vcol <= r.to then
      col = i
    end
  end
  if not col then
    return nil
  end
  return { sep = sep, ranges = ranges, names = names, col = col }
end

-- The cells of the row the cursor is on; wrapped values leave the key cells
-- empty on their next lines, so go up to the row's first line
function M.row(lines, lnum, grid, keys)
  for i = lnum, grid.sep + 1, -1 do
    local chars = by_display(lines[i])
    local cells = {}
    for _, r in ipairs(grid.ranges) do
      table.insert(cells, cell(chars, r))
    end
    local found = true
    for _, k in ipairs(keys) do
      if cells[k] == "" then
        found = false
      end
    end
    if found then
      return cells
    end
  end
end

local function psql(url, script, on_done)
  vim.system(
    { "psql", "-w", "-X", "-q", "-A", "-t", "-F", SEP, "-v", "ON_ERROR_STOP=1", "--dbname", url },
    { text = true, stdin = script },
    function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          on_done(nil, vim.trim(res.stderr))
        else
          on_done(vim.split(vim.trim(res.stdout), "\n", { plain = true }))
        end
      end)
    end
  )
end

-- psql variables for the values, so psql does the quoting
local function vars(values)
  local out = {}
  for name, value in pairs(values) do
    table.insert(
      out,
      ("\\set %s %s"):format(
        name,
        "'" .. value:gsub("\\", "\\\\"):gsub("'", "''"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. "'"
      )
    )
  end
  table.sort(out)
  return table.concat(out, "\n") .. "\n"
end

-- The table's quoted name and primary key, and whether it has the column
local function describe(url, rel, column, on_done)
  local script = vars({ rel = rel, col = column })
    .. [[
select quote_ident(n.nspname) || '.' || quote_ident(c.relname),
       exists (select from pg_attribute where attrelid = c.oid and attname = :'col' and attnum > 0 and not attisdropped),
       coalesce((select string_agg(a.attname, E'\x1e' order by k.ord)
                 from unnest(i.indkey) with ordinality k(attnum, ord)
                 join pg_attribute a on a.attrelid = c.oid and a.attnum = k.attnum), '')
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_index i on i.indrelid = c.oid and i.indisprimary
where c.oid = :'rel'::regclass;
]]
  psql(url, script, function(out, err)
    if not out then
      return on_done(nil, err)
    end
    local f = vim.split(out[1], SEP, { plain = true })
    on_done({ name = f[1], has_col = f[2] == "t", keys = f[3] ~= "" and vim.split(f[3], "\30", { plain = true }) or {} })
  end)
end

local function where(keys, values)
  local parts, vals = {}, {}
  for i, key in ipairs(keys) do
    vals["k" .. i] = values[i]
    table.insert(parts, ("\"%s\" = :'k%d'"):format(key:gsub('"', '""'), i))
  end
  return table.concat(parts, " and "), vals
end

-- The value now as it goes in the prompt: plain, NULL, or as =E'...' when
-- it would not fit on one line or would read as NULL or SQL
local function current(url, rel, column, keys, values, on_done)
  local cond, vals = where(keys, values)
  local script = vars(vals)
    .. ("select count(*) over (), quote_nullable(%s::text) from %s where %s limit 2;\n"):format(
      ('"%s"'):format(column:gsub('"', '""')),
      rel,
      cond
    )
  psql(url, script, function(out, err)
    if not out then
      return on_done(nil, err)
    end
    local f = vim.split(out[1], SEP, { plain = true })
    if f[1] ~= "1" then
      return on_done(nil, f[1] == "" and "the row is gone" or "the key matches more than one row")
    end
    local literal = table.concat(vim.list_slice(f, 2), SEP)
    -- quote_nullable keeps newlines as they are; write them as E'\n'
    for _, line in ipairs(vim.list_slice(out, 2)) do
      literal = literal .. "\n" .. line
    end
    if literal == "NULL" then
      return on_done(literal)
    end
    if literal:find("[\n\r\t]") then
      if not literal:find("^E'") then
        literal = "E" .. literal
      end
      return on_done("=" .. literal:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t"))
    end
    local plain = literal:sub(1, 1) == "E" and literal:sub(3, -2):gsub("\\\\", "\\") or literal:sub(2, -2)
    plain = plain:gsub("''", "'")
    if plain:upper() == "NULL" or plain:find("^=") then
      return on_done("=" .. literal)
    end
    on_done(plain)
  end)
end

-- Update the one row, or nothing if the key no longer matches exactly one
local function update(url, rel, column, expr, keys, values, on_done)
  local cond, vals = where(keys, values)
  if expr.value then
    vals.v = expr.value
  end
  local script = vars(vals)
    .. "begin;\n"
    .. ("with u as (update %s set %s = %s where %s returning 1) select count(*) as n, count(*) = 1 as ok from u \\gset\n"):format(
      rel,
      ('"%s"'):format(column:gsub('"', '""')),
      expr.sql or ":'v'",
      cond
    )
    .. "\\if :ok\ncommit;\n\\else\nrollback;\n\\endif\n\\echo :n\n"
  psql(url, script, function(out, err)
    if not out then
      return on_done(nil, err)
    end
    on_done(tonumber(out[#out]))
  end)
end

local function fail(msg)
  vim.notify("Edit cell: " .. msg, vim.log.levels.WARN)
end

function M.edit()
  local buf = vim.api.nvim_get_current_buf()
  local query = vim.b[buf].db
  if type(query) ~= "table" or not query.db_url then
    return fail("not a result pane")
  end
  local url = vim.fn["db#resolve"](query.db_url)
  if not url:find("^postgres") then
    return fail("Postgres only")
  end
  local ok, input = pcall(vim.fn.readfile, query.input)
  local rel = ok and M.table_of(table.concat(input, "\n"))
  if not rel then
    return fail("the result must come from one SELECT on one table")
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local grid = M.grid(lines, cursor[1], vim.fn.virtcol("."))
  if not grid then
    return fail("put the cursor on a cell in the result")
  end
  local column = grid.names[grid.col]
  describe(url, rel, column, function(info, err)
    if not info then
      return fail(err)
    end
    if not info.has_col then
      return fail(("%s has no column %s"):format(info.name, column))
    end
    if #info.keys == 0 then
      return fail(info.name .. " has no primary key")
    end
    local idx = {}
    for _, key in ipairs(info.keys) do
      local i = vim.fn.index(grid.names, key) + 1
      if i == 0 then
        return fail(("the result has no %s, the primary key"):format(key))
      end
      table.insert(idx, i)
    end
    local cells = M.row(lines, cursor[1], grid, idx)
    if not cells then
      return fail("no row under the cursor")
    end
    local values, shown = {}, {}
    for n, i in ipairs(idx) do
      table.insert(values, cells[i])
      table.insert(shown, ("%s = %s"):format(info.keys[n], cells[i]))
    end
    local target = ("%s.%s (%s)"):format(info.name, column, table.concat(shown, ", "))
    current(url, info.name, column, info.keys, values, function(now, cerr)
      if not now then
        return fail(cerr)
      end
      vim.ui.input({ prompt = target .. " = ", default = now }, function(input)
        if not input or input == now then
          return
        end
        local expr = { value = input }
        if vim.trim(input):upper() == "NULL" then
          expr = { sql = "NULL" }
        elseif input:find("^=") then
          expr = { sql = vim.trim(input:sub(2)) }
          if expr.sql == "" then
            return
          end
        end
        update(url, info.name, column, expr, info.keys, values, function(n, uerr)
          if not n then
            return fail(uerr)
          end
          if n ~= 1 then
            return fail(("%d rows matched, nothing changed"):format(n))
          end
          vim.notify(("Updated %s = %s"):format(target, input))
          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end
          -- Run the query again and come back to the same cell
          vim.api.nvim_create_autocmd("User", {
            pattern = query.output .. "/DBExecutePost",
            once = true,
            callback = function()
              for _, win in ipairs(vim.fn.win_findbuf(buf)) do
                local last = vim.api.nvim_buf_line_count(buf)
                pcall(vim.api.nvim_win_set_cursor, win, { math.min(cursor[1], last), cursor[2] })
              end
            end,
          })
          vim.api.nvim_buf_call(buf, function()
            vim.cmd("normal R")
          end)
        end)
      end)
    end)
  end)
end

return M
