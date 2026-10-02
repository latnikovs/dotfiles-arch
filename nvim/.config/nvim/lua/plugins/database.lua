-- Databases: dadbod, dadbod-ui and completion come from LazyVim's lang.sql
-- extra (lazyvim.json). Connections come from KeePassXC (config/keepass_dbs.lua):
-- the first <leader>D asks for the master password and fills the drawer.
-- Connections added with DBUIAddConnection go to connections.json in
-- plain text, so keep the ones with passwords in KeePassXC.

-- The extra turns off Vim's sqlcomplete for blink, but the SQL ftplugin still
-- maps <Left>/<Right> in insert mode to sqlcomplete functions (E117 on every
-- arrow key in a query buffer). Drop those maps.
vim.g.omni_sql_no_default_maps = 1

-- Export to CSV next to dadbod-ui's <leader>W/E/S (config/db_export.lua)
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "sql", "mysql", "plsql" },
  callback = function(ev)
    local export = require("config.db_export")
    vim.keymap.set("n", "<leader>X", export.export_paragraph, { buffer = ev.buf, desc = "Export Query to CSV" })
    vim.keymap.set("x", "<leader>X", export.export_selection, { buffer = ev.buf, desc = "Export Selection to CSV" })
  end,
})

-- Cancelling: dadbod's <C-c> in a result pane (and closing the pane) stops
-- the client with SIGTERM, and psql then just drops the connection while the
-- server keeps running the statement. SIGINT makes psql send the server a
-- cancel request first, as Ctrl-C at a psql prompt does.
local function interrupt(job)
  local ok, pid = pcall(vim.fn.jobpid, job)
  if ok and pid > 0 then
    vim.uv.kill(pid, "sigint")
  end
end

local function running(job)
  return vim.fn.jobwait({ job }, 0)[1] == -1
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "dbout",
  callback = function(ev)
    -- After dadbod's own buffer setup, which maps <C-c> too
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(ev.buf) then
        return
      end
      vim.keymap.set("n", "<C-c>", function()
        local query = vim.b[ev.buf].db
        local job = type(query) == "table" and query.job
        if not job then
          vim.notify("No query running")
          return
        end
        interrupt(job)
        -- psql exits once the server has cancelled; stop it if it hangs
        vim.defer_fn(function()
          if running(job) then
            vim.fn["db#cancel"](ev.buf)
          end
        end, 3000)
      end, { buffer = ev.buf, desc = "Cancel Query" })
      -- Change the cell under the cursor (config/db_edit.lua)
      vim.keymap.set("n", "cc", function()
        require("config.db_edit").edit()
      end, { buffer = ev.buf, desc = "Edit Cell" })
    end)
  end,
})

-- Column names stay on top while scrolling a result (config/db_sticky.lua)
require("config.db_sticky").setup()

-- Production connections in red: the winbar of their query and result
-- windows, and their line in the drawer (config/db_env.lua)
require("config.db_env").setup()

-- Closing a result pane (gq, <leader>D) runs dadbod's BufUnload, which stops
-- psql at once; this one is defined earlier so it runs first and lets psql
-- cancel on the server, waiting up to a second for it.
vim.api.nvim_create_autocmd("BufUnload", {
  pattern = "*.dbout",
  callback = function(ev)
    local query = vim.b[ev.buf].db
    local job = type(query) == "table" and query.job
    if job and running(job) then
      interrupt(job)
      vim.fn.jobwait({ job }, 1000)
    end
  end,
})

local function keepass_dbs()
  return require("config.keepass_dbs")
end

-- dadbod-ui opens queries only in a normal file window and splits off a new
-- one otherwise, so the start screen would keep a third of the width. Swap it
-- for an empty buffer that the first query then takes over.
local function replace_dashboard()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "snacks_dashboard" then
      vim.api.nvim_win_call(win, function()
        vim.cmd.enew()
      end)
    end
  end
end

