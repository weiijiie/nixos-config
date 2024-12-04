{ pkgs, ... }:
{
  # nixvim uses neovim from unstable
  package = pkgs.unstable.neovim-unwrapped;

  imports = [
    ./settings.nix
    ./theme.nix
    ./plugins.nix # misc smaller plugins
    ./completions.nix
    ./lsp.nix
    ./treesitter.nix
    ./telescope.nix
    ./quickscope.nix
    ./avante.nix
  ];
}
