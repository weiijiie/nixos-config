{
  outputs,
  lib,
  pkgs,
  ...
}:
let
  zellij-zellaude = pkgs.fetchurl {
    url = "https://github.com/ishefi/zellaude/releases/latest/download/zellaude.wasm";
    hash = "sha256-BVz0mmAVN3MrbF/uz1cs5Nnuz9zdH//3wKrShuNOsoo=";
  };

  zshCustomDir = pkgs.stdenv.mkDerivation {
    name = "ohmyzsh-custom-dir";
    src = ../dotfiles/ohmyzsh-custom;
    installPhase = ''
      mkdir -p $out/
      cp -rv $src/* $out/
    '';
  };
in
{
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.custom
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
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
    };
  };

  home.packages =
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
      bottom
      grpc
      gotools
      delve
      nixd
      nixfmt-rfc-style
      cachix
    ])
    ++ [ outputs.packages.${pkgs.stdenv.hostPlatform.system}.nvim ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  programs = {
    git = {
      enable = true;

      settings = {
        alias = {
          ll = "log --pretty=format:'%C(yellow)%h %C(green)%ad%Cred%d %Creset%s%Cblue [%cn]' --decorate --date=short --graph";
          l = "log --all --oneline --graph --decorate";
          cidiff = ''log --date=format:"%Y-%m-%d %H:%M" --pretty="%C(cyan)%h%Creset %C(blue)[%ad]%Creset: %C(green)%s%Creset"'';
        };

        merge = {
          conflictstyle = "diff3";
        };

        diff = {
          colorMoved = "default";
        };
      };
    };

    delta = {
      enable = true;
      enableGitIntegration = true;

      options = {
        navigate = true;
        side-by-side = true;
        theme = "Catppuccin Macchiato";
        features = "decorations";

        decorations = {
          file-style = "lightcoral bold ul";
          file-decoration-style = "blue ul";
          file-modified-label = "#";
          hunk-header-style = "line-number syntax bold";
          hunk-header-decoration-style = "lightcoral box";
          hunk-header-line-number-style = "lightcoral ul";
          hunk-label = "";
          line-numbers-zero-style = "lightslategray";
        };
      };
    };

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

    zellij = {
      enable = true;
      # enableZshIntegration = true;
      # attachExistingSession = true;
      # exitShellOnExit = true;
      settings = {
        default_mode = "locked";
        default_shell = "zsh";
      };
      extraConfig = ''
        // Overrides: bare keys for mode switching, actions return to locked
        keybinds {
          pane {
            bind "p" { SwitchToMode "normal"; }
            bind "d" { NewPane "Down"; SwitchToMode "locked"; }
            bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "locked"; }
            bind "f" { ToggleFocusFullscreen; SwitchToMode "locked"; }
            bind "i" { TogglePanePinned; SwitchToMode "locked"; }
            bind "n" { NewPane; SwitchToMode "locked"; }
            bind "r" { NewPane "Right"; SwitchToMode "locked"; }
            bind "w" { ToggleFloatingPanes; SwitchToMode "locked"; }
            bind "x" { CloseFocus; SwitchToMode "locked"; }
            bind "z" { TogglePaneFrames; SwitchToMode "locked"; }
          }
          tab {
            bind "t" { SwitchToMode "normal"; }
            bind "1" { GoToTab 1; SwitchToMode "locked"; }
            bind "2" { GoToTab 2; SwitchToMode "locked"; }
            bind "3" { GoToTab 3; SwitchToMode "locked"; }
            bind "4" { GoToTab 4; SwitchToMode "locked"; }
            bind "5" { GoToTab 5; SwitchToMode "locked"; }
            bind "6" { GoToTab 6; SwitchToMode "locked"; }
            bind "7" { GoToTab 7; SwitchToMode "locked"; }
            bind "8" { GoToTab 8; SwitchToMode "locked"; }
            bind "9" { GoToTab 9; SwitchToMode "locked"; }
            bind "[" { BreakPaneLeft; SwitchToMode "locked"; }
            bind "]" { BreakPaneRight; SwitchToMode "locked"; }
            bind "b" { BreakPane; SwitchToMode "locked"; }
            bind "n" { NewTab; SwitchToMode "locked"; }
            bind "s" { ToggleActiveSyncTab; SwitchToMode "locked"; }
            bind "x" { CloseTab; SwitchToMode "locked"; }
          }
          resize {
            bind "r" { SwitchToMode "normal"; }
          }
          move {
            bind "m" { SwitchToMode "normal"; }
          }
          scroll {
            bind "s" { SwitchToMode "normal"; }
            bind "e" { EditScrollback; SwitchToMode "locked"; }
          }
          session {
            bind "o" { SwitchToMode "normal"; }
            bind "a" {
              LaunchOrFocusPlugin "zellij:about" {
                floating true
                move_to_focused_tab true
              }
              SwitchToMode "locked"
            }
            bind "c" {
              LaunchOrFocusPlugin "configuration" {
                floating true
                move_to_focused_tab true
              }
              SwitchToMode "locked"
            }
            bind "p" {
              LaunchOrFocusPlugin "plugin-manager" {
                floating true
                move_to_focused_tab true
              }
              SwitchToMode "locked"
            }
            bind "w" {
              LaunchOrFocusPlugin "session-manager" {
                floating true
                move_to_focused_tab true
              }
              SwitchToMode "locked"
            }
          }
          shared_except "locked" "entersearch" {
            bind "enter" { SwitchToMode "locked"; }
          }
          shared_except "locked" "entersearch" "renametab" "renamepane" {
            bind "esc" { SwitchToMode "locked"; }
          }
          shared_except "locked" "entersearch" "renametab" "renamepane" "move" {
            bind "m" { SwitchToMode "move"; }
          }
          shared_except "locked" "entersearch" "search" "renametab" "renamepane" "session" {
            bind "o" { SwitchToMode "session"; }
          }
          shared_except "locked" "tab" "entersearch" "renametab" "renamepane" {
            bind "t" { SwitchToMode "tab"; }
          }
          shared_except "locked" "tab" "scroll" "entersearch" "renametab" "renamepane" {
            bind "s" { SwitchToMode "scroll"; }
          }
          shared_among "normal" "resize" "tab" "scroll" "prompt" "tmux" {
            bind "p" { SwitchToMode "pane"; }
          }
          shared_except "locked" "resize" "pane" "tab" "entersearch" "renametab" "renamepane" {
            bind "r" { SwitchToMode "resize"; }
          }
          shared_among "scroll" "search" {
            bind "Ctrl c" { ScrollToBottom; SwitchToMode "locked"; }
          }
          // Ctrl+h/l for zellij pane navigation in all modes
          locked {
            bind "Ctrl h" { MoveFocusOrTab "left"; }
            bind "Ctrl l" { MoveFocusOrTab "right"; }
          }
          shared_except "locked" {
            bind "Ctrl h" { MoveFocusOrTab "left"; }
            bind "Ctrl j" { MoveFocus "down"; }
            bind "Ctrl k" { MoveFocus "up"; }
            bind "Ctrl l" { MoveFocusOrTab "right"; }
          }
        }
      '';
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history.size = 65536;

      shellAliases = { };

      initContent = lib.mkMerge [
        (
          with pkgs;
          lib.mkBefore ''
            # resolve issues where zsh-vi-mode overrides fzf key bindings
            zvm_after_init() {
              if [[ $options[zle] = on ]]; then
                . ${fzf}/share/fzf/completion.zsh
                . ${fzf}/share/fzf/key-bindings.zsh
              fi

              source ${zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
            }
          ''
        )

        (lib.mkAfter ''
          if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then . $HOME/.nix-profile/etc/profile.d/nix.sh; fi

          path+=("''${HOME}/.local/bin")
          path+=("''${HOME}/go/bin")

          # zsh-autosuggestions configuration
          ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=244"
          ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=25

          # addding helper functions to fpath
          fpath=( "${zshCustomDir}/helpers" "''${fpath[@]}" )
          autoload -Uz ${zshCustomDir}/helpers/*

          # ctrl+j for "jq-zsh-plugin": https://github.com/reegnz/jq-zsh-plugin
          bindkey -v '^j' jq-complete

          # fix for zsh-autocomplete: https://nixos.wiki/wiki/Zsh#Troubleshooting
          if [[ "''${terminfo[kcuu1]}" != "" ]]; then
            bindkey -v "''${terminfo[kcuu1]}" up-line-or-search
          else
            bindkey -v '^[[A' up-line-or-search
          fi

          # kitty SSH issue workaround: https://wiki.archlinux.org/title/Kitty#Terminal_issues_with_SSH
          [ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"

          compdef __fnmcd=cd
        '')
      ];

      oh-my-zsh = {
        enable = true;
        extraConfig = ''
          ZSH_CUSTOM="${zshCustomDir}"
        '';

        plugins = [
          "git"
          "docker"
          "aws"
          "gcloud"
          "kubectl"
          "colored-man-pages"
          "fzf"
          "gh"
        ];
      };

      plugins = [
        {
          name = "vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
        {
          name = "powerlevel10k-config";
          src = lib.cleanSource ../dotfiles;
          file = ".p10k.zsh";
        }
        {
          name = "you-should-use";
          src = pkgs.zsh-you-should-use;
          file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
        }
        {
          name = "jq-zsh-plugin";
          src = pkgs.fetchFromGitHub {
            owner = "reegnz";
            repo = "jq-zsh-plugin";
            rev = "48befbcd91229e48171d4aac5215da205c1f497e";
            sha256 = "sha256-q/xQZ850kifmd8rCMW+aAEhuA43vB9ZAW22sss9e4SE=";
          };
          file = "jq.plugin.zsh";
        }
      ];
    };

    gpg.enable = true;
  };

  # Zellij layout with zellaude tab bar
  xdg.configFile."zellij/layouts/default.kdl".text = ''
    layout {
      default_tab_template {
        pane size=1 borderless=true {
          plugin location="file:${zellij-zellaude}"
        }
        children
        pane size=1 borderless=true {
          plugin location="status-bar"
        }
      }
    }
  '';

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";
}
