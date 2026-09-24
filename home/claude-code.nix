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

  # Prints the github MCP server's request headers, authenticating as whoever
  # `gh auth login` signed in.
  github-mcp-headers = pkgs.writeShellApplication {
    name = "github-mcp-headers";
    runtimeInputs = [
      pkgs.gh
      pkgs.jq
    ];
    text = ''
      token=$(gh auth token)
      jq -n --arg t "$token" '{Authorization: "Bearer \($t)"}'
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

    # A pipe to a server whose IPC contract differs from the client's blocks on
    # the socket read instead of erroring, so an unbounded call strands one
    # process per hook event.
    substituteInPlace $out \
      --replace-fail 'zellij pipe --name "zellaude"' \
        '${pkgs.coreutils}/bin/timeout -k 2 5 zellij pipe --name "zellaude"'

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

  # Claude Code writes ~/.claude/settings.json itself: /config, /model,
  # /effort and /plugin all persist there, and a write through a store symlink
  # fails. The file therefore stays a writable regular file, and each
  # activation merges the declared keys back over whatever Claude last wrote.
  settings-merge = pkgs.writeShellApplication {
    name = "claude-settings-merge";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      # settings.json carries credentials in env, so neither it nor the
      # intermediates below may be group- or world-readable.
      umask 077

      declared="$1"
      target="$HOME/.claude/settings.json"
      base="$target.hm-base"
      merged="$target.hm-new"
      trap 'rm -f "$base" "$merged"' EXIT

      mkdir -p "$HOME/.claude"

      if [ -s "$target" ]; then
        if ! jq -e . "$target" > "$base" 2>/dev/null; then
          echo "claude settings.json is not valid JSON; leaving it unchanged" >&2
          exit 0
        fi
      else
        echo '{}' > "$base"
      fi

      jq -s '.[0] * .[1]' "$base" "$declared" > "$merged"

      # A store symlink an earlier generation left has to be replaced even when
      # the merge itself is a no-op.
      if [ ! -L "$target" ] && [ "$(jq -Sc . "$base")" = "$(jq -Sc . "$merged")" ]; then
        # umask only covers the write path, so tighten a file left loose here.
        chmod 600 "$target"
        exit 0
      fi

      # rename(2) replaces the symlink itself rather than writing through it.
      mv "$merged" "$target"
    '';
  };

  claudeCodeSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";

    model = "opus";
    effortLevel = "high";
    agentPushNotifEnabled = true;

    permissions = {
      defaultMode = "auto";
      blockReadsOutsideWorkingDirectories = false;
    };

    # Retain session transcripts for 60 days (default is 30).
    cleanupPeriodDays = 60;

    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };

    statusLine = {
      type = "command";
      command = "ccstatusline";
      padding = 0;
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

    # GitHub's authorization server has no dynamic client registration, so
    # Claude Code cannot complete OAuth against this endpoint on its own.
    github = {
      type = "http";
      url = "https://api.githubcopilot.com/mcp/";
      headersHelper = "${github-mcp-headers}/bin/github-mcp-headers";
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

    # Ahead of linkGeneration: it deletes the settings.json symlink an earlier
    # generation left, and the merge needs that file's keys.
    home.activation.claudeCodeSettings =
      lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
        ''
          run ${settings-merge}/bin/claude-settings-merge ${
            (pkgs.formats.json { }).generate "claude-code-settings.json" config.claudeCodeConfig.settings
          }
        '';

    # Place the zellaude hook script
    xdg.configFile."zellij/plugins/zellaude-hook.sh" = {
      source = zellaude-hook-versioned;
      executable = true;
    };

    # ccstatusline config — to edit, run `ccstatusline --config /tmp/ccstatusline.json`
    # then copy the result here.
    xdg.configFile."ccstatusline/settings.json".text = builtins.toJSON {
      version = 4;
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
          {
            id = "5";
            type = "session-cost";
            color = "green";
            rawValue = true;
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

        ".claude/skills/using-exe-dev" = {
          source = "${inputs.exe-dev}/skill";
          recursive = true;
        };
      };

    programs.claude-code = {
      enable = true;
      # The flake's packages output is built against llm-agents' pinned
      # nixpkgs and cached at cache.numtide.com, so it downloads prebuilt.
      # The shared-nixpkgs overlay would rebuild it against our nixpkgs.
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
      rulesDir = ./claude-rules;
      mcpServers = config.claudeCodeConfig.mcpServers;
      # settings stays unset: the module installs it as a store symlink that
      # linkGeneration restores over the merged file. The merge above reads
      # claudeCodeConfig.settings directly instead.
    };
  };
}
