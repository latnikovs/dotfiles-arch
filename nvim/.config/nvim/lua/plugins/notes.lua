-- Notes in ~/notes: plain markdown, daily notes under daily/, laid out so the
-- folder also opens as an Obsidian vault. The daily-note keymaps live in
-- config/keymaps.lua; this file is the image half.
return {
  -- Draw images inside nvim through kitty's graphics protocol: inline under
  -- each ![](...) in markdown, and in a float for image files. Inside tmux this
  -- needs allow-passthrough, which .tmux.conf sets.
  {
    "folke/snacks.nvim",
    opts = {
      image = { enabled = true },
    },
  },

  -- Paste the clipboard image (a grim/satty screenshot, a copied picture) into
  -- the note: saves it to assets/ next to the note and inserts the link. The
  -- link is relative to the note, which Obsidian resolves the same way.
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
      default = {
        dir_path = "assets",
        relative_to_current_file = true,
        file_name = "%Y-%m-%d-%H%M%S",
        prompt_for_file_name = false,
      },
    },
    keys = {
      { "<leader>jp", "<cmd>PasteImage<cr>", desc = "Paste Image" },
    },
  },

  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>j", group = "journal" },
      },
    },
  },
}
