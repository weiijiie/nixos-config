# disable some of the config because it has already been
# configured in the devbox during provisioning
{
  config,
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
      custom.code2prompt
      ast-grep
      mdcat
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

  # Plugins and marketplaces from analytics claude-setup script, so
  # claude plugin install doesn't need to write to the read-only settings.json.
  programs.claude-code.settings = {
    enabledPlugins = {
      "slack@claude-plugins-official" = true;
      "atlassian@claude-plugins-official" = true;
      "notion@claude-plugins-official" = true;
      "chronosphere-mcp@mixpanel-monorepo" = true;
      "mixpanel-mcp@mixpanel-monorepo" = true;
      "honeycomb@honeycomb-plugins" = true;
      "chrome-devtools-mcp@mixpanel-monorepo" = true;
      "pagerduty-mcp@mixpanel-monorepo" = true;
      "linear@claude-plugins-official" = true;
    };
    extraKnownMarketplaces = {
      honeycomb-plugins = {
        source = {
          source = "github";
          repo = "honeycombio/agent-skill";
        };
      };
      mixpanel-monorepo = {
        source = {
          source = "directory";
          path = "${config.home.homeDirectory}/analytics/.claude/monorepo-marketplace";
        };
      };
    };
  };

  programs.git.ignores = [ "/go/.editorconfig" ];

  programs.zsh = {
    initContent = lib.mkAfter ''
      # devbox setup
      source ~/.gcpdevbox
      source ~/analytics/google-cloud/scripts/kube.sh

      function gcloud() {
        if [[ "$1" == "compute" && "$2" == "ssh" ]]; then
            TERM=xterm-256color command gcloud "$@"
        else
            command gcloud "$@"
        fi
      }
    '';

    envExtra = lib.mkForce ''
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
