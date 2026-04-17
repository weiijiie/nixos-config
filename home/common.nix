{
  config,
  outputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./claude-code.nix
    ./git.nix
    ./zellij.nix
    ./zsh.nix
  ];

  options.basePackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default =
      (with pkgs; [
        coreutils
        moreutils
        manix
        wget
        dig
        tree
        mosh
        jq
        yq-go
        tokei
        docker
        kubectl
        ngrok
        tldr
        gcc
        btop
        grpc
        gotools
        delve
        nixd
        nixfmt
        cachix
        ast-grep
        mdcat
        jujutsu
      ])
      ++ [
        outputs.packages.${pkgs.stdenv.hostPlatform.system}.nvim
        pkgs.custom.claude-code-transcripts
        pkgs.llm-agents.rtk
      ]
      ++ (builtins.attrValues pkgs.scripts);
  };

  config = {
    home.packages = config.basePackages;

    home.sessionVariables = {
      EDITOR = "nvim";
      RTK_TELEMETRY_DISABLED = "1";
    };

    # Enable home-manager
    programs.home-manager.enable = true;

    programs = {
      vim = {
        enable = false;

        settings = {
          background = "dark";
        };

        plugins =
          with pkgs;
          with vimPlugins;
          [
            vim-airline
            vim-airline-themes
            vim-numbertoggle
            vim-surround
            vim-commentary
            vim-go
            vim-nix
            quick-scope
            rainbow
            ale
            nerdtree
            custom.vim-colors-xcode
          ];

        extraConfig = builtins.readFile ../dotfiles/.vimrc;
      };

      ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks."*".compression = true;
      };

      fzf = {
        enable = true;
      };

      bat = {
        enable = true;
        config = {
          theme = "Catppuccin Macchiato";
        };

        themes =
          let
            catppuccinSrc = pkgs.fetchFromGitHub {
              owner = "catppuccin";
              repo = "bat";
              rev = "d2bbee4f7e7d5bac63c054e4d8eca57954b31471";
              sha256 = "sha256-x1yqPCWuoBSx/cI94eA+AWwhiSA42cLNUOFJl7qjhmw=";
            };
          in
          builtins.listToAttrs (
            builtins.map
              (
                e:
                let
                  name = "Catppuccin ${e}";
                in
                {
                  inherit name;
                  value = {
                    src = catppuccinSrc;
                    file = "themes/${name}.tmTheme";
                  };
                }
              )
              [
                "Frappe"
                "Latte"
                "Macchiato"
                "Mocha"
              ]
          );
      };

      eza = {
        enable = true;
      };

      direnv = {
        enable = true;
        stdlib = ''
          : "''${XDG_CACHE_HOME:="''${HOME}/.cache"}"
          declare -A direnv_layout_dirs
          direnv_layout_dir() {
              local hash path
              echo "''${direnv_layout_dirs[$PWD]:=$(
                  hash="$(sha1sum - <<< "$PWD")"
                  path="''${PWD//[^a-zA-Z0-9]/-}"
                  echo "''${XDG_CACHE_HOME}/direnv/layouts/''${hash}''${path}"
              )}"
          }
        '';
        enableZshIntegration = true;
        nix-direnv = {
          enable = true;
        };
      };

      autojump = {
        enable = true;
        enableZshIntegration = true;
      };

      ranger = {
        enable = true;
      };

      go = {
        enable = true;
      };

      gpg.enable = true;
    };

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    home.stateVersion = "24.05";
  };
}
