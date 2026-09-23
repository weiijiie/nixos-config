# Server-side git history for the vault: the review and rollback layer.
#
# Human edits arrive through the sync client with no commit attached, so a
# timer snapshots them. The agent commits its own edits with real messages, which is
# what makes every agent change a reviewable diff (SPEC section 4).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.vaultGit;

  gitignore = pkgs.writeText "vault-gitignore" ''
    ${lib.concatStringsSep "\n" cfg.ignore}
  '';

  snapshot = pkgs.writeShellApplication {
    name = "vault-snapshot";
    runtimeInputs = [
      pkgs.git
      pkgs.coreutils
    ];
    text = ''
      cd ${lib.escapeShellArg cfg.path}

      git rev-parse --git-dir >/dev/null 2>&1 || git init -q -b main
      # The agent commits here too, as another member of the vault group.
      git config core.sharedRepository group
      install -m 0644 ${gitignore} .gitignore

      git add -A
      if git diff --cached --quiet; then
        exit 0
      fi
      git commit -q -m "human edits @ $(date -Iseconds)"
    '';
  };
in
{
  options.services.vaultGit = {
    enable = lib.mkEnableOption "git history and snapshot timer for the vault";

    path = lib.mkOption {
      type = lib.types.path;
      default = config.services.vaultSync.path;
      defaultText = lib.literalExpression "config.services.vaultSync.path";
      description = "The vault to version.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.services.vaultSync.user;
      defaultText = lib.literalExpression "config.services.vaultSync.user";
      description = "Identity the snapshots are made as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = config.services.vaultSync.group;
      defaultText = lib.literalExpression "config.services.vaultSync.group";
      description = "Group the snapshot service runs under.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = ''
        How often to snapshot, as a systemd time span. Sets the floor on how
        much work an accidental deletion can cost.
      '';
    };

    ignore = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # The sync client's lock, recreated on every start.
        ".obsidian/"
        ".trash/"
      ];
      description = "Patterns written to the vault's .gitignore.";
    };

    author = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "vault snapshot";
        description = "Commit author name for timer-made snapshots.";
      };

      email = lib.mkOption {
        type = lib.types.str;
        default = "vault@${config.networking.hostName}";
        defaultText = lib.literalExpression ''"vault@''${config.networking.hostName}"'';
        description = "Commit author email for timer-made snapshots.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # git refuses a repo another user owns unless it is marked safe, which
    # would keep the rest of the vault group from committing.
    programs.git = {
      enable = true;
      config.safe.directory = cfg.path;
    };

    systemd.services.vault-snapshot = {
      description = "Snapshot vault edits into git";

      environment = {
        GIT_CONFIG_NOSYSTEM = "1";
        GIT_AUTHOR_NAME = cfg.author.name;
        GIT_AUTHOR_EMAIL = cfg.author.email;
        GIT_COMMITTER_NAME = cfg.author.name;
        GIT_COMMITTER_EMAIL = cfg.author.email;
        # git reads ~/.gitconfig; keep snapshots independent of the user's.
        HOME = "/var/empty";
      };

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = lib.getExe snapshot;

        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.path ];
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.timers.vault-snapshot = {
      description = "Snapshot vault edits into git";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
      };
    };
  };
}
