{ pkgs, ... }:
{
  extraPlugins = with pkgs.vimPlugins; [
    quick-scope
  ];

  extraConfigVim = ''
    let g:qs_highlight_on_keys = ['f', 'F', 't', 'T']
  '';

  autoCmd = [
    {
      command = "highlight QuickScopePrimary guifg='#bfff3a' gui=underline ctermfg=155 cterm=underline";
      event = "ColorScheme";
    }
    {
      command = "highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline";
      event = "ColorScheme";
    }
  ];
}
