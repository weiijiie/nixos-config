{
  inputs,
  pkgs ? (import ../nixpkgs.nix) { },
  ...
}:
{
  vim-colors-xcode = pkgs.callPackage ./vim-colors-xcode { };

  code2prompt = pkgs.callPackage ./rust/code2prompt.nix { };

  claude-code-transcripts = pkgs.callPackage ./python/claude-code-transcripts.nix { };

  nvim = inputs.nixvim.legacyPackages.makeNixvimWithModule {
    inherit pkgs;
    module = import ../modules/nvim;
  };
}
