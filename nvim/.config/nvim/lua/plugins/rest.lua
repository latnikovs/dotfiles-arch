-- REST client: my http.nvim (latnikovs/http.nvim, loaded from its clone in
-- ~/Work/latnikovs while I work on it, see config/lazy.lua). Requests in
-- .http files, environments in http-client.env.json, credentials from
-- KeePassXC (config/keepass_http.lua). Everything is under <leader>H:
-- <leader>Hh opens the sidebar for the current directory's http/ folder,
-- <leader>He picks the environment, the rest work in .http buffers, where
-- <CR> sends the request under the cursor.
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
    map(ev.buf, "<CR>", "send_at", "Send Request")
    map(ev.buf, "<leader>Hs", "send_at", "Send Request")
    map(ev.buf, "<leader>Hr", "replay", "Replay Last Request")
    map(ev.buf, "<leader>Hv", "set_var", "Set Variable")
    map(ev.buf, "<leader>Hn", "new_request", "New Request")
    map(ev.buf, "<leader>Ht", "view", "Cycle Response View")
    map(ev.buf, "<leader>Hc", "copy_curl", "Copy as cURL")
    map(ev.buf, "<leader>Hq", "close", "Close Response")
    map(ev.buf, "<leader>Hx", "cancel", "Cancel Request")
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
      { "<leader>Hh", "<cmd>HttpToggle<cr>", desc = "Toggle Sidebar" },
      { "<leader>He", "<cmd>HttpEnv<cr>", desc = "Select Environment" },
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
    opts = { spec = { { "<leader>H", group = "http", icon = { icon = "󰖟 ", color = "blue" } } } },
  },
}
