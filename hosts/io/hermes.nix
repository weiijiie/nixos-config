# The agent runtime (SPEC sections 3 and 6).
#
# Upstream ships the NixOS module, so this only supplies policy: which model,
# which credentials, which directory the agent works in, what it is allowed
# to do from Telegram, and the copy of its memory kept in the vault.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hermes-agent;
  vault = config.services.vaultGit.path;
  memoryDir = "${cfg.stateDir}/.hermes/memories";

  # Everything the agent commits carries this identity, so its changes stand
  # apart from the snapshot timer's.
  agentGitIdentity = {
    GIT_AUTHOR_NAME = "Hermes";
    GIT_AUTHOR_EMAIL = "hermes@io";
    GIT_COMMITTER_NAME = "Hermes";
    GIT_COMMITTER_EMAIL = "hermes@io";
  };

  copyMemory = pkgs.writeShellApplication {
    name = "hermes-memory-copy";
    runtimeInputs = [
      pkgs.git
      pkgs.coreutils
    ];
    text = ''
      cd ${lib.escapeShellArg vault}
      mkdir -p agent/memory

      copied=()
      for name in MEMORY.md USER.md; do
        [ -e ${memoryDir}/"$name" ] || continue

        tmp=$(mktemp -p agent/memory .copy.XXXXXX)
        {
          echo "> Copy of the agent's memory, refreshed whenever it changes."
          echo "> Edits here are overwritten; change it through Telegram."
          echo
          cat ${memoryDir}/"$name"
          # Hermes writes no final newline.
          [ -z "$(tail -c 1 ${memoryDir}/"$name")" ] || echo
        } >"$tmp"
        chmod 0660 "$tmp"
        mv -f "$tmp" agent/memory/"$name"

        copied+=("agent/memory/$name")
      done

      [ ''${#copied[@]} -gt 0 ] || exit 0
      git add -- "''${copied[@]}"
      if git diff --cached --quiet -- "''${copied[@]}"; then
        exit 0
      fi
      git commit -q --only -m "memory: update" -- "''${copied[@]}"
    '';
  };
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  # Decision 19: the vault is reached through group membership rather than by
  # running the agent as the vault owner.
  users.users.hermes.extraGroups = [ config.services.vaultGit.group ];

  services.hermes-agent = {
    enable = true;

    # Upstream's default pre-builds every optional integration -- DingTalk,
    # Feishu, Matrix, Vercel, a speech stack -- for an agent that is 82 MB
    # itself. Taking the minimal build with only the groups this hub uses, and
    # the headless ffmpeg (whose full build reaches clang and llvm for another
    # 1.4 GB), is 1.6 GB against the default's 4.2 GB.
    package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.minimal.override {
      ffmpeg = pkgs.ffmpeg-headless;
      extraDependencyGroups = [
        "anthropic"
        "messaging"
      ];
    };

    # Deployed out of band (decision 18); a Nix path literal would copy the
    # secrets into the world-readable store.
    #
    # Hermes reads its own dotenv, so activation merges these files into
    # $HERMES_HOME/.env rather than systemd passing them to the process.
    # Rotating a secret therefore takes `/run/current-system/activate` before
    # the restart; a restart alone re-reads the old copy.
    environmentFiles = [ "/var/lib/secrets/hermes.env" ];

    # The agent's only way to commit its vault edits: one tool, scoped to the
    # files it names, rather than a shell.
    mcpServers.vault = {
      command = lib.getExe pkgs.custom.vault-mcp;
      env = agentGitIdentity // {
        VAULT_PATH = vault;
      };
    };

    settings = {
      # Where the file and terminal tools operate. Set here rather than via
      # workingDirectory, which the upstream module chowns to the agent's own
      # user and group -- that would lock the vault user out of the vault and
      # stop both the snapshot timer and Obsidian Sync.
      terminal.cwd = vault;

      model = {
        default = "anthropic/claude-opus-5-5";
        # Direct Anthropic rather than a reseller, so the key we hold is the
        # one being billed and capped.
        provider = "anthropic";
      };

      # Telegram shows nothing while a turn runs, so at the 180 s default a
      # turn of a minute or two is silent until the answer lands.
      agent.gateway_notify_interval = 45;

      # Memory is loaded into every prompt, so a save waits for approval over
      # Telegram (`/memory pending`) rather than landing unreviewed (SPEC
      # section 6).
      memory.write_approval = true;

      # A skill file is a persistent instruction store that untrusted input
      # can reach, so the agent does not get nudged into writing them while
      # the review loop is still unproven (SPEC section 6).
      skills.creation_nudge_interval = 0;

      # Telegram is the only inbound human channel and the likeliest path for
      # injected instructions, so it starts without a shell, without skill
      # authoring and without cron. Widen once the review loop has earned it.
      #
      # Naming an MCP server here makes the list an allowlist for servers
      # too; otherwise every enabled server joins it.
      platform_toolsets.telegram = [
        "web"
        "vision"
        "file"
        "todo"
        "memory"
        "vault"
      ];
    };
  };

  # A one-way copy, so memory is readable from any device and versioned with
  # the vault; Hermes itself keeps the files in its own home at mode 0600.
  systemd.paths.hermes-memory-copy = {
    description = "Watch the agent's memory for changes";
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = memoryDir;
  };

  systemd.services.hermes-memory-copy = {
    description = "Copy the agent's memory into the vault";
    environment = agentGitIdentity // {
      HOME = "/var/empty";
    };
    serviceConfig = {
      Type = "oneshot";
      User = cfg.user;
      Group = cfg.group;
      ExecStart = lib.getExe copyMemory;
      # Group-writable, like everything else in the vault.
      UMask = "0007";

      ProtectSystem = "strict";
      ReadWritePaths = [ vault ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  # The module only grants the sandbox write access to workingDirectory.
  systemd.services.hermes-agent.serviceConfig.ReadWritePaths = [ vault ];
}
