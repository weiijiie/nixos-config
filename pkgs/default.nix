{
  inputs,
  pkgs ? (import ../nixpkgs.nix) { },
  ...
}:
{
  vim-colors-xcode = pkgs.callPackage ./vim-colors-xcode { };

  nvim = inputs.nixvim.legacyPackages.makeNixvimWithModule {
    inherit pkgs;
    module = import ../modules/nvim;
  };
}
