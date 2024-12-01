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

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      flake-parts,
      home-manager,
      nix-darwin,
      nixvim,
      mac-app-util,
      ...
    }@inputs:
    let
      inherit (self) outputs;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "i686-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            overlays = [
              outputs.overlays.custom # access my own packages through `pkgs.custom`
              outputs.overlays.modifications
              outputs.overlays.unstable-packages # access unstable packages through `pkgs.unstable`
            ];
          };

          # Custom packages acessible through 'nix build', 'nix shell', etc
          packages = import ./pkgs {
            inputs = inputs';
            inherit pkgs;
          };

          devShells = import ./shell.nix { inherit self pkgs system; };

          formatter = pkgs.nixfmt-rfc-style;

          checks = {
            pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
              src = ./.;
              hooks = {
                nixfmt-rfc-style.enable = true;
              };
            };

            nvim = nixvim.lib.${system}.check.mkTestDerivationFromNixvimModule {
              inherit pkgs;
              module = import ./modules/nvim;
            };
          };
        };

      flake = {
        overlays = import ./overlays { inherit inputs; };

        # Reusable nixos/home-manager modules you might want to export
        # These are usually stuff you would upstream into nixpkgs
        nixosModules = import ./modules/nixos;
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
              system = "x86_64-linux";
            };
            modules = [
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
    };
}
