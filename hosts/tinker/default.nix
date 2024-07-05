{ inputs, outputs, lib, config, pkgs, modulesPath, ... }: {
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
    ./hardware-configuration.nix

    # If you want to use modules from your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    "${modulesPath}/profiles/minimal.nix"
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;

      packageOverrides = pkgs: {
        wayland = pkgs.wayland.override {
          # ran into issues where wayland build step tries to use graphviz to generate docs,
          # and graphviz errors with "Could not find/open font". just skipping the documentation
          # generation for now to address this.
          withDocumentation = false;
        };
      };
    };
  };

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
      # Deduplicate and optimize nix store
      auto-optimise-store = true;
    };
  };

  networking.hostName = "tinker";

  wsl = {
    enable = true;
    defaultUser = "wj";
    startMenuLaunchers = true;
    nativeSystemd = true;
    
    wslConf = {
      automount.root = "/mnt";
    };

    # Enable native Docker support
    docker-native.enable = true;

    # Enable integration with Docker Desktop (needs to be installed)
    # docker-desktop.enable = true;
  };

  programs = {
    zsh.enable = true;
    vim.defaultEditor = true;
    # nix-ld is a workaround for remote vs-code to work, as per: https://nixos.wiki/wiki/Visual_Studio_Code#Remote_WSL
    nix-ld.enable = true;
  };

  environment = {
    systemPackages = [
      pkgs.python3
      pkgs.perl
    ];

    shells = [ pkgs.zsh ];

    variables = 
    let
      # witchcrafty workaround to IFD being blocked, see: https://github.com/Mic92/nix-ld/issues/19 
      nix-ld-so = pkgs.runCommand "ld.so" {} ''
        ln -s "$(cat '${pkgs.stdenv.cc}/nix-support/dynamic-linker')" $out 
      '';
    in
    {
      # NIX_LD_LIBRARY_PATH = lib.makeLibraryPath [
      #   pkgs.stdenv.cc.cc
      # ];
      # NIX_LD = toString nix-ld-so;
    };
  };

  users.defaultUserShell = pkgs.zsh;

  users.users = {
    wj = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        (builtins.readFile ../../home/ssh.pub)
      ];
    };
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
      };
    };
  };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
  ];
  
  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
