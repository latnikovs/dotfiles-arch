-- <leader>Di in a Postgres query buffer: an INSERT template for a table,
-- put below the cursor. The table is the buffer's own (a query opened from a
-- table in the drawer) or, in other query buffers, asked for with the word
-- under the cursor filled in; a name without a schema goes by search_path.
-- One line per column with its type in a comment: DEFAULT where the column
-- has a default or is an identity, NULL elsewhere. Generated columns and
-- GENERATED ALWAYS identities are left out, since Postgres rejects values
-- for them.
local M = {}

local function literal(s)
  return "'" .. s:gsub("'", "''") .. "'"
end

local function columns_query(rel)
  return ([[
select quote_ident(a.attname),
       format_type(a.atttypid, a.atttypmod) || case when a.attnotnull then ' not null' else '' end,
       case when a.atthasdef or a.attidentity <> '' then 'DEFAULT' else 'NULL' end
from pg_attribute a
where a.attrelid = %s
  and a.attnum > 0 and not a.attisdropped
  and a.attgenerated = '' and a.attidentity <> 'a'
order by a.attnum]]):format(rel)
end

function M.template(name, rows)
  local lines = { ("INSERT INTO %s ("):format(name) }
  for i, row in ipairs(rows) do
    table.insert(lines, "  " .. row[1] .. (i < #rows and "," or ""))
  end
  table.insert(lines, ") VALUES (")
  for i, row in ipairs(rows) do
    table.insert(lines, ("  %s%s -- %s %s"):format(row[3], i < #rows and "," or "", row[1], row[2]))
  end
  table.insert(lines, ");")
  return lines
end

local function generate(rel)
  local ok, rows = pcall(vim.fn["db_ui#query"], columns_query(rel))
  if not ok then
    vim.notify("INSERT template: " .. tostring(rows), vim.log.levels.ERROR)
    return
  end
  local ok_name, name = pcall(vim.fn["db_ui#query"], ("select %s::regclass"):format(rel))
  if not ok_name or #rows == 0 or not name[1] then
    vim.notify("INSERT template: no such table, or no columns to insert", vim.log.levels.WARN)
    return
  end
  local lines = M.template(name[1][1], rows)
  if vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_get_current_line() == "" then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  else
    vim.api.nvim_put(lines, "l", true, false)
  end
end

function M.insert()
  local url = vim.b.db
  if type(url) ~= "string" or not url:match("^postgres") then
    vim.notify("INSERT template: not a Postgres query buffer", vim.log.levels.WARN)
    return
  end
  local tbl, schema = vim.b.dbui_table_name, vim.b.dbui_schema_name
  if tbl and tbl ~= "" then
    local rel = schema and schema ~= "" and ("format('%%I.%%I', %s, %s)"):format(literal(schema), literal(tbl))
      or ("quote_ident(%s)"):format(literal(tbl))
    generate(("to_regclass(%s)"):format(rel))
    return
  end
  vim.ui.input({ prompt = "Table: ", default = vim.fn.expand("<cword>") }, function(input)
    if input and vim.trim(input) ~= "" then
      generate(("to_regclass(%s)"):format(literal(vim.trim(input))))
    end
  end)
end

return M
