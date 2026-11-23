-- K on a foreign key cell in a Postgres result pane: the row it points to,
-- in a float next to the cell, so the result stays as it is (dadbod-ui's
-- <C-]> replaces it with the referenced row). K again goes into the float
-- to scroll or yank. q or <Esc> (in the result too, while the float is up)
-- or moving the cursor closes it.
-- When the result comes from one table (config/db_edit.lua's rule), its own
-- foreign keys on the column count, composite ones too; after a join, every
-- single-column foreign key on a column of that name, with a choice when
-- they point to different tables.
local edit = require("config.db_edit")

local M = {}

local RS = "\30"

local function fail(msg)
  vim.notify("Peek: " .. msg, vim.log.levels.WARN)
end

local float = { win = nil, source = nil, result = nil, saved = {} }

local group = vim.api.nvim_create_augroup("db_peek", { clear = true })

local CLOSE_KEYS = { "q", "<Esc>" }

local function close()
  vim.api.nvim_clear_autocmds({ group = group })
  if float.win and vim.api.nvim_win_is_valid(float.win) then
    vim.api.nvim_win_close(float.win, true)
  end
  -- The result's own q (LazyVim's close-with-q) and <Esc> again
  if float.result and vim.api.nvim_buf_is_valid(float.result) then
    for _, lhs in ipairs(CLOSE_KEYS) do
      pcall(vim.keymap.del, "n", lhs, { buffer = float.result })
      local saved = float.saved[lhs]
      if saved and saved.buffer == 1 then
        vim.api.nvim_buf_call(float.result, function()
          vim.fn.mapset("n", false, saved)
        end)
      end
    end
  end
  float.win, float.source, float.result, float.saved = nil, nil, nil, {}
end

