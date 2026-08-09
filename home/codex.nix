{
  config,
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}:
let
  codexSettings = {
    mcp_servers = {
      nixos = {
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
    };
  };

  rtkAwareness = builtins.readFile "${pkgs.llm-agents.rtk}/libexec/rtk/hooks/codex/rtk-awareness.md";
in
{
  options.codexConfig = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    description = "Shared Codex configuration";
  };

  config = {
    codexConfig = {
      settings = codexSettings;
    };

    programs.codex = {
      enable = true;
      # Cached at cache.numtide.com; the shared-nixpkgs overlay would rebuild
      # it locally against our nixpkgs. See home/claude-code.nix.
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
      settings = config.codexConfig.settings;
      context = rtkAwareness;
    };
  };
}
