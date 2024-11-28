# Shell for bootstrapping flake-enabled nix and home-manager
# You can enter it through 'nix develop' or (legacy) 'nix-shell'

{
  self,
  pkgs ? (import ./nixpkgs.nix) { },
  system,
}:
{
  default = pkgs.mkShell {
    # Enable experimental features without having to specify the argument
    NIX_CONFIG = "experimental-features = nix-command flakes";

    inherit (self.checks.${system}.pre-commit-check) shellHook;
    buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;

    nativeBuildInputs = with pkgs; [
      nix
      home-manager
      git
    ];
  };
}
