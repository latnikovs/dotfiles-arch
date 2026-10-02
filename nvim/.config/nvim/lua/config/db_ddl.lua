-- DDL table helper for Postgres in dadbod-ui: the drawer's DDL entry under a
-- table or view opens a query buffer with a marker line, and this fills it
-- with the object's full definition from pg_dump --schema-only (CREATE with
-- defaults, constraints, indexes, triggers, comments, grants). Postgres has
-- no SQL function for a table's DDL, so pg_dump it is.
local M = {}

-- What the helper writes; {schema} and {table} are filled in by dadbod-ui
M.helper = [[-- pg_dump "{schema}"."{table}"]]

-- Drop pg_dump's session settings, \restrict lines and -- headers, and
-- squeeze the blank lines they leave
function M.clean(out)
  local lines, blank = {}, true
  for _, line in ipairs(vim.split(out, "\n", { plain = true })) do
    local skip = line:find("^SET ")
      or line:find("^SELECT pg_catalog%.set_config")
      or line:find("^\\u?n?restrict ")
      or line:find("^%-%-")
    if not skip then
      local is_blank = vim.trim(line) == ""
      if not (is_blank and blank) then
        table.insert(lines, line)
      end
      blank = is_blank
    end
  end
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    table.remove(lines)
  end
  return lines
end

function M.fill(buf)
  local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  local object = first:match('^%-%- pg_dump ("[^"]*"%."[^"]*")$')
  local url = vim.b[buf].db
  if not object or type(url) ~= "string" then
    return
  end
  local function set(lines)
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    end
  end
  set({ "-- Loading " .. object .. " ..." })
  vim.system(
    { "pg_dump", "--schema-only", "--no-password", "--table", object, "--dbname", url },
    { text = true },
    function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          local lines = { "-- pg_dump failed for " .. object }
          for _, line in ipairs(vim.split(vim.trim(res.stderr), "\n")) do
            table.insert(lines, "-- " .. line)
          end
          set(lines)
          return
        end
        local lines = M.clean(res.stdout)
        set(#lines > 0 and lines or { "-- pg_dump returned nothing for " .. object })
      end)
    end
  )
end

-- Open the drawer entry under the cursor with a <Plug> map from dadbod-ui;
-- the DDL entry opens without the auto-execute LazyVim turns on for table
-- helpers (it would run the marker line into an empty result pane) and is
-- filled from pg_dump instead
local function select(plug)
  local ok, item = pcall(vim.fn.eval, "db_ui#drawer#get().get_current_item()")
  local ddl = ok and type(item) == "table" and item.label == "DDL" and item.content == M.helper
  local auto = vim.g.db_ui_auto_execute_table_helpers
  if ddl then
    vim.g.db_ui_auto_execute_table_helpers = 0
  end
  local opened, err = pcall(vim.cmd.execute, ([["normal \<Plug>(%s)"]]):format(plug))
  vim.g.db_ui_auto_execute_table_helpers = auto
  if not opened then
    error(err)
  end
  if ddl and vim.b.dbui_db_key_name then
    M.fill(vim.api.nvim_get_current_buf())
  end
end

function M.setup()
  vim.g.db_ui_table_helpers = vim.tbl_deep_extend("force", vim.g.db_ui_table_helpers or {}, {
    postgresql = { DDL = M.helper },
  })
  -- The keys dadbod-ui's ftplugin gives these two maps
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("db_ddl", { clear = true }),
    pattern = "dbui",
    callback = function(ev)
      for _, key in ipairs({ "o", "<CR>", "<2-LeftMouse>" }) do
        vim.keymap.set("n", key, function()
          select("DBUI_SelectLine")
        end, { buffer = ev.buf, desc = "Open" })
      end
      vim.keymap.set("n", "S", function()
        select("DBUI_SelectLineVsplit")
      end, { buffer = ev.buf, desc = "Open in Vsplit" })
    end,
  })
end

return M
