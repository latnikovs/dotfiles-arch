-- Databases: dadbod, dadbod-ui and completion come from LazyVim's lang.sql
-- extra (lazyvim.json). Connections come from KeePassXC (config/keepass_dbs.lua):
-- the first <leader>D asks for the master password and fills the drawer.
-- Connections added with DBUIAddConnection go to dadbod_ui/connections.json in
-- plain text, so keep the ones with passwords in KeePassXC.
local function keepass_dbs()
  return require("config.keepass_dbs")
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
        vim.fn["db_ui#reset_state"]()
        vim.cmd("DBUI")
      end, { desc = "Reload database connections from KeePassXC" })
    end,
  },
}
