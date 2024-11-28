{ pkgs, ... }:
{
  programs = {
    nixvim = {
      enable = true;

      opts = {
        number = true;
        relativenumber = true;
        scrolloff = 4; # screen lines to keep above/below the cursor

        tabstop = 4; # number of visual spaces per TAB
        softtabstop = 4; # number of spaces in tab when editing
        expandtab = true; # tabs are spaces

        showcmd = true;

        autoindent = true;
        smartindent = true;

        # use system keyboard
        clipboard = "unnamedplus";

        # mouse support
        mouse = "a";

        termguicolors = true;
        guifont = "Cascadia\ Mono\ PL";
      };

      colorschemes = {
        catppuccin = {
          enable = true;
          settings = {
            background = {
              light = "latte";
              dark = "macchiato";
            };
          };
        };
      };

      clipboard = {
        providers.wl-copy = {
          enable = true;
        };
      };

      plugins = {
        lualine.enable = true;
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
      };

      extraConfigLua = with pkgs; ''
        if vim.fn.has("wsl") == 1 then
            vim.g.clipboard = {
                name = "wl-clipboard (wsl)",
                copy = {
                    ["+"] = '${wl-clipboard}/bin/wl-copy --foreground --type text/plain',
                    ["*"] = '${wl-clipboard}/bin/wl-copy --foreground --primary --type text/plain',
                },
                paste = {
                    ["+"] = (function()
                        return vim.fn.systemlist('${wl-clipboard}/bin/wl-paste --no-newline | ${gnused}/bin/sed -e "s/\r$//"', {'''}, 1) -- '1' keeps empty lines
                    end),
                    ["*"] = (function() 
                        return vim.fn.systemlist('${wl-clipboard}/bin/wl-paste --primary --no-newline | ${gnused}/bin/sed -e "s/\r$//"', {'''}, 1)
                    end),
                },
                cache_enabled = true
            }
        end
      '';
    };
  };
}
