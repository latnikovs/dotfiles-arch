-- Route yanks through OSC 52 when the session is remote, so `y` lands in the
-- clipboard of the machine you're sitting at instead of the far end's (which,
-- over SSH, usually has no clipboard at all). Local sessions keep the native
-- provider — pbcopy/wl-copy round-trip faster and support paste.
local M = {}

local function is_remote()
  return vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_CLIENT ~= nil
end

function M.setup()
  if not is_remote() then
    return
  end

  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok then
    return
  end

  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    -- Reading the terminal's clipboard needs an OSC 52 response the terminal
    -- may refuse for security. Fall back to Neovim's own registers instead of
    -- blocking on a reply that never comes.
    paste = {
      ["+"] = function()
        return vim.split(vim.fn.getreg('"'), "\n")
      end,
      ["*"] = function()
        return vim.split(vim.fn.getreg('"'), "\n")
      end,
    },
  }
end

return M
