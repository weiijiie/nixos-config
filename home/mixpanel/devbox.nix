# disable some of the config because it has already been
# configured in the devbox during provisioning
{
  config,
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../common.nix
  ];

  basePackages =
    (with pkgs; [
      manix
      tree
      yq-go
      tokei
      tldr
      bottom
      bazel-buildtools
      delve
      nixd
      nixfmt
      cachix
      custom.claude-code-transcripts
      ast-grep
      mdcat
      jujutsu
    ])
    ++ [
      outputs.packages.${pkgs.stdenv.hostPlatform.system}.nvim
      pkgs.llm-agents.rtk
    ]
    ++ (builtins.attrValues pkgs.scripts);

  programs.ssh.enable = lib.mkForce false;
  programs.go.enable = lib.mkForce false;

  # Claude Code is pre-installed on devbox. Override the package to a simple
  # passthrough to the native binary. The HM module wraps this with --mcp-config.
  programs.claude-code.package = lib.mkForce (
    pkgs.writeShellScriptBin "claude" ''
      exec "$HOME/.local/bin/claude" "$@"
    ''
  );

  # The github plugin already serves this endpoint here, authenticating with the
  # PAT analytics/.shellenv exports. Declaring it again would double the toolset.
  programs.claude-code.mcpServers = lib.mkForce (
    builtins.removeAttrs config.claudeCodeConfig.mcpServers [ "github" ]
  );

  programs.git.ignores = [ "/go/.editorconfig" ];

  # fff-mcp spawns one stdio server per `claude` process and does not exit when
  # its parent dies during headless/eval runs — the orphan (reparented to init)
  # keeps a 250ms filesystem watcher alive and, in a large repo, grows an
  # unbounded in-memory file cache. Left unchecked they accumulate until they
  # exhaust RAM. Reap any fff-mcp whose parent is gone.
  systemd.user.services.fff-mcp-reaper = {
    Unit.Description = "Reap orphaned fff-mcp processes (parent claude exited)";
    Service = {
      Type = "oneshot";
      ExecStart = toString (
        pkgs.writeShellScript "fff-mcp-reaper" ''
          set -u
          for pid in $(${pkgs.procps}/bin/pgrep -x fff-mcp); do
            set -- $(${pkgs.procps}/bin/ps -o ppid=,etimes= -p "$pid" 2>/dev/null)
            # PPID 1 means the process was reparented to init: its claude is dead.
            [ "''${1:-}" = "1" ] || continue
            # Skip freshly forked procs still in the parent-to-init reparent window.
            [ "''${2:-0}" -ge 60 ] || continue
            kill "$pid" 2>/dev/null || true
          done
        ''
      );
    };
  };

  systemd.user.timers.fff-mcp-reaper = {
    Unit.Description = "Periodically reap orphaned fff-mcp processes";
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "2min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  programs.zsh = {
    initContent = lib.mkAfter ''
      # devbox setup
      source ~/.gcpdevbox
      source ~/analytics/google-cloud/scripts/kube.sh

      # Codex's github MCP server reads its bearer from this var; it cannot use
      # OAuth. analytics/.shellenv, sourced from .zshenv, has already pulled the
      # same gh token out of hosts.yml, so only a box without it pays for `gh`.
      export GITHUB_MCP_TOKEN="''${GITHUB_PERSONAL_ACCESS_TOKEN:-$(gh auth token 2>/dev/null)}"

      function gcloud() {
        if [[ "$1" == "compute" && "$2" == "ssh" ]]; then
            TERM=xterm-256color command gcloud "$@"
        else
            command gcloud "$@"
        fi
      }
    '';

    # The login shell is bash, so $SHELL is /bin/bash inside zsh too, and
    # analytics/.shellenv picks its shell integration by $SHELL.
    envExtra = lib.mkForce ''
      export SHELL=${config.programs.zsh.package}/bin/zsh
      source $HOME/analytics/.shellenv
    '';

    shellAliases = {
      bat = "${pkgs.bat}/bin/bat";
      shadow = "kubectl get pods --selector role=lqs-shadow -o json | ${pkgs.jq}/bin/jq -r '.items[0].metadata.name'";
      "perfflame.sh" = "~/analytics/tools/marcus/perfflame.sh";
      arb = "~/analytics/backend/arb/reader/arb";
    };
  };
}
