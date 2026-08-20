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

  # Journal dates and brief timings key off this; revisit before Phase 1.
  time.timeZone = "Etc/UTC";

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

    vaultSync = {
      enable = true;
      localDevice = "io";
    };

    vaultGit.enable = true;
  };

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
