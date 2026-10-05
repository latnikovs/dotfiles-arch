-- REST client for .http files (config/rest.lua): our own, on curl. Replaces
-- kulala.nvim, whose v6 moved request handling into a closed kulala-core
-- binary behind a license token.
local function map(buf, lhs, fn, desc)
  vim.keymap.set("n", lhs, function()
    require("config.rest")[fn]()
  end, { buffer = buf, desc = desc })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "http",
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= "" then
      return -- the response pane's headers view
    end
    map(ev.buf, "<leader>Rs", "run", "Send Request")
    map(ev.buf, "<leader>Rr", "replay", "Replay Last Request")
    map(ev.buf, "<leader>Re", "select_env", "Select Environment")
    map(ev.buf, "<leader>Rt", "toggle_view", "Toggle Headers/Body")
    map(ev.buf, "<leader>Rc", "copy_curl", "Copy as cURL")
    map(ev.buf, "<leader>Rq", "close", "Close Response")
    map(ev.buf, "<leader>Rx", "cancel", "Cancel Request")
    vim.keymap.set("n", "]r", function()
      require("config.rest").jump(true)
    end, { buffer = ev.buf, desc = "Next Request" })
    vim.keymap.set("n", "[r", function()
      require("config.rest").jump(false)
    end, { buffer = ev.buf, desc = "Previous Request" })
  end,
})

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "http" } },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>R", group = "rest", icon = { icon = "󰖟 ", color = "blue" } } } },
  },
}
