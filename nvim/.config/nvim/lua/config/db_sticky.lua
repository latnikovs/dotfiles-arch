-- Sticky column names in result panes: once a result's header has scrolled
-- out of view, a float over the top two lines of the pane shows it (names
-- and the ---+--- line) and follows horizontal scrolling. With several
-- results in one pane it is the header of the one at the top.
local M = {}

local floats = {} -- result window -> { win, buf }
local blocks = {} -- result buffer -> { tick, list of { sep, last } }

-- Each result's ---+--- line and its last row, cached until the pane reloads
local function results(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local cached = blocks[buf]
  if cached and cached.tick == tick then
    return cached.list
  end
  local list = {}
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    if i > 1 and line:match("^%-[-+]*$") then
      table.insert(list, { sep = i, last = #lines })
    elseif #list > 0 and list[#list].last == #lines and line:match("^%(%d+ rows?%)$") then
      list[#list].last = i - 1
    end
  end
  blocks[buf] = { tick = tick, list = list }
  return list
end

local function close(win)
  local float = floats[win]
  floats[win] = nil
  if float then
    pcall(vim.api.nvim_win_close, float.win, true)
    pcall(vim.api.nvim_buf_delete, float.buf, { force = true })
  end
end

function M.update(win)
  if not vim.api.nvim_win_is_valid(win) then
    return close(win)
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype ~= "dbout" then
    return close(win)
  end
  local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  local block
  for _, b in ipairs(results(buf)) do
    -- Only once the names line is out of view, and while rows are in view
    if view.topline >= b.sep and view.topline <= b.last then
      block = b
    end
  end
  local info = vim.fn.getwininfo(win)[1]
  local width = info.width - info.textoff
  if not block or info.height < 4 or width < 1 then
    return close(win)
  end
  local lines = vim.api.nvim_buf_get_lines(buf, block.sep - 2, block.sep, false)
  local float = floats[win]
  if not float or not vim.api.nvim_win_is_valid(float.win) then
    close(win)
    local fbuf = vim.api.nvim_create_buf(false, true)
    vim.bo[fbuf].bufhidden = "wipe"
    local fwin = vim.api.nvim_open_win(fbuf, false, {
      relative = "win",
      win = win,
      row = 0,
      col = info.textoff,
      width = width,
      height = 2,
      focusable = false,
      style = "minimal",
      noautocmd = true,
      zindex = 20,
    })
    vim.wo[fwin].wrap = false
    vim.wo[fwin].winhighlight = "NormalFloat:Normal"
    float = { win = fwin, buf = fbuf }
    floats[win] = float
  else
    vim.api.nvim_win_set_config(float.win, { relative = "win", win = win, row = 0, col = info.textoff, width = width })
  end
  vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, lines)
  vim.api.nvim_win_call(float.win, function()
    vim.fn.winrestview({ topline = 1, lnum = 1, col = 0, leftcol = view.leftcol })
  end)
end

local function update_all()
  for win in pairs(floats) do
    M.update(win)
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not floats[win] and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dbout" then
      M.update(win)
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("db_sticky", { clear = true })
  vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized", "BufWinEnter", "BufReadPost", "TabEnter" }, {
    group = group,
    callback = function()
      -- After the reload or the layout has settled
      vim.schedule(update_all)
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      close(tonumber(ev.match))
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    pattern = "*.dbout",
    callback = function(ev)
      blocks[ev.buf] = nil
    end,
  })
end

return M
