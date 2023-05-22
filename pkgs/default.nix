{ pkgs ? (import ../nixpkgs.nix) { } }: {
  vim-colors-xcode = pkgs.callPackage ./vim-colors-xcode { };
}
