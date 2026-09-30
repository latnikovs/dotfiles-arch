-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Yank the current file's absolute path with the cursor's line number, in the
-- path:line form that jumps straight to the spot when pasted into a terminal,
-- an issue, or a chat. Carried over from the kickstart config.
vim.keymap.set("n", "<leader>yp", function()
  local location = vim.fn.expand("%:p") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", location)
  vim.notify("Copied " .. location)
end, { desc = "[Y]ank full [P]ath:line" })

-- Buffer shortcuts carried over from the kickstart config.
vim.keymap.set("n", "<leader>bn", "<cmd>enew<cr>", { desc = "[B]uffer [N]ew" })
vim.keymap.set("n", "<leader>bR", "<cmd>e!<cr>", { desc = "[B]uffer [R]eload" })

-- Daily notes in ~/notes/daily/YYYY-MM-DD.md, the Obsidian daily-note layout,
-- so the folder still opens as a vault there. A new day starts with its date
-- as the heading. Images: see plugins/notes.lua.
local notes = vim.fn.expand("~/notes")

local function daily_note(offset_days)
  local date = os.date("%Y-%m-%d", os.time() + offset_days * 86400)
  local path = notes .. "/daily/" .. date .. ".md"
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local is_new = vim.fn.filereadable(path) == 0
  vim.cmd.edit(vim.fn.fnameescape(path))
  if is_new and vim.api.nvim_buf_line_count(0) == 1 and vim.fn.getline(1) == "" then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# " .. date, "", "" })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
  end
end

vim.keymap.set("n", "<leader>jj", function()
  daily_note(0)
end, { desc = "Today's Note" })
vim.keymap.set("n", "<leader>jy", function()
  daily_note(-1)
end, { desc = "Yesterday's Note" })
vim.keymap.set("n", "<leader>jf", function()
  Snacks.picker.files({ cwd = notes })
end, { desc = "Find Note" })
vim.keymap.set("n", "<leader>jg", function()
  Snacks.picker.grep({ cwd = notes })
end, { desc = "Grep Notes" })

-- Buffer-local counterpart to LazyVim's <leader>ud, which hides diagnostics in
-- every buffer. Meant for reading prose (markdownlint nagging about a README)
-- without also losing LSP errors in the code buffers alongside it. Linters
-- keep running; their results are just not shown for this buffer.
Snacks.toggle
  .new({
    name = "Diagnostics (Buffer)",
    get = function()
      return vim.diagnostic.is_enabled({ bufnr = 0 })
    end,
    set = function(state)
      vim.diagnostic.enable(state, { bufnr = 0 })
    end,
  })
  :map("<leader>ue")
