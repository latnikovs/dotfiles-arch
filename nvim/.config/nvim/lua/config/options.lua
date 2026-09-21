require("config.remote_clipboard").setup()
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Docs here get written in Latvian and Russian as well as English, and with
-- only the English dictionary every non-English word shows as a spelling
-- error. Checking against all three keeps real typos flagged in each. Neovim
-- offers to download the lv/ru spell files the first time they are missing.
vim.opt.spelllang = { "en", "lv", "ru" }
