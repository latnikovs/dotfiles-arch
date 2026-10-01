-- <leader>X in a DBUI query buffer: export the query under the cursor (its
-- paragraph, as vip picks it) or the visual selection to a CSV file. It runs
-- psql's \copy, so the rows go straight to the file on this machine without
-- passing through nvim, which suits big exports too. Postgres only.
local M = {}

-- One query on one line, as \copy needs: drop -- comments and the trailing ;
function M.one_line(lines)
  local parts = {}
  for _, line in ipairs(lines) do
    line = line:gsub("%-%-.*$", "")
    table.insert(parts, line)
  end
  local sql = vim.trim(table.concat(parts, " "):gsub("%s+", " "))
  sql = vim.trim(sql:gsub(";%s*$", ""))
  if sql == "" then
    return nil, "no query to export"
  end
  if sql:find(";") then
    return nil, "select a single query"
  end
  return sql
end

local function default_path()
  local name = (vim.b.dbui_db_key_name or "query"):gsub("_g:dbs$", ""):gsub("[^%w]+", "-")
  return ("~/Downloads/%s-%s.csv"):format(name, os.date("%Y-%m-%d-%H%M%S"))
end

function M.run(url, sql, path, on_done)
  local copy = ("\\copy (%s) to '%s' csv header"):format(sql, path:gsub("'", "''"))
  vim.system({ "psql", "-w", "-X", "-v", "ON_ERROR_STOP=1", "--dbname", url, "-c", copy }, { text = true }, on_done)
end

function M.export(lines)
  local url = vim.b.db
  if type(url) ~= "string" or not url:find("^postgres") then
    vim.notify("CSV export needs a Postgres DBUI query buffer", vim.log.levels.WARN)
    return
  end
  local sql, err = M.one_line(lines)
  if not sql then
    vim.notify("CSV export: " .. err, vim.log.levels.WARN)
    return
  end
  vim.ui.input({ prompt = "Export CSV to: ", default = default_path(), completion = "file" }, function(input)
    if not input or input == "" then
      return
    end
    local path = vim.fs.normalize(input)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    M.run(url, sql, path, function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          vim.notify("CSV export failed: " .. vim.trim(res.stderr), vim.log.levels.ERROR)
        else
          local rows = res.stdout:match("COPY (%d+)") or "?"
          vim.notify(("Exported %s rows to %s"):format(rows, vim.fn.fnamemodify(path, ":~")))
        end
      end)
    end)
  end)
end

-- The paragraph under the cursor, or the visual selection
function M.export_paragraph()
  local first, last = vim.fn.line("'{"), vim.fn.line("'}")
  M.export(vim.api.nvim_buf_get_lines(0, first - 1, last, false))
end

function M.export_selection()
  local first, last = vim.fn.line("v"), vim.fn.line(".")
  if first > last then
    first, last = last, first
  end
  vim.cmd("normal! \27")
  M.export(vim.api.nvim_buf_get_lines(0, first - 1, last, false))
end

return M
