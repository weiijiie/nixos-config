{
  outputs,
  lib,
  pkgs,
  ...
}:
let
  zellaude-hook = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/ishefi/zellaude/v0.4.1/scripts/zellaude-hook.sh";
    hash = "sha256-o/PQW44U89G56P518aX9Dcr89FcmGDoz20XDpg9c+n0=";
  };

  # The installed hook script needs a version tag on line 2 for zellaude's
  # WASM plugin to recognise it as current and skip re-patching settings.json.
  zellaude-hook-versioned = pkgs.runCommand "zellaude-hook.sh" { } ''
    head -1 ${zellaude-hook} > $out
    echo "# zellaude v0.4.1" >> $out
    tail -n +2 ${zellaude-hook} >> $out
    chmod +x $out
  '';

  mkZellaudeHook = {
    hooks = [
      {
        type = "command";
        command = "~/.config/zellij/plugins/zellaude-hook.sh";
        timeout = 5;
        async = true;
      }
    ];
  };
in
{
  home.packages = [ pkgs.llm-agents.ccstatusline ];

  # Place the zellaude hook script
  xdg.configFile."zellij/plugins/zellaude-hook.sh" = {
    source = zellaude-hook-versioned;
    executable = true;
  };

  # ccstatusline config — to edit, run `ccstatusline --config /tmp/ccstatusline.json`
  # then copy the result here.
  xdg.configFile."ccstatusline/settings.json".text = builtins.toJSON {
    version = 3;
    lines = [
      [
        {
          id = "1";
          type = "model";
          color = "cyan";
          rawValue = true;
        }
        {
          id = "2";
          type = "git-branch";
          color = "magenta";
        }
        {
          id = "3";
          type = "git-changes";
          color = "yellow";
        }
      ]
      [
        {
          id = "4";
          type = "context-bar";
          metadata.display = "progress-short";
          rawValue = true;
          color = "brightBlue";
        }
      ]
      [ ]
    ];
    flexMode = "full-until-compact";
    compactThreshold = 60;
    colorLevel = 2;
    defaultPadding = "";
    defaultSeparator = "  ";
    inheritSeparatorColors = false;
    globalBold = false;
    powerline = {
      enabled = false;
      separators = [ "" ];
      separatorInvertBackground = [ false ];
      startCaps = [ ];
      endCaps = [ ];
      autoAlign = false;
    };
  };

  programs.claude-code = {
    enable = true;
    package = pkgs.llm-agents.claude-code;

    mcpServers = {
      nixos = {
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
    };

    settings = {
      model = "opus";
      effortLevel = "high";

      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      };

      statusLine = {
        type = "command";
        command = "ccstatusline";
        padding = 0;
      };

      enabledPlugins = {
        "superpowers@claude-plugins-official" = true;
        "skill-creator@claude-plugins-official" = true;
        "github@claude-plugins-official" = true;
        "frontend-design@claude-plugins-official" = true;
        "ast-grep@ast-grep-marketplace" = true;
      };

      extraKnownMarketplaces = {
        ast-grep-marketplace = {
          source = {
            source = "github";
            repo = "ast-grep/agent-skill";
          };
        };
      };

      hooks = {
        PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "${pkgs.llm-agents.rtk}/libexec/rtk/hooks/claude/rtk-rewrite.sh";
              }
            ];
          }
          mkZellaudeHook
        ];
        PostToolUse = [ mkZellaudeHook ];
        PostToolUseFailure = [ mkZellaudeHook ];
        UserPromptSubmit = [ mkZellaudeHook ];
        PermissionRequest = [ mkZellaudeHook ];
        Notification = [ mkZellaudeHook ];
        Stop = [ mkZellaudeHook ];
        SubagentStop = [ mkZellaudeHook ];
        SessionStart = [ mkZellaudeHook ];
        SessionEnd = [ mkZellaudeHook ];
      };
    };
  };

}
