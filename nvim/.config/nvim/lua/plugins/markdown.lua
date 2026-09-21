-- markdownlint-cli2 only reads a config file sitting in the linting process's
-- working directory -- it never walks upward -- and nvim-lint pipes the buffer
-- over stdin, so there is no file path to discover a config from either. The
-- global rules therefore have to be passed explicitly. The path is the symlink
-- bootstrap/install.sh creates; when that has not run yet, prepending nothing
-- leaves LazyVim's stock behaviour rather than failing every lint with ENOENT.
local config = vim.fn.expand("~/.markdownlint-cli2.yaml")

return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          prepend_args = vim.fn.filereadable(config) == 1 and { "--config", config } or {},
        },
      },
    },
  },
}
