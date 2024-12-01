{ pkgs, ... }:
let
  qs_group = "qs_colors";
in
{
  extraPlugins = with pkgs.vimPlugins; [
    quick-scope
  ];

  extraConfigVim = ''
    let g:qs_highlight_on_keys = ['f', 'F', 't', 'T']
  '';

  autoCmd = [
    {
      event = "ColorScheme";
      command = "highlight QuickScopePrimary guifg='#bfff3a' gui=underline ctermfg=155 cterm=underline";
      group = qs_group;
    }
    {
      event = "ColorScheme";
      command = "highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline";
      group = qs_group;
    }
  ];

  autoGroups = {
    ${qs_group} = {
      clear = true;
    };
  };
}
