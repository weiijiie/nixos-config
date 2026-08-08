{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 14387;

  npxFallback = ''In restricted subprocess sandboxes, CI, or agent harnesses where `npx -y` exits opaquely (for example with status 216), use an already-installed copy directly: `node "$(npm root)/lavish-axi/dist/cli.mjs" <html-file>` for a local install, `node "$(npm root -g)/lavish-axi/dist/cli.mjs" <html-file>` for a global install, or the bare `lavish-axi <html-file>` bin after installing once.'';

  pathNote = "The `lavish-axi` command is already on PATH. There is no npm install to fall back to, so ignore any instruction to locate the CLI through `npm root`.";

  # The skill permits a background poll only through a tracked facility that wakes the
  # same agent, without naming one for any harness. Left unnamed, a Claude Code session
  # either blocks a turn on the foreground poll or skips polling, and the browser then
  # tells the user no agent is listening with nothing to indicate why.
  pollNote = pkgs.writeText "lavish-poll-harness-note.md" ''

    ## Polling from Claude Code

    Claude Code's Bash tool with `run_in_background: true` is a tracked background-job
    facility: the command keeps running across turns and the harness re-invokes this agent
    when it exits. It satisfies the requirement above, so use it for `lavish-axi poll`
    rather than blocking a turn on a foreground poll. Read the returned output file to
    collect the feedback. The prohibition on `nohup`, `&`, `disown`, and detached
    terminals still stands: those have no wake path.

    Attach the poll in the same turn that opens the session. Until one is attached the
    browser reports that no agent is listening and holds everything the user tries to send.
  '';
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
  # The npx fallback advice is replaced rather than deleted so that a version bump
  # rewording either string fails the build instead of silently reintroducing it.
  lavish-skill = pkgs.runCommand "lavish-skill" { } ''
    mkdir -p $out
    substitute ${pkgs.custom.lavish-axi}/lib/node_modules/lavish-axi/skills/lavish/SKILL.md \
      $out/SKILL.md \
      --replace-fail "npx -y lavish-axi" "lavish-axi" \
      --replace-fail ${lib.escapeShellArg npxFallback} ${lib.escapeShellArg pathNote}
    cat ${pollNote} >> $out/SKILL.md
  '';
in
{
  home.packages = [ lavish-axi ];

  home.file.".claude/skills/lavish".source = lavish-skill;
}
