{
  config,
  pkgs,
  ...
}:
let
  port = 14387;
  stateDir = "${config.home.homeDirectory}/.local/state/lavish-axi";

  # The server binds loopback and the browser lives on the laptop, so nothing here
  # can open one. Reach a session over the SSH forward declared for the devbox host
  # instead; a loopback Host header is the only one the DNS-rebinding guard accepts
  # without further configuration.
  lavish-axi = pkgs.symlinkJoin {
    name = "lavish-axi-configured";
    paths = [ pkgs.custom.lavish-axi ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/lavish-axi \
        --set LAVISH_AXI_STATE_DIR ${stateDir} \
        --set LAVISH_AXI_PORT ${toString port} \
        --set LAVISH_AXI_NO_OPEN 1
    '';
  };

  # The published skill drives the CLI through `npx -y lavish-axi`, which pulls an
  # unpinned copy from the registry and, in agent and CI shells, dies with a bare
  # exit 216. Point every invocation at the wrapper instead. Deriving the skill from
  # the package rather than checking a copy into skills/ keeps the two in step
  # across version bumps.
  lavish-skill = pkgs.runCommand "lavish-skill" { } ''
    mkdir -p $out
    substitute ${pkgs.custom.lavish-axi}/lib/node_modules/lavish-axi/skills/lavish/SKILL.md \
      $out/SKILL.md \
      --replace-fail "npx -y lavish-axi" "lavish-axi"
  '';
in
{
  home.packages = [ lavish-axi ];

  home.file.".claude/skills/lavish".source = lavish-skill;
}
