{
  inputs,
  pkgs ? (import ../nixpkgs.nix) { },
  ...
}:
{
  vim-colors-xcode = pkgs.callPackage ./vim-colors-xcode { };

  obsidian-headless = pkgs.callPackage ./obsidian-headless { };

  vault-mcp = pkgs.callPackage ./vault-mcp { };

  claude-code-transcripts = pkgs.callPackage ./python/claude-code-transcripts.nix { };

  nvim = inputs.nixvim.legacyPackages.makeNixvimWithModule {
    inherit pkgs;
    module = import ../modules/nvim;
  };
}
