{ pkgs, ... }:
{
  # nixvim uses neovim from unstable
  package = pkgs.unstable.neovim-unwrapped;

  imports = [
    ./settings.nix
    ./plugins.nix
  ];
}
