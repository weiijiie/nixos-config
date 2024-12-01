{
  plugins = {
    lualine.enable = true;

    which-key.enable = true;

    web-devicons.enable = true;

    mini = {
      enable = true;
      modules = {
        starter = {
          content_hooks = {
            "__unkeyed-1.adding_bullet" = {
              __raw = "require('mini.starter').gen_hook.adding_bullet()";
            };
            "__unkeyed-2.indexing" = {
              __raw = "require('mini.starter').gen_hook.indexing('all', { 'Builtin actions' })";
            };
            "__unkeyed-3.padding" = {
              __raw = "require('mini.starter').gen_hook.aligning('center', 'center')";
            };
          };
          evaluate_single = true;
          header = ''
            ███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗
            ████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║
            ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║
            ██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║
            ██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║
          '';
          items = {
            "__unkeyed-1.buildtin_actions" = {
              __raw = "require('mini.starter').sections.builtin_actions()";
            };
            "__unkeyed-2.recent_files_current_directory" = {
              __raw = "require('mini.starter').sections.recent_files(10, false)";
            };
            "__unkeyed-3.recent_files" = {
              __raw = "require('mini.starter').sections.recent_files(10, true)";
            };
            "__unkeyed-4.sessions" = {
              __raw = "require('mini.starter').sections.sessions(5, true)";
            };
          };
        };
      };
    };

    telescope = {
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

    treesitter = {
      enable = true;
      settings = { };
    };
  };
}
