{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix

    outputs.nixosModules.vault-sync
    outputs.nixosModules.vault-git

    ./hermes.nix
    ./hermes-cron.nix

    # No hardware to scan on a VPS; virtio is the whole hardware story.
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deploys arrive over ssh as wj, whose locally-built store paths carry
      # no signature; wheel already holds passwordless root here.
      trusted-users = [ "@wheel" ];
    };

    # Deduplicate and optimize nix store
    optimise.automatic = true;

    # 40 GB disk that nothing prunes by hand.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  networking = {
    hostName = "io";
    useDHCP = lib.mkDefault true;
  };

  # Daily-note filenames, the morning brief and snapshot timestamps all read
  # this, so it tracks where I am rather than where the box is.
  time.timeZone = "America/Los_Angeles";

  services = {
    openssh = {
      enable = true;
      settings = {
        # Key-only root is how nixos-anywhere installs and how
        # `nixos-rebuild --target-host` deploys.
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };

    # Lets the provider's console shut the VM down gracefully.
    qemuGuest.enable = true;

    vaultSync.enable = true;

    vaultGit.enable = true;
  };

  # The hub is an appliance, not a workstation: deploys come from tinker, and
  # dev work belongs on a devbox. home/common.nix's full list is 8.4 GB of
  # desktop tooling, which also matters where the system ships as an image
  # (hosts/io/oci.nix).
  home-manager.users.wj.basePackages = lib.mkForce (
    with pkgs;
    [
      coreutils
      git
      jq
    ]
  );

  programs = {
    zsh.enable = true;

    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };

  environment = {
    systemPackages = [ pkgs.git ];
    shells = [ pkgs.zsh ];
  };

  users.defaultUserShell = pkgs.zsh;

  users.users = {
    root.openssh.authorizedKeys.keys = [ (builtins.readFile ../../home/ssh.pub) ];

    wj = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        config.services.vaultSync.group
      ];
      openssh.authorizedKeys.keys = [ (builtins.readFile ../../home/ssh.pub) ];
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "26.05";
}
