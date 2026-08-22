# Syncthing topology for the Obsidian vault.
#
# Device IDs, the folder ID and the on-host path are declared here once. The
# peers outside this flake (Windows-native Syncthing on the laptop, the Android
# app) are paired by hand against these values.
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.vaultSync;

  paired = lib.filterAttrs (name: device: name != cfg.localDevice && device.id != null) cfg.devices;
  unpaired = lib.attrNames (
    lib.filterAttrs (name: device: name != cfg.localDevice && device.id == null) cfg.devices
  );
in
{
  options.services.vaultSync = {
    enable = lib.mkEnableOption "Syncthing sync of the Obsidian vault";

    user = lib.mkOption {
      type = lib.types.str;
      default = "vault";
      description = ''
        Owner of the vault and the identity Syncthing runs as. Services that
        need vault access join this user's group rather than running as it.
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
      default = "/var/lib/syncthing";
      description = "Syncthing's own config, keys and database.";
    };

    localDevice = lib.mkOption {
      type = lib.types.str;
      description = ''
        This host's key in `devices`. Excluded when sharing the folder, since a
        device never shares with itself.
      '';
    };

    devices = lib.mkOption {
      description = ''
        Every device in the mesh. A null id means the device has not been paired
        yet; it is left out of the generated config until its id is filled in.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              id = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Syncthing device ID, from `syncthing device-id`.";
              };

              name = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Display name in the Syncthing UI.";
              };
            };
          }
        )
      );
      default = {
        io.name = "io (hub)";
        framework = {
          name = "framework (windows)";
          id = "U2GVBAP-5WR2IYA-XZEX5Q2-KTBQGL3-6WBHESY-REPB6OU-VIPQSMP-BPK2OQH";
        };
        phone.name = "phone (android)";
      };
    };

    folder = {
      id = lib.mkOption {
        type = lib.types.str;
        default = "obsidian-vault";
        description = "Folder ID. Must match on every device.";
      };

      label = lib.mkOption {
        type = lib.types.str;
        default = "Obsidian Vault";
        description = "Folder label in the Syncthing UI.";
      };
    };

    ignorePatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # Obsidian config travels as its own git repo (SPEC section 4).
        "/.obsidian"
        # The history layer is hub-local and must never reach a device.
        "/.git"
        "/.stversions"
        "/.trash"
      ];
      description = "Syncthing ignore patterns, written to the folder's .stignore.";
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = lib.optional (unpaired != [ ]) (
      "services.vaultSync: no device ID for "
      + lib.concatStringsSep ", " unpaired
      + ". Those peers do not sync until their IDs are filled in."
    );

    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.stateDir;
      createHome = true;
      description = "Obsidian vault owner";
    };

    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.path} 0750 ${cfg.user} ${cfg.group} -"
    ];

    services.syncthing = {
      enable = true;
      inherit (cfg) user group;
      dataDir = cfg.stateDir;
      openDefaultPorts = true;

      # The flake is the source of truth: anything added through the web UI is
      # reverted on restart.
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = lib.mapAttrs (_: device: { inherit (device) id name; }) paired;

        folders.${cfg.folder.id} = {
          inherit (cfg) path ignorePatterns;
          inherit (cfg.folder) label;
          devices = lib.attrNames paired;
        };

        options.urAccepted = -1;
      };
    };
  };
}
