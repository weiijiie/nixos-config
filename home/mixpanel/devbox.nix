{ ... }@args:
(common: common // { 
  home.packges = [
    manix
    tree
    yq-go
    tokei
    ranger
    tldr
    bottom
    nil
    nixfmt-classic
  ];

  go.enable = false;

  programs.zsh.initExtra = common.programs.zsh.initExtra + "\n" + ''
  # devbox setup
  source ~/.gcpdevbox
  '';
} (import ../common.nix args))