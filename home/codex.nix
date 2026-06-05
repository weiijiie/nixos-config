{
  config,
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
      package = pkgs.llm-agents.codex;
      settings = config.codexConfig.settings;
      context = rtkAwareness;
    };
  };
}
