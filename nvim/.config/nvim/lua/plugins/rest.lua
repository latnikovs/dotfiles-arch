-- REST client: kulala.nvim runs requests from .http files (IntelliJ HTTP
-- Client format, env in http-client.env.json); keys come from LazyVim's
-- util.rest extra (lazyvim.json) under <leader>R.
--
-- Pinned to v5.3.4, the last release that is plain Lua + curl. From v6 it
-- downloads a closed kulala-core binary that asks for a license token.
return {
  {
    "mistweaverco/kulala.nvim",
    version = false,
    tag = "v5.3.4",
    -- Its fmt submodule (kulala-fmt) breaks lazy's checkout from a clone of
    -- the v6 branch, and the formatter isn't needed to send requests.
    submodules = false,
  },
}
