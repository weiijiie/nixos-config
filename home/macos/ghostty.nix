{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    enableZshIntegration = true;
    installVimSyntax = true;
    installBatSyntax = true;

    settings = {
      theme = "Catppuccin Mocha";

      font-family = "CaskaydiaMono Nerd Font";
      font-size = 14;

      background-opacity = 0.9;
      background-blur-radius = 10;

      window-padding-x = 8;
      window-padding-y = 8;

      scrollback-limit = 16000;

      copy-on-select = "clipboard";

      shell-integration-features = "ssh-terminfo,ssh-env";

      keybind = [
        "ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
      ];
    };
  };
}
