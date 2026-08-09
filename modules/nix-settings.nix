# Shared nix daemon settings for NixOS hosts.
# Imported by every host via mkHost in flake.nix.
{
  # Numtide's binary cache serves the llm-agents packages (claude-code, codex,
  # ...) prebuilt against their pinned nixpkgs. Only their `packages` outputs
  # hit it; the shared-nixpkgs overlay is built locally against our nixpkgs.
  nix.settings = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