-- Foreign keys with a column of this name, on rel only if given
local function foreign_keys(url, column, rel, on_done)
  local values = { col = column }
  local only = ""
  if rel then
    values.rel = rel
    only = "and c.conrelid = :'rel'::regclass"
  end
  local function names(rel_col, keys)
    return ([[(select string_agg(a.attname, E'\x1e' order by k.ord)
          from unnest(%s) with ordinality k(attnum, ord)
          join pg_attribute a on a.attrelid = %s and a.attnum = k.attnum)]]):format(keys, rel_col)
  end
  local script = edit.vars(values)
    .. ([[
select quote_ident(rn.nspname) || '.' || quote_ident(r.relname),
       %s,
       %s,
       (select string_agg(a.attname, E'\x1e' order by a.attnum)
          from pg_attribute a
          where a.attrelid = c.confrelid and a.attnum > 0 and not a.attisdropped)
from pg_constraint c
join pg_class r on r.oid = c.confrelid
join pg_namespace rn on rn.oid = r.relnamespace
where c.contype = 'f'
  and exists (select from pg_attribute a
              where a.attrelid = c.conrelid and a.attnum = any (c.conkey) and a.attname = :'col')
  %s
order by 1, 3;
]]):format(names("c.conrelid", "c.conkey"), names("c.confrelid", "c.confkey"), only)
  edit.psql(url, script, function(out, err)
    if not out then
      return on_done(nil, err)
    end
    local fks, seen = {}, {}
    for _, line in ipairs(out) do
      if line ~= "" then
        local f = vim.split(line, edit.SEP, { plain = true })
        local fk = {
          target = f[1],
          cols = vim.split(f[2], RS, { plain = true }),
          refs = vim.split(f[3], RS, { plain = true }),
          all = vim.split(f[4], RS, { plain = true }),
        }
        -- Without the table, a composite key's other columns can't be told
        -- apart from same-named ones of other tables in the join
        local key = fk.target .. " " .. table.concat(fk.refs, ",")
        if (rel or #fk.cols == 1) and not seen[key] then
          seen[key] = true
          table.insert(fks, fk)
        end
      end
    end
    on_done(fks)
  end)
end

-- The referenced row as { column, value } pairs, values as text the way
-- psql shows them (vim.NIL for NULL)
local function fetch(url, fk, values, on_done)
  local cond, vals = edit.where(fk.refs, values)
  local cols = {}
  for _, name in ipairs(fk.all) do
    table.insert(cols, ('"%s"::text'):format(name:gsub('"', '""')))
  end
  local script = edit.vars(vals)
    .. ("select array_to_json(array[%s]) from %s where %s limit 2;\n"):format(table.concat(cols, ", "), fk.target, cond)
  edit.psql(url, script, function(out, err)
    if not out then
      return on_done(nil, err)
    end
    if out[1] == "" then
      return on_done(nil, "no row in " .. fk.target)
    end
    if #out > 1 then
      return on_done(nil, "the key matches more than one row in " .. fk.target)
    end
    local ok, row = pcall(vim.json.decode, out[1], { luanil = { array = false } })
    if not ok then
      return on_done(nil, "unreadable row: " .. row)
    end
    local pairs_ = {}
    for i, name in ipairs(fk.all) do
      table.insert(pairs_, { name, row[i] })
    end
    on_done(pairs_)
  end)
end

local function show(win, title, row)
  close()
  local width = 0
  for _, p in ipairs(row) do
    width = math.max(width, vim.fn.strdisplaywidth(p[1]))
  end
  local lines, nulls = {}, {}
  for i, p in ipairs(row) do
    local value = p[2]
    if value == vim.NIL then
      value = "NULL"
      nulls[i] = true
    else
      value = value:gsub("\r", "\\r"):gsub("\n", "\\n"):gsub("\t", "\\t")
    end
    table.insert(lines, p[1] .. string.rep(" ", width - vim.fn.strdisplaywidth(p[1])) .. "  " .. value)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local ns = vim.api.nvim_create_namespace("db_peek")
  for i, line in ipairs(lines) do
    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #row[i][1], hl_group = "Identifier" })
    if nulls[i] then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, #line - 4, { end_col = #line, hl_group = "Comment" })
    end
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local longest = vim.fn.strdisplaywidth(title)
  for _, line in ipairs(lines) do
    longest = math.max(longest, vim.fn.strdisplaywidth(line))
  end
  float.win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = math.max(1, math.min(longest, vim.o.columns - 4)),
    height = math.max(1, math.min(#lines, vim.o.lines - 6)),
    border = "rounded",
    title = " " .. title .. " ",
    style = "minimal",
  })
  float.source = win
  -- q and <Esc> close the float, in it and in the result while it is up
  -- (where q would otherwise close the result pane)
  local source = vim.api.nvim_win_get_buf(win)
  float.result = source
  for _, lhs in ipairs(CLOSE_KEYS) do
    vim.keymap.set("n", lhs, close, { buffer = buf, desc = "Close Peek" })
    vim.api.nvim_buf_call(source, function()
      float.saved[lhs] = vim.fn.maparg(lhs, "n", false, true)
    end)
    vim.keymap.set("n", lhs, close, { buffer = source, desc = "Close Peek" })
  end
  -- Closes when the cursor moves in the result or goes to any window but
  -- the float, as LSP hover does; checked once the switch is done
  local function unless_in_float()
    vim.schedule(function()
      if vim.api.nvim_get_current_win() ~= float.win then
        close()
      end
    end)
  end
  vim.api.nvim_create_autocmd(
    "CursorMoved",
    { group = group, buffer = vim.api.nvim_win_get_buf(win), callback = close }
  )
  vim.api.nvim_create_autocmd(
    "BufLeave",
    { group = group, buffer = vim.api.nvim_win_get_buf(win), callback = unless_in_float }
  )
  vim.api.nvim_create_autocmd("BufLeave", { group = group, buffer = buf, callback = unless_in_float })
end

function M.peek()
  -- K again: into the float
  local win = vim.api.nvim_get_current_win()
  if float.win and vim.api.nvim_win_is_valid(float.win) and float.source == win then
    return vim.api.nvim_set_current_win(float.win)
  end
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
  local rel = ok and edit.table_of(table.concat(input, "\n")) or nil
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local grid = edit.grid(lines, cursor[1], vim.fn.virtcol("."))
  if not grid then
    return fail("put the cursor on a cell in the result")
  end
  local column = grid.names[grid.col]
  foreign_keys(url, column, rel, function(fks, err)
    if not fks then
      return fail(err)
    end
    if #fks == 0 then
      return fail(("no foreign key on %s%s"):format(rel and rel .. "." or "", column))
    end
    local function open(fk)
      local idx = {}
      for _, name in ipairs(fk.cols) do
        local i = vim.fn.index(grid.names, name) + 1
        if i == 0 then
          return fail(("the result has no %s, part of the key to %s"):format(name, fk.target))
        end
        table.insert(idx, i)
      end
      -- The cursor's line only: an empty key cell is NULL here, not the
      -- next line of a wrapped value, which db_edit.row would go up for
      local cells = edit.row(lines, cursor[1], vim.tbl_extend("force", grid, { sep = cursor[1] - 1 }), idx)
      if not cells then
        return fail("the key is empty (NULL)")
      end
      local values, shown = {}, {}
      for n, i in ipairs(idx) do
        if cells[i] == "" then
          return fail(fk.cols[n] .. " is empty (NULL)")
        end
        table.insert(values, cells[i])
        table.insert(shown, ("%s = %s"):format(fk.refs[n], cells[i]))
      end
      fetch(url, fk, values, function(row, ferr)
        if not row then
          return fail(ferr)
        end
        -- Only where the K was pressed, if the cursor is still there
        if
          not vim.api.nvim_win_is_valid(win)
          or vim.api.nvim_get_current_win() ~= win
          or vim.api.nvim_win_get_cursor(win)[1] ~= cursor[1]
        then
          return
        end
        show(win, ("%s (%s)"):format(fk.target, table.concat(shown, ", ")), row)
      end)
    end
    if #fks == 1 then
      return open(fks[1])
    end
    vim.ui.select(fks, {
      prompt = column .. " refers to",
      format_item = function(fk)
        return ("%s (%s)"):format(fk.target, table.concat(fk.refs, ", "))
      end,
    }, function(fk)
      if fk then
        open(fk)
      end
    end)
  end)
end

return M
