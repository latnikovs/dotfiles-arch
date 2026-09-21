-- Follow the macOS appearance with the same Catppuccin pair kitty and tmux use
-- (Latte in light mode, Macchiato in dark), so nvim never ends up dark inside a
-- light terminal.
--
-- auto-dark-mode.nvim only flips 'background'. Neovim re-sources the active
-- colorscheme whenever 'background' is set, and with flavour = "auto" the
-- plugin re-resolves its flavour from the background map below, so nothing
-- else has to listen for the change.
--
-- The colorscheme is loaded through the plugin rather than by name: Neovim
-- 0.12 bundles its own `catppuccin` scheme (Latte/Mocha) in $VIMRUNTIME, and
-- `:colorscheme catppuccin` finds that one before lazy.nvim loads the plugin,
-- silently ignoring the Macchiato mapping.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "auto",
      background = { light = "latte", dark = "macchiato" },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        require("catppuccin").load()
      end,
    },
  },
  {
    "f-person/auto-dark-mode.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      update_interval = 3000,
      fallback = "dark",
    },
  },
}
