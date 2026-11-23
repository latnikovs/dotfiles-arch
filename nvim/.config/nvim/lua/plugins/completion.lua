-- In prose the completion menu pops up on every word and gets in the way of
-- writing. There it stays closed until <C-Space> asks for it; code keeps the
-- automatic menu. Ghost text goes too: LazyVim turns it on, and it shows even
-- with the menu closed.
local prose = { "markdown", "text", "gitcommit" }

local function in_code()
  return not vim.tbl_contains(prose, vim.bo.filetype)
end

return {
  "saghen/blink.cmp",
  opts = {
    completion = {
      menu = { auto_show = in_code },
      ghost_text = { enabled = in_code },
    },
  },
}
