{
  plugins.telescope = {
    enable = true;

    extensions = {
      fzf-native.enable = true;
      live-grep-args.enable = true;
    };

    keymaps = {
      "<C-k>" = "move_selection_previous";
      "<C-j>" = "move_selection_next";
      "<leader>ff" = {
        action = "find_files";
        options = {
          desc = "Fuzzy find files in pwd";
        };
      };
      "<leader>fr" = {
        action = "oldfiles";
        options = {
          desc = "Fuzzy find recent files";
        };
      };
      "<leader>fs" = {
        action = "live_grep";
        options = {
          desc = "Find string in pwd";
        };
      };
      "<leader>fc" = {
        action = "grep_string";
        options = {
          desc = "Find string under cursor in pwd";
        };
      };
    };

    highlightTheme = "catppuccin";
  };
}
