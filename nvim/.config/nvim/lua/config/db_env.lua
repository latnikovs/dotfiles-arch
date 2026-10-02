-- Prod or not at a glance: query and result windows get a winbar with the
-- connection's name, a red bar for production and a dim line for the rest,
-- and production connections are red in the drawer. Production is any
-- connection whose name (from KeePassXC, e.g. "Ordering › PROD") has one of
-- these words in it.
local M = {}

M.words = { "prod", "production", "prd", "live" }

function M.is_prod(name)
  name = name:lower()
  for _, word in ipairs(M.words) do
    if name:find("%f[%w]" .. word .. "%f[^%w]") then
      return true
    end
  end
  return false
end

-- Connection names by the URL their query buffers run with, which is the
-- one their results get; dadbod rewrites the URLs from g:dbs on the way
local by_url = {}

-- The connection a query or result buffer belongs to
function M.name(buf)
  local key = vim.b[buf].dbui_db_key_name
  local db = vim.b[buf].db
  if type(key) == "string" then
    local name = key:gsub("_g:dbs$", "")
    if type(db) == "string" then
      by_url[db] = name
    end
    return name
  end
  local url = type(db) == "table" and db.db_url
  if not url then
    return nil
  end
  if by_url[url] then
    return by_url[url]
  end
  for _, conn in ipairs(type(vim.g.dbs) == "table" and vim.g.dbs or {}) do
    local ok, resolved = pcall(vim.fn["db#resolve"], conn.url)
    if ok and resolved == url then
      by_url[url] = conn.name
      return conn.name
    end
  end
end

local function colors()
  -- Nord red with Nord's snow white on it, readable in light and dark
  vim.api.nvim_set_hl(0, "DbProd", { fg = "#eceff4", bg = "#bf616a", bold = true })
  vim.api.nvim_set_hl(0, "DbConnection", { link = "Comment" })
  vim.api.nvim_set_hl(0, "DbuiProd", { fg = "#bf616a", bold = true })
end

function M.update(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local name = M.name(buf)
  if name then
    local hl = M.is_prod(name) and "DbProd" or "DbConnection"
    vim.wo[win].winbar = ("%%#%s# %s%%="):format(hl, name:gsub("%%", "%%%%"))
    vim.w[win].db_env = true
  elseif vim.w[win].db_env then
    -- The window now shows something else
    vim.wo[win].winbar = ""
    vim.w[win].db_env = nil
  end
end

-- Prod connections in the drawer: the whole line of a connection (they are
-- the only lines that start at the left edge) with a prod word in its name.
-- From after/syntax/dbui.lua, as dadbod-ui's syntax file clears what is
-- there before.
function M.drawer_syntax()
  local words = table.concat(M.words, "\\|")
  vim.cmd(([[syntax match DbuiProd /\c^\S.*\<\(%s\)\>.*$/]]):format(words))
end

function M.setup()
  colors()
  local group = vim.api.nvim_create_augroup("db_env", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = colors })
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter", "FileType" }, {
    group = group,
    callback = function(ev)
      -- dadbod-ui sets the buffer's connection after opening it
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(ev.buf) then
          return
        end
        for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
          M.update(win)
        end
      end)
    end,
  })
end

return M