local function is_db_buf(buf)
  local ft = vim.bo[buf].filetype
  return ft == "dbui" or ft == "dbout" or vim.b[buf].dbui_db_key_name ~= nil
end

local last_query, last_file

-- <leader>D toggles the whole database view: when any dadbod window is up it
-- closes the drawer, the result panes and the query windows (the query
-- buffers stay loaded and listed under the drawer's Buffers), and remembers
-- the query so the next <leader>D brings it back next to the drawer.
local function close_db_windows()
  local wins = vim.tbl_filter(function(win)
    return is_db_buf(vim.api.nvim_win_get_buf(win))
  end, vim.api.nvim_tabpage_list_wins(0))
  if #wins == 0 then
    return false
  end
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.b[buf].dbui_db_key_name and (win == vim.api.nvim_get_current_win() or not last_query) then
      last_query = buf
    end
  end
  -- Query windows go last, so the window that may have to stay open is a
  -- query window and not the result pane: that one is the preview window,
  -- where dadbod puts every result, and a query reopened in it would be
  -- replaced by the next result.
  table.sort(wins, function(a, b)
    local qa = vim.b[vim.api.nvim_win_get_buf(a)].dbui_db_key_name ~= nil
    local qb = vim.b[vim.api.nvim_win_get_buf(b)].dbui_db_key_name ~= nil
    return not qa and qb
  end)
  for _, win in ipairs(wins) do
    if #vim.api.nvim_tabpage_list_wins(0) > 1 then
      vim.api.nvim_win_close(win, false)
    else
      -- The last window: show the file from before <leader>D opened them instead
      vim.wo[win].previewwindow = false
      vim.api.nvim_win_call(win, function()
        if last_file and vim.api.nvim_buf_is_valid(last_file) and vim.bo[last_file].buflisted then
          vim.api.nvim_win_set_buf(win, last_file)
        else
          vim.cmd.enew()
        end
      end)
    end
  end
  return true
end

local function open_db_windows()
  replace_dashboard()
  local cur = vim.api.nvim_get_current_buf()
  if vim.bo[cur].buflisted and not is_db_buf(cur) then
    last_file = cur
  end
  local query_win
  if last_query and vim.api.nvim_buf_is_valid(last_query) and not is_db_buf(vim.api.nvim_get_current_buf()) then
    vim.api.nvim_win_set_buf(0, last_query)
    query_win = vim.api.nvim_get_current_win()
  end
  last_query = nil
  vim.cmd("DBUI")
  -- Back in the query it brought back, ready for <leader>S, not in the drawer
  if query_win and vim.api.nvim_win_is_valid(query_win) then
    vim.api.nvim_set_current_win(query_win)
  end
end

return {
  {
    "kristijanhusak/vim-dadbod-ui",
    cmd = { "DBUIKeepass" },
    keys = {
      {
        "<leader>D",
        function()
          if not close_db_windows() and (keepass_dbs().loaded or keepass_dbs().load()) then
            open_db_windows()
          end
        end,
        desc = "Toggle Databases",
      },
    },
    config = function()
      -- Saved queries (<leader>W) live with the notes, which Syncthing syncs
      -- and versions; one folder per connection. Scratch buffers stay in the
      -- extra's tmp dir under stdpath("data"). DBUIAddConnection would write
      -- its plain-text connections.json here too, another reason not to use it.
      vim.g.db_ui_save_location = vim.fn.expand("~/notes/queries")
      -- DDL entry under each Postgres table: pg_dump's full definition
      require("config.db_ddl").setup()
      -- Re-read KeePassXC after adding or changing an entry there
      vim.api.nvim_create_user_command("DBUIKeepass", function()
        if not keepass_dbs().load() then
          return
        end
        pcall(vim.cmd, "DBUIClose")
        replace_dashboard()
        vim.fn["db_ui#reset_state"]()
        vim.cmd("DBUI")
      end, { desc = "Reload database connections from KeePassXC" })
    end,
  },
}
