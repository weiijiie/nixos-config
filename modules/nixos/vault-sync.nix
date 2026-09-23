# Obsidian Sync for the vault, through the official headless client.
#
# Logging in and linking the remote vault are one-time manual steps
# (docs/personal-agent/PHASE-0.md). The sync settings are declared here and
# reapplied on every start, so a hand-run `ob sync-config` does not last.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.vaultSync;
  ob = lib.getExe' cfg.package "ob";
in
{
  options.services.vaultSync = {
    enable = lib.mkEnableOption "Obsidian Sync of the vault";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.custom.obsidian-headless;
      defaultText = lib.literalExpression "pkgs.custom.obsidian-headless";
      description = "The `ob` client.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "vault";
      description = ''
        Owner of the vault and the identity the sync client runs as. Services
        that need vault access join this user's group rather than running as it.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "vault";
      description = "Group granting read/write access to the vault.";
    };

    path = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/vault";
      description = "Where the vault lives on this host.";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/obsidian-sync";
      description = ''
        The vault user's home, where the client keeps its login token, the
        vault's encryption key and its per-vault settings. The service stays
        inactive until an empty `armed` file exists here.
      '';
    };

    fileTypes = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "image"
          "audio"
          "video"
          "pdf"
          "unsupported"
        ]
      );
      # Anything outside these categories is otherwise dropped without a
      # trace, leaving notes that link to files the hub never received.
      default = [
        "image"
        "audio"
        "video"
        "pdf"
        "unsupported"
      ];
      description = "Attachment categories to sync, besides notes.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.stateDir;
      description = "Obsidian vault owner";
    };

    users.groups.${cfg.group} = { };

    environment.systemPackages = [ cfg.package ];

    systemd.tmpfiles.rules = [
      # Holds the credentials, so closed even to the vault group.
      "d ${cfg.stateDir} 0700 ${cfg.user} ${cfg.group} -"
      # Setgid, so files the client downloads land in the vault group.
      "d ${cfg.path} 2770 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.vault-sync = {
      description = "Obsidian Sync of the vault";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      # Starting against a vault that was never linked only retry-loops.
      unitConfig.ConditionPathExists = "${cfg.stateDir}/armed";

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;

        # The hub runs no editor, so it syncs no editor settings.
        ExecStartPre = lib.escapeShellArgs [
          ob
          "sync-config"
          "--path"
          cfg.path
          "--conflict-strategy"
          "merge"
          "--file-types"
          (lib.concatStringsSep "," cfg.fileTypes)
          "--configs"
          ""
        ];
        ExecStart = "${ob} sync --continuous --path ${cfg.path}";

        # Group-writable downloads, so the agent can edit a note the client
        # fetched rather than only replace it.
        UMask = "0007";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };
  };
}
