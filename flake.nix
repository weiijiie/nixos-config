{
  description = "Weijie's NixOS configurations";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      nixvim,
      mac-app-util,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    in
    {
      # Your custom packages
      # Acessible through 'nix build', 'nix shell', etc
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./pkgs { inherit pkgs; }
      );

      # Devshell for bootstrapping
      # Acessible through 'nix develop' or 'nix-shell' (legacy)
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./shell.nix { inherit pkgs; }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.nixfmt-rfc-style
      );

      # Your custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };

      # Reusable nixos modules you might want to export
      # These are usually stuff you would upstream into nixpkgs
      nixosModules = import ./modules/nixos;

      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      homeManagerModules = import ./modules/home-manager;

      # NixOS configuration entrypoint
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        # old windows laptop
        aldehyde = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;
          };
          modules = [ ./hosts/aldehyde ];
        };
        # framework laptop
        tinker = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs outputs;
          };
          modules = [ ./hosts/tinker ];
        };
      };

      darwinConfigurations = {
        # work laptop
        mixpanel = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {
            inherit inputs outputs;
          };
          modules = [
            mac-app-util.darwinModules.default
            ./hosts/mixpanel
          ];
        };
      };

      # Standalone home-manager configuration entrypoint
      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations = {
        "weijie@aldehyde" = home-manager.lib.homeManagerConfiguration {
          # Home-manager requires 'pkgs' instance
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
          };
          modules = [
            nixvim.homeManagerModules.nixvim
            ./home/common.nix
            ./home/personal.nix
            {
              home = {
                username = "weijie";
                homeDirectory = "/home/weijie";
              };
            }
          ];
        };
        "wj@tinker" = home-manager.lib.homeManagerConfiguration {
          # Home-manager requires 'pkgs' instance
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
          };
          modules = [
            nixvim.homeManagerModules.nixvim
            ./home/common.nix
            ./home/personal.nix
            {
              home = {
                username = "wj";
                homeDirectory = "/home/wj";
              };
            }
          ];
        };
        "weijiehuang@mixpanel" = home-manager.lib.homeManagerConfiguration {
          # Home-manager requires 'pkgs' instance
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          extraSpecialArgs = {
            inherit inputs outputs;
          };
          modules = [
            nixvim.homeManagerModules.nixvim
            mac-app-util.homeManagerModules.default
            ./home/common.nix
            ./home/macos/programs.nix
            ./home/mixpanel/macbook.nix
            {
              home = {
                username = "weijiehuang";
                homeDirectory = "/Users/weijiehuang";
              };
              programs.git = {
                userEmail = nixpkgs.lib.mkForce "weijie.huang@mixpanel.com";
                userName = nixpkgs.lib.mkForce "weijie-mxpl";
              };
            }
          ];
        };
        "weijie_huang@devbox-5372" = home-manager.lib.homeManagerConfiguration {
          # Home-manager requires 'pkgs' instance
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs outputs;
          };
          modules = [
            nixvim.homeManagerModules.nixvim
            ./home/mixpanel/devbox.nix
            {
              home = {
                username = "weijie_huang";
                homeDirectory = "/home/weijie_huang";
              };
            }
          ];
        };
      };
    };
}
