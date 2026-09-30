-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Notes save themselves, like Obsidian: the notes window (SUPER + N) is usually
-- closed with SUPER + W, which kills nvim with the buffer unsaved and leaves a
-- swap file that asks to be recovered next time.
local notes_dir = require("config.notes").dir
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "FocusLost", "BufLeave" }, {
  group = vim.api.nvim_create_augroup("notes_autosave", { clear = true }),
  pattern = notes_dir .. "/*.md",
  callback = function(ev)
    if vim.bo[ev.buf].modified and vim.bo[ev.buf].buftype == "" then
      vim.api.nvim_buf_call(ev.buf, function()
        vim.cmd("silent! update")
      end)
    end
  end,
})
