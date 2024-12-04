{ ... }:
{
  opts = {
    termguicolors = true;
    guifont = "Cascadia\ Mono\ PL";
  };

  colorschemes = {
    catppuccin = {
      enable = true;

      settings = {
        background = {
          light = "latte";
          dark = "mocha";
        };

        transparent_background = true;

        integrations = {
          cmp = true;
          treesitter = true;

          rainbow_delimiters = true;

          indent_blankline = {
            enabled = true;
            scope_color = "blue";
            colored_indent_levels = true;
          };

          which_key = true;
          leap = true;
          noice = true;

          mini = {
            enabled = true;
          };

          telescope = {
            enabled = true;
          };
        };
      };
    };
  };

  plugins = {
    lualine.enable = true;

    web-devicons.enable = true;

    rainbow-delimiters.enable = true;

    indent-blankline = {
      enable = true;
    };

    notify = {
      enable = true;
      backgroundColour = "#222222";
      topDown = false;
    };

    noice = {
      enable = true;
      settings = {
        presets = {
          bottom_search = true;
          lsp_doc_border = true;
        };

        views = {
          cmdline_popup = {
            position = {
              row = 30;
              col = "50%";
            };
            size = {
              width = 60;
              height = "auto";
            };
          };

          popupmenu = {
            relative = "editor";
            position = {
              row = 33;
              col = "50%";
            };
            size = {
              width = 60;
              height = 10;
            };
            border = {
              style = "rounded";
              padding = [
                0
                1
              ];
            };
            win_options = {
              winhighlight = {
                Normal = "Normal";
                FloatBorder = "DiagnosticInfo";
              };
            };
          };
        };

        lsp = {
          override = {
            "cmp.entry.get_documentation" = true;
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown" = true;
          };
        };
      };
    };
  };
}
