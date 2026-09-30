-- markdownlint-cli2 only reads a config file sitting in the linting process's
-- working directory -- it never walks upward -- and nvim-lint pipes the buffer
-- over stdin, so there is no file path to discover a config from either. The
-- global rules therefore have to be passed explicitly. The path is the symlink
-- bootstrap/install.sh creates; when that has not run yet, prepending nothing
-- leaves LazyVim's stock behaviour rather than failing every lint with ENOENT.
local config = vim.fn.expand("~/.markdownlint-cli2.yaml")

return {
  -- <leader>cp (browser preview). LazyVim builds it with mkdp#util#install,
  -- which downloads a prebuilt x86_64 server binary; that fails on aarch64 and
  -- leaves the server without its dependencies (MODULE_NOT_FOUND on preview).
  -- Installing them with node instead works on any architecture; node comes
  -- from mise's global tools.
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && npx --yes yarn install",
  },
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
