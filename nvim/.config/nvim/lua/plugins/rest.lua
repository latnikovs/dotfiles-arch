-- REST client: my http.nvim (latnikovs/http.nvim, loaded from its clone in
-- ~/Work/latnikovs while I work on it, see config/lazy.lua). Requests in
-- .http files, environments in http-client.env.json, credentials from
-- KeePassXC (config/keepass_http.lua). <leader>H opens the sidebar for the
-- current directory's http/ folder.
local function map(buf, lhs, fn, desc)
  vim.keymap.set("n", lhs, function()
    require("httpnvim")[fn]()
  end, { buffer = buf, desc = desc })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "http",
  callback = function(ev)
    if vim.bo[ev.buf].buftype ~= "" then
      return -- the response pane's headers view
    end
    map(ev.buf, "<leader>Rs", "send_at", "Send Request")
    map(ev.buf, "<leader>Rr", "replay", "Replay Last Request")
    map(ev.buf, "<leader>Re", "select_env", "Select Environment")
    map(ev.buf, "<leader>Rv", "set_var", "Set Variable")
    map(ev.buf, "<leader>Rn", "new_request", "New Request")
    map(ev.buf, "<leader>Rt", "view", "Cycle Response View")
    map(ev.buf, "<leader>Rc", "copy_curl", "Copy as cURL")
    map(ev.buf, "<leader>Rq", "close", "Close Response")
    map(ev.buf, "<leader>Rx", "cancel", "Cancel Request")
    map(ev.buf, "gd", "goto_var", "Go to Variable Definition")
    vim.keymap.set("n", "]r", function()
      require("httpnvim").jump(true)
    end, { buffer = ev.buf, desc = "Next Request" })
    vim.keymap.set("n", "[r", function()
      require("httpnvim").jump(false)
    end, { buffer = ev.buf, desc = "Previous Request" })
  end,
})

return {
  {
    "latnikovs/http.nvim",
    ft = "http",
    cmd = { "HttpToggle", "HttpEnv", "HttpSend" },
    keys = {
      { "<leader>H", "<cmd>HttpToggle<cr>", desc = "HTTP Requests" },
    },
    opts = {
      secrets = function(project, callback)
        require("config.keepass_http").secrets(project, callback)
      end,
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "http" } },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>R", group = "rest", icon = { icon = "󰖟 ", color = "blue" } } } },
  },
}
