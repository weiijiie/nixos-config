{ pkgs, ... }:
{
  globals.mapleader = " ";

  opts = {
    number = true;
    relativenumber = true;

    scrolloff = 4; # screen lines to keep above/below the cursor

    tabstop = 4; # number of visual spaces per TAB
    softtabstop = 4; # number of spaces in tab when editing
    expandtab = true; # tabs are spaces

    showcmd = true;

    autoindent = true; # copy indent from current line when starting new one
    smartindent = true;

    # use system keyboard
    clipboard = "unnamedplus";

    ignorecase = true; # ignore case when searching
    smartcase = true; # if search term has mixed case, defaults to case-sensitive search

    backspace = "indent,eol,start";

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
}
