{
  config,
  inputs,
  outputs,
  lib,
  pkgs,
  ...
}:
let
  skillDirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../skills);
  openclawSkillDirs = lib.filterAttrs (_: type: type == "directory") (
    builtins.readDir "${inputs.agent-skills}/skills"
  );

  hunkPkg = inputs.hunk.packages.${pkgs.stdenv.hostPlatform.system}.hunk;

  feedback-inject = pkgs.writeShellApplication {
    name = "claude-feedback-inject";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      input=$(cat)
      cwd=$(jq -r '.cwd // empty' <<<"$input")

      feedback_dir="$HOME/.claude/feedback"
      files=("$feedback_dir/global/active-rules.md")

      if [ -n "$cwd" ]; then
        slug=$(printf '%s' "$cwd" | sed 's|[^A-Za-z0-9]|-|g')
        files+=(
          "$feedback_dir/projects/$slug/active-rules.md"
          "$feedback_dir/projects/$slug/staged-rules.md"
        )
      fi

      content=""
      for f in "''${files[@]}"; do
        if [ -s "$f" ]; then
          content="$content$(cat "$f")"$'\n\n'
        fi
      done

      if [ -z "$content" ]; then
        exit 0
      fi

      jq -n --arg c "$content" \
        '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
    '';
  };

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

  claudeCodeSettings = {
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
      SessionStart = [
        {
          matcher = "startup|clear|compact";
          hooks = [
            {
              type = "command";
              command = "${feedback-inject}/bin/claude-feedback-inject";
            }
          ];
        }
        mkZellaudeHook
      ];
      SessionEnd = [ mkZellaudeHook ];
    };
  };

  claudeCodeMcpServers = {
    nixos = {
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };
  };
in
{
  options.claudeCodeConfig = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    description = "Shared Claude Code configuration";
  };

  config = {
    claudeCodeConfig = {
      settings = claudeCodeSettings;
      mcpServers = claudeCodeMcpServers;
    };

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

    home.file =
      lib.mapAttrs' (name: _: {
        name = ".claude/skills/${name}";
        value = {
          source = ../skills/${name};
          recursive = true;
        };
      }) skillDirs
      // lib.mapAttrs' (name: _: {
        name = ".claude/skills/${name}";
        value = {
          source = "${inputs.agent-skills}/skills/${name}";
          recursive = true;
        };
      }) openclawSkillDirs
      // {
        ".claude/skills/hunk-review/SKILL.md" = {
          source = "${hunkPkg}/skills/hunk-review/SKILL.md";
        };
      };

    programs.claude-code = {
      enable = true;
      package = pkgs.llm-agents.claude-code;
      rulesDir = ./claude-rules;
      mcpServers = config.claudeCodeConfig.mcpServers;
      settings = config.claudeCodeConfig.settings;
    };
  };
}
