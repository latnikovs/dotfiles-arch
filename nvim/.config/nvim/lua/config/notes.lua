-- Daily notes in ~/notes/daily/YYYY-MM-DD.md, the Obsidian daily-note layout,
-- so the folder still opens as a vault there. A module rather than inline in
-- keymaps.lua so the SUPER + N launcher (hypr scripts/notes) can call it at
-- startup, before the VeryLazy keymaps exist. Images: see plugins/notes.lua.
local M = {}

M.dir = vim.fn.expand("~/notes")

-- A new day starts with its date as the heading.
function M.daily(offset_days)
  local date = os.date("%Y-%m-%d", os.time() + (offset_days or 0) * 86400)
  local path = M.dir .. "/daily/" .. date .. ".md"
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local is_new = vim.fn.filereadable(path) == 0
  vim.cmd.edit(vim.fn.fnameescape(path))
  if is_new and vim.api.nvim_buf_line_count(0) == 1 and vim.fn.getline(1) == "" then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# " .. date, "", "" })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
  end
end

return M
