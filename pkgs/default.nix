{
  inputs,
  pkgs ? (import ../nixpkgs.nix) { },
  ...
}:
{
  vim-colors-xcode = pkgs.callPackage ./vim-colors-xcode { };

  claude-code-transcripts = pkgs.callPackage ./python/claude-code-transcripts.nix { };

  nvim = inputs.nixvim.legacyPackages.makeNixvimWithModule {
    inherit pkgs;
    module = import ../modules/nvim;
  };
}
