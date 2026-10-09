-- Nord, light or dark with the desktop, as in kitty and tmux: onenord.nvim is
-- Nord in dark mode and its readable light form (OneNord Light) in light mode.
--
-- auto-dark-mode.nvim only flips 'background' (it reads the freedesktop
-- color-scheme setting, which scripts/theme sets). Neovim re-sources the active
-- colorscheme whenever 'background' is set, and with no `theme` onenord picks
-- dark or light from 'background', so nothing else has to listen for the change.
return {
  {
    "rmehri01/onenord.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      -- OneNord Light's selection (#EAEBED on #F7F8FA) is barely visible: use
      -- a pale Nord blue instead, keeping syntax colours on top of it.
      custom_highlights = {
        light = {
          Visual = { bg = "#C5D6EA" },
          VisualNOS = { bg = "#C5D6EA" },
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onenord",
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
