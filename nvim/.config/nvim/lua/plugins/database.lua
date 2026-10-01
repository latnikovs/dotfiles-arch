-- Databases: dadbod, dadbod-ui and completion come from LazyVim's lang.sql
-- extra (lazyvim.json). Connections come from KeePassXC (config/keepass_dbs.lua):
-- the first <leader>D asks for the master password and fills the drawer.
-- Connections added with DBUIAddConnection go to dadbod_ui/connections.json in
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

return {
  {
    "kristijanhusak/vim-dadbod-ui",
    cmd = { "DBUIKeepass" },
    keys = {
      {
        "<leader>D",
        function()
          if keepass_dbs().loaded or keepass_dbs().load() then
            replace_dashboard()
            vim.cmd("DBUIToggle")
          end
        end,
        desc = "Toggle DBUI",
      },
    },
    config = function()
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
