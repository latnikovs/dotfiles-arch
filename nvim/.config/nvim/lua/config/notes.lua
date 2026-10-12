-- Daily notes in ~/notes/daily/YYYY-MM-DD.md, the Obsidian daily-note layout,
-- so the folder still opens as a vault there. A module rather than inline in
-- keymaps.lua so the SUPER + N launcher (hypr scripts/notes) can call it at
-- startup, before the VeryLazy keymaps exist. Images: see plugins/notes.lua.
local M = {}

M.dir = vim.fn.expand("~/notes")

-- A new day starts with its date as the heading, saved straight away so an
-- untouched note doesn't leave a modified buffer behind.
function M.daily(offset_days)
  local date = os.date("%Y-%m-%d", os.time() + (offset_days or 0) * 86400)
  local path = M.dir .. "/daily/" .. date .. ".md"
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local is_new = vim.fn.filereadable(path) == 0
  -- pcall: any answer to the swap file prompt raises E325, which would print a traceback
  if not pcall(vim.cmd.edit, vim.fn.fnameescape(path)) then
    return
  end
  if is_new and vim.api.nvim_buf_line_count(0) == 1 and vim.fn.getline(1) == "" then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# " .. date, "", "" })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    vim.cmd("silent write")
  end
end

-- The daily notes on disk, oldest first (the YYYY-MM-DD names sort by date).
local function daily_notes()
  local notes = vim.fn.glob(M.dir .. "/daily/*.md", false, true)
  table.sort(notes)
  return notes
end

-- Steps to the next (1) or previous (-1) daily note that exists, skipping the
-- days without one. Outside a daily note it steps from today. Returns whether
-- there was one; quiet leaves out the message when there wasn't.
function M.step(direction, quiet)
  local current = vim.api.nvim_buf_get_name(0)
  if vim.fs.dirname(current) ~= M.dir .. "/daily" then
    current = M.dir .. "/daily/" .. os.date("%Y-%m-%d") .. ".md"
  end
  local notes = daily_notes()
  local first, last, step = 1, #notes, 1
  if direction < 0 then
    first, last, step = #notes, 1, -1
  end
  for i = first, last, step do
    if (direction > 0 and notes[i] > current) or (direction < 0 and notes[i] < current) then
      pcall(vim.cmd.edit, vim.fn.fnameescape(notes[i]))
      return true
    end
  end
  if not quiet then
    vim.notify(direction > 0 and "No newer note" or "No older note", vim.log.levels.INFO)
  end
  return false
end

-- Deletes the current note after asking. A daily note is replaced by the one
-- before it (or after, if it was the first), so the notes window stays on a note.
-- Images it pasted into assets/ are left alone: another note may link them too.
function M.delete()
  local path = vim.api.nvim_buf_get_name(0)
  if not vim.startswith(path, M.dir .. "/") or vim.fn.filereadable(path) == 0 then
    vim.notify("Not a note in " .. M.dir, vim.log.levels.WARN)
    return
  end
  local name = path:sub(#M.dir + 2)
  if vim.fn.confirm("Delete " .. name .. "?", "&Yes\n&No", 2) ~= 1 then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  if vim.fs.dirname(path) == M.dir .. "/daily" then
    local _ = M.step(-1, true) or M.step(1, true)
  end
  if vim.fn.delete(path) ~= 0 then
    vim.notify("Could not delete " .. name, vim.log.levels.ERROR)
    return
  end
  Snacks.bufdelete({ buf = buf, force = true })
  vim.notify("Deleted " .. name, vim.log.levels.INFO)
end

return M
